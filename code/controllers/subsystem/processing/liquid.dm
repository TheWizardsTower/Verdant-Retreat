/*
 ██▓     ██▓  █████   █    ██  ██▓▓█████▄   ██████
▓██▒    ▓██▒▒██▓  ██▒ ██  ▓██▒▓██▒▒██▀ ██▌▒██    ▒
▒██░    ▒██▒▒██▒  ██░▓██  ▒██░▒██▒░██   █▌░ ▓██▄
▒██░    ░██░░██  █▀ ░▓▓█  ░██░░██░░▓█▄   ▌  ▒   ██▒
░██████▒░██░░▒███▒█▄ ▒▒█████▓ ░██░░▒████▓ ▒██████▒▒
░ ▒░▓  ░░▓  ░░ ▒▒░ ▒ ░▒▓▒ ▒ ▒ ░▓   ▒▒▓  ▒ ▒ ▒▓▒ ▒ ░
░ ░ ▒  ░ ▒ ░ ░ ▒░  ░ ░░▒░ ░ ░  ▒ ░ ░ ▒  ▒ ░ ░▒  ░ ░
  ░ ░    ▒ ░   ░   ░  ░░░ ░ ░  ▒ ░ ░ ░  ░ ░  ░  ░
	░  ░ ░      ░       ░      ░     ░          ░
								   ░
									- By Plasmatik

================
This subsystem is used to simulate simple fluid dynamics using cellular automata in a manner similar to Dwarf Fortress.

Many variables are kept on turf.cell because it is faster than using some abstract datastructure. It also makes it easy to check those variables on turfs to make cell do things.
Fluid types are checked in sequence based on the fluid_volume and new_volume associative lists on turfs' liquid datums. The liquid registry (SSliquid.registry) discovers every /datum/liquid subtype at boot for turf initialization to refer to,
So that turf/Initialize() doesn't need to be altered when / if new fluid types get added.

I wrote all of this myself from scratch, and would prefer if this particular system remained outside of open source codebases. Please do not publicly host this code without asking me.
================
*/

PROCESSING_SUBSYSTEM_DEF(liquid)
	name = "liquid"
	priority = SS_PRIORITY_LIQUID
	init_order = INIT_ORDER_LIQUID
	wait = 1
	runlevels = RUNLEVELS_DEFAULT
	flags = SS_KEEP_TIMING
	var/list/liquid_sources
	var/list/liquid_sinks
	var/list/cell_index // turfs with (or recently with) fluid
	var/list/sleeping_cells
	var/contained_cells = 0 // cells with a nonzero contain_max, maintained by /cell/proc/set_contain_max; the per-delta containment check is skipped while 0
	can_fire = FALSE

	var/datum/liquid_registry/registry
	var/datum/liquid_manager/manager
	var/datum/pool_manager/pool_manager
	var/list/overlay_appearance_cache = list() // (state|dir|color|alpha|layer|plane) -> mutable_appearance; one appearance assignment per redraw instead of six var writes

	// The simulation runs in verdant_native; DM keeps the per-type /cell
	// caches in sync from the engine's per-tick deltas and forwards every 
	// DM-side write through the edit queue. This is the best way to
	// communicate with the API.
	var/vn_native_fluids_ready = FALSE
	var/list/vn_edit_queue = list() // Has to be initialized in the var definition >:/
	var/vn_deltas_applied = 0
	var/vn_events_applied = 0
	var/vn_falls_applied = 0
	var/vn_init_warned = FALSE
	var/list/vn_res_queue = list() // collected payloads awaiting drain, FIFO
	var/vn_pending_cursor = 0 // cursor into the head payload
	var/vn_pending_deltas_left = -1 // deltas left in the head payload; -1 = head not yet opened

/datum/controller/subsystem/processing/liquid/PreInit()
	if(!registry)
		registry = new
	if(!manager)
		manager = new
	if(!pool_manager)
		pool_manager = new

/datum/controller/subsystem/processing/liquid/Recover()
	registry = SSliquid.registry
	manager = SSliquid.manager
	pool_manager = SSliquid.pool_manager

/datum/controller/subsystem/processing/liquid/Initialize()
	. = ..()
	NEW_SS_GLOBAL(SSliquid)

	liquid_sources = new
	liquid_sinks = new
	cell_index = new
	sleeping_cells = new

	for(var/turf/T in world) // You can't stop me from doing this. No one can stop me from doing this. Mwahahaha
		if(!T.cell)
			T.cell = new /cell(T)
			T.cell.InitLiquids()

