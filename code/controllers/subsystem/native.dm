// ==============================================================================
// NATIVE OFFLOAD SUBSYSTEM
// ==============================================================================
// Owns the lifecycle of verdant_native.dll (see code/__DEFINES/verdant.dm)
// and keeps the native grid mirror in sync with turf state:
//
//  - Initialize: byondapi handshake + vn_init (early, INIT_ORDER_NATIVE)
//  - fire, stage 1: one-time resumable bulk load of every z-level's cell
//    codes + edge masks (runs once all subsystems are up, so SSmapping's
//    multiz_levels is ready)
//  - fire, stage 2: flush the dirty-turf batch (fed by vn_mark_dirty() from
//    turf-change hooks) as one vn_grid_update/vn_edge_update/vn_annot_update
//    triple per tick, then slow round-robin audit that recomputes a few rows
//    DM-side, compares them in native code, and resyncs on mismatch
//
// Every hook funnels through vn_mark_dirty(T); no hook ever does a call_ext
// of its own.

SUBSYSTEM_DEF(native)
	name = "Verdant Native"
	init_order = INIT_ORDER_NATIVE
	priority = SS_PRIORITY_NATIVE
	wait = 1
	runlevels = RUNLEVEL_LOBBY | RUNLEVELS_DEFAULT
	var/grid_inited = FALSE		// vn_grid_init sent; hooks may start marking
	var/mirror_loaded = FALSE	// bulk load finished; flush/audit active
	// bulk-load cursor
	var/load_z = 1
	var/load_y = 1
	// dirty batch (assoc: turf -> TRUE)
	var/list/dirty_turfs = list()
	// audit cursor + stats
	var/audit_z = 1
	var/audit_y = 1
	var/audit_cooldown = 0
	var/audit_rows_checked = 0
	var/audit_mismatches_found = 0
	var/updates_flushed = 0

/datum/controller/subsystem/native/Initialize()
	vn_startup()
	if(!GLOB.vn_available)
		can_fire = FALSE
	return ..()

/datum/controller/subsystem/native/stat_entry(msg)
	if(!GLOB.vn_available)
		msg += "DISABLED[GLOB.vn_safe_mode ? " (SAFE MODE)" : ""]"
	else if(!mirror_loaded)
		msg += "loading z=[load_z] y=[load_y]"
	else
		msg += "dirty:[length(dirty_turfs)]|flushed:[updates_flushed]|audit:[audit_rows_checked]r/[audit_mismatches_found]m"
	return ..()

/datum/controller/subsystem/native/fire(resumed)
	if(!VN_OK)
		can_fire = FALSE
		return
	if(!Master.init_complete)
		return
	if(!mirror_loaded)
		BulkLoadGrid()
		return
	FlushDirty()
	if(MC_TICK_CHECK)
		return
	AuditStep()

// --- stage 1: bulk load ---

