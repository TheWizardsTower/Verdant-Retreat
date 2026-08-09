/turf/open/floor/rogue
	smoothing_groups = SMOOTH_GROUP_OPEN
	var/prettifyturf = TRUE
	icon = 'icons/turf/roguefloor.dmi'
	baseturfs = list(/turf/open/transparent/openspace)
	neighborlay = null
	var/fertility

/turf/open/floor/rogue/break_tile()
	return //unbreakable

/turf/open/floor/rogue/burn_tile()
	return //unburnable

/turf/open/floor/rogue/Initialize()
	if(prettifyturf)
		dir = pick(GLOB.cardinals)
	. = ..()

//A large amount of turfs have been moved into their own files. Check for them there.


//Rooftops.
/turf/open/floor/rogue/rooftop
	name = "roof"
	desc = "Overlapping wooden shingles protect the building and its inhabitants from the rain."
	icon_state = "roof-arw"
	footstep = FOOTSTEP_WOOD
	barefootstep = FOOTSTEP_HARD_BAREFOOT
	clawfootstep = FOOTSTEP_WOOD_CLAW
	heavyfootstep = FOOTSTEP_GENERIC_HEAVY
	prettifyturf = FALSE

/turf/open/floor/rogue/rooftop/Initialize()
	. = ..()
	icon_state = "roof"
/turf/open/floor/rogue/rooftop/green
	icon_state = "roofg-arw"

/turf/open/floor/rogue/rooftop/green/Initialize()
	. = ..()
	icon_state = "roofg"
/turf/open/floor/rogue/rooftop/green/north
	dir = 1
/turf/open/floor/rogue/rooftop/green/east
	dir = 4
/turf/open/floor/rogue/rooftop/green/west
	dir = 8
/turf/open/floor/rogue/rooftop/green/corner1
	icon_state = "roofgc1-arw"

/turf/open/floor/rogue/rooftop/green/corner1/Initialize()
	. = ..()
	icon_state = "roofgc1"
/turf/open/floor/rogue/rooftop/green/corner1/dirone
	dir = 1
/turf/open/floor/rogue/rooftop/green/corner1/dirfour
	dir = 4
/turf/open/floor/rogue/rooftop/green/corner1/direight
	dir = 8
/turf/open/floor/rogue/rooftop/green/corner1/dirfive
	dir = 5
/turf/open/floor/rogue/rooftop/green/corner1/dirnine
	dir = 9
/turf/open/floor/rogue/rooftop/green/corner1/dirsix
	dir = 6
/turf/open/floor/rogue/rooftop/green/corner1/dirten
	dir = 10


//AZURE SAND


/turf/open/floor/rogue/snow
	name = "snow"
	desc = "A gentle blanket of snow."
	icon_state = "snow"
	footstep = FOOTSTEP_GRASS
	barefootstep = FOOTSTEP_SOFT_BAREFOOT
	heavyfootstep = FOOTSTEP_GENERIC_HEAVY
	landsound = 'sound/foley/jumpland/grassland.wav'
	slowdown = 0
	smoothing_groups = SMOOTH_GROUP_FLOOR_SNOW
	neighborlay = "snowedge"
	spread_chance = 0
	prettifyturf = TRUE

/turf/open/floor/rogue/snowrough
	name = "rough snow"
	desc = "A rugged blanket of snow."
	icon_state = "snowrough"
	layer = MID_TURF_LAYER
	footstep = FOOTSTEP_GRASS
	barefootstep = FOOTSTEP_SOFT_BAREFOOT
	heavyfootstep = FOOTSTEP_GENERIC_HEAVY
	landsound = 'sound/foley/jumpland/grassland.wav'
	slowdown = 0
	smoothing_groups = SMOOTH_GROUP_FLOOR_SNOW
	neighborlay = "snowroughedge"
	spread_chance = 0
	prettifyturf = TRUE


/turf/open/floor/rogue/snowpatchy
	name = "patchy snow"
	desc = "Half-melted snow revealing the hardy grass underneath."
	icon_state = "snowpatchy_grass"
	layer = MID_TURF_LAYER
	footstep = FOOTSTEP_GRASS
	barefootstep = FOOTSTEP_SOFT_BAREFOOT
	heavyfootstep = FOOTSTEP_GENERIC_HEAVY
	landsound = 'sound/foley/jumpland/grassland.wav'
	slowdown = 0
	smoothing_groups = SMOOTH_GROUP_FLOOR_SNOW
	neighborlay = "snowpatchy_grassedge"

/turf/open/floor/rogue/hay
	name = "hay"
	desc = "Dried grass strewn across the floor. It's not the worst thing to sleep on."
	icon = 'icons/turf/roguefloor.dmi'
	icon_state = "hay"
	layer = MID_TURF_LAYER
	footstep = FOOTSTEP_SAND
	barefootstep = FOOTSTEP_SOFT_BAREFOOT
	heavyfootstep = FOOTSTEP_GENERIC_HEAVY
	landsound = 'sound/foley/jumpland/dirtland.wav'
	slowdown = 0

/turf/open/floor/rogue/underworld/space
	name = "void"
	desc = ""
	icon_state = "undervoid"
	layer = MID_TURF_LAYER
	footstep = FOOTSTEP_SAND
	barefootstep = FOOTSTEP_SOFT_BAREFOOT
	heavyfootstep = FOOTSTEP_GENERIC_HEAVY
	landsound = 'sound/foley/jumpland/dirtland.wav'
	slowdown = 50

