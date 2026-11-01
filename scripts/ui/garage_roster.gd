class_name GarageRoster
extends RefCounted

## Garage metadata in GtData team order. The car slugs are the actual `*_full.glb` folders;
## the portrait directories are the original 2D character library, whose folder names predate
## the final team names, so they are mapped per team here instead of derived from GtData.

const CAR_SLUGS: Array[String] = [
	"mercedes_amg", "audi_r8", "nissan_gtr", "bmw_m4", "aston_vantage",
	"chevy_corvette", "honda_nsx", "lexus_rcf", "mclaren_720s", "lambo_huracan",
	"ferrari_296", "ford_mustang", "toyota_supra",
]

const CAR_NAMES: Array[String] = [
	"Mercedes-AMG GT3 Evo", "Audi R8 LMS GT3 Evo II", "Nissan GT-R NISMO GT3",
	"BMW M4 GT3", "Aston Martin Vantage AMR GT3", "Chevrolet Corvette Z06 GT3.R",
	"Honda NSX GT3 Evo22", "Lexus RC F GT3", "McLaren 720S GT3 Evo",
	"Lamborghini Huracan GT3 EVO2",
	"Ferrari 296 GT3", "Ford Mustang GT3", "Toyota GR Supra GT",
]

## Engine layout per car, in CAR_SLUGS order (winning scene callout). Layout only: tuned BoP power
## figures change per season and are not carried in game data.
const CAR_ENGINES: Array[String] = [
	"6.2L V8 NA", "5.2L V10 NA", "3.8L V6 TWIN-TURBO", "3.0L I6 TWIN-TURBO", "4.0L V8 TWIN-TURBO",
	"5.5L V8 NA", "3.5L V6 TWIN-TURBO", "5.4L V8 NA", "4.0L V8 TWIN-TURBO", "5.2L V10 NA",
	"3.0L V6 TWIN-TURBO", "5.4L V8 NA", "5.2L V8 NA",
]

const PRINCIPALS: Array[String] = [
	"Kenji Takahashi", "Rei Kisaragi", "Daisuke Kurogane", "Henrik von Vanta",
	"Lady Victoria Sterling", "\"Big Jim\" Callahan", "Ryuji Sakamoto",
	"Dr. Aris Thorne", "Lord Vincent Chen", "Klaus Richter",
	"Enzo Corelli", "Hank Bradley", "Kenjiro Kazama",
]

## Portrait directory per team, matching `reference-assets/characters/<team>/<driver>/`.
const TEAM_SLUGS: Array[String] = [
	"apex-racing", "neon-drift", "kurogane-gt", "nordic-phantom", "zephyr-racing",
	"corsa-rossa", "tokyo-underground", "valkyrie-scuderia", "cyberpunk-syndicate",
	"veloce-stratos",
	"scuderia-maranello", "ironhorse-motorsport", "neo-wangan-works",
]

## Driver portrait folder per field slot (team * 2 + car), in GtData driver order.
const DRIVER_SLUGS: Array[String] = [
	"kaze-ryu", "sora-ren",
	"makoto-ito", "axel-vale",
	"javier-cruz", "naoki-sato",
	"erik-lindqvist", "freja-berg",
	"arthur-sterling-jr", "harrison-croft",
	"luca-ferrari", "matteo-rossi",
	"ren-mishima", "shinjiro-ono",
	"alistair-finch", "charles-de-vries",
	"dante-vance", "zane-cross",
	"gianluca-moretti", "pierre-mercier",
	"marco-bellini", "alessia-rossi",
	"colt-vance", "wyatt-cooper",
	"hayato-kazama", "rin-takahashi",
]


static func car_path(team: int) -> String:
	var slug: String = CAR_SLUGS[posmod(team, CAR_SLUGS.size())]
	return "res://assets/cars/%s/%s_full.glb" % [slug, slug]


static func portrait_path(slot: int) -> String:
	var team: int = posmod(slot, DRIVER_SLUGS.size()) / 2
	return "res://reference-assets/characters/%s/%s/radio_portrait.png" % [
		TEAM_SLUGS[team], DRIVER_SLUGS[posmod(slot, DRIVER_SLUGS.size())],
	]


## One epithet per driver slot, in GtData.DRIVER_NAMES order (source: DRIVER-CHARACTERIZATION-ROSTER.md,
## checked against GtData.DRIVER_CODES). Shown on the podium panel's narration box.
const DRIVER_EPITHETS: Array[String] = [
	"The High-Voltage Prodigy", "The Cybernetic Calculator",
	"The Apex Drifter", "The Camden Rocker",
	"The Iron Matador", "The Silent Ronin",
	"The Monaco Prodigy", "The Sao Paulo Storm",
	"The Laser Meister", "The Iron Valkyrie",
	"The Redline Brawler", "The Guadalajara Bull",
	"The Siberian Frost", "The Cyber Kitsune",
	"The Monokrom Stylist", "The Bauhaus Architect",
	"The Monsoon Emperor", "The Riviera Playboy",
	"The Ghost Operator", "The Horizon Hunter",
	"The Monza Virtuoso", "The Aero Donna",
	"The Detroit Brawler", "The High-Plains Drifter",
	"The Midnight Ghost", "The Touge Empress",
]

## Podium decoration per place (index 0 = P1): rank kanji and the katakana sound effect.
const RANK_KANJI: Array[String] = ["優勝", "準優勝", "第三位"]
const RANK_SFX: Array[String] = ["ドォン!!", "ザッ!", "ゴゴゴ"]


static func epithet(slot: int) -> String:
	return DRIVER_EPITHETS[slot] if slot >= 0 and slot < DRIVER_EPITHETS.size() else ""


## Baked 2D sprite of the team's car for the podium (made by tools/bake_podium_car_sprites.gd).
static func podium_sprite_path(team: int) -> String:
	var slug: String = CAR_SLUGS[posmod(team, CAR_SLUGS.size())]
	return "res://assets/cars/%s/podium_sprite.png" % slug