/datum/controller/subsystem/processing/liquid/fire(resumed = 0, no_mc_tick = FALSE)
	if(!VN_OK)
		if(!vn_init_warned)
			vn_init_warned = TRUE
			log_world("verdant_native: liquids cannot run - native offload unavailable")
		return
	if(!vn_native_fluids_ready)
		NativeInit()
		return
	NativeFire()

/datum/controller/subsystem/processing/liquid/proc/get_pool(turf/T)
	return SSliquid.pool_manager.get_pool(T)

/datum/controller/subsystem/processing/liquid/proc/get_pool_avg(list/pool)
	return SSliquid.pool_manager.get_pool_avg_fluid(pool)

/datum/controller/subsystem/processing/liquid/proc/spread_shock(mob/living/carbon/C, turf/T, shock_damage, def_zone, siemens_coeff)
	return SSliquid.registry.execute_flag_behavior(FLUID_CONDUCTIVE, "conduct_shock", C, T, shock_damage, def_zone, siemens_coeff)


/datum/controller/subsystem/processing/liquid/proc/handle_flow_interaction(turf/source, turf/target, transfer_amount, is_pressure = FALSE, list/pressure_path)
	var/flow_dir
	if(is_pressure)
		flow_dir = get_dir(source, target)
	else
		var/mask = source.cell.pressure_mask
		if(mask == 0)
			return

		if(mask == NORTH || mask == SOUTH || mask == EAST || mask == WEST)
			flow_dir = mask
		else
			flow_dir = get_dir(source, target)

	if(!flow_dir)
		return

	for(var/atom/movable/AM in target)
		if(!ismob(AM) && !isitem(AM))
			continue

		if(AM.anchored)
			continue

		var/threshold_strong = is_pressure ? 20 : 25
		var/threshold_moderate = 15

		var/throw_range = is_pressure ? clamp(round(transfer_amount / 15), 1, 4) : clamp(round(transfer_amount / 20), 1, 3)
		var/throw_speed = is_pressure ? clamp(round(transfer_amount / 10), 1, 4) : clamp(round(transfer_amount / 15), 1, 3)

		var/throw_dir = flow_dir
		if(prob(20))
			throw_dir = turn(flow_dir, pick(45, -45))

		if(isliving(AM))
			var/mob/living/L = AM

			if(transfer_amount >= threshold_strong)
				if(is_pressure)
					L.Knockdown(30)
					to_chat(L, span_danger("A surge of pressurized liquid blasts into you with tremendous force!"))
				else
					L.Knockdown(20)
					to_chat(L, span_warning("The rushing liquid crashes into you and sweeps you away!"))
			else if(transfer_amount >= threshold_moderate && is_pressure)
				L.Knockdown(10)
				to_chat(L, span_warning("The pressurized liquid strikes you with considerable force!"))
			else
				L.Knockdown(5)
				if(is_pressure)
					to_chat(L, span_notice("The flowing liquid pushes against you!"))
				else
					to_chat(L, span_notice("The rushing liquid nearly knocks you off your feet!"))

		if(throw_range > 0)
			var/turf/target_turf = get_edge_target_turf(target, throw_dir)
			AM.throw_at(target_turf, throw_range, throw_speed)


/datum/controller/subsystem/processing/liquid/proc/update_fluidsum(turf/T)
	var/cell/C = T.cell
	var/list/vols = C.fluid_volume
	var/sum = 0
	for(var/datum/liquid/fluid as anything in vols)
		sum += vols[fluid]
	C.fluidsum = sum
	C.last_fluid_level = FLUID_LEVEL_FROM_SUM(sum)

// Update everything version, for calling during init if necessary
/datum/controller/subsystem/processing/liquid/proc/update_fluidsums()
	for(var/turf/T as anything in cell_index)
		update_fluidsum(T)

/// Test/debug helper: synchronously pushes a DM-authored fluid vector into
/// the engine, retrying past any in-flight tick, so refresh_cell_types
/// round-trips the same values.
/datum/controller/subsystem/processing/liquid/proc/sync_cell_to_native(turf/T)
	if(!vn_native_fluids_ready || !T?.cell)
		return
	var/list/edits = list(VN_FLUID_OP_CLEAR, T.x, T.y, T.z, 0, 0)
	for(var/datum/liquid/fluid as anything in T.cell.fluid_volume)
		var/amt = T.cell.fluid_volume[fluid]
		if(amt <= 0)
			continue
		var/mat = vn_fluid_mat_id(fluid)
		if(mat)
			edits += list(VN_FLUID_OP_SET, T.x, T.y, T.z, mat, amt)
	for(var/attempt in 1 to 10)
		vn_check_result(vn_fluid_edit(edits), "fluid_test_sync")
		if(vn_fluid_total(T.x, T.y, T.z) == T.cell.fluidsum)
			return
		sleep(1)

