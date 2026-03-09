import fs from "node:fs/promises";
import http from "node:http";
import path from "node:path";
import { fileURLToPath } from "node:url";

import { ContentStore } from "./lib/content-store.mjs";
import {
	buildPublicAssetUrl,
	buildSignedAssetUrl,
	createSignedPayloadToken,
	verifyAssetSignature,
	verifySignedPayloadToken
} from "./lib/signing.mjs";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

const port = Number(process.env.PORT ?? 8787);
const baseUrl = process.env.CONTENT_BASE_URL ?? `http://localhost:${port}`;
const contentRoot = path.resolve(__dirname, process.env.CONTENT_ROOT ?? "../../dist/content");
const entitlementsPath = path.resolve(
	__dirname,
	process.env.ENTITLEMENTS_FILE ?? "./data/entitlements.json"
);
const playerStatePath = path.resolve(
	__dirname,
	process.env.PLAYER_STATE_FILE ?? "./data/player_state.json"
);
const signedUrlTtlSeconds = Number(process.env.SIGNED_URL_TTL_SECONDS ?? 300);
const dailyCompletionTokenTtlSeconds = Number(process.env.DAILY_COMPLETION_TOKEN_TTL_SECONDS ?? 21600);
const signingSecret = process.env.CONTENT_SIGNING_SECRET ?? "dev-change-me";

const store = new ContentStore({
	contentRoot,
	entitlementsPath,
	playerStatePath
});

const mimeTypes = {
	".json": "application/json; charset=utf-8",
	".webp": "image/webp",
	".png": "image/png",
	".jpg": "image/jpeg",
	".jpeg": "image/jpeg"
};

