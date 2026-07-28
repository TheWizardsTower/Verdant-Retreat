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
	var/static/vn_box_light = TRUE // Interior lava sources emit ADD_BOX events instead of running view().
	var/static/vn_box_sources // alist: VN_LIGHT_TURF_ID of source turf -> interior /datum/light_source, for opacity-change demotion.
	var/static/list/vn_box_zbounds = list() // "z" -> list(minx, miny, maxx, maxy) covering interior sources' boxes.
	var/static/vn_box_interior_count = 0

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

		vn_box_light = !world.GetConfig("env", "VN_NO_BOX_LIGHT")
		if(GLOB.vn_lighting_native && vn_box_light)
			vn_box_sources = alist()
			vn_classify_box_sources()
			log_world("SSlighting: [vn_box_interior_count] interior box light sources classified")

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

// A source is "interior" when every tile of its range box is lit-eligible with no
// occluder and no multiz descent contribution — view() over such a box returns
// exactly the box, so the source can skip view() and emit ADD_BOX. Classified
// once at init via a Chebyshev dilation of the disqualifier mask; lava only.
/datum/controller/subsystem/lighting/proc/vn_classify_box_sources()
	var/list/per_z = list()
	for(var/datum/light_source/L as anything in GLOB.all_light_sources)
		if(QDELETED(L) || !istype(L.source_atom, /turf/open/lava))
			continue
		if(CEILING(L.light_outer_range, 1) > 4)
			continue
		var/turf/T = L.source_atom
		var/list/zl = per_z["[T.z]"]
		if(!zl)
			zl = list()
			per_z["[T.z]"] = zl
		zl += L
	for(var/zk in per_z)
		vn_classify_box_z(text2num(zk), per_z[zk])

/datum/controller/subsystem/lighting/proc/vn_classify_box_z(z, list/sources)
	var/x0 = world.maxx
	var/y0 = world.maxy
	var/x1 = 1
	var/y1 = 1
	for(var/datum/light_source/L as anything in sources)
		var/turf/T = L.source_atom
		x0 = min(x0, T.x)
		y0 = min(y0, T.y)
		x1 = max(x1, T.x)
		y1 = max(y1, T.y)
	x0 = max(x0 - 4, 1)
	y0 = max(y0 - 4, 1)
	x1 = min(x1 + 4, world.maxx)
	y1 = min(y1 + 4, world.maxy)
	var/w = x1 - x0 + 1
	var/h = y1 - y0 + 1
	var/has_up = length(SSmapping.multiz_levels) && SSmapping.multiz_levels[z][Z_LEVEL_UP]
	var/list/disq = new /list(w * h)
	for(var/y in y0 to y1)
		var/base = (y - y0) * w - x0 + 1
		for(var/x in x0 to x1)
			var/turf/T = locate(x, y, z)
			var/bad = FALSE
			if(T.has_opaque_atom)
				bad = TRUE
			else if(istype(T, /turf/open/transparent))
				bad = TRUE
			else if(!T.dynamic_lighting && !T.light_sources)
				bad = TRUE
			else if(has_up)
				var/turf/A = get_step(T, UP)
				if(istype(A, /turf/open/transparent))
					bad = TRUE
			if(bad)
				disq[base + x] = 1
		CHECK_TICK
	var/list/hd = new /list(w * h)
	for(var/ry in 0 to h - 1)
		var/base = ry * w
		var/cnt = 0
		for(var/x in 1 to min(4, w))
			if(disq[base + x])
				cnt++
		for(var/x in 1 to w)
			var/enter = x + 4
			if(enter <= w && disq[base + enter])
				cnt++
			if(cnt)
				hd[base + x] = 1
			var/leave = x - 4
			if(leave >= 1 && disq[base + leave])
				cnt--
	var/list/vd = new /list(w * h)
	for(var/rx in 1 to w)
		var/cnt = 0
		for(var/ry in 0 to min(3, h - 1))
			if(hd[ry * w + rx])
				cnt++
		for(var/ry in 0 to h - 1)
			var/enter = ry + 4
			if(enter <= h - 1 && hd[enter * w + rx])
				cnt++
			if(cnt)
				vd[ry * w + rx] = 1
			var/leave = ry - 4
			if(leave >= 0 && hd[leave * w + rx])
				cnt--
	var/registered = 0
	for(var/datum/light_source/L as anything in sources)
		var/turf/T = L.source_atom
		if(vd[(T.y - y0) * w + (T.x - x0 + 1)])
			continue
		L.vn_box_interior = TRUE
		vn_box_sources[VN_LIGHT_TURF_ID(T)] = L
		registered++
	if(registered)
		vn_box_interior_count += registered
		var/list/b = vn_box_zbounds["[z]"]
		if(!b)
			vn_box_zbounds["[z]"] = list(x0, y0, x1, y1)
		else
			b[1] = min(b[1], x0)
			b[2] = min(b[2], y0)
			b[3] = max(b[3], x1)
			b[4] = max(b[4], y1)

// Any lighting reconsideration inside an interior region demotes nearby interior
// sources back to the view() path; conservative but rare (opacity changes on the
// lava z only).
/datum/controller/subsystem/lighting/proc/vn_box_demote_near(turf/T)
	if(!vn_box_interior_count)
		return
	var/list/b = vn_box_zbounds["[T.z]"]
	if(!b || T.x < b[1] || T.y < b[2] || T.x > b[3] || T.y > b[4])
		return
	var/x0 = max(T.x - 4, 1)
	var/y0 = max(T.y - 4, 1)
	var/x1 = min(T.x + 4, world.maxx)
	var/y1 = min(T.y + 4, world.maxy)
	var/zoff = (T.z - 1) * world.maxx * world.maxy
	for(var/y in y0 to y1)
		var/rowbase = zoff + (y - 1) * world.maxx - 1
		for(var/x in x0 to x1)
			var/datum/light_source/L = vn_box_sources[rowbase + x]
			if(!L)
				continue
			vn_box_sources[rowbase + x] = null
			vn_box_interior_count--
			if(QDELETED(L))
				continue
			L.vn_box_interior = FALSE
			L.force_update()

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
	while (i < length(queue))
		var/datum/light_source/L = queue[++i]

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
		queue.Cut(1, min(i, length(queue)) + 1)
		i = 0

	if(!init_tick_checks)
		MC_SPLIT_TICK

	queue = corners_queue
	while (i < length(queue))
		var/datum/lighting_corner/C = queue[++i]

		C.update_objects()
		C.needs_update = FALSE
		if(init_tick_checks)
			CHECK_TICK
		else if (MC_TICK_CHECK)
			break
	if (i)
		queue.Cut(1, min(i, length(queue)) + 1)
		i = 0


	if(!init_tick_checks)
		MC_SPLIT_TICK

	queue = objects_queue
	while (i < length(queue))
		var/atom/movable/lighting_object/O = queue[++i]

		if (QDELETED(O))
			continue

		O.update()
		O.needs_update = FALSE
		if(init_tick_checks)
			CHECK_TICK
		else if (MC_TICK_CHECK)
			break
	if (i)
		queue.Cut(1, min(i, length(queue)) + 1)

	if (light_native)
		vn_light_try_flush()


/datum/controller/subsystem/lighting/Recover()
	initialized = SSlighting.initialized
	..()
