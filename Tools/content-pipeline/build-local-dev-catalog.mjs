import fs from "node:fs/promises";
import path from "node:path";
import { spawn } from "node:child_process";

const args = parseArgs(process.argv.slice(2));
const workspaceRoot = process.cwd();
const backupRoot = path.resolve(workspaceRoot, args.backupRoot ?? "dlc_backup_20250901_190152/packs");
const stagingRoot = path.resolve(workspaceRoot, args.staging ?? "content-staging/local-dev");
const outputRoot = path.resolve(workspaceRoot, args.output ?? "dist/content");
const dailyDate = args.dailyDate ?? formatLocalDate(new Date());

const availablePackIds = await listBackupPackIds(backupRoot);
const defaultFreePackIds = selectExistingPackIds(
	availablePackIds,
	parseList(args.freePacks ?? "numbers,farm-animals")
);
const defaultPremiumPackIds = selectExistingPackIds(
	availablePackIds,
	parseList(args.premiumPacks ?? "artistic-cities,wild-animals,usa-pack,wild-animals-cartoon")
);

const freePackIds = defaultFreePackIds.length > 0 ? defaultFreePackIds : availablePackIds.slice(0, 2);
const premiumPackIds = defaultPremiumPackIds.length > 0
	? defaultPremiumPackIds
	: availablePackIds.filter((packId) => !freePackIds.includes(packId));
const orderedPackIds = uniqueList([...freePackIds, ...premiumPackIds]);

if (orderedPackIds.length === 0) {
	throw new Error(`No se encontraron packs DLC en ${backupRoot}`);
}

const dailySourcePackId = resolveDailySourcePackId({
	requestedPackId: args.dailySourcePack ?? "",
	freePackIds,
	premiumPackIds,
	availablePackIds
});
const dailySourcePack = await readBackupPack(backupRoot, dailySourcePackId);

await fs.rm(stagingRoot, { recursive: true, force: true });
await ensureDir(path.join(stagingRoot, "packs"));
await ensureDir(path.join(stagingRoot, "daily", dailyDate));

for (const packId of orderedPackIds) {
	const pack = await readBackupPack(backupRoot, packId);
	const tier = freePackIds.includes(packId) ? "free_rotating" : "premium";
	await writePackToStaging({
		backupRoot,
		stagingRoot,
		pack,
		tier
	});
}

await writeDailyToStaging({
	backupRoot,
	stagingRoot,
	dailyDate,
	sourcePack: dailySourcePack
});

const control = {
	catalogVersion: `local-dev-${dailyDate}`,
	generatedAt: new Date().toISOString(),
	cdnBaseUrl: "",
	freeRotation: {
		slot_count: 12,
		starts_at: `${dailyDate}T00:00:00`,
		ends_at: null,
		active_pack_ids: freePackIds
	},
	seasonalEvents: [],
	packs: orderedPackIds,
	dailyChallenges: [dailyDate]
};

await writeJson(path.join(stagingRoot, "catalog.control.json"), control);
await runRemoteBuild({
	workspaceRoot,
	stagingRoot,
	outputRoot
});
await writeJson(path.join(outputRoot, "catalog", "dev_entitlements.json"), {
	users: {
		demo_free: {
			platform: "test",
			premium_active: false,
			active_skus: [],
			cosmetics: ["starter_frame"]
		},
		demo_premium: {
			platform: "test",
			premium_active: true,
			active_skus: ["premium_monthly"],
			cosmetics: ["starter_frame", "premium_gold_theme"]
		}
	}
});

console.log("");
console.log("Local remote catalog sandbox generated.");
console.log(`Base local pack expected: fruits`);
console.log(`Free remote packs: ${freePackIds.join(", ")}`);
console.log(`Premium remote packs: ${premiumPackIds.join(", ")}`);
console.log(`Daily challenge: ${dailyDate} (source pack: ${dailySourcePackId})`);
console.log(`Staging: ${stagingRoot}`);
console.log(`Output: ${outputRoot}`);

