// verdant.dm - DM API for the verdant_native offload library (byondapi)
//
// verdant_native.dll moves the crunching parts of pathfinding, liquid
// simulation, corner-lighting and behavior-tree evaluation out of the DM interpreter.
// Repo: verdant-native (private). The DLL sits next to the .dmb like rust_g.
//
// Every native call can return an error string "ERR:<code>:<msg>". Wrappers
// must run results through vn_check_result() — a safe_mode error permanently
// disables native paths for the round and the retained DM implementations
// take over. NEVER assume a native call succeeded.

// ABI compatibility number; must match kAbi in the DLL's Exports.cpp.
#define VERDANT_ABI 6

#ifndef VERDANT_NATIVE
/* This comment bypasses grep checks */ /var/__verdant_native

/proc/__detect_verdant_native()
	if(world.system_type == UNIX)
		return __verdant_native = "./libverdant_native.so"
	else
		return __verdant_native = "verdant_native"

#define VERDANT_NATIVE (__verdant_native || __detect_verdant_native())
#endif

/// TRUE once the handshake + init succeeded and safe mode hasn't tripped.
GLOBAL_VAR_INIT(vn_available, FALSE)
/// Set when the DLL reports safe mode or an unrecoverable ERR.
GLOBAL_VAR_INIT(vn_safe_mode, FALSE)

#define VN_IS_ERR(X) (istext(X) && copytext(X, 1, 5) == "ERR:")

/// Can native offload be used right now?
#define VN_OK (GLOB.vn_available && !GLOB.vn_safe_mode)

// --- grid mirror cell code (MUST match src/mirror/GridMirror.h in verdant-native) ---
// bits 0-2: obstacle class from turf contents
#define VN_CLS_NONE 0
#define VN_CLS_DOOR 1			// unlocked mineral door
#define VN_CLS_DOOR_LOCKED 2	// locked mineral door (bash cost via integrity annot)
#define VN_CLS_CLIMB 3			// table / railing / chair / ladder body / open or broken window
#define VN_CLS_WINDOW 4			// intact closed roguewindow, smashable; seals fluid flow
#define VN_CLS_DENSE_OBJ 5		// any other dense obj: impassable
#define VN_CLS_UNSAFE 6			// can_traverse_safely() == FALSE (lava); never entered laterally
#define VN_CLS_MASK 7			// bits 0-2 of a cell code hold the obstacle class
#define VN_CELL_TURF_DENSE (1<<3)	// turf.density (== blocks_flow())
#define VN_CELL_LOS_HARD (1<<4)		// blocks LOS: dense && opaque
#define VN_CELL_LOS_SOFT (1<<5)		// blocks LOS with checkforcover: any opacity
#define VN_CELL_ZMOVER (1<<6)		// ladder/stairs present
#define VN_CELL_OPENSPACE (1<<7)	// isopenspace()

#define VN_ANNOT_DOOR_INTEGRITY 0

// nibble encoding for bulk row strings: value n -> char '0'+n
#define VN_NIBBLE_CHARS "0123456789:;<=>?"
#define VN_NIBBLE(n) copytext(VN_NIBBLE_CHARS, (n) + 1, (n) + 2)

// SSnative fire priority (just above SSquadtree's 68 so the mirror is fresh
// before AI/pathfinding consumers run)
//nice - chaoko99
#define SS_PRIORITY_NATIVE 69 

// --- raw wrappers (one per DLL export) ---
// Macros, not procs: a native call costs one call_ext with no wrapper proc
// overhead. Zero-argument wrappers are object-like macros expanding to the
// callable, so the call site's () applies directly to call_ext's result.

#define vn_version call_ext(VERDANT_NATIVE, "byond:vn_version")
#define vn_init(cfg_json) call_ext(VERDANT_NATIVE, "byond:vn_init")(cfg_json)
#define vn_shutdown call_ext(VERDANT_NATIVE, "byond:vn_shutdown")
#define vn_status call_ext(VERDANT_NATIVE, "byond:vn_status")
#define vn_echo_list(payload) call_ext(VERDANT_NATIVE, "byond:vn_echo_list")(payload)
#define vn_echo_str(payload) call_ext(VERDANT_NATIVE, "byond:vn_echo_str")(payload)

