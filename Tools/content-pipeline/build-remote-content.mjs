import crypto from "node:crypto";
import fs from "node:fs/promises";
import path from "node:path";

const args = parseArgs(process.argv.slice(2));
const workspaceRoot = process.cwd();
const stagingRoot = path.resolve(workspaceRoot, args.staging ?? "content-staging");
const outputRoot = path.resolve(workspaceRoot, args.output ?? "dist/content");
const controlPath = path.join(stagingRoot, "catalog.control.json");

const control = await readJson(controlPath);

await fs.rm(outputRoot, { recursive: true, force: true });
await ensureDir(outputRoot);
await ensureDir(path.join(outputRoot, "catalog"));
await ensureDir(path.join(outputRoot, "catalog", "daily"));

const builtPacks = [];

const packIds = Array.isArray(control.packs) ? control.packs : [];
for (const packId of packIds) {
	const packSourceDir = path.join(stagingRoot, "packs", packId);
	const packMeta = await readJson(path.join(packSourceDir, "pack.meta.json"));
	const builtPack = await buildPack({
		sourceDir: packSourceDir,
		outputRoot,
		baseRelativeDir: path.posix.join("packs", packMeta.id),
		manifestFileName: `pack_manifest.v${packMeta.revision}.json`,
		packMeta
	});
	builtPacks.push(builtPack.catalogEntry);
}

const dailyDates = Array.isArray(control.dailyChallenges) ? control.dailyChallenges : [];
for (const date of dailyDates) {
	const dailySourceDir = path.join(stagingRoot, "daily", date);
	const dailyMeta = await readJson(path.join(dailySourceDir, "daily.meta.json"));
	await buildDailyChallenge({
		sourceDir: dailySourceDir,
		outputRoot,
		date,
		dailyMeta
	});
}

const catalogManifest = {
	schema_version: 1,
	catalog_version: control.catalogVersion ?? new Date().toISOString().slice(0, 10),
	generated_at: control.generatedAt ?? new Date().toISOString(),
	cdn: {
		base_url: control.cdnBaseUrl ?? args.cdnBaseUrl ?? ""
	},
	free_rotation: control.freeRotation ?? {
		slot_count: 12,
		starts_at: null,
		ends_at: null,
		active_pack_ids: []
	},
	seasonal_events: Array.isArray(control.seasonalEvents) ? control.seasonalEvents : [],
	packs: builtPacks
};

await writeJson(path.join(outputRoot, "catalog", "catalog_manifest.json"), catalogManifest);

console.log(`Built remote content into ${outputRoot}`);

async function buildPack({ sourceDir, outputRoot, baseRelativeDir, manifestFileName, packMeta }) {
	const outputPackDir = path.join(outputRoot, ...baseRelativeDir.split("/"));
	await ensureDir(outputPackDir);
	await ensureDir(path.join(outputPackDir, "puzzles"));

	const thumbnailSource = path.join(sourceDir, packMeta.thumbnailFile);
	const thumbnailTargetRelative = path.posix.join(baseRelativeDir, path.basename(packMeta.thumbnailFile));
	await copyFile(thumbnailSource, path.join(outputRoot, ...thumbnailTargetRelative.split("/")));
	const thumbnailStats = await fileDigestAndSize(thumbnailSource);
	let musicTargetRelative = "";
	let musicStats = null;
	if (typeof packMeta.musicFile === "string" && packMeta.musicFile.trim() !== "") {
		assertSupportedMusicFile(packMeta.musicFile);
		const musicSource = path.join(sourceDir, packMeta.musicFile);
		musicTargetRelative = path.posix.join(baseRelativeDir, path.basename(packMeta.musicFile));
		await copyFile(musicSource, path.join(outputRoot, ...musicTargetRelative.split("/")));
		musicStats = await fileDigestAndSize(musicSource);
	}

	const builtPuzzles = [];
	let totalBytes = thumbnailStats.size + (musicStats?.size ?? 0);

	for (const puzzle of packMeta.puzzles ?? []) {
		const sourceFile = path.join(sourceDir, puzzle.file);
		const targetRelative = path.posix.join(baseRelativeDir, "puzzles", path.basename(puzzle.file));
		await copyFile(sourceFile, path.join(outputRoot, ...targetRelative.split("/")));
		const puzzleStats = await fileDigestAndSize(sourceFile);
		totalBytes += puzzleStats.size;
		const builtPuzzle = {
			id: puzzle.id,
			image_path: targetRelative,
			sha256: puzzleStats.sha256,
			width: puzzle.width,
			height: puzzle.height,
			grid: puzzle.grid
		};
		if (puzzle.title != null) {
			builtPuzzle.title = puzzle.title;
		}
		if (puzzle.description != null) {
			builtPuzzle.description = puzzle.description;
		}
		if (puzzle.story != null) {
			builtPuzzle.story = puzzle.story;
		}
		builtPuzzles.push(builtPuzzle);
	}

	const packManifestRelative = path.posix.join(baseRelativeDir, manifestFileName);
	const packManifest = {
		schema_version: 1,
		id: packMeta.id,
		revision: packMeta.revision,
		title: packMeta.title ?? {},
		description: packMeta.description ?? {},
		tier: packMeta.tier ?? "free_rotating",
		thumbnail_path: thumbnailTargetRelative,
		puzzles: builtPuzzles
	};
	if (musicTargetRelative !== "") {
		packManifest.music_path = musicTargetRelative;
	}

	const serializedManifest = JSON.stringify(packManifest, null, 2);
	await writeText(path.join(outputRoot, ...packManifestRelative.split("/")), serializedManifest);
	const manifestHash = sha256(serializedManifest);
	totalBytes += Buffer.byteLength(serializedManifest, "utf8");

	return {
		packManifest,
		packManifestRelative,
		thumbnailTargetRelative,
			catalogEntry: {
				id: packMeta.id,
				revision: packMeta.revision,
				tier: packMeta.tier ?? "free_rotating",
				title: packMeta.title ?? {},
			description: packMeta.description ?? {},
			manifest_path: packManifestRelative,
			thumbnail_path: thumbnailTargetRelative,
			music_path: musicTargetRelative,
			bytes: totalBytes,
			sha256: manifestHash
		}
	};
}

