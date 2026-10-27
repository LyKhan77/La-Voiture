"""
Script to generate the interactive HTML preview for OPSI 3: Street Zine Motion Comic.
Updated with proper character scaling so faces, crowns, and full bodies are crisp & clear!
"""

import base64
import os

def get_base64_image(path):
    with open(path, "rb") as f:
        return "data:image/png;base64," + base64.b64encode(f.read()).decode("utf-8")

def main():
    stage_bg_path = "temp/stage_clean_pristine.png"
    kaze_path = "assets/characters/standees/kaze_ryu.png"
    makoto_path = "assets/characters/standees/makoto_ito.png"
    arthur_path = "assets/characters/standees/arthur_sterling.png"

    print("Encoding images...")
    stage_bg_b64 = get_base64_image(stage_bg_path)
    kaze_b64 = get_base64_image(kaze_path)
    makoto_b64 = get_base64_image(makoto_path)
    arthur_b64 = get_base64_image(arthur_path)

    html_content = f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>La Voiture — Winning Scene: Opsi 3 Street Zine Motion Comic</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Bebas+Neue&family=Permanent+Marker&family=Space+Grotesk:wght@500;700;900&family=Noto+Sans+JP:wght@900&display=swap" rel="stylesheet">
<style>
:root {{
    --acid-lime: #D8FF00;
    --neon-cyan: #00F0FF;
    --hazard-orange: #FF6B00;
    --hot-pink: #FF0055;
    --ink-black: #08080C;
    --pure-white: #FFFFFF;
    --paper-white: #F4F4F6;
}}

* {{
    box-sizing: border-box;
    margin: 0;
    padding: 0;
    user-select: none;
}}

body {{
    background-color: var(--ink-black);
    color: var(--pure-white);
    font-family: 'Space Grotesk', sans-serif;
    overflow: hidden;
    height: 100vh;
    width: 100vw;
    display: flex;
    flex-direction: column;
    justify-content: center;
    align-items: center;
}}

/* 16:9 Stage Frame */
.viewport-frame {{
    position: relative;
    width: 100vw;
    height: 100vh;
    max-width: 1920px;
    max-height: 1080px;
    overflow: hidden;
    background: #09090D;
    box-shadow: 0 0 80px rgba(0,0,0,0.95);
}}

/* 3D Turntable Background with Parallax */
.stage-background {{
    position: absolute;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    background-image: url('{stage_bg_b64}');
    background-size: cover;
    background-position: center;
    filter: brightness(0.60) contrast(1.1) saturate(1.2);
    transform: scale(1.05);
    transition: transform 0.6s cubic-bezier(0.16, 1, 0.3, 1), filter 0.4s ease;
}}

/* Halftone Screentone Grid Overlay across whole stage */
.global-halftone {{
    position: absolute;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    background-image: radial-gradient(rgba(216, 255, 0, 0.10) 1.5px, transparent 1.5px);
    background-size: 10px 10px;
    pointer-events: none;
    z-index: 2;
}}

/* ============================================================
   OPSI 3: THE 3 MOTION COMIC PANELS (ASLEW / SLANTED)
   ============================================================ */
.comic-triptych-stage {{
    position: absolute;
    top: 50%;
    left: 50%;
    transform: translate(-50%, -46%);
    width: 1560px;
    height: 700px;
    display: flex;
    justify-content: center;
    align-items: center;
    gap: 38px;
    z-index: 15;
    transition: transform 0.4s cubic-bezier(0.16, 1, 0.3, 1), opacity 0.4s ease;
}}

/* When Leaderboard Zine Opens, shrink & push left */
.comic-triptych-stage.zine-docked {{
    transform: translate(-65%, -46%) scale(0.92);
    opacity: 0.85;
}}

/* Base Comic Panel Shell */
.manga-panel {{
    position: relative;
    background: #0E0F14;
    border: 5px solid #000;
    box-shadow: 10px 10px 0px #000;
    overflow: visible;
    transition: transform 0.25s cubic-bezier(0.16, 1, 0.3, 1), box-shadow 0.25s ease;
}}

.manga-panel:hover {{
    transform: scale(1.03) !important;
    z-index: 30 !important;
}}

/* Panel Interior Clip Box */
.panel-viewport {{
    position: relative;
    width: 100%;
    height: 100%;
    overflow: hidden;
    background: #111218;
}}

/* Screentone texture inside panel */
.panel-screentone {{
    position: absolute;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    background-size: 8px 8px;
    pointer-events: none;
    z-index: 1;
}}

