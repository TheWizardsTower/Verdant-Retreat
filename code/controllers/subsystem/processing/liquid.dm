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
Fluid types are checked in sequence based on the fluid_volume and new_volume associative lists on turfs' liquid datums. There is a global list of fluid types in _defines/liquid.dm  for turf initialization to refer to,
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
	can_fire = FALSE

	// The simulation runs in verdant_native; DM keeps the per-type /cell
	// caches in sync from the engine's per-tick deltas and forwards every 
	// DM-side write through the edit queue. This is the best way to
	// communicate with the API.
	var/vn_native_fluids_ready = FALSE
	var/list/vn_edit_queue = list()
	var/vn_deltas_applied = 0
	var/vn_events_applied = 0
	var/vn_falls_applied = 0
	var/vn_init_warned = FALSE

/datum/controller/subsystem/processing/liquid/Initialize()
	. = ..()
	NEW_SS_GLOBAL(SSliquid)

	liquid_sources = new
	liquid_sinks = new
	cell_index = new
	sleeping_cells = new

	GLOB.liquid_registry.refresh_registry()

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
	return GLOB.pool_manager.get_pool(T)

/datum/controller/subsystem/processing/liquid/proc/get_pool_avg(list/pool)
	return GLOB.pool_manager.get_pool_avg_fluid(pool)

/datum/controller/subsystem/processing/liquid/proc/spread_shock(mob/living/carbon/C, turf/T, shock_damage, def_zone, siemens_coeff)
	return GLOB.liquid_registry.execute_flag_behavior(FLUID_CONDUCTIVE, "conduct_shock", C, T, shock_damage, def_zone, siemens_coeff)


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

		var/throw_range = is_pressure ? min(4, round(transfer_amount / 15)) : min(3, round(transfer_amount / 20))
		var/throw_speed = is_pressure ? min(4, round(transfer_amount / 10)) : min(3, round(transfer_amount / 15))

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
				L.Stun(5)
				if(is_pressure)
					to_chat(L, span_notice("The flowing liquid pushes against you!"))
				else
					to_chat(L, span_notice("The rushing liquid nearly knocks you off your feet!"))

		if(throw_range > 0)
			var/turf/target_turf = get_edge_target_turf(target, throw_dir)
			AM.throw_at(target_turf, throw_range, throw_speed)


/datum/controller/subsystem/processing/liquid/proc/update_fluidsum(turf/T)
	var/sum = 0
	for(var/datum/liquid/fluid as anything in T.cell.fluid_volume)
		sum += T.cell.fluid_volume[fluid]
	T.cell.fluidsum = sum
	T.cell.last_fluid_level = get_fluid_level(T)

// Update everything version, for calling during init if necessary
/datum/controller/subsystem/processing/liquid/proc/update_fluidsums()
	for(var/turf/T as anything in cell_index)
		var/sum = 0
		for(var/datum/liquid/fluid as anything in T.cell.fluid_volume)
			sum += T.cell.fluid_volume[fluid]
		T.cell.fluidsum = sum
		T.cell.last_fluid_level = get_fluid_level(T)

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
	GLOB.pool_manager.liquid_turfs -= T
	update_cell_image(T)

/datum/controller/subsystem/processing/liquid/proc/get_fluidsums(turf/T) as num
	var/sum = 0
	for(var/datum/liquid/fluid as anything in T.cell.fluid_volume)
		sum += T.cell.fluid_volume[fluid]
	return sum

/datum/controller/subsystem/processing/liquid/proc/get_fluid_level(turf/T) as num
	if(!istype(T) || !T.cell) return FLUID_EMPTY
	var/fluidsum = T.cell.fluidsum

	switch(fluidsum)
		if(0)
			return FLUID_EMPTY
		if(1 to 20)
			return FLUID_VERY_LOW
		if(21 to 30)
			return FLUID_LOW
		if(31 to 40)
			return FLUID_MEDIUM
		if(41 to 55)
			return FLUID_HIGH
		if(56 to 60)
			return FLUID_VERY_HIGH
		if(61 to 95)
			return FLUID_FULL
		else
			return FLUID_OVERFLOW

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