/// Sleeps the calling proc until the sim thread answers. Only call from
/// contexts that may sleep (never from a subsystem fire()), and never
/// directly from world/New() - awaits made there are not serviced and hang
/// forever. Spawned procs are safe.
#define vn_echo_await(delay_ms) call_ext(VERDANT_NATIVE, "byond,await:vn_echo_await")(delay_ms)

// --- grid mirror ---

/// zlinks: flat list [z_above, z_below] per z (absolute z, 0 = none)
#define vn_grid_init(w, h, zn, zlinks) call_ext(VERDANT_NATIVE, "byond:vn_grid_init")(w, h, zn, zlinks)
#define vn_grid_load_rows(z, y0, y1, cells, edges) call_ext(VERDANT_NATIVE, "byond:vn_grid_load_rows")(z, y0, y1, cells, edges)
/// Returns mismatch count as a number, or an ERR string.
#define vn_grid_audit_rows(z, y0, y1, cells, edges) call_ext(VERDANT_NATIVE, "byond:vn_grid_audit_rows")(z, y0, y1, cells, edges)
/// -> flat [x, y, dm_cell, mirror_cell, dm_edge, mirror_edge] per mismatch from the last audit call (max 16)
#define vn_grid_audit_detail call_ext(VERDANT_NATIVE, "byond:vn_grid_audit_detail")
/// updates: flat [x,y,z,code, ...]; returns applied count
#define vn_grid_update(updates) call_ext(VERDANT_NATIVE, "byond:vn_grid_update")(updates)
/// updates: flat [x,y,z,mask, ...]; returns applied count
#define vn_edge_update(updates) call_ext(VERDANT_NATIVE, "byond:vn_edge_update")(updates)
/// updates: flat [x,y,z,kind,value, ...]; value 0 clears; returns applied count
#define vn_annot_update(updates) call_ext(VERDANT_NATIVE, "byond:vn_annot_update")(updates)
#define vn_grid_checksum(z) call_ext(VERDANT_NATIVE, "byond:vn_grid_checksum")(z)
/// Native port of los_blocked(); returns 1 blocked / 0 clear (or ERR string)
#define vn_los(x1, y1, z1, x2, y2, z2, checkforcover) call_ext(VERDANT_NATIVE, "byond:vn_los")(x1, y1, z1, x2, y2, z2, checkforcover)
#define vn_grid_dims call_ext(VERDANT_NATIVE, "byond:vn_grid_dims")
/// Debug: what the mirror believes about one tile -> [cell_code, edge_mask, door_integrity]
#define vn_grid_get(x, y, z) call_ext(VERDANT_NATIVE, "byond:vn_grid_get")(x, y, z)

/// Turf-change hooks call this; no-op before the mirror is initialized.
/// Statement macro (contains an if) - do not use as an expression or as the
/// body of an if/else without braces.
#define vn_mark_dirty(T) if(SSnative?.grid_inited && isturf(T)) { SSnative.dirty_turfs[T] = TRUE }

// --- pathfinding ---

// profile bit layout (must match PathProfile::Unpack in verdant-native):
// bit0 smash, bit1 provoked, bits 4-11 strength_bonus, bits 12-21 weapon force
#define VN_PATH_SMASH (1<<0)
#define VN_PATH_PROVOKED (1<<1)

/// Native A*, await form: the calling proc sleeps until the sim thread
/// answers. Returns a flat [x,y,z ×n] list (empty = no path) or an ERR
/// string. max_cost 0 = unlimited. Same world/New() restriction as all
/// awaits.
#define vn_path_find(sx, sy, sz, tx, ty, tz, max_cost, profile) call_ext(VERDANT_NATIVE, "byond,await:vn_path_find")(sx, sy, sz, tx, ty, tz, max_cost, profile)
/// Synchronous native A* (blocks the tick) - parity checks and short paths.
#define vn_path_find_sync(sx, sy, sz, tx, ty, tz, max_cost, profile) call_ext(VERDANT_NATIVE, "byond:vn_path_find_sync")(sx, sy, sz, tx, ty, tz, max_cost, profile)

// Pathfinding is native-only: A_Star() computes in the DLL and returns null
// when the offload is unavailable.

// --- fluids ---

