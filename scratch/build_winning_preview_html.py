"""
Script to generate the interactive HTML preview for Winning Scene Redesign.
Theme: NFS Unbound x Cel-Shaded Manga Toon x Streetwear Neo-Brutalism.
"""

import base64
import os

def get_base64_image(path):
    with open(path, "rb") as f:
        return "data:image/png;base64," + base64.b64encode(f.read()).decode("utf-8")

def main():
    stage_bg_path = "temp/stage_clean_pristine.png"
    print("Encoding stage background...")
    stage_bg_b64 = get_base64_image(stage_bg_path)

    html_content = f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>La Voiture — Winning Scene Redesign Concept (NFS Unbound x Neo-Brutalism)</title>
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
    --paper-tint: #F2F2F5;
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

/* 16:9 Viewport Stage Frame */
.viewport-frame {{
    position: relative;
    width: 100vw;
    height: 100vh;
    max-width: 1920px;
    max-height: 1080px;
    overflow: hidden;
    background: #0d0d12;
    box-shadow: 0 0 60px rgba(0,0,0,0.95);
}}

/* Background Stage */
.stage-background {{
    position: absolute;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    background-image: url('{stage_bg_b64}');
    background-size: cover;
    background-position: center;
    transform-origin: 50% 50%;
    transition: transform 0.6s cubic-bezier(0.16, 1, 0.3, 1);
}}

/* Camera Zoom Close-Up Mode */
.viewport-frame.zoom-closeup .stage-background {{
    transform: scale(1.68) translateY(-40px);
}}

/* Speedlines Radial Action Burst */
.speedlines-overlay {{
    position: absolute;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    pointer-events: none;
    opacity: 0.35;
    background: repeating-conic-gradient(
        from 0deg at 50% 50%,
        transparent 0deg 4deg,
        rgba(216, 255, 0, 0.15) 4deg 5deg,
        transparent 5deg 12deg,
        rgba(255, 255, 255, 0.08) 12deg 13deg,
        transparent 13deg 20deg
    );
    mix-blend-mode: screen;
    animation: speedline-pulse 0.2s steps(2, end) infinite;
}}

@keyframes speedline-pulse {{
    0%   {{ transform: scale(1) rotate(0deg); opacity: 0.3; }}
    50%  {{ transform: scale(1.02) rotate(1deg); opacity: 0.5; }}
    100% {{ transform: scale(0.99) rotate(-1deg); opacity: 0.3; }}
}}

/* ============================================================
   NFS UNBOUND CELEBRATION TAGS LAYER (SVG ANIMATED)
   ============================================================ */
.celebration-vfx-layer {{
    position: absolute;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    pointer-events: none;
    transform-origin: 50% 50%;
    transition: transform 0.6s cubic-bezier(0.16, 1, 0.3, 1);
}}

.viewport-frame.zoom-closeup .celebration-vfx-layer {{
    transform: scale(1.68) translateY(-40px);
}}

/* P1 WINNER RIG (Centered on Kaze Ryu at X=50%, Y=450px) */
.p1-vfx-anchor {{
    position: absolute;
    left: 50%;
    top: 450px;
    width: 0;
    height: 0;
}}

/* Stepped 12 FPS Anime Cadence vs 60 FPS */
.stepped-12fps {{
    animation: anime-breathing 1.2s steps(6, end) infinite;
}}

.smooth-60fps {{
    animation: anime-breathing 1.2s cubic-bezier(0.4, 0, 0.2, 1) infinite;
}}

@keyframes anime-breathing {{
    0%   {{ transform: translateY(0px) scale(1); }}
    33%  {{ transform: translateY(-3px) scale(1.008); }}
    50%  {{ transform: translateY(-6px) scale(1.015); }}
    83%  {{ transform: translateY(-2px) scale(1.005); }}
    100% {{ transform: translateY(0px) scale(1); }}
}}