/datum/controller/subsystem/native/proc/BulkLoadGrid()
	if(!grid_inited)
		var/list/zlinks = list()
		for(var/z in 1 to world.maxz)
			var/up = 0
			var/down = 0
			if(length(SSmapping.multiz_levels) >= z && islist(SSmapping.multiz_levels[z]))
				if(SSmapping.multiz_levels[z][Z_LEVEL_UP] && z + 1 <= world.maxz)
					up = z + 1
				if(SSmapping.multiz_levels[z][Z_LEVEL_DOWN] && z - 1 >= 1)
					down = z - 1
			zlinks += up
			zlinks += down
		var/res = vn_grid_init(world.maxx, world.maxy, world.maxz, zlinks)
		if(!vn_check_result(res, "grid_init"))
			can_fire = FALSE
			return
		grid_inited = TRUE
		log_world("verdant_native: grid init ok, bulk load starting")

	while(load_z <= world.maxz)
		var/y0 = load_y
		var/list/cellrows = list()
		var/list/edgerows = list()
		var/list/annots = list()
		while(load_y <= world.maxy && length(cellrows) < 16)
			BuildRow(load_y, load_z, cellrows, edgerows, annots)
			load_y++
		var/res = vn_grid_load_rows(load_z, y0, load_y - 1, jointext(cellrows, ""), jointext(edgerows, ""))
		if(!vn_check_result(res, "grid_load"))
			can_fire = FALSE
			return
		if(length(annots))
			vn_check_result(vn_annot_update(annots), "grid_load_annots")
		if(load_y > world.maxy)
			log_world("verdant_native: grid z=[load_z] loaded")
			load_z++
			load_y = 1
		if(MC_TICK_CHECK)
			return

	mirror_loaded = TRUE
	log_world("verdant_native: grid mirror loaded ([world.maxx]x[world.maxy]x[world.maxz])")
	GLOB.vn_light_inited_maxz = world.maxz
	if(vn_check_result(vn_light_init(world.maxx, world.maxy, world.maxz), "light_init"))
		if(!world.GetConfig("env", "VN_NO_NATIVE_LIGHT"))
			GLOB.vn_lighting_native = TRUE
			for(var/datum/light_source/L as anything in GLOB.all_light_sources)
				L.force_update()
			log_world("verdant_native: native corner lighting enabled ([length(GLOB.all_light_sources)] sources)")
#ifdef VN_SELFTEST
	if(world.params["vn_test"] || world.GetConfig("env", "VN_TEST"))
		spawn(100)
			RunSelfTests()
#endif

/// Appends one row's cell string and edge string to the output lists.
/// out_annots (optional): also collects door-integrity annotations, used
/// during bulk load so locked doors have bash costs from the first tick.
/datum/controller/subsystem/native/proc/BuildRow(y, z, list/out_cells, list/out_edges, list/out_annots)
	var/list/crow = list()
	var/list/erow = list()
	for(var/x in 1 to world.maxx)
		var/turf/T = locate(x, y, z)
		var/code = T ? T.vn_cell_code() : 0
		var/emask = T ? T.vn_edge_mask() : 0
		crow += VN_NIBBLE(code >> 4)
		crow += VN_NIBBLE(code & 15)
		erow += VN_NIBBLE(emask)
		if(out_annots && T)
			var/obj/structure/mineral_door/D = locate() in T
			if(D && !D.brokenstate)
				out_annots += x
				out_annots += y
				out_annots += z
				out_annots += VN_ANNOT_DOOR_INTEGRITY
				out_annots += max(1, D.obj_integrity || D.max_integrity)
	out_cells += jointext(crow, "")
	out_edges += jointext(erow, "")

// --- stage 2: dirty flush ---

#define VN_FLUSH_MAX 1500 // turfs per tick; the rest stays queued

/datum/controller/subsystem/native/proc/FlushDirty()
	if(!length(dirty_turfs))
		return
	var/list/batch
	if(length(dirty_turfs) > VN_FLUSH_MAX)
		batch = dirty_turfs.Copy(1, VN_FLUSH_MAX + 1)
		dirty_turfs.Cut(1, VN_FLUSH_MAX + 1)
	else
		batch = dirty_turfs
		dirty_turfs = list()

	var/list/upd = list()
	var/list/edg = list()
	var/list/ann = list()
	for(var/turf/T as anything in batch)
		if(!istype(T))
			continue
		var/code = T.vn_cell_code()
		upd += T.x
		upd += T.y
		upd += T.z
		upd += code
		edg += T.x
		edg += T.y
		edg += T.z
		edg += T.vn_edge_mask()
		// door integrity annotation: pushed unconditionally so a removed
		// door clears its stale value
		var/obj/structure/mineral_door/D = locate() in T
		ann += T.x
		ann += T.y
		ann += T.z
		ann += VN_ANNOT_DOOR_INTEGRITY
		ann += (D && !D.brokenstate) ? max(1, D.obj_integrity || D.max_integrity) : 0

	if(length(upd))
		vn_check_result(vn_grid_update(upd), "grid_update")
		vn_check_result(vn_edge_update(edg), "edge_update")
		vn_check_result(vn_annot_update(ann), "annot_update")
		updates_flushed += length(upd) / 4

