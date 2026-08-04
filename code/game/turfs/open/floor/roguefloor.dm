/turf/open/floor/rogue
	smoothing_groups = SMOOTH_GROUP_OPEN
	var/prettifyturf = TRUE
	icon = 'icons/turf/roguefloor.dmi'
	baseturfs = list(/turf/open/transparent/openspace)
	neighborlay = null

/turf/open/floor/rogue/break_tile()
	return //unbreakable

/turf/open/floor/rogue/burn_tile()
	return //unburnable

/turf/open/floor/rogue/Initialize()
	if(prettifyturf)
		dir = pick(GLOB.cardinals)
	. = ..()

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
/turf/open/floor/rogue/AzureSand
	name = "sand"
	desc = "Warm sand that, sadly, have been mixed with dirt."
	icon_state = "grimshart"
	layer = MID_TURF_LAYER
	footstep = FOOTSTEP_SAND
	barefootstep = FOOTSTEP_SOFT_BAREFOOT
	heavyfootstep = FOOTSTEP_GENERIC_HEAVY
	landsound = 'sound/foley/jumpland/grassland.wav'
	slowdown = 0
	smoothing_groups = SMOOTH_GROUP_FLOOR_DIRT
	neighborlay = "grimshartedge"
	prettifyturf = TRUE


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

/turf/open/floor/rogue/grass
	name = "green grass"
	desc = "Grass, sodden with mud and bogwater."

	icon_state = "grass-green"
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

/turf/open/floor/rogue/dirt/ambush
	name = "dirt"
	desc = "The dirt is pocked with the scars of countless wars."
	icon_state = "dirt"
	footstep = FOOTSTEP_GRASS
	barefootstep = FOOTSTEP_SOFT_BAREFOOT
	heavyfootstep = FOOTSTEP_GENERIC_HEAVY
	landsound = 'sound/foley/jumpland/dirtland.wav'
	slowdown = 2
	neighborlay = "dirtedge"
	muddy = FALSE
	bloodiness = 20
	dirt_amt = 3
	spread_chance = 8

/turf/open/floor/rogue/dirt
	name = "dirt"
	desc = "The dirt is pocked with the scars of countless wars."
	icon_state = "dirt"
	layer = MID_TURF_LAYER
	footstep = FOOTSTEP_MUD
	barefootstep = FOOTSTEP_SOFT_BAREFOOT
	heavyfootstep = FOOTSTEP_GENERIC_HEAVY
	landsound = 'sound/foley/jumpland/dirtland.wav'
	slowdown = 2
	liquid_absorption = 2
	smoothing_groups = SMOOTH_GROUP_FLOOR_DIRT
	neighborlay = "dirtedge"
	var/muddy = FALSE
	var/bloodiness = 20
	var/obj/structure/closet/dirthole/holie
	var/dirt_amt = 3
	prettifyturf = TRUE
/turf/open/floor/rogue/dirt/get_slowdown(mob/user)
	. = ..()
	var/negate_slowdown = FALSE

	for(var/obj/item/stick in user.held_items)
		if(stick.walking_stick && !stick.wielded && !user.cmode)
			negate_slowdown = TRUE
			break

	if(HAS_TRAIT(user, TRAIT_LONGSTRIDER))
		negate_slowdown = TRUE

	if(negate_slowdown)
		. -= 2
	return max(., 0)


/turf/open/floor/rogue/dirt/attack_right(mob/user)
	if(isliving(user))
		var/mob/living/L = user
		if(L.stat != CONSCIOUS)
			return
		var/obj/item/I = new /obj/item/natural/dirtclod(src)
		if(L.put_in_active_hand(I))
			L.visible_message(span_warning("[L] picks up some dirt."))
			dirt_amt--
			if(dirt_amt <= 0)
				src.ChangeTurf(/turf/open/floor/rogue/dirt/road, flags = CHANGETURF_INHERIT_AIR)
		else
			qdel(I)
	.=..()

