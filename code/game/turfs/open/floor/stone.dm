
/turf/open/floor/rogue/stone
	name = "stone bricks"
	desc = "Square-edged bricks put down and around for your convenience. Stones outlast young mortals, and so they are the preferred material by many an elder race."

	icon_state = "stone-brick"
	footstep = FOOTSTEP_STONE
	barefootstep = FOOTSTEP_HARD_BAREFOOT
	clawfootstep = FOOTSTEP_HARD_CLAW
	heavyfootstep = FOOTSTEP_GENERIC_HEAVY
	landsound = 'sound/foley/jumpland/stoneland.wav'
	smoothing_groups = SMOOTH_GROUP_FLOOR_STONE

/turf/open/floor/rogue/stone/pavestones
	name = "pavestones"
	desc = "Tiny little rocks! Rocks in little rectangles!"
	icon_state = "stone-paver"
	neighborlay = null
/turf/open/floor/rogue/stone/rows
	icon_state = "stone-rows"
	neighborlay = null
/turf/open/floor/rogue/stone/ornate
	name = "ornate stone tiles"
	desc = "The circle channel carved into these tiles describe many cycles. When turned but a smidge, one must point must surely mount for the same that another will fall."
	icon_state = "stone-ornate"
	neighborlay = null
/turf/open/floor/rogue/stone/grid3
	name = "stone tiles"
	icon_state = "stone-grid3"
	neighborlay = null
/turf/open/floor/rogue/stone/grid2
	name = "stone tiles"
	icon_state = "stone-grid2"
	neighborlay = null
/turf/open/floor/rogue/stone/masoned
	name = "masoned bricks"
	desc = "Masterfully worked, polished stone. This will last generations."
	icon_state = "stone-masoned"
	neighborlay = "stone-masoned-trim"
/turf/open/floor/rogue/stone/diagonal
	icon_state = "stone-diagonal"
	neighborlay = null
/turf/open/floor/rogue/stone/small
	name = "tiny pavestones"
	desc = "These tiny bricks are preferred in locations where water ingress is a concern."
	icon_state = "stone-small"
	//neighborlay = "trim-tester"
	neighborlay = "stone-small-trim"


/turf/open/floor/rogue/stone/spiral
	name = "swirling stone tiles"
	desc = "These tiles remind you of something, but you just can't recall what."
	icon_state = "stone-swirl"
	neighborlay = null

 // Pending repath.
/turf/open/floor/rogue/blocks
	icon_state = "blocks"
	name = "stone flooring"
	desc = "These rough stone slabs have been arranged in a neat grid for a rustic yet tidy charm."
	footstep = FOOTSTEP_STONE
	barefootstep = FOOTSTEP_HARD_BAREFOOT
	clawfootstep = FOOTSTEP_HARD_CLAW
	heavyfootstep = FOOTSTEP_GENERIC_HEAVY
	landsound = 'sound/foley/jumpland/stoneland.wav'
	smoothing_groups = SMOOTH_GROUP_FLOOR_STONE 
	prettifyturf = TRUE

/turf/open/floor/rogue/blocks/stonered
	icon_state = "stoneredlarge"
	name = "large red tiles"
	desc = "Large red earthen tiles carefully set in a pleasantly symmetrical pattern."
/turf/open/floor/rogue/blocks/stonered/tiny
	icon_state = "stoneredtiny"
	name = "square red tiles"
	desc = "Small square earthen tiles carefully arranged in a somewhat plain pattern."

/turf/open/floor/rogue/blocks/green
	icon_state = "greenblocks"

/turf/open/floor/rogue/blocks/bluestone
	icon_state = "bluestone2"

/turf/open/floor/rogue/blocks/newstone
	icon_state = "newstone2"

/turf/open/floor/rogue/blocks/newstone/alt
	icon_state = "bluestone"

/turf/open/floor/rogue/blocks/paving
	icon_state = "paving"
/turf/open/floor/rogue/blocks/paving/vert
	icon_state = "paving-t"

/turf/open/floor/rogue/blocks/platform
	name = "platform"
	desc = "A destructible platform."
	damage_deflection = 10
	max_integrity = 800
	break_sound = 'sound/combat/hits/onstone/stonedeath.ogg'
	attacked_sound = list('sound/combat/hits/onstone/wallhit.ogg', 'sound/combat/hits/onstone/wallhit2.ogg', 'sound/combat/hits/onstone/wallhit3.ogg')

/turf/open/floor/rogue/blocks/platform/turf_destruction(damage_flag)
	. = ..()
	ScrapeAway(flags = CHANGETURF_INHERIT_AIR)