/* 1. GRAFFITI WINGS TAG (Wide Sprouting Behind Shoulders, Clean Center Gap) */
.graffiti-wings-tag {{
    position: absolute;
    left: -320px;
    top: -110px;
    width: 640px;
    height: 300px;
    pointer-events: none;
    z-index: 1;
}}

.wings-stepped {{
    animation: wings-flapping-12fps 0.4s steps(4, end) infinite;
}}

.wings-smooth {{
    animation: wings-flapping-smooth 0.4s ease-in-out infinite alternate;
}}

@keyframes wings-flapping-12fps {{
    0%   {{ transform: scale(1) rotate(0deg); opacity: 0.95; }}
    25%  {{ transform: scale(1.08, 0.92) rotate(-2deg); opacity: 1; }}
    50%  {{ transform: scale(0.95, 1.06) rotate(2deg); opacity: 0.9; }}
    75%  {{ transform: scale(1.04, 0.97) rotate(1deg); opacity: 1; }}
    100% {{ transform: scale(1) rotate(0deg); opacity: 0.95; }}
}}

@keyframes wings-flapping-smooth {{
    0%   {{ transform: scale(0.95, 1.05) rotate(-2deg); }}
    100% {{ transform: scale(1.08, 0.95) rotate(2deg); }}
}}

/* 2. GRAFFITI CROWN TAG (Floating at Y=-140px, gracefully above Ryu's hair) */
.graffiti-crown-tag {{
    position: absolute;
    left: -60px;
    top: -140px;
    width: 120px;
    height: 80px;
    z-index: 5;
    animation: crown-bobbing 0.8s steps(4, end) infinite;
}}

@keyframes crown-bobbing {{
    0%   {{ transform: translateY(0) rotate(-3deg); }}
    25%  {{ transform: translateY(-6px) rotate(2deg); }}
    50%  {{ transform: translateY(-10px) rotate(-1deg); }}
    75%  {{ transform: translateY(-4px) rotate(3deg); }}
    100% {{ transform: translateY(0) rotate(-3deg); }}
}}

/* 3. JAGGED LIGHTNING SPARKS TAG */
.lightning-sparks-tag {{
    position: absolute;
    left: -160px;
    top: -80px;
    width: 320px;
    height: 280px;
    pointer-events: none;
    z-index: 6;
    animation: sparks-flicker 0.3s steps(3, end) infinite;
}}

@keyframes sparks-flicker {{
    0%   {{ opacity: 0.95; transform: scale(1) rotate(0deg); }}
    33%  {{ opacity: 0.2; transform: scale(1.08) rotate(4deg); }}
    66%  {{ opacity: 1; transform: scale(0.96) rotate(-3deg); }}
    100% {{ opacity: 0.95; transform: scale(1) rotate(0deg); }}
}}

/* 4. EYE-GLINT STAR SPARKLE (Right Eye: X=-8px, Y=-30px) */
.eye-glint {{
    position: absolute;
    left: -8px;
    top: -30px;
    width: 24px;
    height: 24px;
    pointer-events: none;
    z-index: 8;
    animation: eye-glint-cycle 3.2s steps(1, end) infinite;
}}

@keyframes eye-glint-cycle {{
    0%, 84% {{ opacity: 0; transform: scale(0) rotate(0deg); }}
    86%     {{ opacity: 1; transform: scale(1.6) rotate(45deg); }}
    90%     {{ opacity: 0.95; transform: scale(2.2) rotate(90deg); }}
    95%     {{ opacity: 0.4; transform: scale(1.0) rotate(135deg); }}
    100%    {{ opacity: 0; transform: scale(0) rotate(180deg); }}
}}

/* 5. MANGA ONOMATOPOEIA TAGS */
.manga-tag-shousha {{
    position: absolute;
    left: -210px;
    top: -85px;
    font-family: 'Noto Sans JP', sans-serif;
    font-weight: 900;
    font-size: 56px;
    color: var(--acid-lime);
    text-shadow: 
        4px 4px 0px #000, 
        -2px -2px 0px #000, 
        2px -2px 0px #000, 
        -2px 2px 0px #000,
        0 0 24px rgba(216, 255, 0, 0.95);
    transform: rotate(-12deg);
    animation: tag-pulse 1s steps(4, end) infinite alternate;
    z-index: 4;
    letter-spacing: -3px;
}}