#undef VN_FLUSH_MAX

// --- stage 3: slow background audit ---

#define VN_AUDIT_EVERY 50	// fires between audit batches
#define VN_AUDIT_ROWS 4		// rows per batch

/datum/controller/subsystem/native/proc/AuditStep()
	if(audit_cooldown-- > 0)
		return
	audit_cooldown = VN_AUDIT_EVERY
	if(audit_z > world.maxz)
		audit_z = 1
	var/y0 = audit_y
	var/list/crow = list()
	var/list/erow = list()
	while(length(crow) < VN_AUDIT_ROWS && audit_y <= world.maxy)
		BuildRow(audit_y, audit_z, crow, erow)
		audit_y++
	var/cells = jointext(crow, "")
	var/edges = jointext(erow, "")
	var/res = vn_grid_audit_rows(audit_z, y0, audit_y - 1, cells, edges)
	audit_rows_checked += (audit_y - y0)
	if(istext(res))
		vn_check_result(res, "grid_audit")
	else if(res > 0)
		audit_mismatches_found += res
		log_world("verdant_native: grid audit found [res] stale cells (z=[audit_z] y=[y0]-[audit_y - 1]), resyncing - a turf-change hook is missing")
		var/list/detail = vn_grid_audit_detail()
		if(islist(detail))
			for(var/i in 1 to length(detail) step 6)
				var/turf/T = locate(detail[i], detail[i + 1], audit_z)
				var/list/held = list()
				for(var/atom/A as anything in T)
					if(A.density || A.opacity)
						held += "[A.type][A.density ? "/dense" : ""][A.opacity ? "/opaque" : ""]"
				log_world("verdant_native: stale cell ([detail[i]],[detail[i + 1]],[audit_z]) [T.type] dm_cell=[detail[i + 2]] mirror_cell=[detail[i + 3]] dm_edge=[detail[i + 4]] mirror_edge=[detail[i + 5]] contents=[length(held) ? jointext(held, " ") : "none"]")
		vn_check_result(vn_grid_load_rows(audit_z, y0, audit_y - 1, cells, edges), "audit_resync")
	if(audit_y > world.maxy)
		audit_y = 1
		audit_z++

#undef VN_AUDIT_EVERY
#undef VN_AUDIT_ROWS

/// Queue a full rebuild of the mirror (admin resync).
/datum/controller/subsystem/native/proc/FullResync()
	load_z = 1
	load_y = 1
	audit_z = 1
	audit_y = 1
	dirty_turfs = list()
	mirror_loaded = FALSE

// ==============================================================================
// TURF STATE PROJECTION
// ==============================================================================