// edit ops (must match RTLiquidEngine::EditOp)
#define VN_FLUID_OP_ADD 1			// a=mat, b=amount (clamped to capacity)
#define VN_FLUID_OP_SET 2			// a=mat, b=amount (absolute; preferred for sync)
#define VN_FLUID_OP_REMOVE 3		// a=mat, b=amount
#define VN_FLUID_OP_CLEAR 4
#define VN_FLUID_OP_SET_SOURCE 5	// a=mat, b=production rate
#define VN_FLUID_OP_CLEAR_SOURCE 6
#define VN_FLUID_OP_SET_SINK 7		// b=absorption rate
#define VN_FLUID_OP_CLEAR_SINK 8
#define VN_FLUID_OP_SET_FLOW_DIR 9	// a=dir bits

#define vn_fluid_init call_ext(VERDANT_NATIVE, "byond:vn_fluid_init")
#define vn_fluid_register_mat(name) call_ext(VERDANT_NATIVE, "byond:vn_fluid_register_mat")(name)
#define vn_fluid_mat_color(id, rgb) call_ext(VERDANT_NATIVE, "byond:vn_fluid_mat_color")(id, rgb)
/// edits: flat [op,x,y,z,a,b ...]; returns applied count
#define vn_fluid_edit(edits) call_ext(VERDANT_NATIVE, "byond:vn_fluid_edit")(edits)
#define vn_fluid_tick_begin call_ext(VERDANT_NATIVE, "byond:vn_fluid_tick_begin")
/// -> [n_delta, (x,y,z,ntypes,(mat,amt)*n)..., n_event, (sx,sy,sz,tx,ty,tz,amt)..., n_fall, (x,y,z,amt)...]
/// or an empty list while the tick is still running
#define vn_fluid_tick_collect call_ext(VERDANT_NATIVE, "byond:vn_fluid_tick_collect")
#define vn_fluid_config(key, value) call_ext(VERDANT_NATIVE, "byond:vn_fluid_config")(key, value)
#define vn_fluid_total(x, y, z) call_ext(VERDANT_NATIVE, "byond:vn_fluid_total")(x, y, z)
#define vn_fluid_get(x, y, z) call_ext(VERDANT_NATIVE, "byond:vn_fluid_get")(x, y, z)
#define vn_fluid_pool_cells(x, y, z) call_ext(VERDANT_NATIVE, "byond:vn_fluid_pool_cells")(x, y, z)
#define vn_fluid_pool_stats(x, y, z) call_ext(VERDANT_NATIVE, "byond:vn_fluid_pool_stats")(x, y, z)
#define vn_fluid_status call_ext(VERDANT_NATIVE, "byond:vn_fluid_status")

/// edge_drain config applied to the native engine on every successful NativeInit
GLOBAL_VAR_INIT(vn_liquid_edge_drain, TRUE)
/// U-bend vertical surface equalization, applied the same way
GLOBAL_VAR_INIT(vn_liquid_ubend, TRUE)

// --- fire spread ---

// edit ops (must match RTFireEngine::EditOp)
#define VN_FIRE_OP_IGNITE 1			// a=level 1..3 (0 -> 1); no-op on fuel 0 or an already hotter cell
#define VN_FIRE_OP_EXTINGUISH 2		// level -> 0, fuel kept
#define VN_FIRE_OP_SET_FUEL 3		// a=fuel 0..255 (turf-change reseed)
#define VN_FIRE_OP_SET_SPREAD 4		// a=spread 0..100
#define VN_FIRE_OP_SET_EXPOSED 5	// a=0/1 (outdoor and not weatherproof)
#define VN_FIRE_OP_ADD_FUEL 6		// a=amount; fuel clamped to 255