/// Rewrites the cell's per-type cache and fluidsum from engine truth. The
/// per-tick echo carries only fluidsums, so every reader that needs the type
/// vector calls this first.
/datum/controller/subsystem/processing/liquid/proc/refresh_cell_types(turf/T)
	var/cell/C = T?.cell
	if(!C || C.sim_exempt || !vn_native_fluids_ready)
		return
	var/list/pairs = vn_fluid_get(T.x, T.y, T.z)
	if(!islist(pairs))
		return
	var/list/vols = C.fluid_volume
	var/list/mat_paths = GLOB.vn_liquid_mat_path_by_id
	for(var/datum/liquid/fluid as anything in vols)
		if(fluid.type != /datum/liquid || vn_fluid_mat_id(fluid))
			vols[fluid] = 0
	for(var/i = 1, i < length(pairs), i += 2)
		var/mat = pairs[i]
		var/amt = pairs[i + 1]
		var/fluid_path = mat_paths[mat]
		if(!fluid_path)
			continue
		var/datum/liquid/instance
		if(ispath(fluid_path, /datum/liquid))
			instance = locate(fluid_path) in vols
		else
			for(var/datum/liquid/existing as anything in vols)
				if(existing.type == /datum/liquid && existing.reagent == fluid_path)
					instance = existing
					break
			if(!instance)
				instance = SSliquid.registry.create_liquid_from_reagent(fluid_path)
				if(instance)
					vols[instance] = 0
		if(instance)
			vols[instance] = amt
	var/sum = 0
	for(var/datum/liquid/fluid as anything in vols)
		sum += vols[fluid]
	C.fluidsum = sum
	C.last_fluid_level = FLUID_LEVEL_FROM_SUM(sum)

/datum/controller/subsystem/processing/liquid/proc/has_contained_neighbor(turf/T)
	if(istype(T, /turf/open/water) || istype(T, /turf/open/floor/rogue/riverbot) || istype(T, /turf/open/floor/rogue/lakebed))
		return FALSE
	for(var/D in GLOB.cardinals)
		var/turf/N = get_step(T, D)
		if(N?.cell?.contain_max)
			return TRUE
	return FALSE

/datum/controller/subsystem/processing/liquid/proc/clamp_cell_fluid(turf/T, cap)
	var/total = T.cell.fluidsum
	if(total <= cap)
		return
	var/scale = cap / total
	for(var/datum/liquid/fluid as anything in T.cell.fluid_volume)
		var/amt = T.cell.fluid_volume[fluid]
		if(amt <= 0)
			continue
		var/new_amt = round(amt * scale)
		T.cell.fluid_volume[fluid] = new_amt
		var/mat = vn_fluid_mat_id(fluid)
		if(mat)
			vn_fluid_queue(VN_FLUID_OP_SET, T, mat, new_amt)
	update_fluidsum(T)

/datum/controller/subsystem/processing/liquid/proc/clear_cell_fluid(turf/T)
	for(var/datum/liquid/fluid as anything in T.cell.fluid_volume)
		T.cell.fluid_volume[fluid] = 0
	vn_fluid_queue(VN_FLUID_OP_CLEAR, T)
	update_fluidsum(T)
	SSliquid.pool_manager.liquid_turfs -= T
	update_cell_image(T)

/datum/controller/subsystem/processing/liquid/proc/get_fluidsums(turf/T) as num
	var/sum = 0
	for(var/datum/liquid/fluid as anything in T.cell.fluid_volume)
		sum += T.cell.fluid_volume[fluid]
	return sum

/datum/controller/subsystem/processing/liquid/proc/get_fluid_level(turf/T) as num
	if(!istype(T) || !T.cell) return FLUID_EMPTY
	return FLUID_LEVEL_FROM_SUM(T.cell.fluidsum)

/turf/liquid_source
	name = "Liquid source"

/turf/liquid_source/Initialize()
	. = ..()
	SSliquid.liquid_sources += src
	cell.is_liquid_source = TRUE
	cell.production_rate = 1  // Amount of liquid produced per tick

/turf/liquid_source/Destroy()
	SSliquid.liquid_sources -= src
	return ..()

/turf/liquid_sink
	name = "Liquid sink"

/turf/liquid_sink/Initialize()
	. = ..()
	SSliquid.liquid_sinks += src
	cell.is_liquid_sink = TRUE
	cell.absorption_rate = 1  // Amount of liquid absorbed per tick