/// The single point where turf state is projected into the native mirror's
/// 8-bit cell code. Must stay faithful to get_neighbors_3d()/get_move_cost()
/// (code/__HELPERS/pathfinding.dm), __blocked() LOS semantics, blocks_flow(),
/// and isopenspace(). Class precedence when several obstacles share a tile:
/// door > climbable > window > other dense (contents order in DM is
/// unspecified, so a fixed precedence is used instead).
/turf/proc/vn_cell_code()
	var/code = 0
	var/los_hard = FALSE
	var/los_soft = FALSE
	if(density)
		code |= VN_CELL_TURF_DENSE
		if(opacity)
			los_hard = TRUE
	if(opacity)
		los_soft = TRUE
	if(isopenspace(src))
		code |= VN_CELL_OPENSPACE

	var/obj/structure/mineral_door/door
	var/has_climb = FALSE
	var/has_window = FALSE
	var/has_dense = FALSE
	for(var/atom/A as anything in contents)
		if(A.opacity)
			los_soft = TRUE
			if(A.density)
				los_hard = TRUE
		if(!isobj(A))
			continue
		if(istype(A, /obj/structure/ladder) || istype(A, /obj/structure/stairs))
			code |= VN_CELL_ZMOVER
			if(A.density)
				has_climb = TRUE
			continue
		if(!A.density)
			continue
		if(istype(A, /obj/structure/mineral_door))
			if(!door)
				door = A
		else if(istype(A, /obj/structure/table) || istype(A, /obj/structure/fluff/railing) || istype(A, /obj/structure/chair))
			has_climb = TRUE
		else if(istype(A, /obj/structure/roguewindow))
			// open/broken windows are climb-through; only an intact closed one
			// is VN_CLS_WINDOW (which the fluid engine treats as sealed)
			var/obj/structure/roguewindow/W = A
			if(W.climbable)
				has_climb = TRUE
			else
				has_window = TRUE
		else
			has_dense = TRUE

	if(door)
		code |= door.locked ? VN_CLS_DOOR_LOCKED : VN_CLS_DOOR
	else if(has_climb)
		code |= VN_CLS_CLIMB
	else if(has_window)
		code |= VN_CLS_WINDOW
	else if(has_dense)
		code |= VN_CLS_DENSE_OBJ

	if(los_hard)
		code |= VN_CELL_LOS_HARD
	if(los_soft)
		code |= VN_CELL_LOS_SOFT
	return code

/// Directional edge-block mask, replicating LinkBlocked(): a dense obj blocks
/// the edge its dir faces — including objects whose dir is just the default
/// SOUTH. Cardinals only (LinkBlocked compares dir with ==). Open/broken
/// windows are skipped — the mask's only native consumer is fluid flow, and
/// they must let liquid through.
/turf/proc/vn_edge_mask()
	var/mask = 0
	for(var/obj/O in contents)
		if(!O.density || !(O.dir == NORTH || O.dir == SOUTH || O.dir == EAST || O.dir == WEST))
			continue
		if(istype(O, /obj/structure/roguewindow))
			var/obj/structure/roguewindow/W = O
			if(W.climbable)
				continue
		mask |= O.dir
	return mask

// ==============================================================================
// DEBUG VERBS
// ==============================================================================

/client/proc/vn_native_status()
	set name = "VN Native Status"
	set category = "Debug"
	if(!holder)
		return
	var/list/out = list()
	out += "available: [GLOB.vn_available], safe_mode: [GLOB.vn_safe_mode]"
	out += "status: [vn_status()]"
	out += "dims: [json_encode(vn_grid_dims())]"
	out += "mirror_loaded: [SSnative.mirror_loaded] (cursor z=[SSnative.load_z] y=[SSnative.load_y])"
	out += "dirty queued: [length(SSnative.dirty_turfs)], flushed total: [SSnative.updates_flushed]"
	out += "audit: [SSnative.audit_rows_checked] rows checked, [SSnative.audit_mismatches_found] mismatches"
	out += "pathfinding: served=[SSpathfinding.paths_served] failed=[SSpathfinding.paths_failed]"
	out += "liquids: enabled=[SSliquid.can_fire] ready=[SSliquid.vn_native_fluids_ready] deltas=[SSliquid.vn_deltas_applied] events=[SSliquid.vn_events_applied] queued_edits=[length(SSliquid.vn_edit_queue) / 6] | [vn_fluid_status()]"
	out += "behavior trees: native=[GLOB.vn_bt_native] intents=[SSai.vn_intents_dispatched] agents=[length(SSai.vn_mobs)] trees=[length(GLOB.vn_bt_tree_ids)] | [GLOB.vn_bt_native ? vn_bt_status() : "vm idle"]"
	out += "corner lighting: native=[GLOB.vn_lighting_native] inited_maxz=[GLOB.vn_light_inited_maxz] sources=[length(GLOB.all_light_sources)] queued_events=[length(SSlighting.vn_light_events)]"
	for(var/z in 1 to world.maxz)
		out += "z[z] checksum: [vn_grid_checksum(z)]"
	to_chat(usr, out.Join("\n"))