/* Slapped Vinyl Tape Headers */
.panel-tape-strip {{
    position: absolute;
    top: -16px;
    font-family: 'Space Grotesk', sans-serif;
    font-weight: 900;
    font-size: 12px;
    letter-spacing: 1.5px;
    padding: 4px 14px;
    text-transform: uppercase;
    border: 3px solid #000;
    box-shadow: 4px 4px 0px #000;
    z-index: 25;
}}

/* Bottom Panel Card Footer */
.panel-footer-zine {{
    position: absolute;
    bottom: 0;
    left: 0;
    width: 100%;
    background: #000;
    border-top: 3px solid #000;
    padding: 12px 18px;
    display: flex;
    flex-direction: column;
    gap: 2px;
    z-index: 20;
}}

.panel-driver-name {{
    font-family: 'Bebas Neue', sans-serif;
    font-size: 38px;
    line-height: 0.9;
    letter-spacing: 1px;
    color: #FFF;
}}

.panel-stats-sub {{
    font-size: 12px;
    font-weight: 700;
    display: flex;
    justify-content: space-between;
    align-items: center;
    font-family: monospace;
}}

/* ============================================================
   PANEL 1 (LEFT): P2 MAKOTO ITO (Slanted -3.5deg, Cyan)
   ============================================================ */
.panel-p2 {{
    width: 420px;
    height: 590px;
    transform: rotate(-3.5deg) translateY(20px);
    border-color: #000;
    box-shadow: 8px 8px 0px #000, 14px 14px 0px rgba(0, 240, 255, 0.45);
    z-index: 18;
}}

.panel-p2 .panel-screentone {{
    background-image: radial-gradient(rgba(0, 240, 255, 0.18) 1.5px, transparent 1.5px);
}}

.panel-p2 .panel-tape-strip {{
    left: 20px;
    background: var(--neon-cyan);
    color: #000;
    transform: rotate(-3deg);
}}

.character-cutout-p2 {{
    position: absolute;
    bottom: 50px;
    left: 50%;
    transform: translateX(-50%);
    height: 500px;
    width: auto;
    object-fit: contain;
    z-index: 5;
    animation: anime-pose-p2 1.4s steps(6, end) infinite;
}}

@keyframes anime-pose-p2 {{
    0%   {{ transform: translateX(-50%) translateY(0) scale(1); }}
    33%  {{ transform: translateX(-50%) translateY(-5px) scale(1.01); }}
    66%  {{ transform: translateX(-50%) translateY(-2px) scale(1.005); }}
    100% {{ transform: translateX(-50%) translateY(0) scale(1); }}
}}

/* ============================================================
   PANEL 2 (CENTER): P1 KAZE RYU GRAND CHAMPION (Prominent, Acid Lime)
   ============================================================ */
.panel-p1 {{
    width: 530px;
    height: 670px;
    transform: rotate(0deg) translateY(-25px);
    border: 6px solid #000;
    box-shadow: 12px 12px 0px #000, 20px 20px 0px var(--acid-lime);
    z-index: 22;
    background: #080A06;
}}

.panel-p1 .panel-screentone {{
    background-image: radial-gradient(rgba(216, 255, 0, 0.22) 2px, transparent 2px);
    background-size: 10px 10px;
}}

.panel-p1 .panel-tape-strip {{
    left: 50%;
    transform: translateX(-50%) rotate(-1deg);
    background: var(--acid-lime);
    color: #000;
    font-size: 14px;
    padding: 6px 22px;
    box-shadow: 4px 4px 0px #000;
    white-space: nowrap;
}}

/* P1 Character Cutout fitted properly */
.character-cutout-p1 {{
    position: absolute;
    bottom: 55px;
    left: 50%;
    transform: translateX(-50%);
    height: 560px;
    width: auto;
    object-fit: contain;
    z-index: 10;
    animation: anime-pose-p1 1.2s steps(6, end) infinite;
}}

@keyframes anime-pose-p1 {{
    0%   {{ transform: translateX(-50%) translateY(0) scale(1); }}
    33%  {{ transform: translateX(-50%) translateY(-6px) scale(1.012); }}
    50%  {{ transform: translateX(-50%) translateY(-9px) scale(1.018); }}
    83%  {{ transform: translateX(-50%) translateY(-3px) scale(1.006); }}
    100% {{ transform: translateX(-50%) translateY(0) scale(1); }}
}}

/* IN-FRAME GRAFFITI WINGS (Anchored Behind Ryu's Shoulders inside panel) */
.panel-wings-svg {{
    position: absolute;
    top: 90px;
    left: 50%;
    transform: translateX(-50%);
    width: 500px;
    height: 250px;
    z-index: 4;
    animation: wings-flap-12fps 0.4s steps(4, end) infinite;
}}

