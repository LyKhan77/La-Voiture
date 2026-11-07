#!/usr/bin/env python3
"""Build the podium standees from the approved single-figure driver art.

Input, per driver folder in reference-assets/characters/<team>/<driver>/:
  full_body_base.png  standing pose (idle)
  pose_win.png        victory pose, same camera and framing

Output in assets/characters/standees/:
  <slug>.png          idle standee
  <slug>_win.png      victory standee

Both are RGBA, 720 x 1328: the source canvas (720 x 1280) plus TOP_PAD_PX of headroom so a raised fist
never clips, with the soles SOLE_GAP_PX above the bottom edge. The win pose is shifted so its soles land
where the base's soles are, which keeps the feet planted when the podium swaps the two.

The source background is either already transparent or one flat colour (magenta, green, orange). A flat
background is removed by flood fill from the border plus enclosed pockets of the same colour, and the
anti-aliased edge is decontaminated so no coloured halo is left. Sources are never modified.

Usage:
    py tools/build_driver_standees.py              # all 26 drivers
    py tools/build_driver_standees.py --slot 7     # one driver
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage as ndi

ROOT = Path(__file__).resolve().parents[1]
CHARS = ROOT / "reference-assets" / "characters"
OUT = ROOT / "assets" / "characters" / "standees"
SRC_W, SRC_H = 720, 1280
TOP_PAD_PX = 48
SOLE_GAP_PX = 3
TIGHT_L1 = 60        # colour distance counted as "the background colour"
POCKET_MIN_PX = 250  # an enclosed background-coloured pocket smaller than this is kept (it is artwork)
EDGE_BAND_PX = 3


def roster() -> tuple[list[str], list[str]]:
    src = (ROOT / "scripts" / "ui" / "garage_roster.gd").read_text(encoding="utf8")

    def block(name: str) -> list[str]:
        body = src.split(f"const {name}")[1].split("= [")[1].split("]")[0]
        return re.findall(r'"([a-z\-]+)"', body)

    return block("TEAM_SLUGS"), block("DRIVER_SLUGS")


def standee_stem(driver_slug: str) -> str:
    stem = driver_slug.replace("-", "_")
    return "arthur_sterling" if stem == "arthur_sterling_jr" else stem


def load(path: Path) -> np.ndarray:
    image = Image.open(path).convert("RGBA")
    if image.size != (SRC_W, SRC_H):
        image = image.resize((SRC_W, SRC_H), Image.LANCZOS)
    return np.array(image)


def cut_out(rgba: np.ndarray) -> np.ndarray:
    """RGBA with a clean alpha: kept as is when already transparent, else keyed from the flat background."""
    alpha = rgba[:, :, 3]
    if (alpha < 10).mean() > 0.05:
        out = rgba.copy()
        out[alpha < 10] = 0
        return out
    rgb = rgba[:, :, :3].astype(np.int32)
    ring = np.concatenate([rgb[:6].reshape(-1, 3), rgb[-6:].reshape(-1, 3), rgb[:, :6].reshape(-1, 3), rgb[:, -6:].reshape(-1, 3)])
    bg = np.median(ring, axis=0)
    dist = np.abs(rgb - bg).sum(axis=2)
    tight = dist < TIGHT_L1
    labels, count = ndi.label(tight)
    sizes = ndi.sum(tight, labels, index=np.arange(1, count + 1))
    border = set(np.unique(np.concatenate([labels[0], labels[-1], labels[:, 0], labels[:, -1]]))) - {0}
    drop = np.zeros(count + 1, dtype=bool)
    for label, size in enumerate(sizes, start=1):
        drop[label] = label in border or size >= POCKET_MIN_PX
    background = drop[labels]

    # Edge band: partially covered pixels next to the removed background.
    near = ndi.binary_dilation(background, iterations=EDGE_BAND_PX) & ~background
    # The solid colour just inside the edge, taken from the nearest interior pixel.
    interior = ~(near | background)
    _, (iy, ix) = ndi.distance_transform_edt(~interior, return_indices=True)
    solid = rgb[iy, ix].astype(np.float64)
    px = rgb.astype(np.float64)
    span = solid - bg
    denom = (span * span).sum(axis=2)
    cover = np.where(denom > 900.0, ((px - bg) * span).sum(axis=2) / np.maximum(denom, 1.0), 1.0)
    cover = np.clip(cover, 0.0, 1.0)
    new_alpha = np.where(background, 0.0, np.where(near, cover, 1.0))
    safe = np.maximum(new_alpha, 1e-3)[:, :, None]
    color = np.where(near[:, :, None], (px - (1.0 - new_alpha)[:, :, None] * bg) / safe, px)
    out = np.zeros_like(rgba)
    out[:, :, :3] = np.clip(color, 0, 255).astype(np.uint8)
    out[:, :, 3] = np.clip(new_alpha * 255.0, 0, 255).astype(np.uint8)
    out[out[:, :, 3] < 6] = 0
    return out


def figure_box(rgba: np.ndarray) -> tuple[int, int, int, int]:
    ys, xs = np.where(rgba[:, :, 3] > 128)
    return int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())


def feet_center_x(rgba: np.ndarray) -> float:
    _, _, _, bottom = figure_box(rgba)
    ys, xs = np.where(rgba[:, :, 3] > 128)
    rows = ys > bottom - int(0.04 * rgba.shape[0])
    return float(xs[rows].mean())


def place(rgba: np.ndarray, dx: int, dy: int) -> np.ndarray:
    """Paste on the output canvas, moved by (dx, dy) from its top-left at (0, TOP_PAD_PX)."""
    canvas = np.zeros((SRC_H + TOP_PAD_PX, SRC_W, 4), dtype=np.uint8)
    y0, x0 = TOP_PAD_PX + dy, dx
    ys0, ys1 = max(0, -y0), min(SRC_H, canvas.shape[0] - y0)
    xs0, xs1 = max(0, -x0), min(SRC_W, canvas.shape[1] - x0)
    canvas[y0 + ys0:y0 + ys1, x0 + xs0:x0 + xs1] = rgba[ys0:ys1, xs0:xs1]
    return canvas


def build(slot: int, teams: list[str], drivers: list[str]) -> dict:
    folder = CHARS / teams[slot // 2] / drivers[slot]
    base = cut_out(load(folder / "full_body_base.png"))
    win = cut_out(load(folder / "pose_win.png"))
    _, _, _, base_bottom = figure_box(base)
    _, _, _, win_bottom = figure_box(win)
    # Soles of the base land SOLE_GAP_PX above the canvas bottom; the win pose follows the base's feet.
    base_dy = (SRC_H + TOP_PAD_PX - SOLE_GAP_PX - 1) - TOP_PAD_PX - base_bottom
    win_dy = base_dy + (base_bottom - win_bottom)
    win_dx = int(round(feet_center_x(base) - feet_center_x(win)))
    standee = place(base, 0, base_dy)
    victory = place(win, win_dx, win_dy)
    stem = standee_stem(drivers[slot])
    OUT.mkdir(parents=True, exist_ok=True)
    Image.fromarray(standee, "RGBA").save(OUT / f"{stem}.png", optimize=True)
    Image.fromarray(victory, "RGBA").save(OUT / f"{stem}_win.png", optimize=True)
    _, top_b, _, _ = figure_box(standee)
    _, top_w, _, bottom_w = figure_box(victory)
    return {"slot": slot, "stem": stem, "top_base": top_b, "top_win": top_w, "bottom_win": bottom_w,
            "win_shift": (win_dx, win_dy - base_dy)}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--slot", type=int, default=None)
    args = parser.parse_args()
    teams, drivers = roster()
    slots = [args.slot] if args.slot is not None else list(range(len(drivers)))
    for slot in slots:
        info = build(slot, teams, drivers)
        print(info)
    return 0


if __name__ == "__main__":
    sys.exit(main())
