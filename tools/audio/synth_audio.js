// Procedural WAV generator for the FASE 6 sound set (16-bit mono, 44.1 kHz).
// Run: node tools/audio/synth_audio.js [outDir]   (default outDir = assets/audio)
// Writes the UI, engine and radio sounds. The engine loop carries a `smpl` chunk so Godot
// imports it as a forward loop; every partial is an integer Hz on a 1 s loop, so it closes
// on itself with no click.
const fs = require("fs");
const path = require("path");

const RATE = 44100;
const root = path.resolve(process.argv[2] || path.join(__dirname, "..", "..", "assets", "audio"));

function mulberry32(seed) {
	let a = seed >>> 0;
	return () => {
		a = (a + 0x6d2b79f5) >>> 0;
		let t = a;
		t = Math.imul(t ^ (t >>> 15), t | 1);
		t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
		return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
	};
}

const clip = (n) => new Float64Array(Math.round(n * RATE));
const tau = Math.PI * 2;

function normalize(buf, peak) {
	let max = 0;
	for (const v of buf) max = Math.max(max, Math.abs(v));
	if (max > 0) for (let i = 0; i < buf.length; i++) buf[i] *= peak / max;
	return buf;
}

// One-pole filters; `circular` runs two laps so the loop seam carries no step.
function lowpass(buf, cutoff, circular) {
	const k = 1 - Math.exp((-tau * cutoff) / RATE);
	let y = 0;
	const laps = circular ? 2 : 1;
	for (let lap = 0; lap < laps; lap++) {
		for (let i = 0; i < buf.length; i++) {
			y += k * (buf[i] - y);
			if (lap === laps - 1) buf[i] = y;
		}
	}
	return buf;
}

function highpass(buf, cutoff) {
	const low = lowpass(Float64Array.from(buf), cutoff, false);
	for (let i = 0; i < buf.length; i++) buf[i] -= low[i];
	return buf;
}

function writeWav(file, samples, loop) {
	const data = Buffer.alloc(samples.length * 2);
	for (let i = 0; i < samples.length; i++) {
		data.writeInt16LE(Math.round(Math.max(-1, Math.min(1, samples[i])) * 32767), i * 2);
	}
	const fmt = Buffer.alloc(16);
	fmt.writeUInt16LE(1, 0); // PCM
	fmt.writeUInt16LE(1, 2); // mono
	fmt.writeUInt32LE(RATE, 4);
	fmt.writeUInt32LE(RATE * 2, 8);
	fmt.writeUInt16LE(2, 12);
	fmt.writeUInt16LE(16, 14);
	const chunks = [["fmt ", fmt], ["data", data]];
	if (loop) {
		const smpl = Buffer.alloc(60);
		smpl.writeUInt32LE(Math.round(1e9 / RATE), 8); // sample period in ns
		smpl.writeUInt32LE(60, 12); // MIDI unity note
		smpl.writeUInt32LE(1, 28); // one loop
		smpl.writeUInt32LE(0, 44); // loop type: forward
		smpl.writeUInt32LE(0, 48); // loop start
		smpl.writeUInt32LE(samples.length - 1, 52); // loop end
		chunks.push(["smpl", smpl]);
	}
	let size = 4;
	for (const [, body] of chunks) size += 8 + body.length;
	const out = Buffer.alloc(12 + size - 4);
	out.write("RIFF", 0);
	out.writeUInt32LE(size, 4);
	out.write("WAVE", 8);
	let at = 12;
	for (const [id, body] of chunks) {
		out.write(id, at);
		out.writeUInt32LE(body.length, at + 4);
		body.copy(out, at + 8);
		at += 8 + body.length;
	}
	fs.mkdirSync(path.dirname(file), { recursive: true });
	fs.writeFileSync(file, out);
	console.log(`${path.relative(process.cwd(), file)}  ${(samples.length / RATE).toFixed(2)}s  ${out.length}B${loop ? "  loop" : ""}`);
}

// Sharp mechanical switch: a noise tick plus a damped 2.6 kHz body, gone in 40 ms, no tail.
function clickSnap() {
	const rng = mulberry32(11);
	const buf = clip(0.045);
	for (let i = 0; i < buf.length; i++) {
		const t = i / RATE;
		const tick = (rng() * 2 - 1) * Math.exp(-t * 520);
		const body = Math.sin(tau * 2600 * t) * Math.exp(-t * 210) * 0.8;
		const thud = Math.sin(tau * 420 * t) * Math.exp(-t * 330) * 0.5;
		buf[i] = tick + body + thud;
	}
	highpass(buf, 250);
	return normalize(buf, 0.85);
}

