//Landmarks and other helpers which speed up the mapping process and reduce the number of unique instances/subtypes of items/turf/ect



/obj/effect/baseturf_helper //Set the baseturfs of every turf in the /area/ it is placed.
	name = "baseturf editor"
	icon = 'icons/effects/mapping_helpers.dmi'
	icon_state = ""

	var/list/baseturf_to_replace
	var/baseturf

	layer = POINT_LAYER

/obj/effect/baseturf_helper/Initialize()
	. = ..()
	return INITIALIZE_HINT_LATELOAD

/obj/effect/baseturf_helper/LateInitialize()
	if(!baseturf_to_replace)
		baseturf_to_replace = typecacheof(list(/turf/baseturf_bottom))
	else if(!length(baseturf_to_replace))
		baseturf_to_replace = list(baseturf_to_replace = TRUE)
	else if(baseturf_to_replace[baseturf_to_replace[1]] != TRUE) // It's not associative
		var/list/formatted = list()
		for(var/i in baseturf_to_replace)
			formatted[i] = TRUE
		baseturf_to_replace = formatted

	var/area/our_area = get_area(src)
	for(var/i in get_area_turfs(our_area, z))
		replace_baseturf(i)

	qdel(src)

/obj/effect/baseturf_helper/proc/replace_baseturf(turf/thing)
	var/list/baseturf_cache = thing.baseturfs
	if(length(baseturf_cache))
		for(var/i in baseturf_cache)
			if(baseturf_to_replace[i])
				baseturf_cache -= i
		if(!baseturf_cache.len)
			thing.assemble_baseturfs(baseturf)
		else
			thing.PlaceOnBottom(null, baseturf)
	else if(baseturf_to_replace[thing.baseturfs])
		thing.assemble_baseturfs(baseturf)
	else
		thing.PlaceOnBottom(null, baseturf)

/obj/effect/baseturf_helper/lava
	name = "lava baseturf editor"
	baseturf = /turf/open/lava/smooth

/obj/effect/baseturf_helper/lava_land/surface
	name = "lavaland baseturf editor"
	baseturf = /turf/open/lava/smooth/lava_land_surface


/obj/effect/mapping_helpers
	icon = 'icons/effects/mapping_helpers.dmi'
	icon_state = ""
	var/late = FALSE

/obj/effect/mapping_helpers/Initialize()
	..()
	return late ? INITIALIZE_HINT_LATELOAD : INITIALIZE_HINT_QDEL


//needs to do its thing before spawn_rivers() is called
INITIALIZE_IMMEDIATE(/obj/effect/mapping_helpers/no_lava)

/obj/effect/mapping_helpers/no_lava
	icon_state = "no_lava"

/obj/effect/mapping_helpers/no_lava/Initialize()
	. = ..()
	var/turf/T = get_turf(src)
	T.flags_1 |= NO_LAVA_GEN_1

//This helper applies components to things on the map directly.
/obj/effect/mapping_helpers/component_injector
	name = "Component Injector"
	late = TRUE
	var/target_type
	var/target_name
	var/component_type

//Late init so everything is likely ready and loaded (no warranty)
/obj/effect/mapping_helpers/component_injector/LateInitialize()
	if(!ispath(component_type,/datum/component))
		CRASH("Wrong component type in [type] - [component_type] is not a component")
	var/turf/T = get_turf(src)
	for(var/atom/A in T.GetAllContents())
		if(A == src)
			continue
		if(target_name && A.name != target_name)
			continue
		if(target_type && !istype(A,target_type))
			continue
		var/cargs = build_args()
		A._AddComponent(arglist(cargs))
		qdel(src)
		return

/obj/effect/mapping_helpers/component_injector/proc/build_args()
	return list(component_type)

/obj/effect/mapping_helpers/dead_body_placer
	name = "Dead Body placer"
	late = TRUE
	icon_state = "deadbodyplacer"
	var/bodycount = 2 //number of bodies to spawn

/obj/effect/mapping_helpers/dead_body_placer/LateInitialize()
	var/list/trays = list()
	if(!trays.len)
		log_mapping("[src] at [x],[y] could not find any morgues.")
		return
	for (var/i = 1 to bodycount)
		var/mob/living/carbon/human/h = new /mob/living/carbon/human(get_turf(src), 1)
		h.death()
		for (var/part in h.internal_organs) //randomly remove organs from each body, set those we keep to be in stasis
			if (prob(40))
				qdel(part)
			else
				var/obj/item/organ/O = part
				O.organ_flags |= ORGAN_FROZEN
	qdel(src)

//This is our map object, which just gets placed anywhere on the map. A .dm file is linked to it to set the templates list.
//If there's only one template in the list, it will only pick that (useful for editing parts of maps without editing the WHOLE map)
/obj/effect/landmark/map_load_mark
	name = "map loader landmark"
	var/list/templates //List of templates we're trying to pick from (must be a list, even if there's only one entry)

/obj/effect/landmark/map_load_mark/Initialize()
	. = ..()
	LAZYADD(SSmapping.map_load_marks,src)

