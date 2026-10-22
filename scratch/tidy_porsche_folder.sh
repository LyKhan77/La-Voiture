#!/bin/bash
# Moves (never deletes) the extracted Porsche textures into textures/ with clean names, keeps their .import settings and UIDs,
# points the toon material at the new paths, and adds raw/ (copy of the pre-refine Tripo body) next to the refined body.
set -e
cd "$(dirname "$0")/.."
D=assets/cars/porsche_911
mkdir -p $D/textures $D/raw

move_tex() {   # old name, new name
  mv "$D/$1" "$D/textures/$2"
  mv "$D/$1.import" "$D/textures/$2.import"
  awk -v src="res://$D/textures/$2" '
    /^path\.s3tc=/ { next }
    /^dest_files=/ { next }
    /^metadata=\{/ || /^generator_parameters=\{/ { skip = 1 }
    skip == 1 { if ($0 == "}") skip = 0; next }
    /^source_file=/ { print "source_file=\"" src "\""; next }
    { print }' "$D/textures/$2.import" > "$D/textures/$2.import.tmp"
  mv "$D/textures/$2.import.tmp" "$D/textures/$2.import"
}
move_tex porsche_911_body_Color_caa06e4e-d9f7-4654-9f18-f144def4be58.jpg base_color.jpg
move_tex porsche_911_body_NormalGL_caa06e4e-d9f7-4654-9f18-f144def4be58.png normal.png
move_tex porsche_911_body_ORM_caa06e4e-d9f7-4654-9f18-f144def4be58.jpg orm.jpg

sed -i 's#res://assets/cars/porsche_911/porsche_911_body_Color_caa06e4e-d9f7-4654-9f18-f144def4be58.jpg#res://assets/cars/porsche_911/textures/base_color.jpg#' materials/porsche_toon_body.tres

cp scratch/backup_wheel_refine/porsche_911_body.orig.glb $D/raw/porsche_911_raw.glb
awk -v src="res://$D/raw/porsche_911_raw.glb" '
  /^uid=/ || /^path=/ || /^dest_files=/ { next }
  /^source_file=/ { print "source_file=\"" src "\""; next }
  /^gltf\/embedded_image_handling=/ { print "gltf/embedded_image_handling=2"; next }
  { print }' $D/porsche_911_body.glb.import > $D/raw/porsche_911_raw.glb.import
sed -i 's#^gltf/embedded_image_handling=1#gltf/embedded_image_handling=2#' $D/porsche_911_body.glb.import
echo "tidy done"
