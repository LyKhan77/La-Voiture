class_name RadioMarkup
extends RefCounted

## Display helpers of the R2 radio card: the keywords of a call are set as ink blocks in the card's paper colour,
## and the type colour follows how dark the paper is.

const KEYWORDS: Array[String] = [
	"BOX", "WET", "WETS", "INTER", "INTERS", "TYRES", "TYRE", "PIT", "SLICKS", "FUEL", "ERS", "DRS", "PUNCTURE", "CLIFF", "OVERTAKE",
]
const INK := Color("#050505")
## Same threshold as GarageStyle.on_accent: under it the paper is dark and the type turns white.
const DARK_PAPER_LUMINANCE: float = 0.35

static var _pattern: RegEx


## `text` is already capitalised. Whole words only: BOXING is not BOX.
static func highlight(text: String, paper: Color, ink: Color) -> String:
	if _pattern == null:
		_pattern = RegEx.new()
		_pattern.compile("\\b(%s)\\b" % "|".join(KEYWORDS))
	var open: String = "[bgcolor=#%s][color=#%s]" % [ink.to_html(false), paper.to_html(false)]
	return _pattern.sub(text, "%s$1[/color][/bgcolor]" % open, true)


static func ink_for(paper: Color) -> Color:
	return Color.WHITE if paper.get_luminance() < DARK_PAPER_LUMINANCE else INK
