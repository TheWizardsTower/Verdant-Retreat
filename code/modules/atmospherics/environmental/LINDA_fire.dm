

/atom/proc/temperature_expose(exposed_temperature, exposed_volume)
	return null



/turf/proc/hotspot_expose(added, maxstacks, soh = 0)
	if(prob(10))
		vn_fire_queue(VN_FIRE_OP_IGNITE, src, 1)

/obj/effect/hotspot
	anchored = TRUE
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	icon = 'icons/effects/fire.dmi'
	icon_state = "1"
	layer = GASFIRE_LAYER
	light_outer_range =  LIGHT_RANGE_FIRE
	light_color = LIGHT_COLOR_FIRE
	blend_mode = BLEND_ADD

	var/volume = 125
	var/temperature = 100+T0C
	var/firelevel = 1
	var/engine_managed = TRUE

/obj/effect/hotspot/Initialize(mapload, starting_volume, starting_temperature)
	. = ..()
	SSfire.hotspots += src
	if(!isnull(starting_volume))
		volume = starting_volume
	if(!isnull(starting_temperature))
		temperature = starting_temperature
	setDir(pick(GLOB.cardinals))
	air_update_turf()
	var/turf/open/location = loc
	if(istype(location))
		location.active_hotspot = src
	if(engine_managed && !SSfire.applying)
		vn_fire_queue(VN_FIRE_OP_IGNITE, loc, firelevel)
		addtimer(CALLBACK(src, PROC_REF(expire_unadopted)), 10 SECONDS)

/obj/effect/hotspot/proc/expire_unadopted()
	if(!QDELETED(src) && !SSfire.active_fire_turfs[get_turf(src)])
		qdel(src)

/obj/effect/hotspot/Destroy()
	set_light(0)
	SSfire.hotspots -= src
	var/turf/open/T = loc
	if(istype(T) && T.active_hotspot == src)
		T.active_hotspot = null
	if(engine_managed && !SSfire.applying)
		vn_fire_queue(VN_FIRE_OP_EXTINGUISH, loc)
	return ..()

/obj/effect/hotspot/Crossed(atom/movable/AM, oldLoc)
	..()
	if(isliving(AM))
		var/mob/living/L = AM
		L.fire_act(1, 20)

/obj/effect/dummy/lighting_obj/moblight/fire
	name = "fire"
	light_color = LIGHT_COLOR_FIRE
	light_outer_range =  LIGHT_RANGE_FIRE

/obj/effect/hotspot/proc/change_firelevel(level = 1)
	firelevel = level
	icon_state = "[firelevel]"

/// For use with demonic T5 ability
/obj/effect/hotspot/vampiric
	firelevel = 3
	color = COLOR_LIME
	light_color = COLOR_LIME
	engine_managed = FALSE
	var/datum/clan/owner_clan

/obj/effect/hotspot/vampiric/Initialize(mapload, starting_volume, starting_temperature, datum/clan/owner_clan)
	if(!istype(owner_clan))
		return INITIALIZE_HINT_QDEL
	src.owner_clan = owner_clan
	. = ..()
	QDEL_IN(src, 3 SECONDS)

/obj/effect/hotspot/vampiric/Destroy()
	owner_clan = null
	return ..()

/obj/effect/hotspot/vampiric/Crossed(atom/movable/AM, oldLoc)
	var/mob/living/carbon/human/target = AM
	if(istype(target) && target.clan == owner_clan)
		return
	return ..()
