class_name DeckCoach
extends RefCounted

## The plain-language sentence for every option on the deck, kept in one table so the text is easy to
## localise. Index = option index (TYRE index 0 is AUTO, then the five compounds).

const PACE: Array[String] = [
	"Drive gently: tyres and fuel last longer, but you lose time.",
	"A little slower than normal to save the tyres.",
	"Normal pace. Balanced.",
	"Faster laps, but the tyres wear out quicker.",
	"Maximum speed. Tyres and fuel burn fast: use it in short bursts.",
]
const FUEL: Array[String] = [
	"Save fuel, slightly slower.",
	"Normal fuel use.",
	"More engine power, burns more fuel.",
]
const ERS: Array[String] = [
	"Charge the battery while you drive (a bit slower).",
	"Balanced battery use.",
	"Spend the battery for extra power.",
	"A burst of power for passing. Drains the battery very fast.",
]
const TYRE: Array[String] = [
	"The engineer picks the tyre that fits the weather when you pit.",
	"Fastest grip but wears out quickest. Best on a dry track.",
	"Balanced speed and life. The safe choice on a dry track.",
	"Slowest but lasts the longest. Good for long stints.",
	"For a damp track or light rain (water 18-45%).",
	"For heavy rain (water above 45%). Overheats on a dry track.",
]
const BOX: String = "Calls the car into the pits at the next pit entry. You can cancel any time before pit entry with no penalty."