/obj/effect/mapping_helpers/river_flow
	name = "river flow marker"
	icon_state = "field_dir"
	late = TRUE
	var/flow_rate = 1
	var/clear_flow = FALSE
	var/whole_body = TRUE

/obj/effect/mapping_helpers/river_flow/LateInitialize()
	var/turf/T = get_turf(src)
	var/turf/origin = T.resolve_flow_origin_turf()
	if(!origin)
		log_mapping("[src] at [x],[y],[z] is not over a river or basin turf.")
		qdel(src)
		return
	var/list/body = whole_body ? origin.flow_body_members() : list(origin)
	for(var/turf/member as anything in body)
		if(!member.cell)
			member.cell = new /cell(member)
			member.cell.InitLiquids()
		if(clear_flow)
			member.cell.clear_flow_dir()
			member.cell.flow_rate = 1
		else
			member.cell.set_flow_dir(dir)
			member.cell.flow_rate = flow_rate
	for(var/turf/member as anything in body)
		member.refresh_river_overlay()
		var/turf/surface = member.flow_body_surface()
		if(!surface || surface == member)
			continue
		surface.refresh_river_overlay()
		for(var/mob/living/L in surface)
			surface.try_start_river_current(L)
	for(var/mob/living/L in T)
		T.try_start_river_current(L)
	qdel(src)

/obj/effect/mapping_helpers/river_flow/slow
	name = "river flow marker (slow)"
	flow_rate = 0.5

/obj/effect/mapping_helpers/river_flow/fast
	name = "river flow marker (fast)"
	flow_rate = 2

/obj/effect/mapping_helpers/river_flow/stop
	name = "river flow stop marker"
	clear_flow = TRUE

/obj/effect/mapping_helpers/river_flow/tile
	name = "river flow marker (single tile)"
	whole_body = FALSE

/obj/effect/mapping_helpers/river_flow/tile/slow
	name = "river flow marker (single tile, slow)"
	flow_rate = 0.5

/obj/effect/mapping_helpers/river_flow/tile/fast
	name = "river flow marker (single tile, fast)"
	flow_rate = 2

/obj/effect/mapping_helpers/liquid_inlet
	name = "liquid inlet marker"
	icon_state = "field_dir"
	late = TRUE
	var/rate = 3
	var/fluid_type = WATER

/obj/effect/mapping_helpers/liquid_inlet/LateInitialize()
	var/turf/T = get_turf(src)
	if(!T.cell)
		T.cell = new /cell(T)
		T.cell.InitLiquids()
	T.cell.make_liquid_source(rate, fluid_type)
	T.refresh_river_overlay()
	qdel(src)

/obj/effect/mapping_helpers/liquid_inlet/trickle
	name = "liquid inlet marker (trickle)"
	rate = 1

/obj/effect/mapping_helpers/liquid_inlet/heavy
	name = "liquid inlet marker (heavy)"
	rate = 10

/obj/effect/mapping_helpers/liquid_outlet
	name = "liquid outlet marker"
	icon_state = "field_dir"
	late = TRUE
	var/rate = 3

/obj/effect/mapping_helpers/liquid_outlet/LateInitialize()
	var/turf/T = get_turf(src)
	if(!T.cell)
		T.cell = new /cell(T)
		T.cell.InitLiquids()
	T.cell.make_liquid_sink(rate)
	qdel(src)

/obj/effect/mapping_helpers/liquid_outlet/trickle
	name = "liquid outlet marker (trickle)"
	rate = 1

/obj/effect/mapping_helpers/liquid_outlet/heavy
	name = "liquid outlet marker (heavy)"
	rate = 10

/obj/effect/mapping_helpers/liquid_fill
	name = "liquid fill marker"
	icon_state = "field_dir"
	late = TRUE
	var/fluid_type = WATER
	var/amount = MAX_FLUID_VOLUME

/obj/effect/mapping_helpers/liquid_fill/LateInitialize()
	var/turf/T = get_turf(src)
	if(!istype(T, /turf/open))
		log_mapping("[src] at [x],[y],[z] is not over an open turf.")
		qdel(src)
		return
	if(!T.cell)
		T.cell = new /cell(T)
		T.cell.InitLiquids()
	var/datum/liquid/fluid = T.cell.get_fluid_datum(fluid_type)
	if(fluid)
		T.cell.fluid_volume[fluid] = clamp(amount, 0, MAX_FLUID_VOLUME)
		SSliquid.update_fluidsum(T)
		SSliquid.cell_index[T] = TRUE
		SSliquid.update_cell_image(T)
	qdel(src)

/obj/effect/mapping_helpers/liquid_fill/half
	name = "liquid fill marker (half)"
	amount = 50

/obj/effect/mapping_helpers/aquifer_mark
	name = "aquifer marker"
	icon_state = "field_dir"
	late = TRUE

/obj/effect/mapping_helpers/aquifer_mark/LateInitialize()
	var/turf/closed/mineral/M = get_turf(src)
	if(!istype(M) || M.mineralType)
		log_mapping("[src] at [x],[y],[z] is not over a barren mineral wall turf.")
		qdel(src)
		return
	M.ChangeTurf(/turf/closed/mineral/rogue/aquifer, null, CHANGETURF_IGNORE_AIR)
	qdel(src)
