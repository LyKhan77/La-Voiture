// Per-image byte size and pixel size of the textures embedded in a GLB.  node glb_images.js <file.glb>
const fs = require("fs");
const fd = fs.openSync(process.argv[2], "r");
const head = Buffer.alloc(20); fs.readSync(fd, head, 0, 20, 0);
const jl = head.readUInt32LE(12); const jb = Buffer.alloc(jl); fs.readSync(fd, jb, 0, jl, 20);
const j = JSON.parse(jb.toString()); const binStart = 20 + jl + 8;
let total = 0;
for (const im of j.images) {
  const bv = j.bufferViews[im.bufferView]; const buf = Buffer.alloc(bv.byteLength); fs.readSync(fd, buf, 0, bv.byteLength, binStart + (bv.byteOffset || 0));
  let w = 0, h = 0;
  if (im.mimeType === "image/png") { w = buf.readUInt32BE(16); h = buf.readUInt32BE(20); }
  else { let p = 2; while (p < buf.length) { if (buf[p] !== 0xFF) { p++; continue; } const m = buf[p + 1]; const len = buf.readUInt16BE(p + 2); if (m >= 0xC0 && m <= 0xC2) { h = buf.readUInt16BE(p + 5); w = buf.readUInt16BE(p + 7); break; } p += 2 + len; } }
  total += bv.byteLength;
  console.log("IMG", im.name, im.mimeType, w + "x" + h, (bv.byteLength / 1e6).toFixed(2) + " MB", (bv.byteLength * 8 / (w * h)).toFixed(2) + " bits/px");
}
console.log("IMG textures total", (total / 1e6).toFixed(2), "MB of", (fs.statSync(process.argv[2]).size / 1e6).toFixed(2), "MB file");
