SUBSYSTEM_DEF(lighting)
	name = "Lighting"
	wait = 0
	init_order = INIT_ORDER_LIGHTING
	flags = SS_TICKER
	priority = FIRE_PRIORITY_DEFAULT
	var/static/list/sources_queue = list() // List of lighting sources queued for update.
	var/static/list/corners_queue = list() // List of lighting corners queued for update.
	var/static/list/objects_queue = list() // List of lighting objects queued for update.
	processing_flag = PROCESSING_LIGHTING

	var/static/vn_next_light_id = 0 // Counter for /datum/light_source.vn_light_id.
	var/static/list/vn_light_events = list() // Flat ADD/REPLACE/REMOVE event buffer, flushed to vn_light_tick_begin() each fire().
	var/static/vn_light_init_chunk_size = 2048 // Sources per native chunk during the init fire.
	var/static/vn_light_chunk_in_flight = FALSE // TRUE between a successful tick_begin and its collect; the light job is exclusive.
	var/static/list/all_corners = list() // Every /datum/lighting_corner (immortal, append-only); GLOB.vn_light_corners is an alist and cannot be iterated.

/datum/controller/subsystem/lighting/stat_entry()
	..("L:[length(sources_queue)]|C:[length(corners_queue)]|O:[length(objects_queue)]")


/datum/controller/subsystem/lighting/Initialize(timeofday)
	if(!initialized)
		if (CONFIG_GET(flag/starlight))
			for(var/I in GLOB.sortedAreas)
				var/area/A = I
				if (A.dynamic_lighting == DYNAMIC_LIGHTING_IFSTARLIGHT)
					A.luminosity = 0

		if(VN_OK && !GLOB.vn_lighting_native)
			if(vn_check_result(vn_light_init(world.maxx, world.maxy, world.maxz), "light_init"))
				GLOB.vn_light_inited_maxz = world.maxz
				if(!world.GetConfig("env", "VN_NO_NATIVE_LIGHT"))
					GLOB.vn_lighting_native = TRUE
					log_world("SSlighting: native corner lighting enabled for init")

		create_all_lighting_objects()
		initialized = TRUE

	fire(FALSE, TRUE)
	while(length(sources_queue) || length(corners_queue) || length(objects_queue) || length(vn_light_events) || vn_light_chunk_in_flight)
		if(vn_light_chunk_in_flight && !length(sources_queue) && !length(corners_queue) && !length(objects_queue) && !length(vn_light_events))
			stoplag()
		fire(FALSE, TRUE)

	return ..()

// Full rebuild: native contributions live only in corner accumulators and native's
// private per-source memory, so leaving native mode zeroes every corner and
// re-applies every source through the DM path from scratch.
/datum/controller/subsystem/lighting/proc/vn_light_disable_native()
	GLOB.vn_lighting_native = FALSE
	vn_light_events = list()
	vn_light_chunk_in_flight = FALSE
	if (VN_OK)
		vn_light_reset()
	for (var/datum/lighting_corner/C as anything in all_corners)
		if (C.lum_r || C.lum_g || C.lum_b)
			C.update_lumcount(-C.lum_r, -C.lum_g, -C.lum_b)
	for (var/datum/light_source/L as anything in GLOB.all_light_sources)
		if (L.effect_str)
			for (var/datum/lighting_corner/C as anything in L.effect_str)
				LAZYREMOVE(C.affecting, L)
			L.effect_str = null
		L.vn_native_applied = FALSE
		L.force_update()

/datum/controller/subsystem/lighting/proc/apply_light_collect(list/res)
	var/cur = 1
	var/n = res[cur++]
	for (var/i in 1 to n)
		var/id = res[cur++]
		var/dr = res[cur++]
		var/dg = res[cur++]
		var/db = res[cur++]
		var/datum/lighting_corner/C = GLOB.vn_light_corners[id]
		if (!C)
			C = vn_corner_backfill(id)
		if (C)
			C.update_lumcount(dr, dg, db)

