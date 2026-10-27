extends RefCounted

## One placeholder livery color per team (index = team_id), shared by the 3D
## car actors and the 2D circuit radar so a car reads the same in both views.

const COLORS: Array[Color] = [
	Color("#CCFF00"), Color("#00F0FF"), Color("#FF1E56"), Color("#FFE600"), Color("#D946EF"),
	Color("#FF7A00"), Color("#3D7BFF"), Color("#F4F5F7"), Color("#00E08A"), Color("#9B5CFF"),
	Color("#D40000"), Color("#1E3A8A"), Color("#E2E8F0"),
]


static func color_for(team_id: int) -> Color:
	return COLORS[posmod(team_id, COLORS.size())]