@keyframes wings-flap-12fps {{
    0%   {{ transform: translateX(-50%) scale(1) rotate(0deg); }}
    25%  {{ transform: translateX(-50%) scale(1.08, 0.92) rotate(-2deg); }}
    50%  {{ transform: translateX(-50%) scale(0.96, 1.06) rotate(2deg); }}
    75%  {{ transform: translateX(-50%) scale(1.04, 0.98) rotate(1deg); }}
    100% {{ transform: translateX(-50%) scale(1) rotate(0deg); }}
}}

/* IN-FRAME GRAFFITI CROWN (Hovering locked 15px above Ryu's hair inside panel) */
.panel-crown-svg {{
    position: absolute;
    top: 25px;
    left: 50%;
    transform: translateX(-50%);
    width: 120px;
    height: 75px;
    z-index: 12;
    animation: crown-wobble-12fps 0.8s steps(4, end) infinite;
}}

@keyframes crown-wobble-12fps {{
    0%   {{ transform: translateX(-50%) translateY(0) rotate(-3deg); }}
    25%  {{ transform: translateX(-50%) translateY(-5px) rotate(2deg); }}
    50%  {{ transform: translateX(-50%) translateY(-8px) rotate(-1deg); }}
    75%  {{ transform: translateX(-50%) translateY(-3px) rotate(3deg); }}
    100% {{ transform: translateX(-50%) translateY(0) rotate(-3deg); }}
}}

/* IN-FRAME MANGA KANJI 勝者 */
.panel-kanji-shousha {{
    position: absolute;
    top: 55px;
    left: 20px;
    font-family: 'Noto Sans JP', sans-serif;
    font-weight: 900;
    font-size: 60px;
    color: var(--acid-lime);
    text-shadow: 
        4px 4px 0px #000, 
        -2px -2px 0px #000, 
        2px -2px 0px #000, 
        -2px 2px 0px #000,
        0 0 25px rgba(216, 255, 0, 0.9);
    transform: rotate(-10deg);
    z-index: 14;
    letter-spacing: -3px;
    animation: kanji-pulse 1s steps(4, end) infinite alternate;
}}

@keyframes kanji-pulse {{
    0%   {{ transform: rotate(-10deg) scale(1); }}
    100% {{ transform: rotate(-8deg) scale(1.08); }}
}}

/* EYE-GLINT STAR SPARKLE */
.panel-eye-glint {{
    position: absolute;
    top: 104px;
    left: 247px;
    width: 24px;
    height: 24px;
    z-index: 15;
    animation: glint-cycle 3s steps(1, end) infinite;
}}

@keyframes glint-cycle {{
    0%, 84% {{ opacity: 0; transform: scale(0) rotate(0deg); }}
    86%     {{ opacity: 1; transform: scale(1.8) rotate(45deg); }}
    90%     {{ opacity: 0.95; transform: scale(2.4) rotate(90deg); }}
    95%     {{ opacity: 0.4; transform: scale(1.0) rotate(135deg); }}
    100%    {{ opacity: 0; transform: scale(0) rotate(180deg); }}
}}

/* ============================================================
   PANEL 3 (RIGHT): P3 T. KADE (Slanted Right +3.5deg, Hazard Orange)
   ============================================================ */
.panel-p3 {{
    width: 420px;
    height: 590px;
    transform: rotate(3.5deg) translateY(20px);
    border-color: #000;
    box-shadow: 8px 8px 0px #000, 14px 14px 0px rgba(255, 107, 0, 0.45);
    z-index: 18;
}}

.panel-p3 .panel-screentone {{
    background-image: radial-gradient(rgba(255, 107, 0, 0.18) 1.5px, transparent 1.5px);
}}

.panel-p3 .panel-tape-strip {{
    right: 20px;
    background: var(--hazard-orange);
    color: #000;
    transform: rotate(3deg);
}}

.character-cutout-p3 {{
    position: absolute;
    bottom: 50px;
    left: 50%;
    transform: translateX(-50%);
    height: 500px;
    width: auto;
    object-fit: contain;
    z-index: 5;
    animation: anime-pose-p3 1.4s steps(6, end) infinite;
}}

@keyframes anime-pose-p3 {{
    0%   {{ transform: translateX(-50%) translateY(0) scale(1); }}
    33%  {{ transform: translateX(-50%) translateY(-5px) scale(1.01); }}
    66%  {{ transform: translateX(-50%) translateY(-2px) scale(1.005); }}
    100% {{ transform: translateX(-50%) translateY(0) scale(1); }}
}}