/// Sizes itself from the grid mirror, which must be loaded first.
#define vn_fire_init call_ext(VERDANT_NATIVE, "byond:vn_fire_init")
/// props: 4 nibbles per cell, row-major x ascending — fuel-hi, fuel-lo, spread, flags(bit0 exposed)
#define vn_fire_load_rows(z, y0, y1, props) call_ext(VERDANT_NATIVE, "byond:vn_fire_load_rows")(z, y0, y1, props)
/// edits: flat [op,x,y,z,a ...]; returns applied count
#define vn_fire_edit(edits) call_ext(VERDANT_NATIVE, "byond:vn_fire_edit")(edits)
/// keys: douse_threshold, rain, seed
#define vn_fire_config(key, value) call_ext(VERDANT_NATIVE, "byond:vn_fire_config")(key, value)
#define vn_fire_tick_begin call_ext(VERDANT_NATIVE, "byond:vn_fire_tick_begin")
/// -> [n_delta, (x,y,z,level)..., n_burnt, (x,y,z)...]
/// or an empty list while the tick is still running
#define vn_fire_tick_collect call_ext(VERDANT_NATIVE, "byond:vn_fire_tick_collect")
/// -> [level, fuel, spread, flags]
#define vn_fire_get(x, y, z) call_ext(VERDANT_NATIVE, "byond:vn_fire_get")(x, y, z)
#define vn_fire_status call_ext(VERDANT_NATIVE, "byond:vn_fire_status")

/// Queues an edit for the native fire engine; flushed by SSfire's fire.
/// No-op until the engine is seeded, so writers can call unconditionally.
/proc/vn_fire_queue(op, turf/T, a = 0)
	if(!SSfire?.fire_ready || !istype(T))
		return
	var/list/q = SSfire.vn_edit_queue
	q += op
	q += T.x
	q += T.y
	q += T.z
	q += a

// --- behavior trees ---

// node types (must match RTBtVM's NodeType)
#define VN_BT_SELECTOR 1
#define VN_BT_SEQUENCE 2
#define VN_BT_PARALLEL 3
#define VN_BT_PARALLEL_FAIL_EARLY 4
#define VN_BT_ACTION 5				// p0 = invert
#define VN_BT_TIMEOUT 6				// p0 = limit ds
#define VN_BT_STUCK_SENSOR 7		// p0 = stuck_limit ds
#define VN_BT_RETRY 8				// p0 = cooldown ds, p1 = max_failures
#define VN_BT_COOLDOWN 9			// p0 = cooldown ds
#define VN_BT_OBSERVER 10			// p0 = signal slot
#define VN_BT_SERVICE_NATIVE 11		// p0 = interval ds, p1 = monitor kind, p2 = threshold
#define VN_BT_SERVICE_INTENT 12		// p0 = interval ds
#define VN_BT_PROGRESS_PASS 13
#define VN_BT_TARGET_PERSISTENCE 14

// signal slots (must match RTBtVM's Signal)
#define VN_SIG_TARGET_LOST 1
#define VN_SIG_LOW_HEALTH 2
#define VN_SIG_SQUAD_CHANGED 3
#define VN_SIG_PAIN_CRIT 4
#define VN_SIG_HUNGRY 5
#define VN_SIG_TARGET_DEATH 6
#define VN_SIG_BAIT_DEATH 7

// native monitor kinds (VN_BT_SERVICE_NATIVE p1)
#define VN_MON_HEALTH 1
#define VN_MON_PAIN 2
#define VN_MON_HUNGER 3

// intent kinds in the tick result (must match RTBtVM's IntentKind)
#define VN_INTENT_ACTION 0
#define VN_INTENT_SERVICE 1
#define VN_INTENT_CLEAR_PATH 2
#define VN_INTENT_CLEAR_TARGET 3

#define vn_bt_reset call_ext(VERDANT_NATIVE, "byond:vn_bt_reset")
/// flat preorder export [type,p0,p1,p2,nchildren]... -> tree id or ERR
#define vn_bt_load(flat) call_ext(VERDANT_NATIVE, "byond:vn_bt_load")(flat)
#define vn_bt_mob_add(mob_id, tree_id) call_ext(VERDANT_NATIVE, "byond:vn_bt_mob_add")(mob_id, tree_id)
#define vn_bt_mob_remove(mob_id) call_ext(VERDANT_NATIVE, "byond:vn_bt_mob_remove")(mob_id)
/// stride 11: [mob_id, x,y,z, hp_pct, pain_pct, food, target_token, tx,ty,tz]
#define vn_bt_sync(flat) call_ext(VERDANT_NATIVE, "byond:vn_bt_sync")(flat)
/// stride 3: [mob_id, node_id, status]
#define vn_bt_report(flat) call_ext(VERDANT_NATIVE, "byond:vn_bt_report")(flat)
/// stride 2: [mob_id, signal slot]
#define vn_bt_signal(flat) call_ext(VERDANT_NATIVE, "byond:vn_bt_signal")(flat)
#define vn_bt_tick_begin(world_time, ids) call_ext(VERDANT_NATIVE, "byond:vn_bt_tick_begin")(world_time, ids)
/// -> [n_intent, (mob_id, node_id, kind, p) * n] or empty while running
#define vn_bt_tick_collect call_ext(VERDANT_NATIVE, "byond:vn_bt_tick_collect")
#define vn_bt_status call_ext(VERDANT_NATIVE, "byond:vn_bt_status")

