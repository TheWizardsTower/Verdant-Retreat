/turf/open/floor/rogue/wood
	name = "wooden floorboards"
	desc = "Polished wooden floorboards, worn but swept. This is what home feels like."

	icon_state = "boards"
	footstep = FOOTSTEP_WOOD
	barefootstep = FOOTSTEP_HARD_BAREFOOT
	clawfootstep = FOOTSTEP_WOOD_CLAW
	heavyfootstep = FOOTSTEP_GENERIC_HEAVY
	landsound = 'sound/foley/jumpland/woodland.wav'
	smoothing_groups = SMOOTH_GROUP_FLOOR_WOOD
	smoothing_flags =  SMOOTH_EDGE  

/turf/open/floor/rogue/wood/nosmooth //these are here so we can put wood floors next to each other but not have them smooth
	name = "hardwood floorboards"
	desc = "Polished dark floorboards gently stained by the years. This is what luxury looks like."
	icon_state = "boards-dark"
	smoothing_groups = null

/turf/open/floor/rogue/wood/turned
	icon_state = "boards-sideways"
	neighborlay = "boards-sideways-trim"

/turf/open/floor/rogue/wood/herringbone
	name = "wooden herringbone flooring"
	desc = "Thin planks of wood carefully arranged in a rather pleasing pattern. So fine!"
	icon_state = "boards-herringbone"

/turf/open/floor/rogue/wood/diagonal
	icon_state = "boads-diagonal"
	neighborlay = "boards-diagonal-trim"

/turf/open/floor/rogue/wood/chevron
	icon_state = "boards-chevron"
/turf/open/floor/rogue/wood/ruined
	icon_state = "boards-worn"
	name = "ruined wooden floorboards"
	desc = "Interlocking wooden floorboards. These ones could use some love."
	
/turf/open/floor/rogue/wood/ruined/turned
	icon_state = "boards-sideways-ruined"

/turf/open/floor/rogue/wood/ruined/diagonal
	icon_state = "boads-diagonal-ruined"
	neighborlay = "boards-diagonal-trim"

/turf/open/floor/rogue/wood/ruined/chevron
	icon_state = "replace-me"

/turf/open/floor/rogue/wood/ruined/herringbone
	name = "wooden herringbone flooring"
	desc = "Thin planks of wood carefully arranged in a rather pleasing pattern. They could use some care."
	landsound = 'sound/foley/jumpland/woodland.wav'
	icon_state = "boards-herringbone-ruined"


/turf/open/floor/rogue/wood/ruined/platform
	name = "platform"
	desc = "A destructible platform."
	damage_deflection = 8
	break_sound = 'sound/combat/hits/onwood/destroywalldoor.ogg'
	attacked_sound = list('sound/combat/hits/onwood/woodimpact (1).ogg','sound/combat/hits/onwood/woodimpact (2).ogg')

/turf/open/floor/rogue/wood/ruined/platform/turf_destruction(damage_flag)
	. = ..()
	ScrapeAway(flags = CHANGETURF_INHERIT_AIR)


/turf/open/floor/rogue/twig
	name = "twig flooring"
	desc = "Bundles of twigs have been laid flat against the ground. They creak and crackle with the slightest weight."
	icon_state = "twig"
	footstep = FOOTSTEP_GRASS
	barefootstep = FOOTSTEP_SOFT_BAREFOOT
	heavyfootstep = FOOTSTEP_GENERIC_HEAVY
	landsound = 'sound/foley/jumpland/grassland.wav'
	slowdown = 0
	prettifyturf = TRUE

/turf/open/floor/rogue/twig/platform
	name = "twig platform"
	desc = "A destructible platform."
	damage_deflection = 4
	max_integrity = 100		//It's fucking twig.
	break_sound = 'sound/combat/hits/onwood/destroywalldoor.ogg'
	attacked_sound = list('sound/combat/hits/onwood/woodimpact (1).ogg','sound/combat/hits/onwood/woodimpact (2).ogg')

/turf/open/floor/rogue/twig/platform/turf_destruction(damage_flag)
	. = ..()
	ScrapeAway(flags = CHANGETURF_INHERIT_AIR)