/* ============================================================
   TOP HEADLINE: MANGA LOOKBOOK HEADER
   ============================================================ */
.top-header-zine {{
    position: absolute;
    top: 28px;
    left: 48px;
    z-index: 30;
    display: flex;
    flex-direction: column;
    gap: 6px;
}}

.top-badge-strip {{
    display: flex;
    align-items: center;
    gap: 12px;
    font-weight: 700;
    font-size: 13px;
    letter-spacing: 2px;
}}

.tag-black-box {{
    background: #000;
    color: var(--acid-lime);
    padding: 4px 12px;
    border: 2px solid var(--acid-lime);
    transform: skewX(-10deg);
    box-shadow: 3px 3px 0px #000;
}}

.tag-warning-tape {{
    background: repeating-linear-gradient(
        -45deg,
        #D8FF00,
        #D8FF00 10px,
        #000000 10px,
        #000000 20px
    );
    color: #000;
    font-weight: 900;
    padding: 4px 14px;
    font-size: 11px;
    letter-spacing: 1.5px;
    box-shadow: 3px 3px 0px #000;
}}

.main-headline-brutal {{
    font-family: 'Bebas Neue', sans-serif;
    font-size: 88px;
    line-height: 0.82;
    letter-spacing: 2px;
    color: #FFF;
    text-shadow: 6px 6px 0px #000;
}}

.headline-sub-cutout {{
    align-self: flex-start;
    background: var(--pure-white);
    color: var(--ink-black);
    font-family: 'Space Grotesk', sans-serif;
    font-weight: 900;
    font-size: 14px;
    padding: 4px 12px;
    transform: rotate(-2deg);
    box-shadow: 4px 4px 0px var(--hot-pink);
    letter-spacing: 1px;
}}

/* ============================================================
   RACE ZINE: CLASSIFICATION LEADERBOARD DRAWER (TAB)
   ============================================================ */
.race-zine-drawer {{
    position: absolute;
    top: 28px;
    right: 48px;
    bottom: 74px;
    width: 530px;
    background: #0E0F16;
    border: 4px solid #000;
    box-shadow: 10px 10px 0px #000, 16px 16px 0px var(--acid-lime);
    z-index: 40;
    display: flex;
    flex-direction: column;
    transform: translateX(650px) rotate(2deg);
    opacity: 0;
    pointer-events: none;
    transition: transform 0.4s cubic-bezier(0.16, 1, 0.3, 1), opacity 0.3s ease;
    overflow: hidden;
}}

.race-zine-drawer.open {{
    transform: translateX(0) rotate(0deg);
    opacity: 1;
    pointer-events: auto;
}}

.zine-header {{
    background: #000;
    padding: 16px 20px;
    border-bottom: 3px solid var(--acid-lime);
    display: flex;
    justify-content: space-between;
    align-items: center;
}}

.zine-title {{
    font-family: 'Bebas Neue', sans-serif;
    font-size: 34px;
    color: var(--acid-lime);
    letter-spacing: 1.5px;
}}

.zine-badge-close {{
    background: var(--hot-pink);
    color: #FFF;
    border: 2px solid #000;
    box-shadow: 2px 2px 0px #000;
    padding: 5px 12px;
    font-weight: 900;
    font-size: 12px;
    cursor: pointer;
}}

.zine-table-scroll {{
    flex: 1;
    overflow-y: auto;
    padding: 12px 20px;
    display: flex;
    flex-direction: column;
    gap: 4px;
}}

.zine-table-scroll::-webkit-scrollbar {{
    width: 6px;
}}
.zine-table-scroll::-webkit-scrollbar-thumb {{
    background: var(--acid-lime);
}}

.zine-row {{
    display: grid;
    grid-template-columns: 36px 1fr 100px 50px;
    align-items: center;
    padding: 7px 10px;
    background: rgba(255, 255, 255, 0.03);
    border-left: 3px solid transparent;
    font-size: 13px;
    font-weight: 700;
}}

.zine-row.pos-1 {{
    background: rgba(216, 255, 0, 0.16);
    border-left: 4px solid var(--acid-lime);
    color: var(--acid-lime);
}}

.zine-row.pos-2 {{
    border-left: 4px solid var(--neon-cyan);
}}

.zine-row.pos-3 {{
    border-left: 4px solid var(--hazard-orange);
}}

.zine-row:nth-child(even) {{
    background: rgba(255, 255, 255, 0.05);
}}

.zine-pos {{
    font-family: 'Bebas Neue', sans-serif;
    font-size: 19px;
}}

