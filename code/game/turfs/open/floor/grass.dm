
/turf/open/floor/rogue/grass
	name = "green grass"
	desc = "Grass, sodden with mud and bogwater."
	icon = 'icons/turf/roguegrass.dmi'
	icon_state = "grass-1"
	layer = MID_TURF_LAYER_3
	footstep = FOOTSTEP_GRASS
	barefootstep = FOOTSTEP_SOFT_BAREFOOT
	heavyfootstep = FOOTSTEP_GENERIC_HEAVY
	landsound = 'sound/foley/jumpland/grassland.wav'
	slowdown = 0
	liquid_absorption = 1
	smoothing_flags = SMOOTH_EDGE
	smoothing_groups = SMOOTH_GROUP_OPEN_FLOOR + SMOOTH_GROUP_FLOOR_GRASS
	smoothing_list = SMOOTH_GROUP_FLOOR_DIRT_ROAD

	neighborlay = "grass-green-trim"

	spread_chance = 15
	burn_power = 6
	prettifyturf = TRUE
/turf/open/floor/rogue/grass/Initialize()
	. = ..()
	AddComponent(/datum/component/fertility)

/turf/open/floor/rogue/grass/fertility_interaction(fertility)

	switch(fertility)
		if(0-19)
			ChangeTurf(/turf/open/floor/rogue/dirt, flags = CHANGETURF_INHERIT_AIR)
		if(20 to 40)
			icon_state = "grass-1"
		if(41 to 60)
			icon_state = "grass-2"
		if(61 to 80)
			icon_state = "grass-3"
		if(81 to 100)
			icon_state = "grass-4"

//These should really be a child of grass.
/turf/open/floor/rogue/grasscold
	name = "tundra grass"
	desc = "Grass, frigid and touched by winter."
	icon_state = "grass_cold"
	layer = MID_TURF_LAYER
	footstep = FOOTSTEP_GRASS
	barefootstep = FOOTSTEP_SOFT_BAREFOOT
	heavyfootstep = FOOTSTEP_GENERIC_HEAVY
	landsound = 'sound/foley/jumpland/grassland.wav'
	slowdown = 0
	liquid_absorption = 1
	smoothing_groups = SMOOTH_GROUP_FLOOR_GRASS
	neighborlay = "grass_coldedge"
	prettifyturf = TRUE

/turf/open/floor/rogue/grassred
	name = "red grass"
	desc = "Grass, ripe with Dendor's blood."
	icon_state = "grass_red"
	layer = MID_TURF_LAYER
	footstep = FOOTSTEP_GRASS
	barefootstep = FOOTSTEP_SOFT_BAREFOOT
	heavyfootstep = FOOTSTEP_GENERIC_HEAVY
	landsound = 'sound/foley/jumpland/grassland.wav'
	slowdown = 0
	liquid_absorption = 1
	smoothing_groups = SMOOTH_GROUP_FLOOR_GRASS
	prettifyturf = TRUE


/turf/open/floor/rogue/grassyel
	name = "yellow grass"
	desc = "Grass, blessed by Astrata's light."
	icon_state = "grass_yel"
	layer = MID_TURF_LAYER
	footstep = FOOTSTEP_GRASS
	barefootstep = FOOTSTEP_SOFT_BAREFOOT
	heavyfootstep = FOOTSTEP_GENERIC_HEAVY
	landsound = 'sound/foley/jumpland/grassland.wav'
	slowdown = 0
	liquid_absorption = 1
	smoothing_groups = SMOOTH_GROUP_FLOOR_GRASS
	prettifyturf = TRUE