/turf/open/floor/rogue/dirt/Destroy()
	if(holie)
		QDEL_NULL(holie)
	return ..()


/turf/open/floor/rogue/dirt/Crossed(atom/movable/O)
	..()
	if(ishuman(O))
		var/mob/living/carbon/human/H = O
		if(H.shoes && !HAS_TRAIT(H, TRAIT_LIGHT_STEP))
			var/obj/item/clothing/shoes/S = H.shoes
			if(!S.can_be_bloody)
				return
			var/add_blood = 0
			if(bloodiness >= BLOOD_GAIN_PER_STEP)
				add_blood = BLOOD_GAIN_PER_STEP
			else
				add_blood = bloodiness
			S.bloody_shoes[BLOOD_STATE_MUD] = min(MAX_SHOE_BLOODINESS,S.bloody_shoes[BLOOD_STATE_MUD]+add_blood)
			S.blood_state = BLOOD_STATE_MUD
			update_icon()
			H.update_inv_shoes()
		if(water_level)
			SSliquid.pool_manager.queue_wet_update(src)


/turf/open/floor/rogue/dirt/update_water()
	water_level = max(water_level-10,0)
	if(water_level > 10) //this would be a switch on normal tiles
		color = "#95776a"
	else
		color = null
	return TRUE

/turf/open/floor/rogue/dirt/road/update_water()
	water_level = max(water_level-10,0)
	for(var/D in GLOB.cardinals)
		var/turf/TU = get_step(src, D)
		if(istype(TU, /turf/open/water))
			if(!muddy)
				become_muddy()
			return TRUE //stop processing
	if(water_level > 10) //this would be a switch on normal tiles
		if(!muddy)
			become_muddy()
//flood process goes here to spread to other turfs etc
//	if(water_level > 250)
//		return FALSE
	if(muddy)
		if(water_level <= 0)
			water_level = 0
			muddy = FALSE
			slowdown = initial(slowdown)
			icon_state = initial(icon_state)
			name = initial(name)
			footstep = initial(footstep)
			barefootstep = initial(barefootstep)
			clawfootstep = initial(clawfootstep)
			heavyfootstep = initial(heavyfootstep)
			track_prob = initial(track_prob) //Hearthstone port.
	return TRUE

/turf/open/floor/rogue/dirt/proc/become_muddy()
	if(!muddy)
		water_level = max(water_level-100,0)
		muddy = TRUE
		icon_state = "mud[rand (1,3)]"
		name = "mud"
		slowdown = 2
		footstep = FOOTSTEP_MUD
		barefootstep = FOOTSTEP_MUD
		heavyfootstep = FOOTSTEP_MUD
		track_prob = 20 //Hearthstone port.
		bloodiness = 20

/turf/open/floor/rogue/dirt/road
	name = "dirt"
	desc = "The dirt is pocked with the scars of countless steps."
	icon_state = "road"
	layer = MID_TURF_LAYER
	footstep = FOOTSTEP_SAND
	barefootstep = FOOTSTEP_SOFT_BAREFOOT
	heavyfootstep = FOOTSTEP_GENERIC_HEAVY
	landsound = 'sound/foley/jumpland/dirtland.wav'
	smoothing_groups = SMOOTH_GROUP_FLOOR_DIRT_ROAD 
	neighborlay = "roadedge"
	slowdown = 0

/turf/open/floor/rogue/dirt/road/attack_right(mob/user)
	return

/turf/open/floor/rogue/sand
	name = "sand"
	desc = "Fine grains shift and hiss softly beneath your step."
	icon = 'icons/turf/sand.dmi'
	icon_state = "sand"
	layer = MID_TURF_LAYER
	footstep = FOOTSTEP_SAND
	barefootstep = FOOTSTEP_SAND
	clawfootstep = FOOTSTEP_SAND
	heavyfootstep = FOOTSTEP_SAND
	landsound = 'sound/foley/jumpland/dirtland.wav'
	baseturfs = /turf/open/floor/rogue/sand
	slowdown = 0
	liquid_absorption = 3