const server = http.createServer(async (request, response) => {
	try {
		applyCommonHeaders(response);

		if (request.method === "OPTIONS") {
			response.writeHead(204);
			response.end();
			return;
		}

		const url = new URL(request.url ?? "/", baseUrl);

		if (request.method === "GET" && url.pathname === "/health") {
			return sendJson(response, 200, {
				ok: true,
				service: "content-api",
				content_root: contentRoot
			});
		}

		if (request.method === "GET" && url.pathname === "/v1/entitlements") {
			const appUserId = getAppUserId({ request, url });
			const entitlements = await store.readEntitlements(appUserId);
			return sendJson(response, 200, entitlements);
		}

		if (request.method === "GET" && url.pathname === "/v1/catalog") {
			const appUserId = getAppUserId({ request, url });
			const entitlements = await store.readEntitlements(appUserId);
			const catalog = await store.buildCatalogForUser(entitlements);
			return sendJson(response, 200, {
				...catalog,
				content_delivery: {
					mode: "local-asset-gateway",
					sign_endpoint: "/v1/content/sign",
					signed_url_ttl_seconds: signedUrlTtlSeconds
				}
			});
		}

		if (request.method === "GET" && url.pathname.startsWith("/v1/catalog/daily/")) {
			const appUserId = getAppUserId({ request, url });
			const entitlements = await store.readEntitlements(appUserId);
			const date = decodeURIComponent(url.pathname.split("/").pop() ?? "");
			if (date === "") {
				return sendJson(response, 400, { error: "missing_date" });
			}
			const daily = await store.readDailyManifest(date);
			if (Object.keys(daily).length === 0) {
				return sendJson(response, 404, { error: "daily_not_found" });
			}
			if (!store.canAccessTier(daily.tier, entitlements)) {
				return sendJson(response, 403, { error: "not_entitled" });
			}
			return sendJson(response, 200, {
				...daily,
				completion_session: buildDailyCompletionSession({
					appUserId,
					dailyManifest: daily
				})
			});
		}

		if (request.method === "POST" && url.pathname === "/v1/content/sign") {
			const body = await readJsonBody(request);
			const appUserId = getAppUserId({ request, url, body });
			const entitlements = await store.readEntitlements(appUserId);
			const requestedPaths = Array.isArray(body.asset_paths)
				? body.asset_paths
				: Array.isArray(body.paths)
					? body.paths
					: [];

			if (requestedPaths.length === 0) {
				return sendJson(response, 400, { error: "asset_paths_required" });
			}

			const expiresAt = Math.floor(Date.now() / 1000) + signedUrlTtlSeconds;
			const urls = {};

			for (const rawAssetPath of requestedPaths) {
				const assetPath = store.normalizeAssetPath(rawAssetPath);
				const exists = await store.fileExists(assetPath);
				if (!exists) {
					urls[assetPath] = { error: "asset_not_found" };
					continue;
				}

				const isPublic = await store.isPathPublic(assetPath);
				if (isPublic) {
					urls[assetPath] = {
						access: "public",
						url: buildPublicAssetUrl({ baseUrl, assetPath })
					};
					continue;
				}

				const isAccessible = await store.isPathAccessibleForEntitlements(assetPath, entitlements);
				if (!isAccessible) {
					urls[assetPath] = { error: "not_entitled" };
					continue;
				}

				urls[assetPath] = {
					access: "signed",
					url: buildSignedAssetUrl({
						baseUrl,
						assetPath,
						expiresAt,
						secret: signingSecret
					}),
					expires_at: new Date(expiresAt * 1000).toISOString()
				};
			}

			return sendJson(response, 200, {
				app_user_id: appUserId,
				urls
			});
		}

		if (request.method === "POST" && url.pathname === "/v1/rewards/daily/claim") {
			const body = await readJsonBody(request);
			const appUserId = getAppUserId({ request, url, body });
			const entitlements = await store.readEntitlements(appUserId);
			const date = String(body.date ?? body.challenge_date ?? "").trim();
			if (date === "") {
				return sendJson(response, 400, { error: "missing_date" });
			}

			const daily = await store.readDailyManifest(date);
			if (Object.keys(daily).length === 0) {
				return sendJson(response, 404, { error: "daily_not_found" });
			}
			if (!store.canAccessTier(daily.tier, entitlements)) {
				return sendJson(response, 403, { error: "not_entitled" });
			}

			const claimResult = await store.claimDailyReward(appUserId, daily);
			if (claimResult.not_completed) {
				const currentEntitlements = await store.readEntitlements(appUserId);
				return sendJson(response, 200, {
					ok: false,
					reason: "challenge_not_completed",
					entitlements: currentEntitlements
				});
			}
			const updatedEntitlements = await store.readEntitlements(appUserId);
			return sendJson(response, 200, {
				ok: true,
				already_claimed: Boolean(claimResult.already_claimed),
				claim: claimResult.claim,
				entitlements: updatedEntitlements
			});
		}

		if (request.method === "POST" && url.pathname === "/v1/challenges/daily/complete") {
			const body = await readJsonBody(request);
			const appUserId = getAppUserId({ request, url, body });
			const entitlements = await store.readEntitlements(appUserId);
			const date = String(body.date ?? body.challenge_date ?? "").trim();
			if (date === "") {
				return sendJson(response, 400, { error: "missing_date" });
			}

			const daily = await store.readDailyManifest(date);
			if (Object.keys(daily).length === 0) {
				return sendJson(response, 404, { error: "daily_not_found" });
			}
			if (!store.canAccessTier(daily.tier, entitlements)) {
				return sendJson(response, 403, { error: "not_entitled" });
			}
			const completionToken = String(body.completion_token ?? body.challenge_token ?? "").trim();
			if (completionToken === "") {
				return sendJson(response, 400, { error: "missing_completion_token" });
			}
			const verification = verifySignedPayloadToken({
				secret: signingSecret,
				token: completionToken
			});
			if (!verification.ok) {
				return sendJson(response, 403, {
					error: "invalid_completion_token",
					reason: verification.reason
				});
			}
			if (!isValidDailyCompletionPayload(verification.payload, { appUserId, dailyManifest: daily })) {
				return sendJson(response, 403, {
					error: "invalid_completion_token",
					reason: "challenge_mismatch"
				});
			}

			const completionResult = await store.recordDailyCompletion(appUserId, daily, body.stats ?? {});
			const updatedEntitlements = await store.readEntitlements(appUserId);
			return sendJson(response, 200, {
				ok: true,
				already_completed: Boolean(completionResult.already_completed),
				completion: completionResult.completion,
				entitlements: updatedEntitlements
			});
		}

		if (request.method === "GET" && url.pathname === "/content/file") {
			const assetPath = store.normalizeAssetPath(url.searchParams.get("path"));
			if (assetPath === "") {
				return sendJson(response, 400, { error: "missing_path" });
			}

			const exists = await store.fileExists(assetPath);
			if (!exists) {
				return sendJson(response, 404, { error: "asset_not_found" });
			}

			const isPublic = await store.isPathPublic(assetPath);
			if (!isPublic) {
				const expires = Number(url.searchParams.get("expires") ?? 0);
				const signature = url.searchParams.get("sig") ?? "";
				const isExpired = !Number.isFinite(expires) || expires <= Math.floor(Date.now() / 1000);
				const signatureValid = verifyAssetSignature({
					secret: signingSecret,
					assetPath,
					expiresAt: expires,
					signature
				});

				if (isExpired || !signatureValid) {
					return sendJson(response, 403, { error: "invalid_signature" });
				}
			}

			const asset = await store.readAsset(assetPath);
			const contentType = mimeTypes[path.extname(assetPath).toLowerCase()] ?? "application/octet-stream";
			const cacheControl = assetPath.endsWith(".json")
				? "public, max-age=300"
				: "public, max-age=31536000, immutable";

			response.writeHead(200, {
				"Content-Type": contentType,
				"Content-Length": String(asset.size),
				"Cache-Control": cacheControl
			});
			response.end(asset.buffer);
			return;
		}

		sendJson(response, 404, { error: "not_found" });
	} catch (error) {
		sendJson(response, 500, {
			error: "internal_error",
			message: error instanceof Error ? error.message : "Unknown error"
		});
	}
});

