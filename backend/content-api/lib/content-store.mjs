import fs from "node:fs/promises";
import path from "node:path";

const PUBLIC_ONLY_ENTITLEMENTS = Object.freeze({
	premium_active: false
});

export class ContentStore {
	constructor({ contentRoot, entitlementsPath, playerStatePath }) {
		this.contentRoot = path.resolve(contentRoot);
		this.entitlementsPath = path.resolve(entitlementsPath);
		this.playerStatePath = path.resolve(playerStatePath);
	}

	normalizeAssetPath(assetPath) {
		return String(assetPath ?? "").replace(/^\/+/, "");
	}

	resolveContentPath(assetPath) {
		const normalized = this.normalizeAssetPath(assetPath);
		const absolutePath = path.resolve(this.contentRoot, normalized);
		if (
			absolutePath !== this.contentRoot &&
			!absolutePath.startsWith(`${this.contentRoot}${path.sep}`)
		) {
			throw new Error(`Asset path escapes content root: ${normalized}`);
		}
		return absolutePath;
	}

	async fileExists(assetPath) {
		try {
			await fs.access(this.resolveContentPath(assetPath));
			return true;
		} catch {
			return false;
		}
	}

	async readCatalogManifest() {
		return this.#readJsonFromContent("catalog/catalog_manifest.json");
	}

	async readDailyManifest(date) {
		return this.#readJsonFromContent(`catalog/daily/${date}.json`);
	}

	async readEntitlements(appUserId = "anonymous") {
		const data = await this.#readJsonFileOrDefault(this.entitlementsPath, { users: {} });
		const raw = data.users?.[appUserId] ?? {};
		const playerState = await this.readPlayerState(appUserId);
		const mergedCosmetics = new Set(Array.isArray(raw.cosmetics) ? raw.cosmetics : []);
		for (const cosmeticId of Object.keys(playerState.rewards_inventory.cosmetics)) {
			mergedCosmetics.add(cosmeticId);
		}
		return {
			app_user_id: appUserId,
			platform: String(raw.platform ?? "test"),
			premium_active: Boolean(raw.premium_active),
			active_skus: Array.isArray(raw.active_skus) ? raw.active_skus : [],
			cosmetics: Array.from(mergedCosmetics),
			rewards_inventory: playerState.rewards_inventory,
			daily_completions: playerState.daily_completions,
			daily_claims: playerState.daily_claims
		};
	}

	async readPlayerState(appUserId = "anonymous") {
		const data = await this.#readJsonFileOrDefault(this.playerStatePath, { users: {} });
		return this.#normalizePlayerState(data.users?.[appUserId] ?? {});
	}

	canAccessTier(tier, entitlements) {
		switch (String(tier ?? "free")) {
			case "premium":
			case "premium_exclusive":
			case "seasonal_premium":
			case "daily_premium":
				return Boolean(entitlements.premium_active);
			default:
				return true;
		}
	}

	async buildCatalogForUser(entitlements) {
		const catalog = await this.readCatalogManifest();
		const visiblePacks = Array.isArray(catalog.packs)
			? catalog.packs.filter((pack) => this.canAccessTier(pack.tier, entitlements))
			: [];
		const visibleEvents = Array.isArray(catalog.seasonal_events)
			? catalog.seasonal_events.filter((event) => this.canAccessTier(event.tier, entitlements))
			: [];

		return {
			...catalog,
			packs: visiblePacks,
			seasonal_events: visibleEvents,
			viewer: {
				app_user_id: entitlements.app_user_id,
				premium_active: entitlements.premium_active,
				active_skus: entitlements.active_skus,
				cosmetics: entitlements.cosmetics,
				accessible_pack_ids: visiblePacks.map((pack) => pack.id)
			}
		};
	}

	async isPathPublic(assetPath) {
		return this.isPathAccessibleForEntitlements(assetPath, PUBLIC_ONLY_ENTITLEMENTS);
	}

	async isPathAccessibleForEntitlements(assetPath, entitlements) {
		const normalized = this.normalizeAssetPath(assetPath);
		const segments = normalized.split("/").filter(Boolean);
		if (segments.length < 2) {
			return false;
		}

		if (segments[0] === "packs") {
			const packId = segments[1];
			const catalog = await this.readCatalogManifest();
			const pack = Array.isArray(catalog.packs)
				? catalog.packs.find((candidate) => candidate.id === packId)
				: null;
			return pack ? this.canAccessTier(pack.tier, entitlements) : false;
		}

		if (segments[0] === "daily") {
			const date = segments[1];
			const daily = await this.readDailyManifest(date);
			return this.canAccessTier(daily.tier, entitlements);
		}

		return false;
	}

	async readAsset(assetPath) {
		const absolutePath = this.resolveContentPath(assetPath);
		const fileBuffer = await fs.readFile(absolutePath);
		const fileStat = await fs.stat(absolutePath);
		return {
			buffer: fileBuffer,
			size: fileStat.size,
			absolute_path: absolutePath
		};
	}