/turf/open/floor/rogue/sand/Initialize(mapload)
	. = ..()
	if(prob(15))
		icon_state = "sand[rand(1,4)]"

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

/turf/proc/roguesmooth(adjacencies, use_old_behavior)
/*	if(!use_old_behavior)
		adjacencies = null
		var/turf/neighbortest //completely discard the existing adjacencies, they were calculated incorrectly. 
		for (var/testing_dir in list(NORTH, SOUTH, EAST, WEST, NORTHEAST, NORTHWEST, SOUTHEAST, SOUTHWEST))
			neighbortest = get_step(src, testing_dir)
			if(neighbortest ==null)
				continue
			if(istype(neighbortest, /turf/open/transparent/openspace))
				continue
			if(neighbortest.layer >= src.layer)
				continue
			if(neighbortest.type == src)//TODO: make this take a typecache..
				continue
			if(iswallturf(neighbortest))
				continue
			adjacencies |= dir2neighbor(testing_dir)

	var/list/New
	var/holder

	for(var/A in neighborlay_list)
		cut_overlay("[A]")
		neighborlay_list -= A
	var/usedturf
	if(adjacencies & N_NORTH)
		usedturf = get_step(src, NORTH)
		if(isturf(usedturf))
			var/turf/T = usedturf
			if(neighborlay_override)
				holder = "[neighborlay_override]-n"
				LAZYADD(New, holder)
				neighborlay_list += holder
			else if(T.neighborlay)
				holder = "[T.neighborlay]-n"
				LAZYADD(New, holder)
				neighborlay_list += holder
	if(adjacencies & N_SOUTH)
		usedturf = get_step(src, SOUTH)
		if(isturf(usedturf))
			var/turf/T = usedturf
			if(neighborlay_override)
				holder = "[neighborlay_override]-s"
				LAZYADD(New, holder)
				neighborlay_list += holder
			else if(T.neighborlay)
				holder = "[T.neighborlay]-s"
				LAZYADD(New, holder)
				neighborlay_list += holder
	if(adjacencies & N_WEST)
		usedturf = get_step(src, WEST)
		if(isturf(usedturf))
			var/turf/T = usedturf
			if(neighborlay_override)
				holder = "[neighborlay_override]-w"
				LAZYADD(New, holder)
				neighborlay_list += holder
			else if(T.neighborlay)
				holder = "[T.neighborlay]-w"
				LAZYADD(New, holder)
				neighborlay_list += holder
	if(adjacencies & N_EAST)
		usedturf = get_step(src, EAST)
		if(isturf(usedturf))
			var/turf/T = usedturf
			if(neighborlay_override)
				holder = "[neighborlay_override]-e"
				LAZYADD(New, holder)
				neighborlay_list += holder
			else if(T.neighborlay)
				holder = "[T.neighborlay]-e"
				LAZYADD(New, holder)
				neighborlay_list += holder

	if(smooth & SMOOTH_DIAGONAL)
		if(adjacencies & N_NORTHEAST)
			usedturf = get_step(src, NORTHEAST)
			if(isturf(usedturf))
				var/turf/T = usedturf
				if(neighborlay_override)
					holder = "[neighborlay_override]-ne"
					LAZYADD(New, holder)
					neighborlay_list += holder
				else if(T.neighborlay)
					holder = "[T.neighborlay]-ne"
					LAZYADD(New, holder)
					neighborlay_list += holder
		if(adjacencies & N_NORTHWEST)
			usedturf = get_step(src, NORTHWEST)
			if(isturf(usedturf))
				var/turf/T = usedturf
				if(neighborlay_override)
					holder = "[neighborlay_override]-nw"
					LAZYADD(New, holder)
					neighborlay_list += holder
				else if(T.neighborlay)
					holder = "[T.neighborlay]-nw"
					LAZYADD(New, holder)
					neighborlay_list += holder
		if(adjacencies & N_SOUTHEAST)
			usedturf = get_step(src, SOUTHEAST)
			if(isturf(usedturf))
				var/turf/T = usedturf
				if(neighborlay_override)
					holder = "[neighborlay_override]-se"
					LAZYADD(New, holder)
					neighborlay_list += holder
				else if(T.neighborlay)
					holder = "[T.neighborlay]-se"
					LAZYADD(New, holder)
					neighborlay_list += holder
		if(adjacencies & N_SOUTHWEST)
			usedturf = get_step(src, SOUTHWEST)
			if(isturf(usedturf))
				var/turf/T = usedturf
				if(neighborlay_override)
					holder = "[neighborlay_override]-sw"
					LAZYADD(New, holder)
					neighborlay_list += holder
				else if(T.neighborlay)
					holder = "[T.neighborlay]-sw"
					LAZYADD(New, holder)
					neighborlay_list += holder

 

	if(New)
		add_overlay(New)
	return New
*/
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