/// Route supported behavior trees through the native evaluator.
GLOBAL_VAR_INIT(vn_bt_native, FALSE)
/// tree root typepath string -> native tree id (0 = known-unsupported)
GLOBAL_LIST_EMPTY(vn_bt_tree_ids)

// --- corner lighting ---

#define VN_LIGHT_EVT_ADD 1
#define VN_LIGHT_EVT_REMOVE 2
#define VN_LIGHT_EVT_ADD_TURFS 3
#define VN_LIGHT_EVT_ADD_BOX 4

// corner datum x/y are the +-0.5 positions, so round(x*2) is exact.
// Strides are 2*max+1: corner cx2 spans [1, 2*maxx+1], so an even stride
// would alias the map-edge corner column onto the next row. Must match
// light::PackCorner in the DLL exactly.
#define VN_LIGHT_CORNER_ID(C) (((C.z - 1) * (2 * world.maxx + 1) * (2 * world.maxy + 1)) + ((round(C.y * 2) - 1) * (2 * world.maxx + 1)) + (round(C.x * 2) - 1))

// packed (x,y,z) turf identity for ADD_TURFS events; must match light::PackTurf.
#define VN_LIGHT_TURF_ID(T) (((T.z - 1) * world.maxx * world.maxy) + ((T.y - 1) * world.maxx) + (T.x - 1))

#define vn_light_init(maxx, maxy, maxz) call_ext(VERDANT_NATIVE, "byond:vn_light_init")(maxx, maxy, maxz)
#define vn_light_reset call_ext(VERDANT_NATIVE, "byond:vn_light_reset")
/// events: flat [1, source_id, sx,sy,sz, power, inner_range, outer_range, falloff_curve, lum_r, lum_g, lum_b, n, corner_id x n] for ADD/REPLACE, [2, source_id] for REMOVE, [3, ...same header..., n, turf_id x n] for ADD_TURFS (corners derived native-side), concatenated
#define vn_light_tick_begin(events) call_ext(VERDANT_NATIVE, "byond:vn_light_tick_begin")(events)
/// -> [n, (corner_id, delta_r, delta_g, delta_b) x n] or an empty list while the tick is still running
#define vn_light_tick_collect call_ext(VERDANT_NATIVE, "byond:vn_light_tick_collect")

// --- outdoor ceiling/sky sweep (init only) ---

#define vn_outdoor_begin(maxx, maxy, maxz, zup) call_ext(VERDANT_NATIVE, "byond:vn_outdoor_begin")(maxx, maxy, maxz, zup)
/// props: 2 hex nibbles per cell — 1 closed, 2 transparent, 4 weatherproof, 8 wp-structure, 16 pseudo_roof, 32 area-outdoors
#define vn_outdoor_rows(z, y0, y1, props) call_ext(VERDANT_NATIVE, "byond:vn_outdoor_rows")(z, y0, y1, props)
#define vn_outdoor_compute call_ext(VERDANT_NATIVE, "byond:vn_outdoor_compute")
/// -> per-cell result nibbles: 1 CEIL_SKYVISIBLE, 2 CEIL_WEATHERPROOF, state << 2
#define vn_outdoor_fetch(z) call_ext(VERDANT_NATIVE, "byond:vn_outdoor_fetch")(z)
/// -> flat [xy_packed_0based, result_nibble] per effect-needing cell
#define vn_outdoor_fetch_effects(z) call_ext(VERDANT_NATIVE, "byond:vn_outdoor_fetch_effects")(z)

// --- dmm row digestion (map load) ---

/// -> flat [model_index] per tile (1-based position in keys, 0 for space_key), row-major
#define vn_dmm_digest(key_len, keys, space_key, rows) call_ext(VERDANT_NATIVE, "byond:vn_dmm_digest")(key_len, keys, space_key, rows)