.manga-tag-don {{
    position: absolute;
    left: 125px;
    top: -95px;
    background: #000;
    color: #FFF;
    font-family: 'Permanent Marker', cursive;
    font-size: 24px;
    padding: 6px 16px;
    border: 3px solid var(--neon-cyan);
    transform: rotate(14deg);
    box-shadow: 5px 5px 0px var(--neon-cyan);
    animation: tag-pulse-alt 0.8s steps(3, end) infinite alternate;
    z-index: 7;
    white-space: nowrap;
}}

@keyframes tag-pulse {{
    0%   {{ transform: rotate(-12deg) scale(1); }}
    100% {{ transform: rotate(-10deg) scale(1.08); }}
}}

@keyframes tag-pulse-alt {{
    0%   {{ transform: rotate(14deg) scale(0.96); }}
    100% {{ transform: rotate(17deg) scale(1.06); }}
}}

/* P2 MAKOTO SPARKS (Peace signs at X=670px, Y=450px) */
.p2-vfx-anchor {{
    position: absolute;
    left: 670px;
    top: 450px;
    width: 0;
    height: 0;
}}

.p2-sparkle-stars {{
    position: absolute;
    left: -50px;
    top: -45px;
    width: 100px;
    height: 60px;
    animation: sparks-flicker 0.4s steps(3, end) infinite;
}}

/* P3 ARTHUR AMBER SPARKS (At X=1240px, Y=460px) */
.p3-vfx-anchor {{
    position: absolute;
    left: 1240px;
    top: 460px;
    width: 0;
    height: 0;
}}

.p3-amber-sparks {{
    position: absolute;
    left: -40px;
    top: -55px;
    width: 80px;
    height: 70px;
    animation: sparks-flicker 0.4s steps(3, end) infinite;
}}

/* ============================================================
   NEO-BRUTALISM UI: STREETWEAR MANGA TOON X GRAFFITI
   ============================================================ */

/* Top Brutalist Header */
.top-header-zine {{
    position: absolute;
    top: 32px;
    left: 48px;
    z-index: 20;
    display: flex;
    flex-direction: column;
    gap: 8px;
}}