//Church floors

/turf/open/floor/rogue/churchmarble
	icon_state = "church_marble"
	name = "marble flooring"
	desc = "Polished marble tiling clacks softly with every footstep. A prized material for vaunted halls."
	footstep = FOOTSTEP_TILE
	barefootstep = FOOTSTEP_HARD_BAREFOOT
	clawfootstep = FOOTSTEP_HARD_CLAW
	heavyfootstep = FOOTSTEP_GENERIC_HEAVY
	landsound = 'sound/foley/jumpland/stoneland.wav'
	smoothing_groups = SMOOTH_GROUP_FLOOR_STONE 

	prettifyturf = TRUE

/turf/open/floor/rogue/church
	icon_state = "church"
	name = "polished tile floor"
	desc = "Glazed tiling that has withstood the decades with barely a scratch despite the steady accumulation of dirt and grime."
	footstep = FOOTSTEP_TILE
	barefootstep = FOOTSTEP_HARD_BAREFOOT
	clawfootstep = FOOTSTEP_HARD_CLAW
	heavyfootstep = FOOTSTEP_GENERIC_HEAVY
	landsound = 'sound/foley/jumpland/stoneland.wav'
	smoothing_groups = SMOOTH_GROUP_FLOOR_STONE 

	prettifyturf = TRUE

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




/obj/effect/decal/cobbleedge
	name = "old cobble path"
	desc = "Erosion and time have worn this path to half-scattered rocks slowly sinking back into the earth."
	icon = 'icons/turf/roguefloor.dmi'
	icon_state = "cobblestone_edges"
	mouse_opacity = 0

/obj/effect/decal/carpet
	name = "exotic rug"
	desc = "Dazzling symmetrical patterns flow with an old culture's style."
	pixel_w = -16
	pixel_z = -17
	icon = 'icons/roguetown/misc/64x64.dmi'
	icon_state = "kover"

/obj/effect/decal/carpet/kover_darkred
	name = "exotic red rug"
	desc = "Dazzling symmetrical patterns flow with an old culture's style."
	icon = 'icons/roguetown/misc/64x64.dmi'
	icon_state = "kover_darkred"

/obj/effect/decal/carpet/kover_purple
	name = "exotic purple rug"
	desc = "Dazzling symmetrical patterns flow with an old culture's style."
	icon = 'icons/roguetown/misc/64x64.dmi'
	icon_state = "kover_purple"

/obj/effect/decal/carpet/kover_black
	name = "exotic black carpet"
	desc = "Dazzling symmetrical patterns flow with an old culture's style."
	icon = 'icons/roguetown/misc/64x64.dmi'
	icon_state = "kover_black"

/obj/effect/decal/carpet/square
	name = "green carpet"
	desc = "Soft green carpeting that reminds you of grassy meadows."
	pixel_w = -16
	pixel_z = -16
	icon = 'icons/roguetown/misc/64x64.dmi'
	icon_state = "greencarpet"