/datum/controller/subsystem/processing/liquid/proc/update_cell_image(turf/T)
	T.ensure_liquid_overlay()
	var/datum/liquid/mostfluid = T.get_highest_fluid_by_volume()

	if(mostfluid)
		T.liquid_overlay.color = mostfluid.color

	var/fluid_level = get_fluid_level(T)

	if(isopenspace(T))
		var/turf/below = GetBelow(T)
		if(below?.cell && get_fluid_level(below) >= FLUID_FULL)
			var/datum/liquid/below_fluid = below.get_highest_fluid_by_volume()
			if(below_fluid)
				T.liquid_overlay.color = below_fluid.color
			if(below.cell.flow_dir && (istype(below, /turf/open/floor/rogue/riverbot) || istype(below, /turf/open/floor/rogue/lakebed)))
				T.liquid_overlay.icon_state = "rivermove"
				T.liquid_overlay.dir = below.cell.flow_dir
			else
				T.liquid_overlay.icon_state = "together"
			T.liquid_overlay.alpha = 205
			if(below.cell.is_liquid_source && T.cell && !T.cell.is_liquid_sink)
				T.cell.make_liquid_sink(100)
		else
			T.liquid_overlay.alpha = 0
			if(T.cell?.is_liquid_sink)
				T.cell.remove_liquid_sink()
		return

	if(T.cell?.flow_dir && (istype(T, /turf/open/water) || istype(T, /turf/open/floor/rogue/riverbot) || istype(T, /turf/open/floor/rogue/lakebed)))
		T.liquid_overlay.icon_state = "rivermove"
		T.liquid_overlay.dir = T.cell.flow_dir
	else
		T.liquid_overlay.icon_state = "together"

	if((fluid_level >= FLUID_FULL && isopenspace(GetAbove(T))) || istype(T, /turf/open/floor/rogue/riverbot) || istype(T, /turf/open/floor/rogue/lakebed))
		T.liquid_overlay.layer = ABOVE_MOB_LAYER
		T.liquid_overlay.plane = GAME_PLANE_HIGHEST
	else
		T.liquid_overlay.layer = BELOW_MOB_LAYER
		T.liquid_overlay.plane = FLOOR_PLANE

	switch(fluid_level)
		if(FLUID_EMPTY) T.liquid_overlay.alpha = 0
		if(FLUID_VERY_LOW) T.liquid_overlay.alpha = 80
		if(FLUID_LOW) T.liquid_overlay.alpha = 100
		if(FLUID_MEDIUM) T.liquid_overlay.alpha = 115
		if(FLUID_HIGH) T.liquid_overlay.alpha = 145
		if(FLUID_VERY_HIGH) T.liquid_overlay.alpha = 185
		if(FLUID_FULL)
			T.liquid_overlay.alpha = 205
		if(FLUID_OVERFLOW)
			T.liquid_overlay.alpha = 235

	if((T.cell.last_fluid_level < fluid_level) && (fluid_level >= FLUID_FULL) || (T.cell.last_fluid_level > fluid_level) && (fluid_level < FLUID_FULL))
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
	GLOB.vn_liquid_mat_paths = list()
	for(var/fluid_path in GLOB.liquid_types)
		var/id = vn_fluid_register_mat("[fluid_path]")
		if(!isnum(id))
			vn_check_result(id, "fluid_register_mat")
			return FALSE
		GLOB.vn_liquid_mats["[fluid_path]"] = id
		GLOB.vn_liquid_mat_paths["[id]"] = fluid_path

	// vn_fluid_init() wipes engine config, so this must run on every successful init
	vn_check_result(vn_fluid_config("edge_drain", GLOB.vn_liquid_edge_drain ? 1 : 0), "fluid_config_edge_drain")
	vn_check_result(vn_fluid_config("evap_threshold", world.GetConfig("env", "VN_NO_EVAP") ? 0 : 10), "fluid_config_evap_threshold")
	vn_check_result(vn_fluid_config("evap_rate", 1), "fluid_config_evap_rate")
	vn_check_result(vn_fluid_config("ubend", GLOB.vn_liquid_ubend ? 1 : 0), "fluid_config_ubend")
	vn_check_result(vn_fluid_config("ubend_rate", 10), "fluid_config_ubend_rate")

	// bulk sync: everything with fluid plus sources/sinks/flow overrides
	var/list/edits = list()
	var/list/seen = list()
	NativeQueueCellState(cell_index, edits, seen)
	NativeQueueCellState(sleeping_cells, edits, seen)
	NativeQueueCellState(GLOB.pool_manager.liquid_turfs, edits, seen)
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
		NativeApplyResults(res)

	if(length(vn_edit_queue))
		var/list/q = vn_edit_queue
		vn_edit_queue = list()
		vn_check_result(vn_fluid_edit(q), "fluid_edit_flush")

	vn_check_result(vn_fluid_tick_begin(), "fluid_begin")

	// DM-side periodic effects keep their own cadence
	GLOB.pool_manager.process_continuous_behaviors()
	GLOB.pool_manager.process_floor_reactions()
	GLOB.pool_manager.process_absorption()
	GLOB.pool_manager.process_rain_injection()
	GLOB.pool_manager.process_wet_updates()