/client/proc/vn_native_resync()
	set name = "VN Native Resync"
	set category = "Debug"
	if(!holder)
		return
	SSnative.FullResync()
	to_chat(usr, "verdant_native: full grid resync queued")

/client/proc/vn_native_selftest()
	set name = "VN Native Selftest"
	set category = "Debug"
	if(!holder)
		return
	to_chat(usr, vn_selftest())

/client/proc/vn_native_bt_toggle()
	set name = "VN Behavior Trees Native Toggle"
	set category = "Debug"
	if(!holder)
		return
	GLOB.vn_bt_native = !GLOB.vn_bt_native
	log_admin("[key_name(usr)] set native behavior trees to [GLOB.vn_bt_native]")
	to_chat(usr, "native behavior trees: [GLOB.vn_bt_native ? "ON" : "OFF"] ([vn_bt_status()])")

/client/proc/vn_native_lighting_toggle()
	set name = "VN Corner Lighting Native Toggle"
	set category = "Debug"
	if(!holder)
		return
	GLOB.vn_lighting_native = !GLOB.vn_lighting_native
	if(GLOB.vn_lighting_native)
		if(vn_check_result(vn_light_init(world.maxx, world.maxy, world.maxz), "light_init"))
			GLOB.vn_light_inited_maxz = world.maxz
		for(var/datum/light_source/L as anything in GLOB.all_light_sources)
			L.force_update()
	else
		SSlighting.vn_light_disable_native()
	log_admin("[key_name(usr)] set native corner lighting to [GLOB.vn_lighting_native]")
	to_chat(usr, "native corner lighting: [GLOB.vn_lighting_native ? "ON" : "OFF"] (sources=[length(GLOB.all_light_sources)])")

/client/proc/vn_native_liquids_toggle()
	set name = "VN Liquids Toggle"
	set category = "Debug"
	if(!holder)
		return
	SSliquid.can_fire = !SSliquid.can_fire
	if(SSliquid.can_fire)
		SSliquid.next_fire = world.time + SSliquid.wait
	log_admin("[key_name(usr)] set SSliquid to [SSliquid.can_fire]")
	to_chat(usr, "liquids: [SSliquid.can_fire ? "ON" : "OFF"] ([vn_fluid_status()])")

/// LOS parity spot-check: compares vn_los against los_blocked for random
/// turf pairs around the caller. Reports divergences.
/client/proc/vn_native_los_check()
	set name = "VN Native LOS Check"
	set category = "Debug"
	if(!holder)
		return
	var/turf/origin = get_turf(usr.client ? usr : mob)
	if(!origin)
		return
	var/checked = 0
	var/diverged = 0
	for(var/i in 1 to 200)
		var/turf/A = locate(origin.x + rand(-10, 10), origin.y + rand(-10, 10), origin.z)
		var/turf/B = locate(origin.x + rand(-10, 10), origin.y + rand(-10, 10), origin.z)
		if(!A || !B)
			continue
		var/cover = prob(50)
		var/dm_result = los_blocked(A, B, cover) ? 1 : 0
		var/native_result = vn_los(A.x, A.y, A.z, B.x, B.y, B.z, cover)
		if(VN_IS_ERR(native_result))
			to_chat(usr, "vn_los error: [native_result]")
			return
		checked++
		if(dm_result != native_result)
			diverged++
			to_chat(usr, "DIVERGED: ([A.x],[A.y]) -> ([B.x],[B.y]) cover=[cover]: dm=[dm_result] native=[native_result]")
	to_chat(usr, "LOS parity: [checked] pairs checked, [diverged] diverged")