/// Route light_source.update_corners()/SSlighting.fire() through the native engine.
GLOBAL_VAR_INIT(vn_lighting_native, FALSE)
/// world.maxz as of the last successful vn_light_init; corners on z beyond
/// this are not native-managed (z-levels can be added at runtime).
GLOBAL_VAR_INIT(vn_light_inited_maxz, 0)
/// VN_LIGHT_CORNER_ID (numeric key) -> /datum/lighting_corner, registered in New().
/// An alist: numeric keys are legal and fast, but it cannot be for-looped or
/// indexed positionally — iterate SSlighting.all_corners instead.
GLOBAL_VAR_INIT(vn_light_corners, alist())
/// All live /datum/light_source instances, maintained in New()/Destroy()
GLOBAL_LIST_EMPTY(all_light_sources)

// --- fluids ---

// Liquids are native-only: SSliquid drives the engine when enabled
// (it ships with can_fire = FALSE).
/// static fluid typepath string, or dynamic reagent typepath string -> native mat id
GLOBAL_LIST_EMPTY(vn_liquid_mats)
/// mat id (numeric key) -> resolved static fluid typepath, or dynamic reagent
/// typepath. An alist: numeric keys are legal and fast, but it cannot be
/// for-looped or indexed positionally.
GLOBAL_VAR_INIT(vn_liquid_mat_path_by_id, alist())
/// dynamic reagent typepath string -> TRUE once on-demand registration has
/// failed for it (budget exhausted, etc.) - stops repeat attempts.
GLOBAL_LIST_EMPTY(vn_liquid_mat_failed)

/// Native mat id for a fluid datum/typepath. Static /datum/liquid subtypes
/// are keyed by typepath and registered by NativeInit at boot; a miss just
/// returns 0. Dynamic reagent liquids (bare /datum/liquid instances with
/// .reagent set) are keyed by their reagent typepath and registered
/// on-demand the first time an instance is seen.
/proc/vn_fluid_mat_id(fluid_or_path)
	var/datum/liquid/fluid = ispath(fluid_or_path) ? null : fluid_or_path
	if(fluid && fluid.type == /datum/liquid && fluid.reagent)
		return vn_fluid_dynamic_mat_id(fluid.reagent)
	var/path = fluid ? fluid.type : fluid_or_path
	return GLOB.vn_liquid_mats["[path]"] || 0

/// Looks up (or registers) the native mat id for a dynamic reagent liquid,
/// keyed by reagent typepath. Never registers before the native fluid
/// engine is live. Returns 0 when unregistered: not live yet, budget
/// exhausted, or a cached prior failure for this reagent.
/proc/vn_fluid_dynamic_mat_id(reagent_path)
	var/key = "[reagent_path]"
	var/id = GLOB.vn_liquid_mats[key]
	if(id)
		return id
	if(GLOB.vn_liquid_mat_failed[key])
		return 0
	if(!SSliquid?.vn_native_fluids_ready)
		return 0

	var/result = vn_fluid_register_mat(key)
	if(!isnum(result))
		vn_check_result(result, "fluid_register_mat_dynamic")
		GLOB.vn_liquid_mat_failed[key] = TRUE
		log_world("verdant_native: dynamic liquid mat registration failed for [key] - staying DM-only for this reagent")
		return 0

	GLOB.vn_liquid_mats[key] = result
	GLOB.vn_liquid_mat_path_by_id[result] = reagent_path
	var/rgb_int = vn_color_rgb(initial(reagent_path:color))
	if(rgb_int)
		vn_fluid_mat_color(result, rgb_int)
	return result

/// "#RRGGBB(AA)" color string -> 0xRRGGBB int for the engine's blend math;
/// 0 for anything unparsable.
/proc/vn_color_rgb(color)
	if(!istext(color) || length(color) < 7 || copytext(color, 1, 2) != "#")
		return 0
	return hex2num(copytext(color, 2, 8))

/// Queues an edit for the native fluid engine; flushed by SSliquid's fire.
/// No-op unless native fluids are live, so writers can call unconditionally.
/proc/vn_fluid_queue(op, turf/T, a = 0, b = 0)
	if(!SSliquid?.vn_native_fluids_ready || !istype(T))
		return
	var/list/q = SSliquid.vn_edit_queue
	q += op
	q += T.x
	q += T.y
	q += T.z
	q += a
	q += b

