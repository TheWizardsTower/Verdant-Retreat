// ==============================================================================
// FIRE SPREAD SUBSYSTEM
// ==============================================================================
// The cellular-automaton fire simulation runs in verdant_native (RTFireEngine).
// This is native-only and will disable itself if the .dll is not present or fails to load.

SUBSYSTEM_DEF(fire)
	name = "Fire"
	priority = FIRE_PRIORITY_HOTSPOTS
	flags = SS_BACKGROUND
	wait = 1 SECONDS
	runlevels = RUNLEVEL_GAME | RUNLEVEL_POSTGAME

	var/fire_ready = FALSE
	var/list/vn_edit_queue = list()
	var/list/active_fire_turfs = list()
	var/list/hotspots = list()
	var/applying = FALSE
	var/last_rain = FALSE

	var/engine_inited = FALSE
	var/seed_z = 1
	var/seed_y = 1
	var/vn_init_warned = FALSE
	var/deltas_applied = 0
	var/burnouts_applied = 0

/datum/controller/subsystem/fire/stat_entry(msg)
	if(!fire_ready)
		msg += "seeding z=[seed_z] y=[seed_y]"
	else
		msg += "burning:[length(active_fire_turfs)]|hotspots:[length(hotspots)]|deltas:[deltas_applied]|burnt:[burnouts_applied]"
	return ..()

/datum/controller/subsystem/fire/fire(resumed)
	if(!VN_OK)
		if(!vn_init_warned)
			vn_init_warned = TRUE
			log_world("verdant_native: fire spread cannot run - native offload unavailable")
		can_fire = FALSE
		return
	if(!fire_ready)
		NativeInit()
		return
	NativeFire()

/datum/controller/subsystem/fire/proc/NativeInit()
	if(!SSnative?.mirror_loaded || !Master.init_complete)
		return FALSE
	if(!engine_inited)
		if(!vn_check_result(vn_fire_init(), "fire_init"))
			can_fire = FALSE
			return FALSE
		engine_inited = TRUE

	while(seed_z <= world.maxz)
		var/y0 = seed_y
		var/list/rows = list()
		while(seed_y <= world.maxy && length(rows) < 16)
			rows += BuildSeedRow(seed_y, seed_z)
			seed_y++
		if(!vn_check_result(vn_fire_load_rows(seed_z, y0, seed_y - 1, jointext(rows, "")), "fire_load_rows"))
			can_fire = FALSE
			return FALSE
		if(seed_y > world.maxy)
			seed_z++
			seed_y = 1
		if(MC_TICK_CHECK)
			return FALSE

	fire_ready = TRUE
	log_world("verdant_native: fire engine live ([world.maxx]x[world.maxy]x[world.maxz] seeded)")
	return TRUE

/datum/controller/subsystem/fire/proc/BuildSeedRow(y, z)
	var/list/row = list()
	for(var/x in 1 to world.maxx)
		var/turf/T = locate(x, y, z)
		var/fuel = 0
		var/spread = 0
		var/flags = 0
		if(T)
			fuel = clamp(T.burn_power, 0, 255)
			spread = clamp(T.spread_chance, 0, 15)
			if(T.outdoor_effect && !T.outdoor_effect.weatherproof)
				flags |= 1
		row += VN_NIBBLE(fuel >> 4)
		row += VN_NIBBLE(fuel & 15)
		row += VN_NIBBLE(spread)
		row += VN_NIBBLE(flags)
	return jointext(row, "")

/datum/controller/subsystem/fire/proc/NativeFire()
	var/raining = (SSParticleWeather?.runningWeather?.target_trait == PARTICLEWEATHER_RAIN)
	if(raining != last_rain)
		last_rain = raining
		vn_check_result(vn_fire_config("rain", raining ? 1 : 0), "fire_config_rain")

	var/list/res = vn_fire_tick_collect()
	if(!islist(res))
		vn_check_result(res, "fire_collect")
		return
	if(length(res))
		NativeApplyResults(res)

	if(length(vn_edit_queue))
		var/list/q = vn_edit_queue
		vn_edit_queue = list()
		vn_check_result(vn_fire_edit(q), "fire_edit_flush")

	vn_check_result(vn_fire_tick_begin(), "fire_begin")

	ExposeBurningTurfs()

/datum/controller/subsystem/fire/proc/NativeApplyResults(list/res)
	var/cur = 1
	var/n_delta = res[cur++]
	applying = TRUE
	for(var/i in 1 to n_delta)
		var/turf/T = locate(res[cur], res[cur + 1], res[cur + 2])
		var/level = res[cur + 3]
		cur += 4
		if(!T)
			continue
		ApplyLevel(T, level)
		deltas_applied++

	var/n_burnt = res[cur++]
	for(var/i in 1 to n_burnt)
		var/turf/T = locate(res[cur], res[cur + 1], res[cur + 2])
		cur += 3
		if(!T)
			continue
		T.burn_tile()
		burnouts_applied++
	applying = FALSE

/datum/controller/subsystem/fire/proc/ApplyLevel(turf/T, level)
	var/obj/effect/hotspot/H = GetEngineHotspot(T)
	if(level > 0)
		active_fire_turfs[T] = level
		if(!H)
			H = new /obj/effect/hotspot(T)
		H.change_firelevel(level)
	else
		active_fire_turfs -= T
		if(H)
			qdel(H)

/datum/controller/subsystem/fire/proc/GetEngineHotspot(turf/T)
	for(var/obj/effect/hotspot/H in T)
		if(H.engine_managed && !QDELETED(H))
			return H
	return null

/datum/controller/subsystem/fire/proc/ExposeBurningTurfs()
	for(var/turf/T as anything in active_fire_turfs)
		if(QDELETED(T))
			active_fire_turfs -= T
			continue
		var/level = active_fire_turfs[T]
		for(var/atom/movable/AM as anything in T)
			if(QDELETED(AM) || istype(AM, /obj/effect/hotspot))
				continue
			if(isliving(AM))
				var/mob/living/L = AM
				L.fire_act(1, 20)
			else if(isobj(AM))
				var/obj/O = AM
				O.fire_act((100 + T0C) * level)
