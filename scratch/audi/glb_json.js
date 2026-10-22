// Prints the JSON chunk summary of a GLB: materials, textures, images, extensions.  node glb_json.js <file.glb>
const fs = require("fs");
const fd = fs.openSync(process.argv[2], "r");
const head = Buffer.alloc(20); fs.readSync(fd, head, 0, 20, 0);
const jsonLen = head.readUInt32LE(12);
const buf = Buffer.alloc(jsonLen); fs.readSync(fd, buf, 0, jsonLen, 20);
const j = JSON.parse(buf.toString("utf8"));
console.log("asset", JSON.stringify(j.asset));
console.log("extensionsUsed", JSON.stringify(j.extensionsUsed), "required", JSON.stringify(j.extensionsRequired));
console.log("materials", JSON.stringify(j.materials, null, 1));
console.log("textures", JSON.stringify(j.textures));
console.log("images", JSON.stringify(j.images));
console.log("samplers", JSON.stringify(j.samplers));
for (const m of j.meshes) console.log("mesh", m.name, JSON.stringify(m.primitives.map(p => ({attrs: Object.keys(p.attributes), mat: p.material, mode: p.mode}))));