	async recordDailyCompletion(appUserId, dailyManifest, completionStats = {}) {
		const challengeKey = String(dailyManifest?.date ?? dailyManifest?.challenge_id ?? "").trim();
		if (challengeKey === "") {
			throw new Error("daily_manifest_missing_challenge_key");
		}

		const stateDocument = await this.#readJsonFileOrDefault(this.playerStatePath, { users: {} });
		const userState = this.#normalizePlayerState(stateDocument.users?.[appUserId] ?? {});
		const existingCompletion = userState.daily_completions[challengeKey] ?? {};
		const completedAt = new Date().toISOString();
		const normalizedStats = this.#normalizeCompletionStats(completionStats);

		const entry = {
			challenge_key: challengeKey,
			challenge_id: String(dailyManifest.challenge_id ?? challengeKey),
			date: String(dailyManifest.date ?? challengeKey),
			completed: true,
			completed_at: String(existingCompletion.completed_at ?? completedAt),
			last_completed_at: completedAt,
			completion_count: Number(existingCompletion.completion_count ?? 0) + 1,
			source: "daily_challenge",
			last_stats: normalizedStats
		};

		if (Number.isFinite(normalizedStats.elapsed_time) && normalizedStats.elapsed_time > 0) {
			const previousBestTime = Number(existingCompletion.best_time ?? 0);
			entry.best_time = previousBestTime > 0
				? Math.min(previousBestTime, normalizedStats.elapsed_time)
				: normalizedStats.elapsed_time;
		} else if (Number.isFinite(existingCompletion.best_time)) {
			entry.best_time = Number(existingCompletion.best_time);
		}

		if (Number.isFinite(normalizedStats.moves) && normalizedStats.moves > 0) {
			const previousBestMoves = Number(existingCompletion.best_moves ?? 0);
			entry.best_moves = previousBestMoves > 0
				? Math.min(previousBestMoves, normalizedStats.moves)
				: normalizedStats.moves;
		} else if (Number.isFinite(existingCompletion.best_moves)) {
			entry.best_moves = Number(existingCompletion.best_moves);
		}

		if (Number.isFinite(normalizedStats.score) && normalizedStats.score > 0) {
			entry.best_score = Math.max(Number(existingCompletion.best_score ?? 0), normalizedStats.score);
		} else if (Number.isFinite(existingCompletion.best_score)) {
			entry.best_score = Number(existingCompletion.best_score);
		}

		userState.daily_completions[challengeKey] = entry;
		stateDocument.users ??= {};
		stateDocument.users[appUserId] = userState;
		await this.#writeJsonFile(this.playerStatePath, stateDocument);

		return {
			already_completed: Boolean(existingCompletion.completed),
			completion: entry,
			player_state: userState
		};
	}

	async claimDailyReward(appUserId, dailyManifest) {
		const challengeKey = String(dailyManifest?.date ?? dailyManifest?.challenge_id ?? "").trim();
		if (challengeKey === "") {
			throw new Error("daily_manifest_missing_challenge_key");
		}

		const stateDocument = await this.#readJsonFileOrDefault(this.playerStatePath, { users: {} });
		const userState = this.#normalizePlayerState(stateDocument.users?.[appUserId] ?? {});
		const completionEntry = userState.daily_completions[challengeKey];
		if (!completionEntry?.completed) {
			return {
				already_claimed: false,
				not_completed: true,
				player_state: userState
			};
		}
		const existingClaim = userState.daily_claims[challengeKey];
		if (existingClaim?.reward_claimed) {
			return {
				already_claimed: true,
				claim: existingClaim,
				player_state: userState
			};
		}

		const rewardPayload = this.#normalizeRewardPayload(dailyManifest.reward ?? {});
		const claimedAt = new Date().toISOString();
		const appliedReward = this.#applyRewardPayload(userState, rewardPayload);
		const claimEntry = {
			challenge_key: challengeKey,
			challenge_id: String(dailyManifest.challenge_id ?? challengeKey),
			date: String(dailyManifest.date ?? challengeKey),
			reward_claimed: true,
			claimed_at: claimedAt,
			reward: rewardPayload,
			applied_reward: appliedReward,
			source: "daily_challenge"
		};

		userState.daily_claims[challengeKey] = claimEntry;
		stateDocument.users ??= {};
		stateDocument.users[appUserId] = userState;
		await this.#writeJsonFile(this.playerStatePath, stateDocument);

		return {
			already_claimed: false,
			claim: claimEntry,
			player_state: userState
		};
	}

	#normalizePlayerState(rawState) {
		const rewards = typeof rawState?.rewards_inventory === "object" && rawState.rewards_inventory !== null
			? rawState.rewards_inventory
			: {};
		const currencies = typeof rewards.currencies === "object" && rewards.currencies !== null
			? rewards.currencies
			: {};
		const cosmetics = typeof rewards.cosmetics === "object" && rewards.cosmetics !== null
			? rewards.cosmetics
			: {};
		const dailyCompletions = typeof rawState?.daily_completions === "object" && rawState.daily_completions !== null
			? rawState.daily_completions
			: {};
		const dailyClaims = typeof rawState?.daily_claims === "object" && rawState.daily_claims !== null
			? rawState.daily_claims
			: {};