// ADD_TURFS results can reference corners no DM code has materialized yet;
// decode the id and generate them on the first eligible master turf.
/datum/controller/subsystem/lighting/proc/vn_corner_backfill(id)
	var/w2 = 2 * world.maxx + 1
	var/per_z = w2 * (2 * world.maxy + 1)
	var/z = round(id / per_z) + 1
	var/rem = id % per_z
	var/cy2 = round(rem / w2) + 1
	var/cx2 = (rem % w2) + 1
	for(var/tx in list((cx2 - 1) * 0.5, (cx2 + 1) * 0.5))
		if(tx < 1 || tx > world.maxx)
			continue
		for(var/ty in list((cy2 - 1) * 0.5, (cy2 + 1) * 0.5))
			if(ty < 1 || ty > world.maxy)
				continue
			var/turf/T = locate(tx, ty, z)
			if(!T)
				continue
			T.generate_missing_corners()
			var/datum/lighting_corner/C = GLOB.vn_light_corners[id]
			if(C)
				return C
	return null

/datum/controller/subsystem/lighting/proc/vn_light_try_collect()
	if(!vn_light_chunk_in_flight)
		return
	var/res = vn_light_tick_collect()
	if(islist(res))
		if(length(res))
			apply_light_collect(res)
			vn_light_chunk_in_flight = FALSE
	else if(!vn_check_result(res, "light_tick_collect"))
		vn_light_disable_native()

/datum/controller/subsystem/lighting/proc/vn_light_try_flush()
	if(!length(vn_light_events))
		return
	if(vn_light_chunk_in_flight)
		return
	var/res = vn_light_tick_begin(vn_light_events)
	if(res == "busy" || (istext(res) && findtext(res, "ERR:queue:") == 1))
		return
	if(vn_check_result(res, "light_tick_begin"))
		vn_light_events = list()
		vn_light_chunk_in_flight = TRUE
	else
		vn_light_disable_native()

// Init-only: block until the in-flight chunk lands, apply it, then begin the
// buffered one. Sleeping is legal here (Initialize context, not the MC loop).
/datum/controller/subsystem/lighting/proc/vn_light_pump_chunk()
	while(vn_light_chunk_in_flight)
		var/res = vn_light_tick_collect()
		if(islist(res))
			if(length(res))
				apply_light_collect(res)
				vn_light_chunk_in_flight = FALSE
				break
			stoplag()
		else if(!vn_check_result(res, "light_tick_collect"))
			vn_light_disable_native()
			return
	vn_light_try_flush()

/datum/controller/subsystem/lighting/fire(resumed, init_tick_checks)
	MC_SPLIT_TICK_INIT(3)
	if(!init_tick_checks)
		MC_SPLIT_TICK

	var/light_native = VN_OK && GLOB.vn_lighting_native
	if (light_native)
		vn_light_try_collect()
		light_native = VN_OK && GLOB.vn_lighting_native

	var/list/queue = sources_queue
	var/i = 0
	var/chunk_ctr = 0
	for (i in 1 to length(queue))
		var/datum/light_source/L = queue[i]

		L.update_corners()

		L.needs_update = LIGHTING_NO_UPDATE

		if(init_tick_checks)
			CHECK_TICK
			if(light_native && ++chunk_ctr >= vn_light_init_chunk_size)
				chunk_ctr = 0
				vn_light_pump_chunk()
				light_native = VN_OK && GLOB.vn_lighting_native
		else if (MC_TICK_CHECK)
			break
	if (i)
		queue.Cut(1, i+1)
		i = 0

	if(!init_tick_checks)
		MC_SPLIT_TICK

	queue = corners_queue
	for (i in 1 to length(queue))
		var/datum/lighting_corner/C = queue[i]

		C.update_objects()
		C.needs_update = FALSE
		if(init_tick_checks)
			CHECK_TICK
		else if (MC_TICK_CHECK)
			break
	if (i)
		queue.Cut(1, i+1)
		i = 0


	if(!init_tick_checks)
		MC_SPLIT_TICK

	queue = objects_queue
	for (i in 1 to length(queue))
		var/atom/movable/lighting_object/O = queue[i]

		if (QDELETED(O))
			continue

		O.update()
		O.needs_update = FALSE
		if(init_tick_checks)
			CHECK_TICK
		else if (MC_TICK_CHECK)
			break
	if (i)
		queue.Cut(1, i+1)

	if (light_native)
		vn_light_try_flush()


/datum/controller/subsystem/lighting/Recover()
	initialized = SSlighting.initialized
	..()