/datum/controller/subsystem/processing/liquid/proc/NativeApplyResults(list/res)
	var/cur = 1
	var/n_delta = res[cur++]
	for(var/i in 1 to n_delta)
		var/x = res[cur++]
		var/y = res[cur++]
		var/z = res[cur++]
		var/ntypes = res[cur++]
		var/turf/T = locate(x, y, z)
		if(!T)
			cur += ntypes * 2
			continue
		if(T.cell?.sim_exempt)
			cur += ntypes * 2
			continue
		if(!T.cell) // fluid reached a turf created after init (e.g. construction)
			T.cell = new /cell(T)
			T.cell.InitLiquids()
		var/list/vols = T.cell.fluid_volume
		// zero every native-mapped type (static or registered dynamic), then
		// apply the reported vector; still-unmapped dynamic types are
		// DM-only and left alone
		for(var/datum/liquid/fluid as anything in vols)
			if(vn_fluid_mat_id(fluid))
				vols[fluid] = 0
		for(var/t in 1 to ntypes)
			var/mat = res[cur++]
			var/amt = res[cur++]
			var/fluid_path = GLOB.vn_liquid_mat_paths["[mat]"]
			if(istext(fluid_path))
				fluid_path = text2path(fluid_path)
			if(!fluid_path)
				continue
			var/datum/liquid/instance
			if(ispath(fluid_path, /datum/liquid))
				instance = locate(fluid_path) in vols
			else
				// mat id maps to a reagent typepath (dynamic liquid): match
				// the cell's existing same-reagent instance, or create one
				for(var/datum/liquid/existing as anything in vols)
					if(existing.type == /datum/liquid && existing.reagent == fluid_path)
						instance = existing
						break
				if(!instance)
					instance = GLOB.liquid_registry.create_liquid_from_reagent(fluid_path)
					if(instance)
						vols[instance] = 0
			if(instance)
				vols[instance] = amt
		update_fluidsum(T)
		cell_index[T] = TRUE
		if(T.cell.contain_max && T.cell.fluidsum > T.cell.contain_max)
			clamp_cell_fluid(T, T.cell.contain_max)
		else if(!T.cell.contain_max && T.cell.fluidsum > 0 && has_contained_neighbor(T))
			clear_cell_fluid(T)
		if(T.cell.fluidsum >= MIN_FLUID_VOLUME)
			GLOB.pool_manager.liquid_turfs[T] = TRUE
		else
			GLOB.pool_manager.liquid_turfs -= T
		if(T.cell.fluidsum >= LIQUID_DOUSE_THRESHOLD)
			if(!T.cell.doused)
				T.cell.doused = TRUE
				T.douse_contents()
		else
			T.cell.doused = FALSE
		update_cell_image(T)
		if(istype(T, /turf/open/floor/rogue/riverbot) || istype(T, /turf/open/floor/rogue/lakebed))
			for(var/mob/living/L in T)
				L.update_submersion()
			var/turf/above_T = GetAbove(T)
			if(above_T && isopenspace(above_T))
				for(var/mob/living/L in above_T)
					L.update_submersion()
		vn_deltas_applied++

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

/datum/controller/subsystem/processing/liquid/proc/convert_fluid_to_reagent(datum/liquid/fluid, amount, atom/container, turf/T)
	return GLOB.liquid_manager.convert_fluid_to_reagent(fluid, amount, container, T)

/datum/controller/subsystem/processing/liquid/proc/convert_reagent_to_fluid(reagent_type, amount, atom/container, turf/T)
	return GLOB.liquid_manager.convert_reagent_to_fluid(reagent_type, amount, container, T)

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
	var/added = GLOB.liquid_manager.add_fluid(T, fluid, fluid_amount)
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
		trims["[direction]"] = new /obj/effect/water/trim(null, direction)
		current_trim_dirs["[direction]"] = FALSE

/obj/effect/liquid/update_icon()
	var/turf/here = loc
	if(!isturf(here))
		return
	var/is_lake_surface = FALSE
	if(isopenspace(here))
		var/turf/below = GetBelow(here)
		if(below?.cell && GET_FLUID_LEVEL(below) >= FLUID_FULL)
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
		if(turf_to_check.cell && GET_FLUID_LEVEL(turf_to_check) >= FLUID_FULL)
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
				vis_contents += trims["[direction]"]
				current_trim_dirs["[direction]"] = TRUE


/datum/controller/subsystem/processing/liquid/proc/get_safe_pool_size(turf/T)
	if(!T?.cell)
		return 0

	return GLOB.pool_manager.get_pool_size(T)
