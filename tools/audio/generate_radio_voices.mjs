// Renders the team radio voice clips (FASE 6) with Kokoro-82M, a local Apache-2.0 TTS model:
// bm_lewis for the engineer, am_eric for the driver and af_bella for Freja Berg (see tools/audio/radio_lines.mjs).
// Clips go to assets/audio/radio/voice/<id>.wav (mono 24 kHz, trimmed, loudness-normalised; the
// in-game Radio bus adds the band-pass and the grit) and the lookup table to manifest.json.
//
// One-time setup, in a folder OUTSIDE the project (so Godot never scans node_modules):
//   mkdir <KOKORO_DIR> && cd <KOKORO_DIR> && npm init -y && npm install kokoro-js
// Run: KOKORO_DIR=<KOKORO_DIR> node tools/audio/generate_radio_voices.mjs [--force] [--only id,id]
// Existing clips are kept unless --force; ffmpeg must be on PATH.
import fs from "fs";
import path from "path";
import os from "os";
import { execFileSync } from "child_process";
import { fileURLToPath, pathToFileURL } from "url";
import { LINES, VOICES } from "./radio_lines.mjs";

const kokoroDir = process.env.KOKORO_DIR;
if (!kokoroDir) throw new Error("set KOKORO_DIR to the folder where kokoro-js is installed");
const force = process.argv.includes("--force");
const onlyArg = process.argv.indexOf("--only");
const only = onlyArg >= 0 ? new Set(process.argv[onlyArg + 1].split(",")) : null;
const outDir = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..", "..", "assets", "audio", "radio", "voice");
const { KokoroTTS } = await import(pathToFileURL(path.join(kokoroDir, "node_modules", "kokoro-js", "dist", "kokoro.js")).href);

const ids = new Set();
for (const line of LINES) {
	if (ids.has(line.id)) throw new Error(`duplicate id ${line.id}`);
	ids.add(line.id);
	new RegExp(line.pattern); // fail early on a broken pattern
}

// Trim silence at both ends (the reverse trick), soften the edges, then match loudness.
const POLISH = [
	"silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0.02",
	"areverse", "silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0.03",
	"afade=t=in:d=0.02", "areverse", "afade=t=in:d=0.004",
	"loudnorm=I=-16:TP=-1.5:LRA=7",
].join(",");

fs.mkdirSync(outDir, { recursive: true });
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "radio-voice-"));
const tts = await KokoroTTS.from_pretrained("onnx-community/Kokoro-82M-v1.0-ONNX", { dtype: "q8", device: "cpu" });
let made = 0;
for (const line of LINES) {
	const file = path.join(outDir, `${line.id}.wav`);
	if ((only && !only.has(line.id)) || (!only && !force && fs.existsSync(file))) continue;
	const { voice, speed } = VOICES[line.voice === "female" ? "driver_female" : line.speaker];
	const raw = path.join(tmp, `${line.id}.wav`);
	const audio = await tts.generate(line.spoken, { voice, speed });
	await audio.save(raw);
	execFileSync("ffmpeg", ["-y", "-loglevel", "error", "-i", raw, "-af", POLISH, "-ar", "24000", "-ac", "1", "-c:a", "pcm_s16le", file]);
	made += 1;
	console.log(`${line.id}  ${line.speaker}  "${line.spoken}"`);
}
fs.rmSync(tmp, { recursive: true, force: true });

const manifest = LINES.map((line) => ({
	id: line.id,
	speaker: line.speaker,
	pattern: line.pattern,
	file: `res://assets/audio/radio/voice/${line.id}.wav`,
	spoken: line.spoken,
	...(line.voice ? { voice: line.voice } : {}),
}));
fs.writeFileSync(path.join(outDir, "manifest.json"), JSON.stringify(manifest, null, "\t") + "\n");
console.log(`${made} clip(s) rendered, ${manifest.length} in manifest.json`);
