class_name GarageRoster
extends RefCounted

## Garage metadata in GtData team order. The car slugs are the actual `*_full.glb` folders;
## the portrait directories are the original 2D character library, whose folder names predate
## the final team names, so they are mapped per team here instead of derived from GtData.

const CAR_SLUGS: Array[String] = [
	"mercedes_amg", "audi_r8", "nissan_gtr", "bmw_m4", "aston_vantage",
	"chevy_corvette", "honda_nsx", "lexus_rcf", "mclaren_720s", "lambo_huracan",
]

const CAR_NAMES: Array[String] = [
	"Mercedes-AMG GT3 Evo", "Audi R8 LMS GT3 Evo II", "Nissan GT-R NISMO GT3",
	"BMW M4 GT3", "Aston Martin Vantage AMR GT3", "Chevrolet Corvette Z06 GT3.R",
	"Honda NSX GT3 Evo22", "Lexus RC F GT3", "McLaren 720S GT3 Evo",
	"Lamborghini Huracan GT3 EVO2",
]

const PRINCIPALS: Array[String] = [
	"Kenji Takahashi", "Rei Kisaragi", "Daisuke Kurogane", "Henrik von Vanta",
	"Lady Victoria Sterling", "\"Big Jim\" Callahan", "Ryuji Sakamoto",
	"Dr. Aris Thorne", "Lord Vincent Chen", "Klaus Richter",
]

## Portrait directory per team, matching `reference-assets/characters/<team>/<driver>/`.
const TEAM_SLUGS: Array[String] = [
	"apex-racing", "neon-drift", "kurogane-gt", "nordic-phantom", "zephyr-racing",
	"corsa-rossa", "tokyo-underground", "valkyrie-scuderia", "cyberpunk-syndicate",
	"veloce-stratos",
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
]


static func car_path(team: int) -> String:
	var slug: String = CAR_SLUGS[posmod(team, CAR_SLUGS.size())]
	return "res://assets/cars/%s/%s_full.glb" % [slug, slug]


static func portrait_path(slot: int) -> String:
	var team: int = posmod(slot, DRIVER_SLUGS.size()) / 2
	return "res://reference-assets/characters/%s/%s/radio_portrait.png" % [
		TEAM_SLUGS[team], DRIVER_SLUGS[posmod(slot, DRIVER_SLUGS.size())],
	]
