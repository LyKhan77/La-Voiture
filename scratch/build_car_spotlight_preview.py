"""
Script to generate the updated Winning Scene preview with:
1. NO WINGS (Wings removed completely).
2. CAR PROMINENTLY HIGHLIGHTED & SPOTLIGHTED:
   - Upper/Center 65% of screen dedicated to the GT3 Car on the illuminated turntable.
   - Volumetric anime spotlight beam focused on the car.
   - Headlight glare/flares and neon underglow ring.
   - Machine Spec Decal (e.g. /// MERCEDES-AMG GT3 EVO // 550 HP // APEX LIVERY).
   - Driver panels arranged as sleek slanted manga cards in the lower third (not blocking the car).
   - Interactive Machine Spotlight Camera toggle [M] / [CAM].
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
<title>La Voiture — Winning Scene: Car Spotlight x Motion Comic</title>
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

/* 3D Turntable Background with Car */
.stage-background {{
    position: absolute;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    background-image: url('{stage_bg_b64}');
    background-size: cover;
    background-position: center;
    transition: transform 0.6s cubic-bezier(0.16, 1, 0.3, 1), filter 0.4s ease;
}}

/* Car Spotlight Zoom Mode */
.viewport-frame.mode-car-focus .stage-background {{
    transform: scale(1.45) translateY(40px);
    filter: brightness(1.1) contrast(1.15);
}}

/* ============================================================
   CAR SPOTLIGHT & LIGHTING FX LAYER
   ============================================================ */
.car-spotlight-rig {{
    position: absolute;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    pointer-events: none;
    z-index: 5;
    transition: opacity 0.4s ease;
}}

/* Volumetric Spotlight Beam from ceiling onto Car */
.spotlight-beam {{
    position: absolute;
    top: -50px;
    left: 50%;
    transform: translateX(-50%);
    width: 700px;
    height: 650px;
    background: linear-gradient(
        180deg,
        rgba(255, 255, 255, 0.45) 0%,
        rgba(216, 255, 0, 0.18) 40%,
        rgba(216, 255, 0, 0.05) 80%,
        transparent 100%
    );
    clip-path: polygon(35% 0%, 65% 0%, 95% 100%, 5% 100%);
    mix-blend-mode: screen;
    animation: beam-pulse 3s ease-in-out infinite alternate;
}}

@keyframes beam-pulse {{
    0%   {{ opacity: 0.75; transform: translateX(-50%) scale(1); }}
    100% {{ opacity: 0.95; transform: translateX(-50%) scale(1.03); }}
}}

/* Headlight Flares */
.headlight-flare-left {{
    position: absolute;
    top: 545px;
    left: 855px;
    width: 60px;
    height: 24px;
    background: radial-gradient(ellipse at center, #FFFFFF 0%, #D8FF00 40%, transparent 75%);
    filter: drop-shadow(0 0 15px #D8FF00);
    transform: rotate(-10deg);
}}

.headlight-flare-right {{
    position: absolute;
    top: 545px;
    left: 1005px;
    width: 60px;
    height: 24px;
    background: radial-gradient(ellipse at center, #FFFFFF 0%, #D8FF00 40%, transparent 75%);
    filter: drop-shadow(0 0 15px #D8FF00);
    transform: rotate(10deg);
}}

/* Turntable Neon Glow Ring */
.turntable-neon-ring {{
    position: absolute;
    top: 565px;
    left: 50%;
    transform: translateX(-50%);
    width: 750px;
    height: 180px;
    border-radius: 50%;
    border: 3px solid rgba(216, 255, 0, 0.65);
    box-shadow: 0 0 35px rgba(216, 255, 0, 0.5), inset 0 0 25px rgba(216, 255, 0, 0.3);
    opacity: 0.85;
    animation: ring-glow 2s ease-in-out infinite alternate;
}}

@keyframes ring-glow {{
    0%   {{ opacity: 0.6; box-shadow: 0 0 20px rgba(216, 255, 0, 0.4); }}
    100% {{ opacity: 0.95; box-shadow: 0 0 45px rgba(216, 255, 0, 0.8); }}
}}

/* Floating Machine Spec Banner (Directly highlighting the GT3 Car) */
.car-spec-callout {{
    position: absolute;
    top: 260px;
    right: 70px;
    display: flex;
    flex-direction: column;
    gap: 4px;
    z-index: 12;
    background: rgba(8, 9, 14, 0.92);
    border: 3px solid var(--acid-lime);
    box-shadow: 6px 6px 0px #000;
    padding: 12px 18px;
    transform: rotate(2deg);
    animation: callout-float 2.5s ease-in-out infinite alternate;
}}

@keyframes callout-float {{
    0%   {{ transform: rotate(2deg) translateY(0); }}
    100% {{ transform: rotate(1.5deg) translateY(-6px); }}
}}

.spec-badge {{
    background: var(--acid-lime);
    color: #000;
    font-weight: 900;
    font-size: 11px;
    padding: 2px 8px;
    letter-spacing: 1.5px;
    align-self: flex-start;
}}

.spec-car-name {{
    font-family: 'Bebas Neue', sans-serif;
    font-size: 32px;
    color: #FFF;
    letter-spacing: 1px;
    line-height: 0.95;
}}

.spec-stats-grid {{
    display: flex;
    gap: 16px;
    font-size: 11px;
    font-family: monospace;
    color: #BBB;
    border-top: 1px solid #333;
    padding-top: 6px;
    margin-top: 4px;
}}

/* ============================================================
   LOWER-THIRD MANGA CHARACTER CARDS (Not Blocking the Car)
   ============================================================ */
.lower-manga-dock {{
    position: absolute;
    bottom: 55px;
    left: 50%;
    transform: translateX(-50%);
    width: 92%;
    max-width: 1480px;
    display: grid;
    grid-template-columns: 1fr 1.25fr 1fr;
    gap: 28px;
    align-items: end;
    z-index: 20;
    transition: transform 0.4s cubic-bezier(0.16, 1, 0.3, 1), opacity 0.4s ease;
}}

/* Dock recedes when Leaderboard Zine opens */
.lower-manga-dock.dock-receded {{
    transform: translateX(-50%) translateY(70px);
    opacity: 0.12;
    pointer-events: none;
}}

/* When Car Focus is active, lower cards slightly to reveal full car */
.viewport-frame.mode-car-focus .lower-manga-dock {{
    transform: translateX(-50%) translateY(40px);
}}

/* Sleek Slanted Comic Cards */
.manga-card-compact {{
    position: relative;
    background: rgba(14, 15, 22, 0.96);
    border: 4px solid #000;
    box-shadow: 8px 8px 0px #000;
    padding: 14px 18px;
    display: flex;
    flex-direction: column;
    gap: 6px;
    cursor: pointer;
    overflow: visible;
    transition: transform 0.2s cubic-bezier(0.16, 1, 0.3, 1), box-shadow 0.2s ease;
}}

.manga-card-compact:hover {{
    transform: scale(1.025);
}}

.card-screentone {{
    position: absolute;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    background-image: radial-gradient(rgba(255, 255, 255, 0.12) 1.2px, transparent 1.2px);
    background-size: 8px 8px;
    pointer-events: none;
}}

.tape-tag {{
    position: absolute;
    top: -14px;
    font-family: 'Space Grotesk', sans-serif;
    font-weight: 900;
    font-size: 11px;
    letter-spacing: 1.5px;
    padding: 3px 12px;
    text-transform: uppercase;
    border: 2px solid #000;
    box-shadow: 3px 3px 0px #000;
    z-index: 25;
}}

/* P2 (Left, Cyan, Slanted -3.5deg) */
.card-p2 {{
    transform: rotate(-3deg) skewX(-2deg);
    border-color: var(--neon-cyan);
    box-shadow: 6px 6px 0px #000, 10px 10px 0px rgba(0, 240, 255, 0.45);
}}
.card-p2 .tape-tag {{
    left: 14px;
    background: var(--neon-cyan);
    color: #000;
    transform: rotate(-3deg);
}}

/* P1 (Center, Elevated, Acid Lime, Hard Dropshadow) */
.card-p1 {{
    transform: translateY(-12px) scale(1.04);
    border-color: var(--acid-lime);
    box-shadow: 8px 8px 0px #000, 14px 14px 0px var(--acid-lime);
    background: rgba(12, 16, 10, 0.98);
    padding: 18px 24px;
}}
.card-p1 .tape-tag {{
    left: 50%;
    transform: translateX(-50%) rotate(-1deg);
    background: var(--acid-lime);
    color: #000;
    font-size: 13px;
    padding: 4px 18px;
    box-shadow: 4px 4px 0px #000;
    white-space: nowrap;
}}

/* P3 (Right, Orange, Slanted +3.5deg) */
.card-p3 {{
    transform: rotate(3deg) skewX(2deg);
    border-color: var(--hazard-orange);
    box-shadow: 6px 6px 0px #000, 10px 10px 0px rgba(255, 107, 0, 0.45);
}}
.card-p3 .tape-tag {{
    right: 14px;
    background: var(--hazard-orange);
    color: #000;
    transform: rotate(3deg);
}}

/* Driver Name & Stats Layout */
.card-header-row {{
    display: flex;
    justify-content: space-between;
    align-items: baseline;
    position: relative;
    z-index: 5;
}}

.driver-name-headline {{
    font-family: 'Bebas Neue', sans-serif;
    font-size: 38px;
    line-height: 0.9;
    letter-spacing: 1px;
    color: #FFF;
    text-shadow: 2px 2px 0px #000;
}}

.team-pill {{
    font-size: 11px;
    font-weight: 700;
    padding: 2px 8px;
    border-radius: 2px;
    letter-spacing: 1px;
    text-transform: uppercase;
}}

.card-stats-row {{
    display: flex;
    justify-content: space-between;
    align-items: center;
    border-top: 2px solid rgba(255, 255, 255, 0.15);
    padding-top: 8px;
    margin-top: 4px;
    font-family: 'Space Grotesk', sans-serif;
    font-weight: 700;
    font-size: 14px;
    position: relative;
    z-index: 5;
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

    <!-- 3D Turntable Background with Car & Drivers -->
    <div class="stage-background" id="stageBg"></div>

    <!-- CAR SPOTLIGHT & LIGHTING RIG LAYER (HIGHLIGHTING THE CAR) -->
    <div class="car-spotlight-rig" id="spotlightRig">
        <!-- Volumetric Beam from above focused on Car -->
        <div class="spotlight-beam"></div>
        <!-- Headlight Glare Flares -->
        <div class="headlight-flare-left"></div>
        <div class="headlight-flare-right"></div>
        <!-- Turntable Acid Lime Glow Ring -->
        <div class="turntable-neon-ring"></div>
    </div>

    <!-- Machine Spec Decal (Prominently Celebrating the Car) -->
    <div class="car-spec-callout">
        <span class="spec-badge">WINNING MACHINE // P1</span>
        <div class="spec-car-name">MERCEDES-AMG GT3 EVO</div>
        <div class="spec-stats-grid">
            <span>CHASSIS #01</span>
            <span>6.2L V8 NA</span>
            <span>550 HP</span>
            <span>BBS FI-R WHEELS</span>
        </div>
    </div>

    <!-- Top Lookbook Header -->
    <div class="top-header-zine">
        <div class="top-badge-strip">
            <span class="tag-black-box">/// LA VOITURE // CHAMPIONSHIP PODIUM [VOL. 11]</span>
            <span class="tag-warning-tape">OFFICIAL SCRUTINEERED MACHINE & DRIVERS</span>
        </div>
        <div class="main-headline-brutal">RACE COMPLETE</div>
        <div class="headline-sub-cutout">SUZUKA GRAND PRIX // 3 LAPS // PRO GT3 CATEGORY</div>
    </div>

    <!-- ============================================================
         LOWER-THIRD MANGA CHARACTER CARDS (Unobstructed Car View!)
         ============================================================ -->
    <div class="lower-manga-dock" id="mangaDock">
        
        <!-- P2 CARD (Left, Neon Cyan, Slanted -3.5deg) -->
        <div class="manga-card-compact card-p2" onclick="toggleZine(true)">
            <div class="card-screentone"></div>
            <span class="tape-tag">[P2] RUNNER-UP</span>
            <div class="card-header-row">
                <span class="driver-name-headline">#03 MAKOTO ITO</span>
                <span class="team-pill" style="background: rgba(0,240,255,0.18); color: var(--neon-cyan); border: 1px solid var(--neon-cyan);">NEON DRIFT</span>
            </div>
            <div class="card-stats-row">
                <span style="color: var(--neon-cyan); font-family: monospace;">GAP: +1.700s</span>
                <span style="color: #FFF; font-weight: 900;">18 PTS</span>
            </div>
        </div>

        <!-- P1 GRAND CHAMPION CARD (Center, Elevated, Acid Lime) -->
        <div class="manga-card-compact card-p1" onclick="toggleZine(true)">
            <div class="card-screentone"></div>
            <span class="tape-tag">★ [P1] GRAND CHAMPION // WINNER ★</span>
            <div class="card-header-row">
                <span class="driver-name-headline" style="font-size: 44px; color: var(--acid-lime);">#01 KAZE RYU</span>
                <span class="team-pill" style="background: var(--acid-lime); color: #000; font-weight: 900;">APEX RACING</span>
            </div>
            <div class="card-stats-row">
                <div style="display: flex; gap: 8px; align-items: center;">
                    <span style="color: var(--acid-lime); font-family: monospace;">TIME: 5:00.000</span>
                    <span style="background: var(--hot-pink); color: #FFF; font-size: 11px; padding: 2px 8px; font-weight: 900;">FL: 1:32.000 [+1 PT]</span>
                </div>
                <span style="font-size: 20px; font-weight: 900; color: var(--acid-lime);">25+1 PTS</span>
            </div>
        </div>

        <!-- P3 CARD (Right, Hazard Orange, Slanted +3.5deg) -->
        <div class="manga-card-compact card-p3" onclick="toggleZine(true)">
            <div class="card-screentone"></div>
            <span class="tape-tag">[P3] BRONZE LOCK</span>
            <div class="card-header-row">
                <span class="driver-name-headline">#09 T. KADE</span>
                <span class="team-pill" style="background: rgba(255,107,0,0.18); color: var(--hazard-orange); border: 1px solid var(--hazard-orange);">RAZORLINE</span>
            </div>
            <div class="card-stats-row">
                <span style="color: var(--hazard-orange); font-family: monospace;">GAP: +3.400s</span>
                <span style="color: #FFF; font-weight: 900;">15 PTS</span>
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
        <button class="tool-btn active" id="btnSpotlight" onclick="toggleSpotlight()">
            <span class="key-badge">S</span> Car Spotlight
        </button>
        <button class="tool-btn" id="btnFocus" onclick="toggleCarFocus()">
            <span class="key-badge">M</span> Focus Machine
        </button>
        <button class="tool-btn" onclick="alert('Tekan ESC untuk kembali ke HQ!')">
            <span class="key-badge">ESC</span> Exit HQ
        </button>
    </div>

</div>

<script>
let zineOpen = false;
let spotlightActive = true;
let carFocusActive = false;

function toggleZine(forceState) {{
    zineOpen = (forceState !== undefined) ? forceState : !zineOpen;
    const drawer = document.getElementById('raceZine');
    const dock = document.getElementById('mangaDock');
    const btn = document.getElementById('btnZine');

    if (zineOpen) {{
        drawer.classList.add('open');
        dock.classList.add('dock-receded');
        btn.classList.add('active');
    }} else {{
        drawer.classList.remove('open');
        dock.classList.remove('dock-receded');
        btn.classList.remove('active');
    }}
}}

function toggleSpotlight() {{
    spotlightActive = !spotlightActive;
    const rig = document.getElementById('spotlightRig');
    const btn = document.getElementById('btnSpotlight');
    rig.style.opacity = spotlightActive ? '1' : '0.2';
    btn.classList.toggle('active', spotlightActive);
}}

function toggleCarFocus() {{
    carFocusActive = !carFocusActive;
    const stage = document.getElementById('viewportStage');
    const btn = document.getElementById('btnFocus');
    stage.classList.toggle('mode-car-focus', carFocusActive);
    btn.classList.toggle('active', carFocusActive);
}}

window.addEventListener('keydown', (e) => {{
    if (e.key === 'Tab') {{
        e.preventDefault();
        toggleZine();
    }} else if (e.key.toLowerCase() === 's') {{
        toggleSpotlight();
    }} else if (e.key.toLowerCase() === 'm') {{
        toggleCarFocus();
    }}
}});
</script>

</body>
</html>
"""

    output_path = "temp/car_spotlight_preview.html"
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    with open(output_path, "w", encoding="utf-8") as f:
        f.write(html_content)

    print(f"Car Spotlight Preview HTML generated at: {output_path}")

if __name__ == "__main__":
    main()