async function buildDailyChallenge({ sourceDir, outputRoot, date, dailyMeta }) {
	const packMeta = dailyMeta.pack;
	if (!packMeta || typeof packMeta !== "object") {
		throw new Error(`daily.meta.json for ${date} must include a 'pack' object`);
	}

	const builtPack = await buildPack({
		sourceDir,
		outputRoot,
		baseRelativeDir: path.posix.join("daily", date),
		manifestFileName: "pack_manifest.json",
		packMeta
	});

	const heroRelativePath = builtPack.thumbnailTargetRelative;
	const dailyManifest = {
		schema_version: 1,
		challenge_id: dailyMeta.challengeId ?? `daily-${date}`,
		date,
		tier: dailyMeta.tier ?? "free",
		title: dailyMeta.title ?? {},
		pack_id: packMeta.id,
		pack_manifest_path: builtPack.packManifestRelative,
		image_path: heroRelativePath,
		challenge: dailyMeta.challenge ?? {},
		reward: dailyMeta.reward ?? {},
		sha256: builtPack.catalogEntry.sha256,
		expires_at: dailyMeta.expiresAt ?? null
	};

	await writeJson(path.join(outputRoot, "catalog", "daily", `${date}.json`), dailyManifest);
}

async function fileDigestAndSize(filePath) {
	const content = await fs.readFile(filePath);
	return {
		size: content.byteLength,
		sha256: sha256(content)
	};
}

async function copyFile(sourcePath, targetPath) {
	await ensureDir(path.dirname(targetPath));
	await fs.copyFile(sourcePath, targetPath);
}

async function ensureDir(dirPath) {
	await fs.mkdir(dirPath, { recursive: true });
}

async function writeJson(filePath, payload) {
	await writeText(filePath, JSON.stringify(payload, null, 2));
}

async function writeText(filePath, content) {
	await ensureDir(path.dirname(filePath));
	await fs.writeFile(filePath, content, "utf8");
}

async function readJson(filePath) {
	const raw = await fs.readFile(filePath, "utf8");
	return JSON.parse(raw);
}

function sha256(content) {
	return crypto.createHash("sha256").update(content).digest("hex");
}

function parseArgs(argv) {
	const parsed = {};
	for (let index = 0; index < argv.length; index += 1) {
		const entry = argv[index];
		if (!entry.startsWith("--")) {
			continue;
		}
		const key = entry.slice(2);
		const value = argv[index + 1];
		parsed[key] = value;
		index += 1;
	}
	return parsed;
}

function assertSupportedMusicFile(fileName) {
	const normalized = String(fileName).toLowerCase();
	if (normalized.endsWith(".ogg") || normalized.endsWith(".oga") || normalized.endsWith(".mp3")) {
		return;
	}
	throw new Error(`Unsupported music file for remote pack: ${fileName}. Use .ogg, .oga or .mp3`);
}