/turf/liquid_sink/Destroy()
	SSliquid.liquid_sinks -= src
	return ..()

/// Band the overlay shows: the native-committed band (engine-side hysteresis),
/// falling back to the live band before the first commit or when a dry cell wets.
/datum/controller/subsystem/processing/liquid/proc/get_vis_fluid_level(turf/T, live)
	if(isnull(live))
		live = get_fluid_level(T)
	var/cell/C = T?.cell
	if(!C || C.vis_fluid_level < 0)
		return live
	if(C.vis_fluid_level == FLUID_EMPTY && live != FLUID_EMPTY)
		return live
	return C.vis_fluid_level

/// One appearance assignment per redraw: every var write to an overlay
/// rebuilds its appearance, so the six target fields are folded into a
/// cached mutable_appearance keyed on their tuple.
/datum/controller/subsystem/processing/liquid/proc/apply_overlay_appearance(obj/effect/liquid/OV, state, ndir, ncolor, nalpha, nlayer, nplane)
	var/key = "[state]|[ndir]|[ncolor]|[nalpha]|[nlayer]|[nplane]"
	var/mutable_appearance/MA = overlay_appearance_cache[key]
	if(!MA)
		if(length(overlay_appearance_cache) > 512)
			overlay_appearance_cache = list()
		MA = new /mutable_appearance(OV)
		MA.icon_state = state
		MA.dir = ndir
		MA.color = ncolor
		MA.alpha = nalpha
		MA.layer = nlayer
		MA.plane = nplane
		overlay_appearance_cache[key] = MA
	OV.appearance = MA

/// Registry singleton for a static native mat id; null for dynamics (their
/// display color always arrives via the committed vis_rgb).
/datum/controller/subsystem/processing/liquid/proc/mat_singleton(mat)
	var/fluid_path = GLOB.vn_liquid_mat_path_by_id[mat]
	if(ispath(fluid_path, /datum/liquid))
		return registry.registered_liquids[fluid_path]
	return null

/// Display color committed with the cell's band, as a "#RRGGBB" string;
/// null before any commit carries one.
/datum/controller/subsystem/processing/liquid/proc/cell_vis_color(cell/C)
	if(!C)
		return null
	if(C.vis_color)
		return C.vis_color
	if(C.vis_mat)
		var/datum/liquid/L = mat_singleton(C.vis_mat)
		if(L?.color)
			return L.color
	return null

/datum/controller/subsystem/processing/liquid/proc/update_cell_image(turf/T)
	T.ensure_liquid_overlay()
	var/obj/effect/liquid/OV = T.liquid_overlay

	var/ncolor = cell_vis_color(T.cell) || OV.color

	var/live_level = get_fluid_level(T)
	var/fluid_level = get_vis_fluid_level(T, live_level)

	if(isopenspace(T))
		var/turf/below = GetBelow(T)
		if(below?.cell && get_vis_fluid_level(below) >= FLUID_FULL)
			ncolor = cell_vis_color(below.cell) || ncolor
			var/state = "together"
			var/ndir = OV.dir
			if(below.cell.flow_dir && (istype(below, /turf/open/floor/rogue/riverbot) || istype(below, /turf/open/floor/rogue/lakebed)))
				state = "rivermove"
				ndir = below.cell.flow_dir
			apply_overlay_appearance(OV, state, ndir, ncolor, 205, OV.layer, OV.plane)
			if(below.cell.is_liquid_source && T.cell && !T.cell.is_liquid_sink)
				T.cell.make_liquid_sink(100)
		else
			apply_overlay_appearance(OV, OV.icon_state, OV.dir, OV.color, 0, OV.layer, OV.plane)
			if(T.cell?.is_liquid_sink)
				T.cell.remove_liquid_sink()
		return

	var/state = "together"
	var/ndir = OV.dir
	if(T.cell?.flow_dir && (istype(T, /turf/open/water) || istype(T, /turf/open/floor/rogue/riverbot) || istype(T, /turf/open/floor/rogue/lakebed)))
		state = "rivermove"
		ndir = T.cell.flow_dir

	var/nlayer
	var/nplane
	if((fluid_level >= FLUID_FULL && isopenspace(GetAbove(T))) || istype(T, /turf/open/floor/rogue/riverbot) || istype(T, /turf/open/floor/rogue/lakebed))
		nlayer = ABOVE_MOB_LAYER
		nplane = GAME_PLANE_HIGHEST
	else if(fluid_level >= FLUID_HIGH)
		nlayer = BELOW_MOB_LAYER
		nplane = GAME_PLANE
	else if(fluid_level >= FLUID_LOW)
		nlayer = WATER_OVER_ITEM_LAYER
		nplane = GAME_PLANE
	else
		nlayer = BELOW_MOB_LAYER
		nplane = FLOOR_PLANE

	var/nalpha = 0
	switch(fluid_level)
		if(FLUID_VERY_LOW) nalpha = 80
		if(FLUID_LOW) nalpha = 100
		if(FLUID_MEDIUM) nalpha = 115
		if(FLUID_HIGH) nalpha = 145
		if(FLUID_VERY_HIGH) nalpha = 185
		if(FLUID_FULL) nalpha = 205
		if(FLUID_OVERFLOW) nalpha = 235

	apply_overlay_appearance(OV, state, ndir, ncolor, nalpha, nlayer, nplane)

	if((T.cell.last_fluid_level < live_level) && (live_level >= FLUID_FULL) || (T.cell.last_fluid_level > live_level) && (live_level < FLUID_FULL))
		var/list/queue = list()
		var/list/pool = get_pool(T)
		var/pool_avg = get_pool_avg(pool)
		if(pool_avg > 70) queue[pool] = TRUE
		if(length(queue)) for(var/list/p as anything in queue) for(var/turf/in_pool as anything in p) in_pool.liquid_overlay?.update_icon()