/turf/open/floor/rogue/greenstone
	icon_state = "greenstone"
	footstep = FOOTSTEP_STONE
	barefootstep = FOOTSTEP_HARD_BAREFOOT
	clawfootstep = FOOTSTEP_HARD_CLAW
	heavyfootstep = FOOTSTEP_GENERIC_HEAVY
	landsound = 'sound/foley/jumpland/stoneland.wav'
	icon = 'icons/turf/greenstone.dmi'

/turf/open/floor/rogue/greenstone/runed
	icon_state = "greenstoneruned"

/turf/open/floor/rogue/hexstone
	icon_state = "hexstone"
	footstep = FOOTSTEP_STONE
	barefootstep = FOOTSTEP_HARD_BAREFOOT
	clawfootstep = FOOTSTEP_HARD_CLAW
	heavyfootstep = FOOTSTEP_GENERIC_HEAVY
	landsound = 'sound/foley/jumpland/stoneland.wav'
	smoothing_groups = SMOOTH_GROUP_FLOOR_STONE 

	prettifyturf = TRUE

//Needs to be repathed.


/turf/open/floor/rogue/churchbrick
	icon_state = "church_brick"
	footstep = FOOTSTEP_TILE
	barefootstep = FOOTSTEP_HARD_BAREFOOT
	clawfootstep = FOOTSTEP_HARD_CLAW
	heavyfootstep = FOOTSTEP_GENERIC_HEAVY
	landsound = 'sound/foley/jumpland/stoneland.wav'
	smoothing_groups = SMOOTH_GROUP_FLOOR_STONE 

	prettifyturf = TRUE

/turf/open/floor/rogue/churchrough
	icon_state = "church_rough"
	footstep = FOOTSTEP_STONE
	barefootstep = FOOTSTEP_HARD_BAREFOOT
	clawfootstep = FOOTSTEP_HARD_CLAW
	heavyfootstep = FOOTSTEP_GENERIC_HEAVY
	landsound = 'sound/foley/jumpland/stoneland.wav'
	smoothing_groups = SMOOTH_GROUP_FLOOR_STONE 

	prettifyturf = TRUE

/turf/open/floor/rogue/herringbone
	icon_state = "herringbone"
	name = "stone herringbone flooring"
	desc = "These stone bricks have been carefully arranged in a rather pleasing pattern."
	footstep = FOOTSTEP_STONE
	barefootstep = FOOTSTEP_HARD_BAREFOOT
	clawfootstep = FOOTSTEP_HARD_CLAW
	heavyfootstep = FOOTSTEP_GENERIC_HEAVY
	landsound = 'sound/foley/jumpland/stoneland.wav'
	neighborlay = "herringedge"
	smoothing_groups = SMOOTH_GROUP_FLOOR_STONE 


/turf/open/floor/rogue/cobble
	icon_state = "cobblestone1"
	name = "cobblestone"
	desc = "Stone bricks carefully inlaid upon the ground for a more refined and resilient path."
	footstep = FOOTSTEP_STONE
	barefootstep = FOOTSTEP_HARD_BAREFOOT
	clawfootstep = FOOTSTEP_HARD_CLAW
	heavyfootstep = FOOTSTEP_GENERIC_HEAVY
	landsound = 'sound/foley/jumpland/stoneland.wav'
	neighborlay = "cobbleedge"
	smoothing_groups = SMOOTH_GROUP_FLOOR_STONE 


/turf/open/floor/rogue/cobble/Initialize()
	. = ..()
	icon_state = "cobblestone[rand(1,3)]"

/turf/open/floor/rogue/cobble/mossy
	name = "mossy cobblestone"
	desc = "Dirt and moss have crept between the gaps of this stone-brick flooring."
	icon_state = "mossystone1"
	footstep = FOOTSTEP_STONE
	barefootstep = FOOTSTEP_HARD_BAREFOOT
	clawfootstep = FOOTSTEP_HARD_CLAW
	heavyfootstep = FOOTSTEP_GENERIC_HEAVY
	landsound = 'sound/foley/jumpland/stoneland.wav'
	neighborlay = "mossystone_edges"


/turf/open/floor/rogue/cobble/mossy/Initialize()
	. = ..()
	icon_state = "mossystone[rand(1,3)]"

/turf/open/floor/rogue/cobblerock
	icon_state = "cobblerock"
	name = "cobbled rock path"
	desc = "A crude path of lumpy rocks that allows feet and cart wheels alike to escape the treacherous mud."
	footstep = FOOTSTEP_STONE
	barefootstep = FOOTSTEP_HARD_BAREFOOT
	clawfootstep = FOOTSTEP_HARD_CLAW
	heavyfootstep = FOOTSTEP_GENERIC_HEAVY
	landsound = 'sound/foley/jumpland/stoneland.wav'
	smoothing_groups = SMOOTH_GROUP_FLOOR_STONE 