.top-badge-strip {{
    display: flex;
    align-items: center;
    gap: 12px;
    font-family: 'Space Grotesk', sans-serif;
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

.headline-wrap {{
    display: flex;
    flex-direction: column;
    gap: 4px;
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
    font-size: 15px;
    padding: 4px 14px;
    transform: rotate(-2deg);
    box-shadow: 4px 4px 0px var(--hot-pink);
    letter-spacing: 1px;
    margin-top: 4px;
}}

/* ============================================================
   SLANTED STICKER PODIUM CARDS (P2, P1, P3)
   ============================================================ */
.podium-cards-dock {{
    position: absolute;
    bottom: 68px;
    left: 50%;
    transform: translateX(-50%);
    width: 90%;
    max-width: 1420px;
    display: grid;
    grid-template-columns: 1fr 1.3fr 1fr;
    gap: 28px;
    align-items: end;
    z-index: 25;
    transition: transform 0.35s cubic-bezier(0.16, 1, 0.3, 1), opacity 0.35s ease;
}}

/* Auto-dodge when Leaderboard Zine opens */
.podium-cards-dock.dock-receded {{
    transform: translateX(-50%) translateY(55px);
    opacity: 0.15;
    pointer-events: none;
}}

/* Base Card Style: Slanted Brutalist Box */
.brutal-card {{
    background: rgba(14, 15, 22, 0.96);
    backdrop-filter: blur(10px);
    border: 3px solid #000;
    position: relative;
    padding: 18px 22px;
    display: flex;
    flex-direction: column;
    gap: 8px;
    cursor: pointer;
    transition: transform 0.2s cubic-bezier(0.16, 1, 0.3, 1), box-shadow 0.2s ease;
}}

.brutal-card:hover {{
    transform: scale(1.02);
}}

/* Halftone Screentone Pattern Overlay */
.card-screentone-bg {{
    position: absolute;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    background-image: radial-gradient(rgba(255, 255, 255, 0.12) 1.2px, transparent 1.2px);
    background-size: 8px 8px;
    pointer-events: none;
    z-index: 1;
}}

/* Slapped Vinyl Sticker Tag */
.sticker-tag {{
    position: absolute;
    top: -14px;
    font-family: 'Space Grotesk', sans-serif;
    font-weight: 900;
    font-size: 11px;
    padding: 3px 12px;
    text-transform: uppercase;
    letter-spacing: 1.5px;
    border: 2px solid #000;
    box-shadow: 3px 3px 0px #000;
    z-index: 10;
}}

/* Stencil Big Position Numbers in Background */
.card-stencil-num {{
    position: absolute;
    right: 14px;
    bottom: -6px;
    font-family: 'Bebas Neue', sans-serif;
    font-size: 96px;
    line-height: 0.8;
    opacity: 0.14;
    font-weight: 900;
    pointer-events: none;
    z-index: 2;
}}

.card-content {{
    position: relative;
    z-index: 5;
    display: flex;
    flex-direction: column;
    gap: 4px;
}}

.driver-tag-row {{
    display: flex;
    align-items: baseline;
    justify-content: space-between;
}}

.driver-name-text {{
    font-family: 'Bebas Neue', sans-serif;
    font-size: 40px;
    line-height: 0.9;
    letter-spacing: 1px;
    color: #FFF;
    text-shadow: 2px 2px 0px #000;
}}

.team-badge-pill {{
    font-size: 11px;
    font-weight: 700;
    padding: 2px 8px;
    border-radius: 2px;
    letter-spacing: 1px;
    text-transform: uppercase;
}}

.timing-stats-row {{
    display: flex;
    justify-content: space-between;
    align-items: center;
    border-top: 2px solid rgba(255, 255, 255, 0.15);
    padding-top: 8px;
    margin-top: 4px;
    font-family: 'Space Grotesk', sans-serif;
    font-weight: 700;
    font-size: 14px;
}}

/* P2 Specific (Slanted -3.5deg, Cyan) */
.card-p2 {{
    transform: rotate(-3deg) skewX(-2deg);
    border: 3px solid var(--neon-cyan);
    box-shadow: 6px 6px 0px #000, 10px 10px 0px rgba(0, 240, 255, 0.45);
}}

.card-p2 .sticker-tag {{
    left: 16px;
    background: var(--neon-cyan);
    color: #000;
    transform: rotate(-4deg);
}}

.card-p2 .team-badge-pill {{
    background: rgba(0, 240, 255, 0.18);
    color: var(--neon-cyan);
    border: 1px solid var(--neon-cyan);
}}

/* P1 Champion Card (Elevated, Acid Lime, Hard Dropshadow) */
.card-p1 {{
    transform: translateY(-16px) scale(1.05);
    border: 4px solid var(--acid-lime);
    box-shadow: 8px 8px 0px #000, 14px 14px 0px var(--acid-lime);
    background: rgba(14, 18, 12, 0.96);
    padding: 22px 26px;
}}

.card-p1 .sticker-tag {{
    left: 50%;
    transform: translateX(-50%) rotate(-2deg);
    background: var(--acid-lime);
    color: #000;
    font-size: 13px;
    padding: 5px 18px;
    box-shadow: 4px 4px 0px #000;
    white-space: nowrap;
}}

.card-p1 .driver-name-text {{
    font-size: 48px;
    color: var(--acid-lime);
    text-shadow: 3px 3px 0px #000;
}}

.card-p1 .team-badge-pill {{
    background: var(--acid-lime);
    color: #000;
    font-weight: 900;
}}

.bonus-pill-fl {{
    background: var(--hot-pink);
    color: #FFF;
    font-size: 11px;
    font-weight: 900;
    padding: 2px 8px;
    box-shadow: 2px 2px 0px #000;
    transform: rotate(-2deg);
}}

/* P3 Specific (Slanted +3.5deg, Orange) */
.card-p3 {{
    transform: rotate(3deg) skewX(2deg);
    border: 3px solid var(--hazard-orange);
    box-shadow: 6px 6px 0px #000, 10px 10px 0px rgba(255, 107, 0, 0.45);
}}

.card-p3 .sticker-tag {{
    right: 16px;
    background: var(--hazard-orange);
    color: #000;
    transform: rotate(3deg);
}}

.card-p3 .team-badge-pill {{
    background: rgba(255, 107, 0, 0.18);
    color: var(--hazard-orange);
    border: 1px solid var(--hazard-orange);
}}

/* ============================================================
   RACE ZINE: CLASSIFICATION LEADERBOARD DRAWER
   ============================================================ */
.race-zine-drawer {{
    position: absolute;
    top: 32px;
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

    <!-- 3D World / Studio Background -->
    <div class="stage-background" id="stageBg"></div>

    <!-- Manga Speedline Action Burst -->
    <div class="speedlines-overlay" id="speedlinesLayer"></div>

    <!-- NFS Unbound Celebration VFX & Animated Rig Layer -->
    <div class="celebration-vfx-layer" id="celebrationLayer">
        
        <!-- P1 WINNER RIG (Centered on Kaze Ryu at X=50%, Y=450px) -->
        <div class="p1-vfx-anchor stepped-12fps" id="p1Anchor">

            <!-- 1. GRAFFITI WINGS TAG (Sprouting Behind Shoulders with Wide Clear Center) -->
            <svg class="graffiti-wings-tag wings-stepped" id="wingsVfx" viewBox="0 0 640 300" fill="none" xmlns="http://www.w3.org/2000/svg">
                <defs>
                    <filter id="neonGlowLime" x="-20%" y="-20%" width="140%" height="140%">
                        <feDropShadow dx="0" dy="0" stdDeviation="6" flood-color="#D8FF00" flood-opacity="0.9"/>
                    </filter>
                </defs>

                <!-- Left Wing Feathers (Starting at X=240, spreading outward left to X=20) -->
                <g filter="url(#neonGlowLime)">
                    <path d="M 240 150 C 180 80 110 50 20 80 C -5 95 10 125 55 130 C 105 135 160 150 230 170 Z" 
                          fill="#D8FF00" stroke="#000" stroke-width="5" stroke-linejoin="round"/>
                    <path d="M 230 170 C 160 125 80 120 10 160 C -2 170 15 195 65 190 C 120 185 180 190 225 200 Z" 
                          fill="#D8FF00" stroke="#000" stroke-width="4.5" stroke-linejoin="round"/>
                    <path d="M 225 200 C 170 175 95 185 35 230 C 22 242 45 255 85 240 C 130 225 185 220 220 215 Z" 
                          fill="#00F0FF" stroke="#000" stroke-width="4" stroke-linejoin="round"/>
                </g>
                <path d="M 220 155 Q 120 105 45 115" stroke="#FFF" stroke-width="3" stroke-linecap="round"/>
                <path d="M 210 180 Q 110 155 35 175" stroke="#00F0FF" stroke-width="3" stroke-linecap="round"/>

                <!-- Right Wing Feathers (Starting at X=400, spreading outward right to X=620) -->
                <g filter="url(#neonGlowLime)">
                    <path d="M 400 150 C 460 80 530 50 620 80 C 645 95 630 125 585 130 C 535 135 480 150 410 170 Z" 
                          fill="#D8FF00" stroke="#000" stroke-width="5" stroke-linejoin="round"/>
                    <path d="M 410 170 C 480 125 560 120 630 160 C 642 170 625 195 575 190 C 520 185 460 190 415 200 Z" 
                          fill="#D8FF00" stroke="#000" stroke-width="4.5" stroke-linejoin="round"/>
                    <path d="M 415 200 C 470 175 545 185 605 230 C 618 242 595 255 555 240 C 510 225 455 220 420 215 Z" 
                          fill="#00F0FF" stroke="#000" stroke-width="4" stroke-linejoin="round"/>
                </g>
                <path d="M 420 155 Q 520 105 595 115" stroke="#FFF" stroke-width="3" stroke-linecap="round"/>
                <path d="M 430 180 Q 530 155 605 175" stroke="#00F0FF" stroke-width="3" stroke-linecap="round"/>
            </svg>

            <!-- 2. GRAFFITI CROWN TAG (Floating gracefully above Ryu's Head) -->
            <svg class="graffiti-crown-tag" id="crownVfx" viewBox="0 0 160 100" fill="none" xmlns="http://www.w3.org/2000/svg">
                <defs>
                    <filter id="crownGlow" x="-20%" y="-20%" width="140%" height="140%">
                        <feDropShadow dx="0" dy="0" stdDeviation="5" flood-color="#FFEE00" flood-opacity="0.9"/>
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
                <path d="M 15 15 Q 15 5 10 5 Q 15 5 15 -5 Q 15 5 20 5 Q 15 5 15 15 Z" fill="#D8FF00"/>
                <path d="M 145 12 Q 145 4 140 4 Q 145 4 145 -4 Q 145 4 150 4 Q 145 4 145 12 Z" fill="#00F0FF"/>
            </svg>

            <!-- 3. JAGGED LIGHTNING SPARKS TAG -->
            <svg class="lightning-sparks-tag" id="sparksVfx" viewBox="0 0 320 280" fill="none" xmlns="http://www.w3.org/2000/svg">
                <path d="M 75 80 L 90 115 L 70 122 L 85 155 L 60 140" stroke="#D8FF00" stroke-width="5" stroke-linecap="round" stroke-linejoin="bevel" filter="drop-shadow(0 0 6px #D8FF00)"/>
                <path d="M 245 180 L 225 208 L 238 214 L 218 248" stroke="#00F0FF" stroke-width="4.5" stroke-linecap="round" stroke-linejoin="bevel" filter="drop-shadow(0 0 6px #00F0FF)"/>
                <path d="M 230 55 L 245 78 L 232 84 L 250 105" stroke="#FFEE00" stroke-width="4" stroke-linecap="round" stroke-linejoin="bevel"/>
            </svg>

            <!-- 4. EYE-GLINT STAR SPARKLE -->
            <svg class="eye-glint" viewBox="0 0 40 40" fill="none" xmlns="http://www.w3.org/2000/svg">
                <path d="M 20 0 Q 20 20 0 20 Q 20 20 20 40 Q 20 20 40 20 Q 20 20 20 0 Z" fill="#FFFFFF" filter="drop-shadow(0 0 6px #00F0FF)"/>
            </svg>

            <!-- 5. MANGA ONOMATOPOEIA TAGS -->
            <div class="manga-tag-shousha" id="kanjiTag">勝者</div>
            <div class="manga-tag-don" id="donTag">#1 APEX</div>

        </div>

        <!-- P2 MAKOTO SPARKS (Peace signs) -->
        <div class="p2-vfx-anchor" id="p2Anchor">
            <svg class="p2-sparkle-stars" viewBox="0 0 100 60" fill="none" xmlns="http://www.w3.org/2000/svg">
                <path d="M 25 15 Q 25 30 10 30 Q 25 30 25 45 Q 25 30 40 30 Q 25 30 25 15 Z" fill="#00F0FF" filter="drop-shadow(0 0 5px #00F0FF)"/>
                <path d="M 75 5 Q 75 15 65 15 Q 75 15 75 25 Q 75 15 85 15 Q 75 15 75 5 Z" fill="#FFFFFF"/>
            </svg>
        </div>

        <!-- P3 ARTHUR AMBER SPARKS -->
        <div class="p3-vfx-anchor" id="p3Anchor">
            <svg class="p3-amber-sparks" viewBox="0 0 80 70" fill="none" xmlns="http://www.w3.org/2000/svg">
                <path d="M 40 10 L 48 25 L 65 30 L 50 42 L 54 60 L 40 50 L 26 60 L 30 42 L 15 30 L 32 25 Z" fill="#FF6B00" opacity="0.8" filter="drop-shadow(0 0 5px #FF6B00)"/>
            </svg>
        </div>

    </div>

    <!-- Top Neo-Brutalist Manga Header -->
    <div class="top-header-zine">
        <div class="top-badge-strip">
            <span class="tag-black-box">/// LA VOITURE // CHAMPIONSHIP PODIUM</span>
            <span class="tag-warning-tape">OFFICIAL SCRUTINEERING APPROVED</span>
        </div>
        <div class="headline-wrap">
            <div class="main-headline-brutal">RACE COMPLETE</div>
            <div class="headline-sub-cutout">SUZUKA GRAND PRIX // 3 LAPS // GT3 PRO CATEGORY</div>
        </div>
    </div>

    <!-- ============================================================
         SLANTED STICKER PODIUM CARDS (P2, P1, P3)
         ============================================================ -->
    <div class="podium-cards-dock" id="cardsDock">
        
        <!-- P2 RUNNER-UP CARD (Slanted Left -3.5deg) -->
        <div class="brutal-card card-p2" onclick="toggleZine(true)">
            <div class="card-screentone-bg"></div>
            <span class="sticker-tag">[P2] RUNNER-UP</span>
            <div class="card-stencil-num">02</div>
            <div class="card-content">
                <div class="driver-tag-row">
                    <span class="driver-name-text">#03 M. ITO</span>
                    <span class="team-badge-pill">NEON DRIFT</span>
                </div>
                <div class="timing-stats-row">
                    <span style="color: var(--neon-cyan); font-family: monospace;">GAP: +1.700s</span>
                    <span style="font-weight: 900;">18 PTS</span>
                </div>
            </div>
        </div>

        <!-- P1 GRAND CHAMPION CARD (Center Elevated, Acid Lime) -->
        <div class="brutal-card card-p1" onclick="toggleZine(true)">
            <div class="card-screentone-bg"></div>
            <span class="sticker-tag">★ [P1] GRAND CHAMPION ★</span>
            <div class="card-stencil-num">01</div>
            <div class="card-content">
                <div class="driver-tag-row">
                    <span class="driver-name-text">#01 KAZE RYU</span>
                    <span class="team-badge-pill">APEX RACING</span>
                </div>
                <div class="timing-stats-row">
                    <div style="display: flex; gap: 8px; align-items: center;">
                        <span style="color: var(--acid-lime); font-family: monospace;">TIME: 5:00.000</span>
                        <span class="bonus-pill-fl">FL: 1:32.000 [+1 PT]</span>
                    </div>
                    <span style="font-size: 22px; font-weight: 900; color: var(--acid-lime);">25+1 PTS</span>
                </div>
            </div>
        </div>

        <!-- P3 BRONZE PODIUM CARD (Slanted Right +3.5deg) -->
        <div class="brutal-card card-p3" onclick="toggleZine(true)">
            <div class="card-screentone-bg"></div>
            <span class="sticker-tag">[P3] BRONZE LOCK</span>
            <div class="card-stencil-num">03</div>
            <div class="card-content">
                <div class="driver-tag-row">
                    <span class="driver-name-text">#09 T. KADE</span>
                    <span class="team-badge-pill">RAZORLINE</span>
                </div>
                <div class="timing-stats-row">
                    <span style="color: var(--hazard-orange); font-family: monospace;">GAP: +3.400s</span>
                    <span style="font-weight: 900;">15 PTS</span>
                </div>
            </div>
        </div>

    </div>

    <!-- ============================================================
         RACE ZINE: CLASSIFICATION LEADERBOARD DRAWER
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
            <span class="key-badge">W</span> Graffiti Wings
        </button>
        <button class="tool-btn active" id="btnCrown" onclick="toggleCrown()">
            <span class="key-badge">C</span> Crown & Sparks
        </button>
        <button class="tool-btn active" id="btnFps" onclick="toggleAnimeFps()">
            <span class="key-badge">F</span> <span id="fpsLabel">12 FPS Sakuga</span>
        </button>
        <button class="tool-btn" id="btnZoom" onclick="toggleZoom()">
            <span class="key-badge">Z</span> Hero Close-Up
        </button>
        <button class="tool-btn" onclick="alert('Tekan ESC untuk kembali ke HQ pada game runtime!')">
            <span class="key-badge">ESC</span> Exit HQ
        </button>
    </div>

</div>

<script>
let zineOpen = false;
let wingsVisible = true;
let crownVisible = true;
let animeFps = true;
let isZoomed = false;

function toggleZine(forceState) {{
    zineOpen = (forceState !== undefined) ? forceState : !zineOpen;
    const drawer = document.getElementById('raceZine');
    const cardsDock = document.getElementById('cardsDock');
    const btn = document.getElementById('btnZine');

    if (zineOpen) {{
        drawer.classList.add('open');
        cardsDock.classList.add('dock-receded');
        btn.classList.add('active');
    }} else {{
        drawer.classList.remove('open');
        cardsDock.classList.remove('dock-receded');
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
    const sparks = document.getElementById('sparksVfx');
    const kanji = document.getElementById('kanjiTag');
    const don = document.getElementById('donTag');
    const btn = document.getElementById('btnCrown');

    const disp = crownVisible ? 'block' : 'none';
    crown.style.display = disp;
    sparks.style.display = disp;
    kanji.style.display = disp;
    don.style.display = disp;
    btn.classList.toggle('active', crownVisible);
}}

function toggleAnimeFps() {{
    animeFps = !animeFps;
    const anchor = document.getElementById('p1Anchor');
    const wings = document.getElementById('wingsVfx');
    const fpsLabel = document.getElementById('fpsLabel');
    const btn = document.getElementById('btnFps');

    if (animeFps) {{
        anchor.classList.add('stepped-12fps');
        anchor.classList.remove('smooth-60fps');
        wings.classList.add('wings-stepped');
        wings.classList.remove('wings-smooth');
        fpsLabel.innerText = '12 FPS Sakuga';
        btn.classList.add('active');
    }} else {{
        anchor.classList.remove('stepped-12fps');
        anchor.classList.add('smooth-60fps');
        wings.classList.remove('wings-stepped');
        wings.classList.add('wings-smooth');
        fpsLabel.innerText = '60 FPS Smooth';
        btn.classList.remove('active');
    }}
}}

function toggleZoom() {{
    isZoomed = !isZoomed;
    const stage = document.getElementById('viewportStage');
    const btn = document.getElementById('btnZoom');
    stage.classList.toggle('zoom-closeup', isZoomed);
    btn.classList.toggle('active', isZoomed);
}}

// Keyboard Shortcuts Listener (TAB, W, C, F, Z)
window.addEventListener('keydown', (e) => {{
    if (e.key === 'Tab') {{
        e.preventDefault();
        toggleZine();
    }} else if (e.key.toLowerCase() === 'w') {{
        toggleWings();
    }} else if (e.key.toLowerCase() === 'c') {{
        toggleCrown();
    }} else if (e.key.toLowerCase() === 'f') {{
        toggleAnimeFps();
    }} else if (e.key.toLowerCase() === 'z') {{
        toggleZoom();
    }}
}});
</script>

</body>
</html>
"""

    output_path = "temp/winning_scene_preview.html"
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    with open(output_path, "w", encoding="utf-8") as f:
        f.write(html_content)

    print(f"Preview HTML successfully generated at: {output_path}")

if __name__ == "__main__":
    main()