//================================================================
// --- Native offload (verdant_native) ---
// The engine owns the simulation; this side applies its per-tick deltas
// into the /cell caches so every existing reader keeps working, forwards
// queued writes, and runs the DM-side effects (shoves, images, behaviors).
//================================================================

/// One-time native bring-up: engine init, material handshake, bulk sync of
/// the current fluid state. Returns FALSE while the grid mirror is loading.
/datum/controller/subsystem/processing/liquid/proc/NativeInit()
	if(!SSnative?.mirror_loaded)
		return FALSE
	var/res = vn_fluid_init()
	if(!vn_check_result(res, "fluid_init"))
		return FALSE

	GLOB.vn_liquid_mats = list()
	GLOB.vn_liquid_mat_path_by_id = alist()
	for(var/fluid_path in SSliquid.registry.registered_liquids)
		var/id = vn_fluid_register_mat("[fluid_path]")
		if(!isnum(id))
			vn_check_result(id, "fluid_register_mat")
			return FALSE
		GLOB.vn_liquid_mats["[fluid_path]"] = id
		GLOB.vn_liquid_mat_path_by_id[id] = fluid_path
		var/datum/liquid/registered = SSliquid.registry.registered_liquids[fluid_path]
		var/rgb_int = vn_color_rgb(registered?.color)
		if(!rgb_int && registered?.reagent)
			rgb_int = vn_color_rgb(initial(registered.reagent:color))
		if(rgb_int)
			vn_check_result(vn_fluid_mat_color(id, rgb_int), "fluid_mat_color")

	// vn_fluid_init() wipes engine config, so this must run on every successful init
	vn_check_result(vn_fluid_config("edge_drain", GLOB.vn_liquid_edge_drain ? 1 : 0), "fluid_config_edge_drain")
	vn_check_result(vn_fluid_config("evap_threshold", 0), "fluid_config_evap_threshold")
	vn_check_result(vn_fluid_config("evap_rate", 1), "fluid_config_evap_rate")
	vn_check_result(vn_fluid_config("ubend", GLOB.vn_liquid_ubend ? 1 : 0), "fluid_config_ubend")
	vn_check_result(vn_fluid_config("ubend_rate", 10), "fluid_config_ubend_rate")
	vn_check_result(vn_fluid_config("band1", FLUID_BAND_EDGE_1), "fluid_config_band1")
	vn_check_result(vn_fluid_config("band2", FLUID_BAND_EDGE_2), "fluid_config_band2")
	vn_check_result(vn_fluid_config("band3", FLUID_BAND_EDGE_3), "fluid_config_band3")
	vn_check_result(vn_fluid_config("band4", FLUID_BAND_EDGE_4), "fluid_config_band4")
	vn_check_result(vn_fluid_config("band5", FLUID_BAND_EDGE_5), "fluid_config_band5")
	vn_check_result(vn_fluid_config("band6", FLUID_BAND_EDGE_6), "fluid_config_band6")
	vn_check_result(vn_fluid_config("vis_hold_ticks", LIQUID_VIS_HOLD_TICKS), "fluid_config_vis_hold")
	vn_check_result(vn_fluid_config("max_deltas", LIQUID_MAX_DELTAS_PER_TICK), "fluid_config_max_deltas")

	// bulk sync: everything with fluid plus sources/sinks/flow overrides
	var/list/edits = list()
	var/list/seen = list()
	NativeQueueCellState(cell_index, edits, seen)
	NativeQueueCellState(sleeping_cells, edits, seen)
	NativeQueueCellState(SSliquid.pool_manager.liquid_turfs, edits, seen)
	for(var/turf/T as anything in liquid_sources)
		if(!T?.cell)
			continue
		var/mat = vn_fluid_mat_id(T.cell.source_fluid_type)
		if(mat)
			edits += list(VN_FLUID_OP_SET_SOURCE, T.x, T.y, T.z, mat, T.cell.production_rate)
	for(var/turf/T as anything in liquid_sinks)
		if(!T?.cell)
			continue
		edits += list(VN_FLUID_OP_SET_SINK, T.x, T.y, T.z, 0, T.cell.absorption_rate)
	if(length(edits))
		if(!vn_check_result(vn_fluid_edit(edits), "fluid_bulk_sync"))
			return FALSE

	vn_native_fluids_ready = TRUE
	log_world("verdant_native: fluid engine live ([length(GLOB.vn_liquid_mats)] mats, [length(seen)] wet cells synced)")
	return TRUE