/obj/effect/decal/carpet/square/black
	name = "black carpet"
	desc = "As black as the night sky during a storm."
	icon = 'icons/roguetown/misc/64x64.dmi'
	icon_state = "blackcarpet"

/turf/open/floor/rogue/tile
	icon_state = "chess"
	desc = "Feet march across a grid of plots and schemes."
	landsound = 'sound/foley/jumpland/tileland.wav'
	footstep = FOOTSTEP_TILE
	barefootstep = FOOTSTEP_HARD_BAREFOOT
	clawfootstep = FOOTSTEP_HARD_CLAW
	heavyfootstep = FOOTSTEP_GENERIC_HEAVY
	footstepstealth = TRUE
	smoothing_groups = SMOOTH_GROUP_FLOOR_STONE 


/turf/open/floor/rogue/tile/masonic
	icon_state = "masonic"
/turf/open/floor/rogue/tile/masonic/single
	icon_state = "masonicsingle"
/turf/open/floor/rogue/tile/masonic/inverted
	icon_state = "masonicsingleinvert"
/turf/open/floor/rogue/tile/masonic/spiral
	icon_state = "masonicspiral"

/turf/open/floor/rogue/tile/bath
	name = "bath tiles"
	desc = "A special waterproof flooring suited for baths and pools. Slippery when wet."
	icon_state = "bathtile"
/turf/open/floor/rogue/tile/chess
	icon_state = "stone-checker"
/turf/open/floor/rogue/tile/brick
	icon_state = "bricktile"

/turf/open/floor/rogue/tile/bfloorz
	icon_state = "bfloorz"

/turf/open/floor/rogue/tile/tilerg
	icon_state = "tilerg"

/turf/open/floor/rogue/tile/checker
	icon_state = "linoleum"

/turf/open/floor/rogue/tile/checkeralt
	icon_state = "tile"

/turf/open/floor/rogue/tile/brownbrick
	icon_state = "brown"

/turf/open/floor/rogue/tile/harem
	icon = 'icons/turf/roguefloor.dmi'
	icon_state = "harem"

/turf/open/floor/rogue/tile/harem1
	icon = 'icons/turf/roguefloor.dmi'
	icon_state = "harem1"

/turf/open/floor/rogue/tile/harem2
	icon = 'icons/turf/roguefloor.dmi'
	icon_state = "harem2"

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

/turf/open/floor/rogue/carpet
	icon_state = "carpet"
	desc = "Plush fabric softens your step. Did you remember to wipe your shoes?"
	landsound = 'sound/foley/jumpland/carpetland.wav'
	footstep = FOOTSTEP_CARPET
	barefootstep = FOOTSTEP_SOFT_BAREFOOT
	clawfootstep = FOOTSTEP_SOFT_BAREFOOT
	heavyfootstep = FOOTSTEP_GENERIC_HEAVY
	smoothing_groups = SMOOTH_GROUP_FLOOR_CARPET

/turf/open/floor/rogue/carpet/lord
	icon_state = ""

/turf/open/floor/rogue/carpet/lord/Initialize()
	. = ..()
	if(GLOB.lordprimary)
		lordcolor(GLOB.lordprimary,GLOB.lordsecondary)
	GLOB.lordcolor += src

/turf/open/floor/rogue/carpet/lord/Destroy()
	GLOB.lordcolor -= src
	return ..()

/turf/open/floor/rogue/carpet/lord/lordcolor(primary,secondary)
	if(!primary || !secondary)
		return
	var/mutable_appearance/M = mutable_appearance(icon, "[icon_state]_primary", -(layer+0.1))
	M.color = primary
	add_overlay(M)

/turf/open/floor/rogue/carpet/lord/center
	icon_state = "carpet_c"


/turf/open/floor/rogue/carpet/lord/left
	icon_state = "carpet_l"

/turf/open/floor/rogue/carpet/lord/right
	icon_state = "carpet_r"

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