async function writePackToStaging({ backupRoot, stagingRoot, pack, tier }) {
	const packDir = path.join(stagingRoot, "packs", pack.id);
	await ensureDir(packDir);

	const thumbnailSource = resolveBackupAssetPath(backupRoot, pack.id, pack.image_path);
	const thumbnailFile = path.basename(thumbnailSource);
	await copyFile(thumbnailSource, path.join(packDir, thumbnailFile));

	const packMeta = {
		id: pack.id,
		revision: 1,
		tier,
		title: toLocalizedText(pack.name),
		description: toLocalizedText(pack.description),
		thumbnailFile,
		puzzles: []
	};

	for (const puzzle of Array.isArray(pack.puzzles) ? pack.puzzles : []) {
		const puzzleSource = resolveBackupAssetPath(backupRoot, pack.id, puzzle.image);
		const puzzleFile = path.basename(puzzleSource);
		await copyFile(puzzleSource, path.join(packDir, puzzleFile));
		packMeta.puzzles.push({
			id: String(puzzle.id ?? puzzleFile),
			file: puzzleFile,
			width: 1440,
			height: 1440,
			grid: defaultGridForDifficulty(String(pack.difficulty ?? "easy"))
		});
	}

	await writeJson(path.join(packDir, "pack.meta.json"), packMeta);
}

async function writeDailyToStaging({ backupRoot, stagingRoot, dailyDate, sourcePack }) {
	const dailyDir = path.join(stagingRoot, "daily", dailyDate);
	await ensureDir(dailyDir);

	const thumbnailSource = resolveBackupAssetPath(backupRoot, sourcePack.id, sourcePack.image_path);
	const heroFile = path.basename(thumbnailSource);
	await copyFile(thumbnailSource, path.join(dailyDir, heroFile));

	const sourcePuzzle = Array.isArray(sourcePack.puzzles) && sourcePack.puzzles.length > 0
		? sourcePack.puzzles[0]
		: null;
	if (sourcePuzzle === null) {
		throw new Error(`El pack ${sourcePack.id} no tiene puzzles para crear el daily`);
	}

	const puzzleSource = resolveBackupAssetPath(backupRoot, sourcePack.id, sourcePuzzle.image);
	const puzzleFile = path.basename(puzzleSource);
	await copyFile(puzzleSource, path.join(dailyDir, puzzleFile));

	const dailyMeta = {
		challengeId: `daily-${dailyDate}`,
		date: dailyDate,
		tier: "free",
		title: {
			es: "Desafio diario local",
			en: "Local daily challenge"
		},
		expiresAt: buildNextDayIso(dailyDate),
		challenge: {
			game_mode: 4,
			max_moves: 48,
			max_time: 240,
			max_flips: 12,
			max_flip_moves: 48
		},
		reward: {
			currencies: {
				coins: 25
			},
			cosmetics: [
				{
					id: "frame_local_daily",
					type: "frame",
					title: {
						es: "Marco daily local",
						en: "Local daily frame"
					}
				}
			]
		},
		pack: {
			id: `daily-${dailyDate}`,
			revision: 1,
			tier: "free",
			title: {
				es: `Daily desde ${sourcePack.name}`,
				en: `Daily from ${sourcePack.name}`
			},
			description: {
				es: "Contenido diario generado desde el sandbox local.",
				en: "Daily content generated from the local sandbox."
			},
			thumbnailFile: heroFile,
			puzzles: [
				{
					id: `${sourcePack.id}-daily-01`,
					file: puzzleFile,
					width: 1440,
					height: 1440,
					grid: defaultGridForDifficulty(String(sourcePack.difficulty ?? "easy"))
				}
			]
		}
	};

	await writeJson(path.join(dailyDir, "daily.meta.json"), dailyMeta);
}

