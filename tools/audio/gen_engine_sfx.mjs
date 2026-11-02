// Offline generator for the engine SFX of Fase 21.3 (ElevenLabs Sound Effects API).
// Run: node --env-file=.env.local tools/audio/gen_engine_sfx.mjs [name ...] [--force]
// No names = every clip that is not on disk yet. The key comes from ELEVENLABS_API_KEY only.
// Clips are 44.1 kHz WAV so Godot can loop them sample-exact (EngineAudio3D.looped()).
import { existsSync, mkdirSync, writeFileSync } from "node:fs";

const OUT_DIR = "assets/audio/engine/profiles";
const API = "https://api.elevenlabs.io/v1/sound-generation?output_format=wav_44100";
const STEADY = "held at one fixed rpm like a dyno hold, perfectly steady pitch and volume from start to end, no revving up or down, no gear change, no tire noise, no music, seamless loop";

// Each engine loop is recorded at one steady rpm (`ref_rpm` in EngineProfile) so it pitches cleanly.
const CLIPS = [
	["v8_na_on", `GT3 race car, naturally aspirated 6.2 litre V8 engine at full throttle, 5000 rpm, deep muscular thunder and burble from the exhaust, ${STEADY}`, 4, true],
	["v8_na_off", `GT3 race car, naturally aspirated 6.2 litre V8 engine off throttle overrun at 5000 rpm, softer lumpy burble with light exhaust crackle, ${STEADY}`, 4, true],
	["v10_na_on", `GT3 race car, naturally aspirated 5.2 litre V10 engine at full throttle, 6000 rpm, shrill high pitched howling scream from the exhaust, ${STEADY}`, 4, true],
	["v10_na_off", `GT3 race car, naturally aspirated 5.2 litre V10 engine off throttle overrun at 6000 rpm, thinner raspy whine with exhaust crackle, ${STEADY}`, 4, true],
	["v6_tt_on", `GT3 race car, twin turbo 3.0 litre V6 engine at constant full throttle cruise in top gear on a long straight at constant speed, the engine note never changes, raspy hard edged growl, slightly muffled, ${STEADY}`, 6, true],
	["v6_tt_off", `GT3 race car, twin turbo 3.0 litre V6 engine off throttle overrun at 5500 rpm, hollow raspy drone with turbo flutter, ${STEADY}`, 4, true],
	["i6_tt_on", `GT3 race car, twin turbo 3.0 litre inline six engine at full throttle, 5500 rpm, smooth silky metallic straight six rasp, ${STEADY}`, 4, true],
	["i6_tt_off", `GT3 race car, twin turbo 3.0 litre inline six engine off throttle overrun at 5500 rpm, smooth lighter hum with soft pops, ${STEADY}`, 4, true],
	["v8_tt_on", `GT3 race car, twin turbo 4.0 litre V8 engine at constant full throttle cruise in top gear on a long straight at constant speed, the engine note never changes, dense deep muffled thrum, ${STEADY}`, 6, true],
	["v8_tt_off", `GT3 race car, twin turbo 4.0 litre V8 engine coasting off throttle in top gear at constant speed, the engine note never changes, low muffled rumble with occasional crackle, ${STEADY}`, 6, true],
	["turbo_whistle", "turbocharger whistle held at one fixed pitch, perfectly steady pure high whine at constant volume from start to end, isolated, no engine sound, seamless loop", 3, true],
	["blow_off", "race car turbo blow-off valve release, single sharp psshh with wastegate flutter chatter, isolated", 1, false],
	["upshift_crack", "race car upshift, single sharp exhaust bang crack from ignition cut, isolated, no engine drone", 1, false],
	["overrun_crackle", "race car lifting off throttle, exhaust overrun crackle and popping burble, isolated", 2, false],
];

const key = process.env.ELEVENLABS_API_KEY;
if (!key) {
	console.error("ELEVENLABS_API_KEY missing: run with node --env-file=.env.local");
	process.exit(1);
}
const args = process.argv.slice(2);
const force = args.includes("--force");
const names = args.filter((a) => !a.startsWith("--"));
const unknown = names.filter((n) => !CLIPS.some(([name]) => name === n));
if (unknown.length) {
	console.error(`unknown clip(s): ${unknown.join(", ")}`);
	process.exit(1);
}
mkdirSync(OUT_DIR, { recursive: true });

let failed = 0;
for (const [name, text, duration_seconds, loop] of CLIPS) {
	if (names.length && !names.includes(name)) continue;
	const path = `${OUT_DIR}/${name}.wav`;
	if (existsSync(path) && !force) {
		console.log(`skip ${path} (exists; --force to regenerate)`);
		continue;
	}
	const res = await fetch(API, {
		method: "POST",
		headers: { "xi-api-key": key, "Content-Type": "application/json" },
		body: JSON.stringify({ text, duration_seconds, loop, prompt_influence: 0.8, model_id: "eleven_text_to_sound_v2" }),
	});
	if (!res.ok) {
		failed++;
		console.error(`FAIL ${name}: HTTP ${res.status} ${(await res.text()).slice(0, 300)}`);
		continue;
	}
	writeFileSync(path, Buffer.from(await res.arrayBuffer()));
	console.log(`ok ${path} (${res.headers.get("character-cost") ?? "?"} credits)`);
}
process.exit(failed ? 1 : 0);
