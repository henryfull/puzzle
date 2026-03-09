import crypto from "node:crypto";

function canonicalizeAssetSignaturePayload(assetPath, expiresAt) {
	return `${assetPath}:${expiresAt}`;
}

function createHmacHex(secret, payload) {
	return crypto
		.createHmac("sha256", secret)
		.update(payload)
		.digest("hex");
}

function decodeBase64UrlJson(segment) {
	try {
		const parsed = JSON.parse(Buffer.from(String(segment ?? ""), "base64url").toString("utf8"));
		return typeof parsed === "object" && parsed !== null ? parsed : null;
	} catch {
		return null;
	}
}

export function createAssetSignature({ secret, assetPath, expiresAt }) {
	return createHmacHex(secret, canonicalizeAssetSignaturePayload(assetPath, expiresAt));
}

export function verifyAssetSignature({ secret, assetPath, expiresAt, signature }) {
	const expected = createAssetSignature({ secret, assetPath, expiresAt });
	const expectedBuffer = Buffer.from(expected, "utf8");
	const receivedBuffer = Buffer.from(signature ?? "", "utf8");
	if (expectedBuffer.length !== receivedBuffer.length) {
		return false;
	}
	return crypto.timingSafeEqual(expectedBuffer, receivedBuffer);
}

export function buildPublicAssetUrl({ baseUrl, assetPath }) {
	const url = new URL("/content/file", baseUrl);
	url.searchParams.set("path", assetPath);
	return url.toString();
}

export function buildSignedAssetUrl({ baseUrl, assetPath, expiresAt, secret }) {
	const url = new URL("/content/file", baseUrl);
	url.searchParams.set("path", assetPath);
	url.searchParams.set("expires", String(expiresAt));
	url.searchParams.set("sig", createAssetSignature({ secret, assetPath, expiresAt }));
	return url.toString();
}

export function createSignedPayloadToken({ secret, payload }) {
	const encodedPayload = Buffer.from(JSON.stringify(payload), "utf8").toString("base64url");
	const signature = createHmacHex(secret, encodedPayload);
	return `${encodedPayload}.${signature}`;
}

export function verifySignedPayloadToken({ secret, token }) {
	const normalizedToken = String(token ?? "").trim();
	const [encodedPayload, receivedSignature] = normalizedToken.split(".", 2);
	if (!encodedPayload || !receivedSignature) {
		return { ok: false, reason: "malformed_token" };
	}

	const expectedSignature = createHmacHex(secret, encodedPayload);
	const expectedBuffer = Buffer.from(expectedSignature, "utf8");
	const receivedBuffer = Buffer.from(receivedSignature, "utf8");
	if (expectedBuffer.length !== receivedBuffer.length) {
		return { ok: false, reason: "invalid_signature" };
	}
	if (!crypto.timingSafeEqual(expectedBuffer, receivedBuffer)) {
		return { ok: false, reason: "invalid_signature" };
	}

	const payload = decodeBase64UrlJson(encodedPayload);
	if (payload === null) {
		return { ok: false, reason: "invalid_payload" };
	}

	const expiresAt = Number(payload.exp ?? 0);
	if (!Number.isFinite(expiresAt) || expiresAt <= Math.floor(Date.now() / 1000)) {
		return { ok: false, reason: "token_expired", payload };
	}

	return { ok: true, payload };
}
