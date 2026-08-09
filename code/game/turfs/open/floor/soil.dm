
/turf/open/floor/rogue/dirt
	name = "dirt"
	desc = "The dirt is pocked with the scars of countless wars."
	icon_state = "dirt"
	layer = MID_TURF_LAYER
	footstep = FOOTSTEP_SAND
	barefootstep = FOOTSTEP_SOFT_BAREFOOT
	heavyfootstep = FOOTSTEP_GENERIC_HEAVY
	landsound = 'sound/foley/jumpland/dirtland.wav'
	slowdown = 1
	liquid_absorption = 2
	smoothing_groups = SMOOTH_GROUP_FLOOR_DIRT
	neighborlay = "dirtedge"
	var/muddy = FALSE
	var/bloodiness = 20
	var/obj/structure/closet/dirthole/holie
	var/dirt_amt = 3
	prettifyturf = TRUE

/turf/open/floor/rogue/dirt/Initialize()
	. = ..()
	AddComponent(/datum/component/fertility)

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

/turf/open/floor/rogue/dirt/mud
	icon_state = "mud1"
	name = "mud"
	slowdown = 2
	footstep = FOOTSTEP_MUD
	barefootstep = FOOTSTEP_MUD
	heavyfootstep = FOOTSTEP_MUD
	prettifyturf = TRUE
	slowdown = 2
/turf/open/floor/rogue/dirt/mud/Initialize()
	. = ..()
	icon_state = "mud[rand (1,3)]"



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