.zine-driver {{
    display: flex;
    flex-direction: column;
}}

.zine-team-sub {{
    font-size: 10px;
    opacity: 0.65;
}}

.zine-gap {{
    font-family: monospace;
    font-size: 12px;
}}

.zine-pts {{
    text-align: right;
    font-weight: 900;
}}

/* ============================================================
   BOTTOM INTERACTIVE TOOLBAR
   ============================================================ */
.bottom-toolbar {{
    position: absolute;
    bottom: 14px;
    left: 50%;
    transform: translateX(-50%);
    display: flex;
    gap: 12px;
    z-index: 50;
}}

.tool-btn {{
    background: #000;
    color: #FFF;
    border: 2px solid #333;
    box-shadow: 3px 3px 0px #000;
    padding: 7px 16px;
    font-family: 'Space Grotesk', sans-serif;
    font-weight: 700;
    font-size: 12px;
    text-transform: uppercase;
    letter-spacing: 1px;
    cursor: pointer;
    transition: all 0.15s ease;
    display: flex;
    align-items: center;
    gap: 8px;
}}

.tool-btn:hover {{
    border-color: var(--acid-lime);
    color: var(--acid-lime);
    transform: translateY(-2px);
    box-shadow: 4px 4px 0px var(--acid-lime);
}}

.tool-btn.active {{
    background: var(--acid-lime);
    color: #000;
    border-color: #000;
    box-shadow: 4px 4px 0px #000;
}}

.key-badge {{
    background: rgba(255, 255, 255, 0.2);
    color: inherit;
    padding: 1px 6px;
    border-radius: 2px;
    font-size: 10px;
}}

.tool-btn.active .key-badge {{
    background: #000;
    color: var(--acid-lime);
}}
</style>
</head>
<body>