		return {
			rewards_inventory: {
				currencies: structuredClone(currencies),
				cosmetics: structuredClone(cosmetics)
			},
			daily_completions: structuredClone(dailyCompletions),
			daily_claims: structuredClone(dailyClaims)
		};
	}

	#normalizeRewardPayload(rawReward) {
		if (typeof rawReward !== "object" || rawReward === null) {
			return { currencies: {}, cosmetics: [] };
		}

		const normalized = {
			currencies: {},
			cosmetics: []
		};

		if (typeof rawReward.currencies === "object" && rawReward.currencies !== null) {
			for (const [currencyId, amount] of Object.entries(rawReward.currencies)) {
				const normalizedId = String(currencyId ?? "").trim();
				const normalizedAmount = Number(amount ?? 0);
				if (normalizedId === "" || !Number.isFinite(normalizedAmount) || normalizedAmount === 0) {
					continue;
				}
				normalized.currencies[normalizedId] = Math.trunc(normalizedAmount);
			}
		}

		if (Array.isArray(rawReward.cosmetics)) {
			for (const cosmeticEntry of rawReward.cosmetics) {
				if (typeof cosmeticEntry === "string") {
					const cosmeticId = cosmeticEntry.trim();
					if (cosmeticId !== "") {
						normalized.cosmetics.push({ id: cosmeticId });
					}
					continue;
				}
				if (typeof cosmeticEntry === "object" && cosmeticEntry !== null) {
					const cosmeticId = String(cosmeticEntry.id ?? "").trim();
					if (cosmeticId !== "") {
						normalized.cosmetics.push(structuredClone(cosmeticEntry));
					}
				}
			}
		}

		return normalized;
	}

	#normalizeCompletionStats(rawStats) {
		if (typeof rawStats !== "object" || rawStats === null) {
			return {};
		}

		const normalized = {};
		const mappings = {
			pack_id: "pack_id",
			puzzle_id: "puzzle_id",
			elapsed_time: "elapsed_time",
			completion_time: "elapsed_time",
			moves: "moves",
			total_moves: "moves",
			flips: "flips",
			flip_uses: "flips",
			flip_moves: "flip_moves",
			final_score: "score",
			score: "score",
			max_streak: "max_streak"
		};

		for (const [inputKey, outputKey] of Object.entries(mappings)) {
			if (!(inputKey in rawStats)) {
				continue;
			}
			if (outputKey === "pack_id" || outputKey === "puzzle_id") {
				normalized[outputKey] = String(rawStats[inputKey] ?? "");
				continue;
			}
			const numericValue = Number(rawStats[inputKey] ?? 0);
			if (Number.isFinite(numericValue)) {
				normalized[outputKey] = numericValue;
			}
		}

		return normalized;
	}

	#applyRewardPayload(userState, rewardPayload) {
		const applied = {
			currencies: {},
			cosmetics: [],
			duplicate_cosmetics: []
		};

		for (const [currencyId, amount] of Object.entries(rewardPayload.currencies ?? {})) {
			const normalizedId = String(currencyId ?? "").trim();
			const normalizedAmount = Number(amount ?? 0);
			if (normalizedId === "" || !Number.isFinite(normalizedAmount) || normalizedAmount === 0) {
				continue;
			}
			const currentAmount = Number(userState.rewards_inventory.currencies[normalizedId] ?? 0);
			userState.rewards_inventory.currencies[normalizedId] = currentAmount + Math.trunc(normalizedAmount);
			applied.currencies[normalizedId] = Math.trunc(normalizedAmount);
		}

		for (const cosmeticEntry of rewardPayload.cosmetics ?? []) {
			if (typeof cosmeticEntry !== "object" || cosmeticEntry === null) {
				continue;
			}
			const cosmeticId = String(cosmeticEntry.id ?? "").trim();
			if (cosmeticId === "") {
				continue;
			}
			if (userState.rewards_inventory.cosmetics[cosmeticId]) {
				applied.duplicate_cosmetics.push(cosmeticId);
				continue;
			}
			const normalizedCosmetic = structuredClone(cosmeticEntry);
			normalizedCosmetic.owned = true;
			normalizedCosmetic.unlocked_at = new Date().toISOString();
			userState.rewards_inventory.cosmetics[cosmeticId] = normalizedCosmetic;
			applied.cosmetics.push(normalizedCosmetic);
		}

		return applied;
	}

	async #readJsonFromContent(relativePath) {
		return this.#readJsonFileOrDefault(this.resolveContentPath(relativePath), {});
	}

	async #readJsonFileOrDefault(absolutePath, fallbackValue) {
		try {
			const raw = await fs.readFile(absolutePath, "utf8");
			return JSON.parse(raw);
		} catch (error) {
			if (error.code === "ENOENT") {
				return structuredClone(fallbackValue);
			}
			throw error;
		}
	}

	async #writeJsonFile(absolutePath, payload) {
		await fs.mkdir(path.dirname(absolutePath), { recursive: true });
		await fs.writeFile(absolutePath, JSON.stringify(payload, null, 2), "utf8");
	}
}