// BOX / critical-tyre alarm: two tones swapping at 6 Hz.
function warningSiren() {
	const buf = clip(1.2);
	let phase = 0;
	for (let i = 0; i < buf.length; i++) {
		const t = i / RATE;
		const high = Math.floor(t * 6) % 2 === 0;
		phase += (tau * (high ? 1040 : 780)) / RATE;
		const gate = Math.min(1, t * 400, (buf.length - i) / RATE * 400);
		buf[i] = (Math.sin(phase) + 0.35 * Math.sin(phase * 3)) * gate;
	}
	return normalize(buf, 0.7);
}

// One red-light pair: a 1 kHz tone with a 5 ms attack and a short release.
function startBeep() {
	const buf = clip(0.2);
	for (let i = 0; i < buf.length; i++) {
		const t = i / RATE;
		const env = Math.min(1, t / 0.005) * Math.min(1, (0.2 - t) / 0.04);
		buf[i] = (Math.sin(tau * 1000 * t) + 0.25 * Math.sin(tau * 2000 * t)) * env;
	}
	return normalize(buf, 0.75);
}

// Green buzzer: a higher, longer, buzzier tone than the red beeps.
function lightsOut() {
	const buf = clip(0.7);
	for (let i = 0; i < buf.length; i++) {
		const t = i / RATE;
		const env = Math.min(1, t / 0.004) * Math.min(1, (0.7 - t) / 0.12);
		let v = 0;
		for (let h = 1; h <= 7; h += 2) v += Math.sin(tau * 1320 * h * t) / h; // square-ish buzz
		buf[i] = v * env;
	}
	return normalize(buf, 0.8);
}

// Walkie-talkie key-up: a noise burst with a rising chirp.
function squelchIn() {
	const rng = mulberry32(21);
	const buf = clip(0.2);
	let phase = 0;
	for (let i = 0; i < buf.length; i++) {
		const t = i / RATE;
		phase += (tau * (1200 + 5000 * t)) / RATE;
		const hiss = (rng() * 2 - 1) * 0.55 * Math.exp(-t * 14);
		const chirp = Math.sin(phase) * Math.exp(-t * 11);
		buf[i] = (hiss + chirp) * Math.min(1, t / 0.003);
	}
	return normalize(highpass(buf, 400), 0.8);
}

// Key-down roger beep: a short tone then a hiss tail that fades out.
function squelchOut() {
	const rng = mulberry32(22);
	const buf = clip(0.32);
	for (let i = 0; i < buf.length; i++) {
		const t = i / RATE;
		const tone = t < 0.09 ? Math.sin(tau * 1760 * t) * Math.min(1, t / 0.004) * Math.min(1, (0.09 - t) / 0.01) : 0;
		const hiss = (rng() * 2 - 1) * 0.45 * Math.exp(-Math.max(0, t - 0.09) * 18) * (t > 0.085 ? 1 : 0.2);
		buf[i] = tone + hiss;
	}
	return normalize(highpass(buf, 400), 0.8);
}

// Flat-6 GT3 note at pitch_scale 1.0 (~mid revs): firing fundamental + harmonics, an
// exhaust-rasp noise band and a slow cylinder-to-cylinder wobble. Whole Hz on a 1 s loop.
function gt3EngineLoop() {
	const rng = mulberry32(31);
	const buf = clip(1.0);
	const f0 = 110;
	const partials = [[1, 1.0], [2, 0.7], [3, 0.55], [4, 0.4], [5, 0.3], [6, 0.35], [7, 0.18], [9, 0.12], [12, 0.1]];
	for (let i = 0; i < buf.length; i++) {
		const t = i / RATE;
		const pulse = 0.72 + 0.28 * Math.cos(tau * f0 * t); // one bang per cycle
		const wobble = 1 + 0.08 * Math.sin(tau * 7 * t) + 0.05 * Math.sin(tau * 13 * t);
		let v = 0.55 * Math.sin(tau * (f0 / 2) * t); // half-order firing roughness
		for (const [h, a] of partials) v += a * Math.sin(tau * f0 * h * t + h * 0.4);
		buf[i] = v * pulse * wobble;
	}
	const rasp = new Float64Array(buf.length);
	for (let i = 0; i < rasp.length; i++) rasp[i] = rng() * 2 - 1;
	lowpass(rasp, 2600, true);
	highpass(rasp, 600);
	for (let i = 0; i < buf.length; i++) {
		const t = i / RATE;
		buf[i] += rasp[i] * 0.9 * (0.7 + 0.3 * Math.cos(tau * f0 * t));
	}
	return normalize(buf, 0.85);
}

const sounds = [
	["ui/click_snap.wav", clickSnap(), false],
	["ui/warning_siren.wav", warningSiren(), false],
	["ui/start_beep.wav", startBeep(), false],
	["ui/lights_out.wav", lightsOut(), false],
	["radio/squelch_in.wav", squelchIn(), false],
	["radio/squelch_out.wav", squelchOut(), false],
	["engine/gt3_engine_loop.wav", gt3EngineLoop(), true],
];
for (const [file, samples, loop] of sounds) writeWav(path.join(root, file), samples, loop);