<div class="viewport-frame" id="viewportStage">

    <!-- 3D Turntable Background (Car & Stage visible through parallax) -->
    <div class="stage-background" id="stageBg"></div>

    <!-- Screentone Grid Layer -->
    <div class="global-halftone"></div>

    <!-- Top Lookbook Header -->
    <div class="top-header-zine">
        <div class="top-badge-strip">
            <span class="tag-black-box">/// LA VOITURE // CHAMPIONSHIP PODIUM [VOL. 11]</span>
            <span class="tag-warning-tape">MOTION COMIC ISSUE #01</span>
        </div>
        <div class="main-headline-brutal">RACE COMPLETE</div>
        <div class="headline-sub-cutout">SUZUKA GRAND PRIX // 3 LAPS // PRO GT3 SERIES</div>
    </div>

    <!-- ============================================================
         THE 3 SLANTED MOTION COMIC PANELS (TRIPTYCH)
         ============================================================ -->
    <div class="comic-triptych-stage" id="comicStage">
        
        <!-- PANEL 1: P2 MAKOTO ITO (Slanted Left -3.5deg, Neon Cyan) -->
        <div class="manga-panel panel-p2" onclick="toggleZine(true)">
            <span class="panel-tape-strip">[P2] RUNNER-UP</span>
            <div class="panel-viewport">
                <div class="panel-screentone"></div>
                <!-- Character Cutout -->
                <img src="{makoto_b64}" class="character-cutout-p2" alt="Makoto Ito">
                <!-- Cyan Sparks Tag -->
                <svg style="position: absolute; top: 120px; left: 30px; width: 80px; height: 80px; z-index: 8;" viewBox="0 0 100 100" fill="none">
                    <path d="M 50 10 Q 50 50 10 50 Q 50 50 50 90 Q 50 50 90 50 Q 50 50 50 10 Z" fill="#00F0FF" filter="drop-shadow(0 0 8px #00F0FF)"/>
                </svg>
            </div>
            <div class="panel-footer-zine">
                <span class="panel-driver-name">#03 MAKOTO ITO</span>
                <div class="panel-stats-sub">
                    <span style="color: var(--neon-cyan);">GAP: +1.700s</span>
                    <span style="color: #FFF; font-weight: 900;">18 PTS</span>
                </div>
            </div>
        </div>

        <!-- PANEL 2: P1 GRAND CHAMPION KAZE RYU (Elevated, Acid Lime, In-Frame Tags) -->
        <div class="manga-panel panel-p1" onclick="toggleZine(true)">
            <span class="panel-tape-strip">★ [P1] GRAND CHAMPION // WINNER ★</span>
            <div class="panel-viewport">
                <div class="panel-screentone"></div>

                <!-- 1. IN-FRAME GRAFFITI WINGS (Anchored Behind Ryu's Shoulders inside panel) -->
                <svg class="panel-wings-svg" id="wingsVfx" viewBox="0 0 540 280" fill="none" xmlns="http://www.w3.org/2000/svg">
                    <defs>
                        <filter id="neonGlowLime" x="-20%" y="-20%" width="140%" height="140%">
                            <feDropShadow dx="0" dy="0" stdDeviation="6" flood-color="#D8FF00" flood-opacity="0.95"/>
                        </filter>
                    </defs>
                    <!-- Left Wing -->
                    <g filter="url(#neonGlowLime)">
                        <path d="M 210 140 C 150 70 80 40 10 70 C -10 85 5 115 50 120 C 100 125 150 140 200 160 Z" 
                              fill="#D8FF00" stroke="#000" stroke-width="5" stroke-linejoin="round"/>
                        <path d="M 200 160 C 130 115 60 110 5 150 C -5 160 10 185 60 180 C 110 175 160 180 195 190 Z" 
                              fill="#D8FF00" stroke="#000" stroke-width="4.5" stroke-linejoin="round"/>
                        <path d="M 195 190 C 140 165 75 175 25 220 C 12 232 35 245 75 230 C 120 215 170 210 190 205 Z" 
                              fill="#00F0FF" stroke="#000" stroke-width="4" stroke-linejoin="round"/>
                    </g>
                    <!-- Right Wing -->
                    <g filter="url(#neonGlowLime)">
                        <path d="M 330 140 C 390 70 460 40 530 70 C 550 85 535 115 490 120 C 440 125 390 140 340 160 Z" 
                              fill="#D8FF00" stroke="#000" stroke-width="5" stroke-linejoin="round"/>
                        <path d="M 340 160 C 410 115 480 110 535 150 C 545 160 530 185 480 180 C 430 175 380 180 345 190 Z" 
                              fill="#D8FF00" stroke="#000" stroke-width="4.5" stroke-linejoin="round"/>
                        <path d="M 345 190 C 400 165 465 175 515 220 C 528 232 505 245 465 230 C 420 215 370 210 350 205 Z" 
                              fill="#00F0FF" stroke="#000" stroke-width="4" stroke-linejoin="round"/>
                    </g>
                </svg>

                <!-- 2. IN-FRAME GRAFFITI CROWN (Hovering locked above Ryu inside panel) -->
                <svg class="panel-crown-svg" id="crownVfx" viewBox="0 0 160 100" fill="none" xmlns="http://www.w3.org/2000/svg">
                    <defs>
                        <filter id="crownGlow" x="-20%" y="-20%" width="140%" height="140%">
                            <feDropShadow dx="0" dy="0" stdDeviation="5" flood-color="#FFEE00" flood-opacity="0.95"/>
                        </filter>
                    </defs>
                    <g filter="url(#crownGlow)">
                        <path d="M 20 60 L 30 20 L 55 45 L 80 10 L 105 45 L 130 20 L 140 60 Q 80 75 20 60 Z" 
                              fill="#FFEA00" stroke="#000" stroke-width="5" stroke-linejoin="round"/>
                        <path d="M 45 66 Q 47 85 45 92 Q 43 85 40 65" fill="#FFEA00" stroke="#000" stroke-width="2.5"/>
                        <path d="M 80 68 Q 82 92 80 98 Q 78 92 75 68" fill="#FFEA00" stroke="#000" stroke-width="2.5"/>
                        <path d="M 115 65 Q 118 80 115 88 Q 112 80 110 65" fill="#FFEA00" stroke="#000" stroke-width="2.5"/>
                        <circle cx="80" cy="22" r="4" fill="#FFF"/>
                        <circle cx="35" cy="28" r="3" fill="#FFF"/>
                        <circle cx="125" cy="28" r="3" fill="#FFF"/>
                    </g>
                </svg>

                <!-- 3. IN-FRAME MANGA KANJI 勝者 -->
                <div class="panel-kanji-shousha">勝者</div>

                <!-- 4. EYE-GLINT STAR SPARKLE -->
                <svg class="panel-eye-glint" viewBox="0 0 40 40" fill="none">
                    <path d="M 20 0 Q 20 20 0 20 Q 20 20 20 40 Q 20 20 40 20 Q 20 20 20 0 Z" fill="#FFFFFF" filter="drop-shadow(0 0 6px #00F0FF)"/>
                </svg>

                <!-- 5. CHARACTER CUTOUT P1 (Kaze Ryu) -->
                <img src="{kaze_b64}" class="character-cutout-p1" alt="Kaze Ryu">

            </div>
            <div class="panel-footer-zine" style="background: rgba(14, 18, 12, 0.98); border-top: 3px solid var(--acid-lime);">
                <span class="panel-driver-name" style="font-size: 42px; color: var(--acid-lime);">#01 KAZE RYU</span>
                <div class="panel-stats-sub">
                    <span style="color: var(--acid-lime);">APEX RACING // 5:00.000</span>
                    <span style="background: var(--hot-pink); color: #FFF; padding: 2px 8px; font-weight: 900;">FL: 1:32.000 [+1 PT]</span>
                    <span style="font-size: 18px; font-weight: 900; color: var(--acid-lime);">25+1 PTS</span>
                </div>
            </div>
        </div>

        <!-- PANEL 3: P3 ARTHUR STERLING (Slanted Right +3.5deg, Hazard Orange) -->
        <div class="manga-panel panel-p3" onclick="toggleZine(true)">
            <span class="panel-tape-strip">[P3] BRONZE LOCK</span>
            <div class="panel-viewport">
                <div class="panel-screentone"></div>
                <!-- Character Cutout -->
                <img src="{arthur_b64}" class="character-cutout-p3" alt="Arthur Sterling">
                <!-- Orange Sparks Tag -->
                <svg style="position: absolute; top: 110px; right: 25px; width: 70px; height: 70px; z-index: 8;" viewBox="0 0 100 100" fill="none">
                    <path d="M 50 10 L 60 35 L 85 40 L 65 60 L 70 85 L 50 70 L 30 85 L 35 60 L 15 40 L 40 35 Z" fill="#FF6B00" filter="drop-shadow(0 0 8px #FF6B00)"/>
                </svg>
            </div>
            <div class="panel-footer-zine">
                <span class="panel-driver-name">#09 T. KADE</span>
                <div class="panel-stats-sub">
                    <span style="color: var(--hazard-orange);">GAP: +3.400s</span>
                    <span style="color: #FFF; font-weight: 900;">15 PTS</span>
                </div>
            </div>
        </div>

    </div>

    <!-- ============================================================
         RACE ZINE: CLASSIFICATION LEADERBOARD DRAWER (TAB)
         ============================================================ -->
    <div class="race-zine-drawer" id="raceZine">
        <div class="zine-header">
            <div>
                <span style="font-size: 11px; font-weight: 900; letter-spacing: 2px; color: #888;">/// ISSUE #01 // OFFICIAL CLASSIFICATION</span>
                <div class="zine-title">RACE CLASSIFICATION</div>
            </div>
            <button class="zine-badge-close" onclick="toggleZine(false)">[TAB] CLOSE ✕</button>
        </div>

        <div class="zine-table-scroll">
            <div class="zine-row pos-1">
                <span class="zine-pos">01</span>
                <div class="zine-driver">
                    <span>K. RYU</span>
                    <span class="zine-team-sub">APEX RACING // #01</span>
                </div>
                <span class="zine-gap">5:00.000</span>
                <span class="zine-pts">25 PTS</span>
            </div>

            <div class="zine-row pos-2">
                <span class="zine-pos">02</span>
                <div class="zine-driver">
                    <span>M. ITO</span>
                    <span class="zine-team-sub">NEON DRIFT // #03</span>
                </div>
                <span class="zine-gap">+1.700s</span>
                <span class="zine-pts">18 PTS</span>
            </div>

            <div class="zine-row pos-3">
                <span class="zine-pos">03</span>
                <div class="zine-driver">
                    <span>T. KADE</span>
                    <span class="zine-team-sub">RAZORLINE // #09</span>
                </div>
                <span class="zine-gap">+3.400s</span>
                <span class="zine-pts">15 PTS</span>
            </div>

            <div class="zine-row" style="background: rgba(255, 0, 85, 0.12); border-left: 4px solid var(--hot-pink);">
                <span class="zine-pos">04</span>
                <div class="zine-driver">
                    <span style="color: #FF0055;">N. SATO ★ FL</span>
                    <span class="zine-team-sub">KUROGANE GT // #07</span>
                </div>
                <span class="zine-gap">+10.000s</span>
                <span class="zine-pts">12+1 PTS</span>
            </div>

            <div class="zine-row">
                <span class="zine-pos">05</span>
                <div class="zine-driver">
                    <span>V. SOKOL</span>
                    <span class="zine-team-sub">ONI WORKS // #13</span>
                </div>
                <span class="zine-gap">+12.000s</span>
                <span class="zine-pts">10 PTS</span>
            </div>

            <div class="zine-row">
                <span class="zine-pos">06</span>
                <div class="zine-driver">
                    <span>J. CRUZ</span>
                    <span class="zine-team-sub">CHROME SYNDICATE</span>
                </div>
                <span class="zine-gap">+14.000s</span>
                <span class="zine-pts">8 PTS</span>
            </div>

            <div class="zine-row">
                <span class="zine-pos">07</span>
                <div class="zine-driver">
                    <span>B. TANAKA</span>
                    <span class="zine-team-sub">KUROGANE GT</span>
                </div>
                <span class="zine-gap">+16.000s</span>
                <span class="zine-pts">6 PTS</span>
            </div>

            <div class="zine-row">
                <span class="zine-pos">08</span>
                <div class="zine-driver">
                    <span>O. MBEKI</span>
                    <span class="zine-team-sub">VANTA MOTORS</span>
                </div>
                <span class="zine-gap">+20.000s</span>
                <span class="zine-pts">4 PTS</span>
            </div>

            <div class="zine-row">
                <span class="zine-pos">09</span>
                <div class="zine-driver">
                    <span>P. AOKI</span>
                    <span class="zine-team-sub">STATIC SPEED</span>
                </div>
                <span class="zine-gap">+22.000s</span>
                <span class="zine-pts">2 PTS</span>
            </div>

            <div class="zine-row">
                <span class="zine-pos">10</span>
                <div class="zine-driver">
                    <span>F. DUVAL</span>
                    <span class="zine-team-sub">NIGHT SHIFT</span>
                </div>
                <span class="zine-gap">+24.000s</span>
                <span class="zine-pts">1 PTS</span>
            </div>
        </div>

        <div style="background: #000; padding: 12px 20px; border-top: 2px solid #222; font-size: 11px;">
            <div style="color: var(--acid-lime); font-weight: 900; margin-bottom: 4px;">/// CONSTRUCTORS' HAUL</div>
            <div style="display: flex; justify-content: space-between; opacity: 0.85;">
                <span>1. Apex Racing: 25 PTS</span>
                <span>2. Kurogane GT: 21 PTS</span>
                <span>3. Neon Drift: 18 PTS</span>
            </div>
        </div>
    </div>

    <!-- Bottom Interactive Control Toolbar -->
    <div class="bottom-toolbar">
        <button class="tool-btn" id="btnZine" onclick="toggleZine()">
            <span class="key-badge">TAB</span> Race Zine
        </button>
        <button class="tool-btn active" id="btnWings" onclick="toggleWings()">
            <span class="key-badge">W</span> In-Frame Wings
        </button>
        <button class="tool-btn active" id="btnCrown" onclick="toggleCrown()">
            <span class="key-badge">C</span> Crown & Kanji
        </button>
        <button class="tool-btn" onclick="alert('Tekan ESC untuk kembali ke HQ!')">
            <span class="key-badge">ESC</span> Exit HQ
        </button>
    </div>

</div>

<script>
let zineOpen = false;
let wingsVisible = true;
let crownVisible = true;

function toggleZine(forceState) {{
    zineOpen = (forceState !== undefined) ? forceState : !zineOpen;
    const drawer = document.getElementById('raceZine');
    const stage = document.getElementById('comicStage');
    const btn = document.getElementById('btnZine');

    if (zineOpen) {{
        drawer.classList.add('open');
        stage.classList.add('zine-docked');
        btn.classList.add('active');
    }} else {{
        drawer.classList.remove('open');
        stage.classList.remove('zine-docked');
        btn.classList.remove('active');
    }}
}}

function toggleWings() {{
    wingsVisible = !wingsVisible;
    const wings = document.getElementById('wingsVfx');
    const btn = document.getElementById('btnWings');
    wings.style.display = wingsVisible ? 'block' : 'none';
    btn.classList.toggle('active', wingsVisible);
}}

function toggleCrown() {{
    crownVisible = !crownVisible;
    const crown = document.getElementById('crownVfx');
    const btn = document.getElementById('btnCrown');
    crown.style.display = crownVisible ? 'block' : 'none';
    btn.classList.toggle('active', crownVisible);
}}

window.addEventListener('keydown', (e) => {{
    if (e.key === 'Tab') {{
        e.preventDefault();
        toggleZine();
    }} else if (e.key.toLowerCase() === 'w') {{
        toggleWings();
    }} else if (e.key.toLowerCase() === 'c') {{
        toggleCrown();
    }}
}});
</script>

</body>
</html>
"""

    output_path = "temp/opsi3_zine_preview.html"
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    with open(output_path, "w", encoding="utf-8") as f:
        f.write(html_content)

    print(f"Opsi 3 Preview HTML successfully regenerated at: {output_path}")

if __name__ == "__main__":
    main()
