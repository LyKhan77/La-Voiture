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