async function runRemoteBuild({ workspaceRoot, stagingRoot, outputRoot }) {
	const buildScriptPath = path.join(workspaceRoot, "tools", "content-pipeline", "build-remote-content.mjs");
	await new Promise((resolve, reject) => {
		const child = spawn(
			process.execPath,
			[
				buildScriptPath,
				"--staging", path.relative(workspaceRoot, stagingRoot),
				"--output", path.relative(workspaceRoot, outputRoot)
			],
			{
				cwd: workspaceRoot,
				stdio: "inherit"
			}
		);
		child.on("exit", (code) => {
			if (code === 0) {
				resolve();
				return;
			}
			reject(new Error(`build-remote-content.mjs terminó con código ${code}`));
		});
		child.on("error", reject);
	});
}

async function listBackupPackIds(backupRoot) {
	const entries = await fs.readdir(backupRoot, { withFileTypes: true });
	const packIds = [];
	for (const entry of entries) {
		if (!entry.isFile() || !entry.name.endsWith(".json")) {
			continue;
		}
		const packId = entry.name.replace(/\.json$/u, "");
		if (packId !== "fruits") {
			packIds.push(packId);
		}
	}
	packIds.sort();
	return packIds;
}

async function readBackupPack(backupRoot, packId) {
	const packPath = path.join(backupRoot, `${packId}.json`);
	const raw = await fs.readFile(packPath, "utf8");
	return JSON.parse(raw);
}

function resolveBackupAssetPath(backupRoot, packId, resourcePath) {
	const normalized = String(resourcePath ?? "");
	const packPrefix = `res://dlc/packs/${packId}/`;
	if (normalized.startsWith(packPrefix)) {
		return path.join(backupRoot, packId, normalized.slice(packPrefix.length));
	}
	throw new Error(`Ruta de asset no soportada para ${packId}: ${normalized}`);
}

function toLocalizedText(value) {
	const text = String(value ?? "").trim();
	return {
		es: text,
		en: text
	};
}

function defaultGridForDifficulty(difficulty) {
	switch (String(difficulty).toLowerCase()) {
		case "medium":
			return { columns: 4, rows: 5 };
		case "hard":
			return { columns: 5, rows: 5 };
		default:
			return { columns: 4, rows: 4 };
	}
}

function resolveDailySourcePackId({ requestedPackId, freePackIds, premiumPackIds, availablePackIds }) {
	if (requestedPackId && availablePackIds.includes(requestedPackId)) {
		return requestedPackId;
	}
	if (freePackIds.length > 0) {
		return freePackIds[0];
	}
	if (premiumPackIds.length > 0) {
		return premiumPackIds[0];
	}
	return availablePackIds[0] ?? "";
}

function buildNextDayIso(dateText) {
	const [year, month, day] = String(dateText).split("-").map((value) => Number(value));
	const nextDate = new Date(year, month - 1, day + 1, 0, 0, 0);
	return `${formatLocalDate(nextDate)}T00:00:00`;
}

function formatLocalDate(date) {
	const year = date.getFullYear();
	const month = String(date.getMonth() + 1).padStart(2, "0");
	const day = String(date.getDate()).padStart(2, "0");
	return `${year}-${month}-${day}`;
}

function parseList(value) {
	return String(value ?? "")
		.split(",")
		.map((entry) => entry.trim())
		.filter(Boolean);
}

function selectExistingPackIds(availablePackIds, requestedPackIds) {
	return requestedPackIds.filter((packId) => availablePackIds.includes(packId));
}

function uniqueList(items) {
	return Array.from(new Set(items));
}

async function ensureDir(dirPath) {
	await fs.mkdir(dirPath, { recursive: true });
}

async function copyFile(sourcePath, targetPath) {
	await ensureDir(path.dirname(targetPath));
	await fs.copyFile(sourcePath, targetPath);
}

async function writeJson(filePath, payload) {
	await ensureDir(path.dirname(filePath));
	await fs.writeFile(filePath, JSON.stringify(payload, null, 2), "utf8");
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