/turf/open/floor/rogue/underworld/space/sparkle_quiet
	name = "void"
	desc = ""
	icon_state = "undervoid2"

/turf/open/floor/rogue/underworld/space/quiet
	name = "void"
	desc = ""
	icon_state = "undervoid3"

/turf/open/floor/rogue/underworld/road
	name = "ash"
	desc = "Smells like burnt wood."
	icon_state = "ash"
	footstep = FOOTSTEP_SAND
	barefootstep = FOOTSTEP_SOFT_BAREFOOT
	heavyfootstep = FOOTSTEP_GENERIC_HEAVY
	landsound = 'sound/foley/jumpland/dirtland.wav'
	smoothing_groups = SMOOTH_GROUP_FLOOR_DIRT_ROAD 

	slowdown = 0

/turf/open/floor/rogue/underworld/road/Initialize()
	. = ..()
	dir = rand(0,8)

/turf/open/floor/rogue/volcanic
	name = "solidified lava"
	desc = "Once, it burned anything it touched with the hatred of hell itself. Now a hardened black crust crunches beneath your feet."
	icon_state = "lavafloor"
	layer = MID_TURF_LAYER
	footstep = FOOTSTEP_SAND
	barefootstep = FOOTSTEP_SOFT_BAREFOOT
	clawfootstep = FOOTSTEP_SAND
	heavyfootstep = FOOTSTEP_GENERIC_HEAVY
	landsound = 'sound/foley/jumpland/dirtland.wav'
	smoothing_groups = SMOOTH_GROUP_FLOOR_DIRT
	neighborlay = "lavedge"
	prettifyturf = TRUE


/obj/effect/decal/mossy
	name = "mossy brick floor"
	desc = "dirt and moss have crept between the gaps of this stone-brick flooring."
	icon = 'icons/turf/roguefloor.dmi'
	icon_state = "mossyedge"
	mouse_opacity = 0

/obj/effect/decal/cobble/mossy
	name = "mossy brick floor"
	desc = "Dirt and moss have crept between the gaps of this stone-brick flooring. Rather fitting for an outdoor garden; not so much for a home."
	icon = 'icons/turf/roguefloor.dmi'
	icon_state = "mossystone_edges"
	mouse_opacity = 0



/turf/open/floor/rogue/concrete
	icon_state = "concretefloor1"
	name = "slab flooring"
	desc = "Solid stone slabs have been carefully carved and laid to rest with nary a hair's breadth between them."
	landsound = 'sound/foley/jumpland/stoneland.wav'
	footstep = FOOTSTEP_STONE
	barefootstep = FOOTSTEP_HARD_BAREFOOT
	clawfootstep = FOOTSTEP_HARD_CLAW
	heavyfootstep = FOOTSTEP_GENERIC_HEAVY
	smoothing_groups = SMOOTH_GROUP_FLOOR_STONE 


	prettifyturf = TRUE

/turf/open/floor/rogue/concrete/bronze
	color = "#ff9100"

/turf/open/floor/rogue/metal
	icon_state = "plating1"
	desc = "Covered in the tell-tale nicks of thousands of hammer-blows, this metal flooring clangs beneath your feet with every step."
	landsound = 'sound/foley/jumpland/metalland.wav'
	footstep = FOOTSTEP_PLATING
	barefootstep = FOOTSTEP_HARD_BAREFOOT
	clawfootstep = FOOTSTEP_HARD_CLAW
	heavyfootstep = FOOTSTEP_GENERIC_HEAVY
	footstepstealth = TRUE
	smoothing_groups = SMOOTH_GROUP_FLOOR_STONE 


	prettifyturf = TRUE

/turf/open/floor/rogue/metal/barograte
	icon_state = "barograte"
/turf/open/floor/rogue/metal/barograte/open
	icon_state = "barograteopen"



/turf/open/floor/rogue/shroud
	name = "treetop"
	icon_state = "treetop1"
	landsound = 'sound/foley/jumpland/dirtland.wav'
	footstep = null
	barefootstep = null
	clawfootstep = null
	heavyfootstep = null
	slowdown = 4
	prettifyturf = TRUE
/turf/open/floor/rogue/shroud/Entered(atom/movable/AM, atom/oldLoc)
	..()
	if(isliving(AM))
		if(istype(oldLoc, type))
			playsound(AM, "plantcross", 100, TRUE)

/turf/open/floor/rogue/shroud/Initialize()
	. = ..()
	icon_state = "treetop[rand(1,2)]"

/turf/open/floor/rogue/naturalstone
	name = "rough stone ground"
	desc = "Rough stone that's been exposed to the air either through erosion or the swing of a pickaxe. A few patchy lichens eke out a living between the cracks."
	icon_state = "digstone"
	footstep = FOOTSTEP_STONE
	barefootstep = FOOTSTEP_HARD_BAREFOOT
	clawfootstep = FOOTSTEP_HARD_CLAW
	heavyfootstep = FOOTSTEP_GENERIC_HEAVY
	landsound = 'sound/foley/jumpland/grassland.wav'

/turf/open/floor/rogue/naturalstone/aquifer
	name = "damp stone floor"
	desc = "Water trickles up steadily from cracks in the rock."

/turf/open/floor/rogue/naturalstone/aquifer/Initialize()
	. = ..()
	if(!cell)
		cell = new /cell(src)
		cell.InitLiquids()
	cell.make_liquid_source(2)
	SSliquid.update_fluidsum(src)
	SSliquid.cell_index[src] = TRUE

/obj/effect/decal/cobbleedge
	icon = 'icons/effects/effects.dmi'
	icon_state = "scanline"