/datum/controller/subsystem/processing/liquid/proc/NativeQueueCellState(list/turfs, list/edits, list/seen)
	for(var/turf/T as anything in turfs)
		if(!T?.cell || seen[T])
			continue
		if(T.cell.sim_exempt)
			seen[T] = TRUE
			continue
		seen[T] = TRUE
		for(var/datum/liquid/fluid as anything in T.cell.fluid_volume)
			var/amt = T.cell.fluid_volume[fluid]
			if(amt <= 0)
				continue
			var/mat = vn_fluid_mat_id(fluid)
			if(mat)
				edits += list(VN_FLUID_OP_SET, T.x, T.y, T.z, mat, amt)
		if(T.cell.flow_dir)
			edits += list(VN_FLUID_OP_SET_FLOW_DIR, T.x, T.y, T.z, T.cell.flow_dir, 0)

/// The whole native-mode tick: apply last results, flush writes, kick next.
/datum/controller/subsystem/processing/liquid/proc/NativeFire()
	var/list/res = vn_fluid_tick_collect()
	if(!islist(res))
		vn_check_result(res, "fluid_collect")
		return
	if(length(res))
		vn_res_queue += list(res)
	if(length(vn_res_queue))
		NativeDrainPending()

	if(length(vn_edit_queue))
		var/list/q = vn_edit_queue
		vn_edit_queue = list()
		vn_check_result(vn_fluid_edit(q), "fluid_edit_flush")

	vn_check_result(vn_fluid_tick_begin(), "fluid_begin")

	// DM-side periodic effects keep their own cadence
	SSliquid.pool_manager.process_continuous_behaviors()
	SSliquid.pool_manager.process_floor_reactions()
	SSliquid.pool_manager.process_absorption()
	SSliquid.pool_manager.process_evaporation()
	SSliquid.pool_manager.process_rain_injection()
	SSliquid.pool_manager.process_wet_updates()

/// Drains queued payloads under the per-fire delta budget; each payload's
/// tail sections (events, falls, bands) apply when its delta section is
/// exhausted. With two or more payloads queued the budget stretches to at
/// least the whole head, so the backlog converges at every load level.
/datum/controller/subsystem/processing/liquid/proc/NativeDrainPending()
	var/budget = LIQUID_APPLY_DELTAS_PER_FIRE
	while(length(vn_res_queue))
		var/list/res = vn_res_queue[1]
		if(vn_pending_deltas_left < 0)
			vn_pending_cursor = 2
			vn_pending_deltas_left = res[1]
		if(length(vn_res_queue) >= 2)
			budget = max(budget, vn_pending_deltas_left)
		while(vn_pending_deltas_left > 0)
			if(budget <= 0)
				return
			vn_pending_cursor = NativeApplyDelta(res, vn_pending_cursor)
			vn_pending_deltas_left--
			budget--
		NativeApplyTail(res, vn_pending_cursor)
		vn_res_queue.Cut(1, 2)
		vn_pending_deltas_left = -1
		vn_pending_cursor = 0

