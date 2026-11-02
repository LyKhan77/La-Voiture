// Cut the steadiest stretch of a generated engine clip into a seamless loop (Fase 21.3).
// AI engine clips tend to "accelerate"; a pitched loop must hold one note, so this finds the
// window with the least pitch and level drift and crossfades its tail into its head.
// Run: node tools/audio/trim_steady_loop.mjs <in.wav> <out.wav> [loop_seconds=1.75]
// Self-check: node tools/audio/trim_steady_loop.mjs --self-test
import { readFileSync, writeFileSync } from "node:fs";
import { pathToFileURL } from "node:url";

const HOP_S = 0.125;
const FADE_S = 0.15;

export function readWav(buf) {
	let p = 12, fmt = null, data = null;
	while (p + 8 <= buf.length) {
		const id = buf.toString("ascii", p, p + 4), size = buf.readUInt32LE(p + 4);
		if (id === "fmt ") fmt = { channels: buf.readUInt16LE(p + 10), rate: buf.readUInt32LE(p + 12), bits: buf.readUInt16LE(p + 22) };
		if (id === "data") data = buf.subarray(p + 8, p + 8 + size);
		p += 8 + size + (size & 1);
	}
	if (!fmt || !data || fmt.bits !== 16) throw new Error("need a 16-bit PCM WAV");
	const frames = Math.floor(data.length / 2 / fmt.channels);
	const ch = Array.from({ length: fmt.channels }, () => new Float32Array(frames));
	for (let i = 0; i < frames; i++)
		for (let c = 0; c < fmt.channels; c++) ch[c][i] = data.readInt16LE((i * fmt.channels + c) * 2) / 32768;
	return { rate: fmt.rate, ch };
}

export function writeWav(rate, ch) {
	const frames = ch[0].length, n = ch.length, buf = Buffer.alloc(44 + frames * n * 2);
	buf.write("RIFF", 0); buf.writeUInt32LE(36 + frames * n * 2, 4); buf.write("WAVEfmt ", 8);
	buf.writeUInt32LE(16, 16); buf.writeUInt16LE(1, 20); buf.writeUInt16LE(n, 22); buf.writeUInt32LE(rate, 24);
	buf.writeUInt32LE(rate * n * 2, 28); buf.writeUInt16LE(n * 2, 32); buf.writeUInt16LE(16, 34);
	buf.write("data", 36); buf.writeUInt32LE(frames * n * 2, 40);
	for (let i = 0; i < frames; i++)
		for (let c = 0; c < n; c++) buf.writeInt16LE(Math.round(Math.max(-1, Math.min(1, ch[c][i])) * 32767), 44 + (i * n + c) * 2);
	return buf;
}

// Fundamental (40-400 Hz) and level of every hop, octave errors folded onto the clip median.
function analyse(mono, rate) {
	const hop = Math.floor(rate * HOP_S), out = [];
	for (let s = 0; s + hop <= mono.length; s += hop) {
		let energy = 0, best = 0, bestLag = 0;
		for (let i = s; i < s + hop; i++) energy += mono[i] * mono[i];
		for (let lag = Math.floor(rate / 400); lag < rate / 40; lag++) {
			let c = 0;
			for (let i = s; i < s + hop - lag; i += 2) c += mono[i] * mono[i + lag];
			if (c > best) { best = c; bestLag = lag; }
		}
		out.push({ f0: bestLag ? rate / bestLag : 0, db: 10 * Math.log10(energy / hop + 1e-12) });
	}
	const sorted = out.map((h) => h.f0).filter((f) => f > 0).sort((a, b) => a - b);
	const median = sorted[Math.floor(sorted.length / 2)] || 100;
	for (const h of out) {
		while (h.f0 > median * Math.SQRT2) h.f0 /= 2;
		while (h.f0 > 0 && h.f0 < median / Math.SQRT2) h.f0 *= 2;
	}
	return out;
}

// Returns { start, drift } of the steadiest window: drift = pitch spread (fraction) + level spread / 50 dB.
export function steadiestWindow(mono, rate, loopS) {
	const hops = analyse(mono, rate), span = Math.round(loopS / HOP_S);
	const fadeHops = Math.ceil(FADE_S / HOP_S);
	let best = { start: 0, drift: Infinity };
	for (let h = 0; h + span + fadeHops <= hops.length; h++) {
		const w = hops.slice(h, h + span);
		const f = w.map((x) => x.f0), d = w.map((x) => x.db);
		const drift = (Math.max(...f) - Math.min(...f)) / Math.min(...f) + (Math.max(...d) - Math.min(...d)) / 50;
		if (drift < best.drift) best = { start: h * Math.floor(rate * HOP_S), drift };
	}
	if (best.drift === Infinity) throw new Error("clip shorter than loop + fade");
	return best;
}

// Loop of `len` frames from `start`; its head is crossfaded (equal power) with what follows its tail.
export function seamlessLoop(ch, rate, start, len) {
	const fade = Math.floor(rate * FADE_S);
	return ch.map((x) => {
		const y = x.slice(start, start + len);
		for (let i = 0; i < fade; i++) {
			const t = i / fade;
			y[i] = x[start + i] * Math.sqrt(t) + x[start + len + i] * Math.sqrt(1 - t);
		}
		return y;
	});
}

function selfTest() {
	const rate = 8000, n = rate * 4, x = new Float32Array(n);
	// 1 s steady 100 Hz, then a sweep up: the steady second must win.
	let phase = 0;
	for (let i = 0; i < n; i++) {
		const f = i < rate * 1.5 ? 100 : 100 + (i - rate * 1.5) / rate * 80;
		phase += 2 * Math.PI * f / rate;
		x[i] = 0.5 * Math.sin(phase);
	}
	const w = steadiestWindow(x, rate, 1.0);
	console.assert(w.start < rate * 0.5, `steady window should start early, got ${w.start}`);
	const [y] = seamlessLoop([x], rate, w.start, rate);
	console.assert(Math.abs(y[y.length - 1] - y[0]) < 0.1, "loop seam should be continuous");
	const back = readWav(writeWav(rate, [y]));
	console.assert(back.ch[0].length === rate && Math.abs(back.ch[0][100] - y[100]) < 1e-3, "wav round trip");
	console.log("self-test ok");
}

const isMain = import.meta.url === pathToFileURL(process.argv[1] ?? "").href;
if (!isMain) {
	// imported as a library
} else if (process.argv[2] === "--self-test") selfTest();
else if (process.argv.length >= 4) {
	const [, , inPath, outPath, loopArg] = process.argv;
	const { rate, ch } = readWav(readFileSync(inPath));
	const mono = ch[0].map((v, i) => ch.reduce((s, c) => s + c[i], 0) / ch.length);
	const loopS = Number(loopArg ?? 1.75);
	const { start, drift } = steadiestWindow(mono, rate, loopS);
	writeFileSync(outPath, writeWav(rate, seamlessLoop(ch, rate, start, Math.floor(rate * loopS))));
	console.log(`${outPath}: ${loopS}s loop from ${(start / rate).toFixed(2)}s, drift ${(drift * 100).toFixed(1)}%`);
} else {
	console.error("usage: trim_steady_loop.mjs <in.wav> <out.wav> [loop_seconds] | --self-test");
	process.exit(1);
}
