#!/usr/bin/env python3
"""Cut out the podium standee character from a concept sheet.

The shipped ``reference-assets/characters/*/*/full_body_concept.png`` files are
turnaround model sheets, not single studio portraits: they contain a title,
several views of the same driver, panel rules and a painted ground shadow.  A
standee needs the main full-body figure only, so this tool:

1. crops a hand-tuned primary-view region per driver (art direction, not magic),
2. builds an edge-connected background matte around the figure,
3. removes the ground/backdrop shadow while keeping interior grey clothing and
   black manga ink,
4. decontaminates partially transparent boundary pixels so no grey halo is left,
5. resamples the isolated figure into the original image canvas with its soles
   one pixel above the bottom edge.

Only Pillow and NumPy are used.  Raw reference assets are never modified.

Usage
-----
    py scratch/process_character_cutout.py
    py scratch/process_character_cutout.py --driver kaze-ryu --force
    py scratch/process_character_cutout.py --self-test

Default output: ``assets/characters/standees/<driver_slug underscores>.png``.
Existing outputs are skipped unless ``--force`` is passed.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
CHARACTERS_DIR = ROOT / "reference-assets" / "characters"
DEFAULT_OUT_DIR = ROOT / "assets" / "characters" / "standees"

# Runtime filename exceptions.  Everything else is just '-' -> '_'.
OUTPUT_NAME_OVERRIDES = {"arthur-sterling-jr": "arthur_sterling"}

# Primary front/full-body view in each source sheet, in source pixel coordinates.
# All current sources are 768x1376, but the coordinates are read against the
# actual image size so a regenerated sheet with a different size fails loudly
# instead of silently cropping the wrong area.
# ponytail: hand-tuned per-sheet view hints; a new unreviewed sheet falls back to
# the full canvas, which still works but may keep titles/other poses.
DRIVER_HINTS: dict[str, dict] = {
    "kaze-ryu": {"crop": (100, 90, 745, 1376)},
    "sora-ren": {"crop": (15, 70, 376, 700), "bg_seeds": [(240, 169)], "raw_outside_below": 300},
    "luca-ferrari": {"crop": (40, 690, 356, 1310), "enclosed_cleanup": True, "raw_outside_below": 350},
    "matteo-rossi": {"crop": (2, 70, 380, 684)},
    "dante-vance": {"crop": (5, 30, 380, 700)},
    "zane-cross": {
        "crop": (5, 90, 478, 1376),
        # A second turnaround view overlaps the hero's right glove.  The cut
        # below keeps the hero and drops the back view.
        "polygon": [(0, 0), (340, 0), (340, 1286), (0, 1286)],
    },
    "javier-cruz": {"crop": (5, 45, 378, 715)},
    "naoki-sato": {"crop": (5, 60, 320, 715)},
    "axel-vale": {"crop": (5, 30, 650, 1376)},
    "makoto-ito": {
        "crop": (5, 90, 495, 1376), "raw_outside_below": 700,
        # Keep the complete raised sleeve; split the neighbouring back view below its elbow.
        "polygon": [
            (0, 0), (489, 0), (489, 295), (465, 310), (474, 330),
            (479, 350), (480, 380), (481, 405), (477, 425), (464, 443),
            (442, 455), (390, 472), (390, 650), (450, 1000), (460, 1286), (0, 1286),
        ],
    },
    "erik-lindqvist": {
        "crop": (25, 45, 352, 660),
        # The sheet paints a halftone shadow behind the legs.  Below this row,
        # drop pixels that a blurred-ink flood reaches from the crop border.
        "outside_below": 360,
    },
    "freja-berg": {"crop": (5, 80, 385, 1376)},
    "ren-mishima": {"crop": (2, 50, 378, 708), "bg_seeds": [(251, 223)], "raw_outside_below": 300},
    "shinjiro-ono": {
        "crop": (160, 35, 660, 1376),
        # Trace the central three-quarter figure where the sheet's other poses overlap it.
        "polygon": [
            (125, 17), (318, 17), (348, 251), (395, 275), (459, 347),
            (493, 445), (481, 525), (429, 625), (374, 663), (349, 677),
            (355, 811), (386, 1000), (400, 1172), (430, 1300), (330, 1315),
            (318, 1205), (305, 1185), (222, 925), (214, 985), (192, 1175),
            (194, 1225), (160, 1273), (88, 1273), (28, 1237), (30, 1205),
            (99, 1153), (72, 1005), (68, 892), (72, 780), (46, 773),
            (20, 735), (24, 665), (47, 584), (58, 458), (75, 351), (92, 281),
        ],
        "raw_outside_below": 0,
    },
    "alistair-finch": {"crop": (2, 50, 378, 705)},
    "charles-de-vries": {
        "crop": (5, 40, 205, 850),
        # The studio shadow is enclosed by its own ink contour, so seed the
        # background flood inside it explicitly.
        "bg_seeds": [(120, 600)],
    },
    "gianluca-moretti": {"crop": (2, 60, 240, 685)},
    "pierre-mercier": {"crop": (2, 95, 355, 675)},
    "arthur-sterling-jr": {"crop": (10, 55, 380, 1100), "enclosed_cleanup": True, "raw_outside_below": 300},
    "harrison-croft": {"crop": (2, 70, 380, 715)},
    "wyatt-cooper": {"crop": (0, 0, 384, 1376)},
    "rin-takahashi": {"crop": (0, 0, 310, 768), "canvas_size": (768, 1376)},
}

BG_TOLERANCE = 9.0
BLUR_SIZE = 5


# --------------------------------------------------------------------------- #
# NumPy helpers (no OpenCV/SciPy so the tool runs with the documented deps).
# --------------------------------------------------------------------------- #
def _box_blur(rgb: np.ndarray, size: int = BLUR_SIZE) -> np.ndarray:
    """Separable box blur via an integral image; used for matte segmentation."""
    pad = size // 2
    padded = np.pad(rgb, ((pad, pad), (pad, pad), (0, 0)), mode="edge")
    integral = padded.cumsum(axis=0).cumsum(axis=1)
    integral = np.pad(integral, ((1, 0), (1, 0), (0, 0)), mode="constant")
    h, w = rgb.shape[:2]
    total = (
        integral[size:size + h, size:size + w]
        - integral[0:h, size:size + w]
        - integral[size:size + h, 0:w]
        + integral[0:h, 0:w]
    )
    return total / float(size * size)


def _smooth(luma: np.ndarray) -> np.ndarray:
    p = np.pad(luma, 1, mode="edge")
    return (
        p[:-2, :-2] + p[:-2, 1:-1] + p[:-2, 2:]
        + p[1:-1, :-2] + p[1:-1, 1:-1] + p[1:-1, 2:]
        + p[2:, :-2] + p[2:, 1:-1] + p[2:, 2:]
    ) / 9.0


def _runs(mask: np.ndarray) -> list[tuple[int, int, int]]:
    """Return (y, x_start, x_end_exclusive) horizontal runs of True."""
    runs: list[tuple[int, int, int]] = []
    for y in range(mask.shape[0]):
        row = mask[y]
        delta = np.diff(np.r_[False, row, False].astype(np.int8))
        starts = np.nonzero(delta == 1)[0]
        ends = np.nonzero(delta == -1)[0]
        runs.extend((y, int(s), int(e)) for s, e in zip(starts, ends))
    return runs


def _largest_component(mask: np.ndarray) -> tuple[np.ndarray, int]:
    """Keep the largest 4-connected component of ``mask``."""
    runs = _runs(mask)
    if not runs:
        return np.zeros_like(mask), 0
    parent = list(range(len(runs)))

    def find(a: int) -> int:
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a

    def union(a: int, b: int) -> None:
        ra, rb = find(a), find(b)
        if ra != rb:
            parent[rb] = ra

    last_row: list[int] = []
    current_y = -1
    for i, (y, x0, x1) in enumerate(runs):
        if y != current_y:
            previous_row = last_row
            last_row = []
            current_y = y
        for k in previous_row:
            _, px0, px1 = runs[k]
            if px0 < x1 and px1 > x0:
                union(i, k)
        last_row.append(i)

    areas: dict[int, int] = {}
    for i, (_, x0, x1) in enumerate(runs):
        root = find(i)
        areas[root] = areas.get(root, 0) + (x1 - x0)

    best = max(areas, key=areas.get)
    kept = np.zeros_like(mask)
    for i, (y, x0, x1) in enumerate(runs):
        if find(i) == best:
            kept[y, x0:x1] = True
    return kept, areas[best]


def _enclosed_background(fillable: np.ndarray, crop: np.ndarray, palette: np.ndarray) -> np.ndarray:
    """Select fillable components whose mean colour is the studio backdrop.

    The normal rule only accepts background connected to the crop border.  A
    painted shadow can be sealed inside its own outline, so the optional hint
    also accepts enclosed components that are flat, achromatic and close to the
    sampled backdrop.  Interior grey *clothing* is protected unless a driver
    hint explicitly opts into this pass.
    """
    runs = _runs(fillable)
    if not runs:
        return np.zeros_like(fillable)
    parent = list(range(len(runs)))

    def find(a: int) -> int:
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a

    def union(a: int, b: int) -> None:
        ra, rb = find(a), find(b)
        if ra != rb:
            parent[rb] = ra

    last_row: list[int] = []
    current_y = -1
    for i, (y, x0, x1) in enumerate(runs):
        if y != current_y:
            previous_row = last_row
            last_row = []
            current_y = y
        for k in previous_row:
            _, px0, px1 = runs[k]
            if px0 < x1 and px1 > x0:
                union(i, k)
        last_row.append(i)

    stats: dict[int, dict] = {}
    rgb = crop.astype(np.float64)
    for i, (y, x0, x1) in enumerate(runs):
        root = find(i)
        item = stats.setdefault(root, {"area": 0, "sum": np.zeros(3), "border": False})
        item["area"] += x1 - x0
        item["sum"] += rgb[y, x0:x1].sum(0)
        if y == 0 or y == fillable.shape[0] - 1 or x0 == 0 or x1 == fillable.shape[1]:
            item["border"] = True

    minimum = max(4, int(fillable.size * 0.0005))
    selected: set[int] = set()
    for root, item in stats.items():
        mean = item["sum"] / max(1, item["area"])
        chroma = float(mean.max() - mean.min())
        luma = float(0.2126 * mean[0] + 0.7152 * mean[1] + 0.0722 * mean[2])
        near = float(np.linalg.norm(palette - mean, axis=1).min())
        if item["border"] or (
            item["area"] >= minimum and near < 14.0 and chroma < 12.0 and luma > 55.0
        ):
            selected.add(root)

    selected_mask = np.zeros_like(fillable)
    for i, (y, x0, x1) in enumerate(runs):
        if find(i) in selected:
            selected_mask[y, x0:x1] = True
    return selected_mask


def _erode(mask: np.ndarray) -> np.ndarray:
    out = mask.copy()
    out[1:, :] &= mask[:-1, :]
    out[:-1, :] &= mask[1:, :]
    out[:, 1:] &= mask[:, :-1]
    out[:, :-1] &= mask[:, 1:]
    out[1:, 1:] &= mask[:-1, :-1]
    out[:-1, :-1] &= mask[1:, 1:]
    out[1:, :-1] &= mask[:-1, 1:]
    out[:-1, 1:] &= mask[1:, :-1]
    return out


def _dilate(mask: np.ndarray) -> np.ndarray:
    out = mask.copy()
    out[1:, :] |= mask[:-1, :]
    out[:-1, :] |= mask[1:, :]
    out[:, 1:] |= mask[:, :-1]
    out[:, :-1] |= mask[:, 1:]
    out[1:, 1:] |= mask[:-1, :-1]
    out[:-1, :-1] |= mask[1:, 1:]
    out[1:, :-1] |= mask[:-1, 1:]
    out[:-1, 1:] |= mask[1:, :-1]
    return out


def _flood_from_edges(fillable: np.ndarray, seeds=()) -> np.ndarray:
    """Scanline flood fill starting at every fillable border/seed pixel."""
    h, w = fillable.shape
    visited = np.zeros((h, w), bool)
    stack: list[tuple[int, int]] = []

    for x in range(w):
        if fillable[0, x]:
            stack.append((x, 0))
        if fillable[h - 1, x]:
            stack.append((x, h - 1))
    for y in range(h):
        if fillable[y, 0]:
            stack.append((0, y))
        if fillable[y, w - 1]:
            stack.append((w - 1, y))
    for sx, sy in seeds:
        if 0 <= sx < w and 0 <= sy < h and fillable[sy, sx]:
            stack.append((int(sx), int(sy)))

    while stack:
        x, y = stack.pop()
        if visited[y, x] or not fillable[y, x]:
            continue
        x0 = x
        while x0 > 0 and fillable[y, x0 - 1] and not visited[y, x0 - 1]:
            x0 -= 1
        x1 = x
        while x1 < w - 1 and fillable[y, x1 + 1] and not visited[y, x1 + 1]:
            x1 += 1
        visited[y, x0:x1 + 1] = True
        for ny in (y - 1, y + 1):
            if 0 <= ny < h:
                segment = fillable[ny, x0:x1 + 1] & ~visited[ny, x0:x1 + 1]
                indexes = np.nonzero(segment)[0]
                if indexes.size:
                    cuts = np.nonzero(np.diff(indexes) > 1)[0]
                    for start in np.r_[indexes[0], indexes[cuts + 1]]:
                        stack.append((x0 + int(start), ny))
    return visited


def _estimate_palette(crop: np.ndarray) -> np.ndarray:
    """Dominant low-chroma background colours sampled from the crop border."""
    h, w = crop.shape[:2]
    ring = np.concatenate(
        [
            crop[0:5].reshape(-1, 3),
            crop[-5:].reshape(-1, 3),
            crop[:, 0:5].reshape(-1, 3),
            crop[:, -5:].reshape(-1, 3),
        ]
    ).astype(np.int32)
    chroma = ring.max(1) - ring.min(1)
    luma = 0.2126 * ring[:, 0] + 0.7152 * ring[:, 1] + 0.0722 * ring[:, 2]
    ring = ring[(chroma < 14) & (luma > 45)]
    if ring.size == 0:
        return np.array([[168, 168, 168]], dtype=np.float32)

    quantised = ring // 4 * 4
    values, counts = np.unique(quantised, axis=0, return_counts=True)
    order = np.argsort(counts)[::-1]
    palette: list[tuple[int, int, int]] = []
    for index in order[:40]:
        colour = values[index]
        share = counts[index] / len(ring)
        if share < 0.015:
            break
        if any(np.abs(colour - np.array(prev)).max() < 10 for prev in palette):
            continue
        palette.append(tuple(int(v) for v in colour))
        if len(palette) >= 5:
            break
    if not palette:
        palette = [(168, 168, 168)]
    return np.array(palette, dtype=np.float32)


def _background_candidate(crop: np.ndarray, palette: np.ndarray) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """Return (fillable mask, blurred distance map, nearest palette index).

    Segmentation runs on a 5x5 box blur so halftone dots and screentone shadows
    are seen as flat background instead of individual black dots.  Colour
    distance alone would leak through light-grey clothing; the flood fill is
    restricted to edge-connected pixels and the gradient gate stops it at ink.
    """
    rgb = crop.astype(np.float32)
    blurred = _box_blur(rgb, BLUR_SIZE)
    diff = blurred[None, :, :, :] - palette[:, None, None, :]
    distance = np.sqrt((diff * diff).sum(3)).min(0)
    nearest = ((diff * diff).sum(3)).argmin(0)

    chroma = blurred.max(2) - blurred.min(2)
    luma = 0.2126 * blurred[:, :, 0] + 0.7152 * blurred[:, :, 1] + 0.0722 * blurred[:, :, 2]
    bg_luma = (
        0.2126 * palette[:, 0] + 0.7152 * palette[:, 1] + 0.0722 * palette[:, 2]
    )[nearest]

    smooth_luma = _smooth(luma)
    gx = np.zeros_like(smooth_luma)
    gy = np.zeros_like(smooth_luma)
    gx[:, 1:-1] = np.abs(smooth_luma[:, 2:] - smooth_luma[:, :-2]) / 2.0
    gy[1:-1, :] = np.abs(smooth_luma[2:, :] - smooth_luma[:-2, :]) / 2.0
    gradient = np.maximum(gx, gy)

    # Low-contrast greys darker than the studio backdrop are shadows, not ink.
    shadow = (
        (chroma < 12)
        & (luma > 55)
        & (luma < bg_luma + 10)
        & (gradient < 8)
        & (distance < 80)
    )
    fillable = (distance < BG_TOLERANCE) | shadow
    return fillable, distance, nearest


def _strip_ground_shadow(crop: np.ndarray, mask: np.ndarray) -> np.ndarray:
    """Drop opaque pixels below the lowest ink line of each column.

    Studio sheets paint/airbrush a soft shadow under the figure.  It is connected
    to the boots, so a plain background flood cannot remove it.  Every character
    has a dark boot/outline pixel at the lowest part of its silhouette; anything
    below that ink line is floor shadow and is removed.
    """
    rgb = crop.astype(np.float32)
    luma = 0.2126 * rgb[:, :, 0] + 0.7152 * rgb[:, :, 1] + 0.0722 * rgb[:, :, 2]
    ink = (luma < 60) & mask
    h, w = mask.shape
    columns = np.nonzero(mask.any(0))[0]
    if columns.size == 0:
        return mask

    x0, x1 = int(columns.min()), int(columns.max()) + 1
    sole = np.full(w, -1.0)
    for x in range(x0, x1):
        rows = np.nonzero(ink[:, x])[0]
        if rows.size:
            sole[x] = rows.max()
    valid = sole >= 0
    if valid.sum() < 2:
        floor = int(np.nonzero(mask.any(1))[0].max())
        yy = np.arange(h)[:, None]
        return mask & ~(yy > floor + 1)

    sole = np.interp(np.arange(w), np.nonzero(valid)[0], sole[valid])
    smoothed = sole.copy()
    for delta in range(1, 19):
        smoothed = np.maximum(
            smoothed, np.r_[np.full(delta, -1e9), sole[:-delta]]
        )
        smoothed = np.maximum(
            smoothed, np.r_[sole[delta:], np.full(delta, -1e9)]
        )
    yy = np.arange(h)[:, None]
    return mask & ~(yy > smoothed[None, :] + 1)


def _build_matte(crop: np.ndarray, seeds=(), enclosed_cleanup: bool = False) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """Return (decontaminated RGB, alpha uint8, opaque mask)."""
    palette = _estimate_palette(crop)
    fillable, distance, nearest = _background_candidate(crop, palette)
    background = _flood_from_edges(fillable, seeds=seeds)
    if enclosed_cleanup:
        background |= _enclosed_background(fillable, crop, palette)
    opaque, _ = _largest_component(~background)
    if not opaque.any():
        raise RuntimeError("matte produced no foreground; check the crop hint")

    expanded_background = background
    for _ in range(3):
        expanded_background = _dilate(expanded_background)
    band = opaque & expanded_background

    alpha = np.where(opaque, 1.0, 0.0).astype(np.float32)
    rgb = crop.astype(np.float32)
    original_distance = np.sqrt(
        (((rgb[None, :, :, :] - palette[:, None, None, :]) ** 2).sum(3))
    ).min(0)
    soft = np.clip((original_distance - 4.0) / (80.0 - 4.0), 0.0, 1.0)
    alpha[band] = soft[band]

    # Un-premultiply the observed background blend so a grey fringe is not left
    # when the standee is scaled up in the shader.
    out = rgb.copy()
    blended = band & (alpha > 0.02)
    a = alpha[blended][:, None]
    bg = palette[nearest][blended]
    out[blended] = np.clip((rgb[blended] - (1.0 - a) * bg) / a, 0, 255)
    return out.astype(np.uint8), (alpha * 255.0).astype(np.uint8), opaque


def _compose(fig: np.ndarray, alpha: np.ndarray, width: int, height: int) -> Image.Image:
    """Resample the isolated figure into the original canvas, soles at y=H-3.

    RGBA is resized premultiplied so transparent pixels cannot bleed their RGB
    into the silhouette edge.
    """
    ys, xs = np.nonzero(alpha > 8)
    if ys.size == 0:
        return Image.new("RGBA", (width, height), (0, 0, 0, 0))
    y0, y1 = int(ys.min()), int(ys.max()) + 1
    x0, x1 = int(xs.min()), int(xs.max()) + 1
    rgb = fig[y0:y1, x0:x1].astype(np.float32)
    a = alpha[y0:y1, x0:x1].astype(np.float32) / 255.0
    cw, ch = x1 - x0, y1 - y0

    target_h = max(1, height - 2)
    target_w = max(1, int(round(target_h * cw / ch)))
    if target_w > width - 2:
        target_w = width - 2
        target_h = max(1, int(round(target_w * ch / cw)))

    premultiplied = np.dstack([rgb * a[:, :, None], a * 255.0])
    resized = np.asarray(
        Image.fromarray(premultiplied.astype(np.uint8), "RGBA").resize(
            (target_w, target_h), Image.LANCZOS
        )
    ).astype(np.float32)
    out_rgb = resized[:, :, :3]
    out_a = resized[:, :, 3]
    safe = out_a > 0.0
    out_rgb[safe] = np.clip(out_rgb[safe] / (out_a[safe, None] / 255.0), 0, 255)
    composed = np.dstack([out_rgb, out_a]).astype(np.uint8)

    canvas = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    canvas.alpha_composite(
        Image.fromarray(composed, "RGBA"),
        ((width - target_w) // 2, max(0, height - 1 - target_h)),
    )
    return canvas


def _apply_polygon(mask: np.ndarray, points) -> np.ndarray:
    draw = Image.new("L", (mask.shape[1], mask.shape[0]), 0)
    ImageDraw.Draw(draw).polygon(points, fill=255)
    return mask & (np.asarray(draw) > 0)


def _process(source: Path, hint: dict) -> tuple[Image.Image, dict]:
    image = Image.open(source).convert("RGB")
    full = np.asarray(image)
    height, width = full.shape[:2]

    crop_box = hint.get("crop", (0, 0, width, height))
    x0, y0, x1, y1 = crop_box
    if not (0 <= x0 < x1 <= width and 0 <= y0 < y1 <= height):
        raise ValueError(f"crop {crop_box} outside {source} ({width}x{height})")
    crop = full[y0:y1, x0:x1]

    fig, soft_alpha, _ = _build_matte(
        crop,
        seeds=hint.get("bg_seeds", ()),
        enclosed_cleanup=bool(hint.get("enclosed_cleanup", False)),
    )
    opaque = _strip_ground_shadow(crop, soft_alpha > 8)
    if "polygon" in hint:
        opaque = _apply_polygon(opaque, hint["polygon"])
    for _ in range(int(hint.get("erode", 0))):
        core, _ = _largest_component(_erode(opaque))
        opaque = _dilate(core) & opaque
    if "outside_below" in hint:
        # Halftone studio shadows sit outside the figure's ink contour.  A
        # coarse ink flood identifies the outside region; only drop it below
        # the safe row so a leaky neckline can never eat the head.
        blurred = _box_blur(crop.astype(np.float32), BLUR_SIZE)
        luma = 0.2126 * blurred[:, :, 0] + 0.7152 * blurred[:, :, 1] + 0.0722 * blurred[:, :, 2]
        outside = _flood_from_edges(~(luma < 110))
        rows = np.arange(opaque.shape[0])[:, None]
        opaque &= ~(outside & (rows > int(hint["outside_below"])))
    if "raw_outside_below" in hint:
        # Raw (unblurred) dark ink gives a tighter silhouette contour than the
        # blurred matte, so exterior grey floor shadows can be dropped while
        # enclosed grey clothing stays inside the contour.
        raw = crop.astype(np.float32)
        raw_luma = 0.2126 * raw[:, :, 0] + 0.7152 * raw[:, :, 1] + 0.0722 * raw[:, :, 2]
        outside = _flood_from_edges(~(raw_luma < 80))
        rows = np.arange(opaque.shape[0])[:, None]
        opaque &= ~(outside & (rows > int(hint["raw_outside_below"])))

    alpha = np.where(opaque, soft_alpha, 0).astype(np.uint8)
    canvas_w, canvas_h = hint.get("canvas_size", (width, height))
    composed = _compose(fig, alpha, canvas_w, canvas_h)
    meta = {
        "source": str(source),
        "source_size": (width, height),
        "crop": crop_box,
        "opaque_pixels": int((alpha > 8).sum()),
        "output_size": composed.size,
    }
    return composed, meta


def _output_name(slug: str) -> str:
    return OUTPUT_NAME_OVERRIDES.get(slug, slug.replace("-", "_"))


def _discover() -> dict[str, Path]:
    found: dict[str, Path] = {}
    for path in sorted(CHARACTERS_DIR.glob("*/*/full_body_concept.png")):
        found[path.parent.name] = path
    return found


def _self_test() -> None:
    """Deterministic synthetic checks for the matte and composition behaviour."""
    checks = 0

    width, height = 300, 320
    bg = np.array([168, 168, 168], dtype=np.float32)
    body = np.array([210, 70, 70], dtype=np.float32)
    source = np.full((height, width, 3), bg, dtype=np.float32)

    # Grey "clothing" inside a closed black ink outline.  It is exactly the
    # background colour, so only edge-connectivity can protect it.
    bx0, by0, bx1, by1 = 30, 30, 150, 300
    source[by0:by0 + 3, bx0:bx1] = 0
    source[by1 - 3:by1, bx0:bx1] = 0
    source[by0:by1, bx0:bx0 + 3] = 0
    source[by0:by1, bx1 - 3:bx1] = 0
    source[by0 + 3:by1 - 3, bx0 + 3:bx1 - 3] = bg
    source[100:104, 50:130] = 0  # black manga ink stroke

    # A soft-edged red arm with a connector to the outlined body, so both are
    # one opaque component for the largest-component stage.
    source[250:262, 130:170] = 0
    source[40:280, 170:250] = body
    # Soft edge faces the crop border so the flood fill leaves a partial-alpha
    # boundary pixel adjacent to background.
    for index, step in enumerate(np.linspace(1.0, 0.0, 20)):
        x = 250 + index
        source[40:280, x] = bg * (1.0 - step) + body * step

    synthetic = Image.fromarray(source.astype(np.uint8), "RGB")
    crop = np.asarray(synthetic)
    fig, soft_alpha, _ = _build_matte(crop)
    opaque = _strip_ground_shadow(crop, soft_alpha > 8)
    alpha = np.where(opaque, soft_alpha, 0).astype(np.uint8)

    def require(condition: bool, message: str) -> None:
        nonlocal checks
        if not condition:
            raise AssertionError(f"self-test failed: {message}")
        checks += 1

    require(alpha[5, 5] == 0, "background corner was not cleared")
    require(alpha[200, 90] == 255, "enclosed grey clothing was erased")
    require(
        alpha[102, 90] == 255 and int(fig[102, 90].max()) < 20,
        "black manga ink was not preserved",
    )

    band_alpha = alpha[200, 245:280]
    partial = np.nonzero((band_alpha > 10) & (band_alpha < 245))[0]
    require(partial.size > 0, "soft edge produced no partial alpha")
    px = 245 + int(partial[0])
    observed = source[200, px]
    recovered = fig[200, px].astype(np.float32)
    observed_d = float(np.linalg.norm(observed - bg))
    recovered_d = float(np.linalg.norm(recovered - bg))
    require(
        recovered_d > observed_d + 3.0,
        "edge pixel was not decontaminated (grey halo remains)",
    )

    composed = _compose(fig, alpha, width, height)
    require(composed.size == (width, height), "compose changed canvas dimensions")
    composed_alpha = np.asarray(composed)[:, :, 3]
    require(
        composed_alpha[height - 2].max() > 8,
        "composed soles do not reach the bottom canvas edge",
    )

    print(f"self-test: PASS ({checks} checks)")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--driver", action="append", default=[], help="driver folder slug (repeatable)")
    parser.add_argument("--source", type=Path, help="ad-hoc source PNG")
    parser.add_argument("--output", type=Path, help="ad-hoc output PNG (requires --source)")
    parser.add_argument("--out-dir", type=Path, default=DEFAULT_OUT_DIR)
    parser.add_argument("--force", action="store_true", help="overwrite existing standees")
    parser.add_argument("--self-test", action="store_true", help="run deterministic synthetic checks")
    args = parser.parse_args(argv)

    if args.self_test:
        _self_test()
        return 0

    if args.source:
        if not args.output:
            parser.error("--source requires --output")
        source = args.source.resolve()
        composition, meta = _process(source, DRIVER_HINTS.get(source.parent.name, {}))
        if args.output.exists() and not args.force:
            print(f"SKIP {args.output} (exists; use --force)")
            return 0
        args.output.parent.mkdir(parents=True, exist_ok=True)
        composition.save(args.output)
        print(f"WROTE {args.output} {meta['output_size']} from {source}")
        return 0

    drivers = _discover()
    if not drivers:
        print(f"no full_body_concept.png under {CHARACTERS_DIR}", file=sys.stderr)
        return 1
    requested = args.driver or sorted(drivers)
    missing = [slug for slug in requested if slug not in drivers]
    if missing:
        print(f"unknown driver(s): {', '.join(missing)}", file=sys.stderr)
        return 1

    args.out_dir.mkdir(parents=True, exist_ok=True)
    written = 0
    skipped = 0
    for slug in requested:
        destination = args.out_dir / f"{_output_name(slug)}.png"
        if destination.exists() and not args.force:
            print(f"SKIP {destination.name} (exists; use --force)")
            skipped += 1
            continue
        hint = DRIVER_HINTS.get(slug, {})
        try:
            composition, meta = _process(drivers[slug], hint)
        except Exception as exc:  # keep processing the rest of the roster
            print(f"FAIL {slug}: {exc}", file=sys.stderr)
            continue
        composition.save(destination)
        written += 1
        figure_pixels = int((np.asarray(composition)[:, :, 3] > 8).sum())
        print(
            f"WROTE {destination.name:22s} {composition.size[0]}x{composition.size[1]} "
            f"RGBA  opaque={figure_pixels}"
        )

    print(f"done: {written} written, {skipped} skipped, {len(requested)} requested")
    return 0 if written + skipped == len(requested) else 1


if __name__ == "__main__":
    raise SystemExit(main())
