// Voice audition for the team radio (FASE 6): renders one engineer line and one driver line
// with each candidate Kokoro voice, raw and run through an approximation of the in-game Radio bus.
// Kokoro-82M (Apache-2.0) runs locally; nothing is sent anywhere after the model download.
//
// One-time setup, in a folder OUTSIDE the project (so Godot never scans node_modules):
//   mkdir <KOKORO_DIR> && cd <KOKORO_DIR> && npm init -y && npm install kokoro-js
// Run: KOKORO_DIR=<KOKORO_DIR> node tools/audio/kokoro_samples.mjs <outDir> [voice ...]
import fs from "fs";
import path from "path";
import { execFileSync } from "child_process";
import { pathToFileURL } from "url";

const kokoroDir = process.env.KOKORO_DIR;
if (!kokoroDir) throw new Error("set KOKORO_DIR to the folder where kokoro-js is installed");
const outDir = path.resolve(process.argv[2] || "scratch/voice_samples");
const { KokoroTTS } = await import(pathToFileURL(path.join(kokoroDir, "node_modules", "kokoro-js", "dist", "kokoro.js")).href);

const DEFAULT_VOICES = ["bm_george", "bm_lewis", "am_michael", "am_fenrir", "am_puck", "am_eric"];
const voices = process.argv.length > 3 ? process.argv.slice(3) : DEFAULT_VOICES;
const LINES = {
	engineer: "Box this lap, confirm medium tyres.",
	driver: "Tyres are gone, I need to box now!",
};
// 300 Hz - 3.4 kHz telephone band, a little grit and a limiter: close to the Radio bus chain.
const RADIO_FILTER = "highpass=f=300,lowpass=f=3400,acrusher=bits=12:mix=0.25,volume=1.4,alimiter=limit=0.9";

const tts = await KokoroTTS.from_pretrained("onnx-community/Kokoro-82M-v1.0-ONNX", { dtype: "q8", device: "cpu" });
console.log("available voices:", Object.keys(tts.voices).join(", "));
fs.mkdirSync(outDir, { recursive: true });
for (const voice of voices) {
	for (const [role, text] of Object.entries(LINES)) {
		const raw = path.join(outDir, `${voice}_${role}_raw.wav`);
		const radio = path.join(outDir, `${voice}_${role}_radio.wav`);
		const audio = await tts.generate(text, { voice });
		await audio.save(raw);
		execFileSync("ffmpeg", ["-y", "-loglevel", "error", "-i", raw, "-af", RADIO_FILTER, radio]);
		console.log(`${voice} ${role}: ${(audio.audio.length / audio.sampling_rate).toFixed(2)}s`);
	}
}