ensureContentRoot().then(() => {
	server.listen(port, () => {
		console.log(`Content API listening on ${baseUrl}`);
		console.log(`Content root: ${contentRoot}`);
		console.log(`Player state: ${playerStatePath}`);
	});
});

async function ensureContentRoot() {
	await fs.mkdir(contentRoot, { recursive: true });
}

function applyCommonHeaders(response) {
	response.setHeader("Access-Control-Allow-Origin", "*");
	response.setHeader("Access-Control-Allow-Methods", "GET,POST,OPTIONS");
	response.setHeader("Access-Control-Allow-Headers", "Content-Type, Authorization, X-App-User-Id");
}

function getAppUserId({ request, url, body = null }) {
	const authHeader = request.headers.authorization ?? "";
	if (authHeader.startsWith("Bearer ")) {
		return authHeader.slice("Bearer ".length).trim() || "anonymous";
	}
	const headerUserId = request.headers["x-app-user-id"];
	if (typeof headerUserId === "string" && headerUserId.trim() !== "") {
		return headerUserId.trim();
	}
	const queryUserId = url.searchParams.get("app_user_id");
	if (queryUserId) {
		return queryUserId;
	}
	if (body && typeof body.app_user_id === "string" && body.app_user_id.trim() !== "") {
		return body.app_user_id.trim();
	}
	return "anonymous";
}

async function readJsonBody(request) {
	const chunks = [];
	for await (const chunk of request) {
		chunks.push(Buffer.from(chunk));
	}
	if (chunks.length === 0) {
		return {};
	}
	const text = Buffer.concat(chunks).toString("utf8");
	return text.trim() === "" ? {} : JSON.parse(text);
}

function sendJson(response, statusCode, payload) {
	response.writeHead(statusCode, {
		"Content-Type": "application/json; charset=utf-8"
	});
	response.end(JSON.stringify(payload, null, 2));
}

function buildDailyCompletionSession({ appUserId, dailyManifest }) {
	const issuedAt = Math.floor(Date.now() / 1000);
	const expiresAt = resolveDailyCompletionExpiry(dailyManifest, issuedAt);
	const payload = {
		kind: "daily_completion",
		app_user_id: appUserId,
		challenge_id: String(dailyManifest.challenge_id ?? dailyManifest.date ?? ""),
		date: String(dailyManifest.date ?? dailyManifest.challenge_id ?? ""),
		iat: issuedAt,
		exp: expiresAt
	};

	return {
		token: createSignedPayloadToken({
			secret: signingSecret,
			payload
		}),
		issued_at: new Date(issuedAt * 1000).toISOString(),
		expires_at: new Date(expiresAt * 1000).toISOString()
	};
}

function resolveDailyCompletionExpiry(dailyManifest, issuedAt) {
	const ttlExpiry = issuedAt + Math.max(60, dailyCompletionTokenTtlSeconds);
	const manifestExpiryMs = Date.parse(String(dailyManifest?.expires_at ?? ""));
	if (!Number.isFinite(manifestExpiryMs) || manifestExpiryMs <= 0) {
		return ttlExpiry;
	}
	const manifestExpiry = Math.floor(manifestExpiryMs / 1000);
	return Math.max(issuedAt + 60, Math.min(ttlExpiry, manifestExpiry));
}

function isValidDailyCompletionPayload(payload, { appUserId, dailyManifest }) {
	if (typeof payload !== "object" || payload === null) {
		return false;
	}
	if (String(payload.kind ?? "") !== "daily_completion") {
		return false;
	}
	if (String(payload.app_user_id ?? "") !== String(appUserId ?? "")) {
		return false;
	}
	const expectedChallengeId = String(dailyManifest?.challenge_id ?? dailyManifest?.date ?? "");
	if (String(payload.challenge_id ?? "") !== expectedChallengeId) {
		return false;
	}
	const expectedDate = String(dailyManifest?.date ?? dailyManifest?.challenge_id ?? "");
	return String(payload.date ?? "") === expectedDate;
}