/// Applies one fluidsum record starting at `cur`; returns the next cursor.
/// The type vector is NOT mirrored per tick — readers that need it call
/// refresh_cell_types for engine truth on demand.
/datum/controller/subsystem/processing/liquid/proc/NativeApplyDelta(list/res, cur)
	var/list/wet_turfs = pool_manager.liquid_turfs
	var/x = res[cur++]
	var/y = res[cur++]
	var/z = res[cur++]
	var/sum = res[cur++]
	var/turf/T = locate(x, y, z)
	if(!T)
		return cur
	var/cell/C = T.cell
	if(C?.sim_exempt)
		return cur
	if(!C) // fluid reached a turf created after init (e.g. construction)
		C = new /cell(T)
		T.cell = C
		C.InitLiquids()
	var/old_level = C.last_fluid_level
	var/old_sum = C.fluidsum
	C.fluidsum = sum
	var/level = FLUID_LEVEL_FROM_SUM(sum)
	C.last_fluid_level = level
	cell_index[T] = TRUE
	if(contained_cells)
		if(C.contain_max && sum > C.contain_max)
			clamp_cell_fluid(T, C.contain_max)
			sum = C.fluidsum
			level = C.last_fluid_level
		else if(!C.contain_max && sum > 0 && has_contained_neighbor(T))
			clear_cell_fluid(T)
			sum = 0
			level = FLUID_EMPTY
	if(sum >= MIN_FLUID_VOLUME)
		wet_turfs[T] = TRUE
	else if(wet_turfs[T])
		wet_turfs -= T
	if(sum >= LIQUID_DOUSE_THRESHOLD)
		if(!C.doused)
			C.doused = TRUE
			T.douse_contents()
	else
		C.doused = FALSE
	// live-band changes only redraw while the live band actually drives the
	// display (no committed vis band yet); otherwise the band-commit section
	// owns the redraw and this one would produce an identical appearance
	if(level != old_level && C.vis_fluid_level <= FLUID_EMPTY)
		update_cell_image(T)
	if((old_sum >= SUBMERSION_FLUID_THRESHOLD) != (sum >= SUBMERSION_FLUID_THRESHOLD) && (istype(T, /turf/open/floor/rogue/riverbot) || istype(T, /turf/open/floor/rogue/lakebed)))
		for(var/mob/living/L in T)
			L.update_submersion()
		var/turf/above_T = GetAbove(T)
		if(above_T && isopenspace(above_T))
			for(var/mob/living/L in above_T)
				L.update_submersion()
	vn_deltas_applied++
	return cur

/// Applies the trailing event/fall/band sections of a fully-drained payload.
/datum/controller/subsystem/processing/liquid/proc/NativeApplyTail(list/res, cur)
	var/n_event = res[cur++]
	for(var/i in 1 to n_event)
		var/turf/S = locate(res[cur], res[cur + 1], res[cur + 2])
		var/turf/E = locate(res[cur + 3], res[cur + 4], res[cur + 5])
		var/amt = res[cur + 6]
		cur += 7
		if(S && E)
			handle_flow_interaction(S, E, amt, TRUE, null)
			vn_events_applied++

	var/n_fall = res[cur++]
	for(var/i in 1 to n_fall)
		var/turf/L = locate(res[cur], res[cur + 1], res[cur + 2])
		var/f_amt = res[cur + 3]
		cur += 4
		if(L)
			L.liquid_fall_landed(f_amt)
			vn_falls_applied++

	var/n_band = res[cur++]
	for(var/i in 1 to n_band)
		var/turf/B = locate(res[cur], res[cur + 1], res[cur + 2])
		var/band = res[cur + 3]
		var/mat = res[cur + 4]
		var/rgb_int = res[cur + 5]
		cur += 6
		var/cell/BC = B?.cell
		if(BC && (BC.vis_fluid_level != band || BC.vis_mat != mat || BC.vis_rgb != rgb_int))
			var/was_surface = BC.vis_fluid_level >= FLUID_FULL
			var/old_rgb = BC.vis_rgb
			BC.vis_fluid_level = band
			BC.vis_mat = mat
			BC.vis_rgb = rgb_int
			BC.vis_color = rgb_int ? "#[num2hex(rgb_int, 6)]" : null
			update_cell_image(B)
			var/is_surface = band >= FLUID_FULL
			if(was_surface != is_surface || (is_surface && old_rgb != rgb_int))
				var/turf/above = GetAbove(B)
				if(above && isopenspace(above))
					update_cell_image(above)

/datum/controller/subsystem/processing/liquid/proc/convert_fluid_to_reagent(datum/liquid/fluid, amount, atom/container, turf/T)
	return SSliquid.manager.convert_fluid_to_reagent(fluid, amount, container, T)

/datum/controller/subsystem/processing/liquid/proc/convert_reagent_to_fluid(reagent_type, amount, atom/container, turf/T)
	return SSliquid.manager.convert_reagent_to_fluid(reagent_type, amount, container, T)

//The testing spawner