// --- result handling ---

/// Returns TRUE if the result is usable; on ERR logs it and, for safe_mode,
/// permanently routes back to the DM implementations for this round.
/// A null result means the export itself is missing (DLL/DM version skew) -
/// logged and treated as failure, since call_ext returns null silently.
/proc/vn_check_result(result, context = "native")
	if(isnull(result))
		log_world("verdant_native [context]: null result - export missing? (DLL older than the DM API?)")
		return FALSE
	if(!VN_IS_ERR(result))
		return TRUE
	log_world("verdant_native [context]: [result]")
	if(findtext(result, "ERR:safe_mode", 1, 14) || findtext(result, "ERR:exception", 1, 14))
		GLOB.vn_safe_mode = TRUE
		GLOB.vn_available = FALSE
		log_world("verdant_native: SAFE MODE - native offload disabled for this round")
		message_admins("verdant_native entered safe mode; native offload disabled. ([result])")
	return FALSE

// --- lifecycle (called from SSnative and world procs) ---

/// Handshake + init. Sets GLOB.vn_available. Safe to call more than once.
/proc/vn_startup()
	GLOB.vn_available = FALSE
	GLOB.vn_safe_mode = FALSE

	var/version = vn_version()
	if(isnull(version) || !istext(version) || VN_IS_ERR(version))
		log_world("verdant_native: library unavailable ([isnull(version) ? "null" : version]) - native offload disabled")
		return FALSE
	if(!findtext(version, "abi=[VERDANT_ABI];"))
		log_world("verdant_native: ABI mismatch (want [VERDANT_ABI], got \"[version]\") - native offload disabled")
		return FALSE

	var/result = vn_init(json_encode(list(
		"maxx" = world.maxx,
		"maxy" = world.maxy,
		"maxz" = world.maxz,
		"tick_lag" = world.tick_lag,
	)))
	if(result != "ok")
		log_world("verdant_native: init failed ([result]) - native offload disabled")
		return FALSE

	GLOB.vn_available = TRUE
	log_world("verdant_native: initialized ([version])")
	return TRUE

/// Called from /world/Del and /world/Reboot. Never raises.
/proc/vn_world_shutdown()
	if(!GLOB.vn_available)
		return
	GLOB.vn_available = FALSE
	vn_shutdown()

// --- selftest (Advanced Proc Call or the SSnative debug verb) ---

/// Round-trips data through every call shape and times the bulk paths.
/// Sleeps; do not call from a fire().
/proc/vn_selftest(list_size = 10000, str_kb = 64, reps = 10)
	var/list/out = list()
	out += "version: [vn_version()]"
	out += "status: [vn_status()]"

	// float-list round trip
	var/list/payload = new /list(list_size)
	for(var/i in 1 to list_size)
		payload[i] = i % 100
	var/t0 = REALTIMEOFDAY
	var/list/echoed
	for(var/r in 1 to reps)
		echoed = vn_echo_list(payload)
	var/t1 = REALTIMEOFDAY
	if(VN_IS_ERR(echoed))
		out += "echo_list: [echoed]"
	else
		out += "echo_list: [list_size] floats x[reps] in [t1 - t0]ds (n=[echoed[1]], fnv=[echoed[2]])"

	// bulk-string round trip (the grid-row encoding path)
	var/chunk = ""
	for(var/i in 1 to 64)
		chunk += "0123456789abcdef"	// 1 KB
	var/str = ""
	for(var/i in 1 to str_kb)
		str += chunk
	t0 = REALTIMEOFDAY
	var/sres
	for(var/r in 1 to reps)
		sres = vn_echo_str(str)
	t1 = REALTIMEOFDAY
	out += "echo_str: [str_kb]KB x[reps] in [t1 - t0]ds ([sres])"

	// async pipeline
	t0 = REALTIMEOFDAY
	var/ares = vn_echo_await(100)
	t1 = REALTIMEOFDAY
	out += "echo_await(100ms): \"[ares]\" in [t1 - t0]ds"

	out += "status: [vn_status()]"
	var/report = out.Join("\n")
	log_world("vn_selftest:\n[report]")
	return report