/obj/item/liquid_spawner
	name = "Liquid Spawner"
	desc = "A magical device that spawns liquid."
	icon_state = "tome"
	var/fluid_amount = 10
	var/fluid = WATER

/obj/item/liquid_spawner/attack_self(mob/user)
	var/turf/T = get_turf(user)
	if(!T)
		return
	if(!T.cell)
		T.cell = new /cell(T)
		T.cell.InitLiquids()
	var/datum/liquid/t_fluid = T.get_fluid_datum(fluid)
	if(!t_fluid) CRASH ("Unable to find fluid data for [fluid] on [T] at [T.x], [T.y], [T.z]!")
	var/added = SSliquid.manager.add_fluid(T, fluid, fluid_amount)
	user.visible_message("[user] uses \the [src] to summon [added] units of [t_fluid.name]. Total [t_fluid.name] volume: [T.cell.fluid_volume[t_fluid]].")

/obj/item/liquid_spawner/attack_right(mob/user)
	switch(fluid_amount)
		if(10) fluid_amount = 20
		if(20) fluid_amount = 30
		if(30) fluid_amount = 40
		if(40) fluid_amount = 50
		if(50) fluid_amount = 10
	to_chat(user, "<span class='notice'>The fluid transfer amount is now [fluid_amount].</span>")

/obj/item/liquid_spawner/ShiftRightClick(mob/user)
	if(fluid == WATER)
		fluid = FUEL
	else
		fluid = WATER
	to_chat(user, "<span class='notice'>The fluid type is now [fluid].</span>")

/obj/effect/liquid
	icon = 'icons/turf/newwater.dmi'
	icon_state = "together"
	plane = FLOOR_PLANE
	layer = BELOW_MOB_LAYER
	mouse_opacity = 0
	var/list/trims
	var/list/current_trim_dirs

/obj/effect/water/trim
	icon = 'icons/turf/newwater.dmi'
	plane = FLOOR_PLANE
	layer = BELOW_MOB_LAYER
	mouse_opacity = 0

/obj/effect/water/trim/Initialize(mapload, direction)
	. = ..()
	dir = direction
	switch(direction)
		if(NORTH)
			icon_state = "edge-n"
		if(SOUTH)
			icon_state = "edge-s"
		if(EAST)
			icon_state = "edge-e"
		if(WEST)
			icon_state = "edge-w"

/obj/effect/liquid/Initialize(mapload)
	. = ..()
	alpha = 0
	trims = list()
	current_trim_dirs = list()
	for(var/direction in GLOB.cardinals)
		current_trim_dirs["[direction]"] = FALSE

/obj/effect/liquid/update_icon()
	var/turf/here = loc
	if(!isturf(here))
		return
	var/is_lake_surface = FALSE
	if(isopenspace(here))
		var/turf/below = GetBelow(here)
		if(below?.cell && SSliquid.get_vis_fluid_level(below) >= FLUID_FULL)
			is_lake_surface = TRUE

	var/list/needed_trim_dirs = list()
	for(var/direction in GLOB.cardinals)
		needed_trim_dirs["[direction]"] = FALSE
		if(!is_lake_surface)
			continue

		var/turf/turf_to_check = get_step(here, direction)
		if(!turf_to_check)
			continue

		if(isopenspace(turf_to_check) || istype(turf_to_check, /turf/open/water))
			continue
		if(turf_to_check.cell && SSliquid.get_vis_fluid_level(turf_to_check) >= FLUID_FULL)
			continue

		needed_trim_dirs["[direction]"] = TRUE

	// Check if anything actually changed before modifying vis_contents
	var/changes_needed = FALSE
	for(var/direction in GLOB.cardinals)
		if(current_trim_dirs["[direction]"] != needed_trim_dirs["[direction]"])
			changes_needed = TRUE
			break

	// Only update vis_contents if changes are actually needed
	if(changes_needed)
		// Remove trims that are no longer needed
		for(var/direction in GLOB.cardinals)
			if(current_trim_dirs["[direction]"] && !needed_trim_dirs["[direction]"])
				vis_contents -= trims["[direction]"]
				current_trim_dirs["[direction]"] = FALSE

			// Add trims that are newly needed
			else if(!current_trim_dirs["[direction]"] && needed_trim_dirs["[direction]"])
				if(!trims["[direction]"])
					trims["[direction]"] = new /obj/effect/water/trim(null, direction)
				vis_contents += trims["[direction]"]
				current_trim_dirs["[direction]"] = TRUE


/datum/controller/subsystem/processing/liquid/proc/get_safe_pool_size(turf/T)
	if(!T?.cell)
		return 0

	return SSliquid.pool_manager.get_pool_size(T)
