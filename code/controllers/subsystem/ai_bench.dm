#define VNA_TICKS 60
#define VNA_TREE_TYPES list(	/datum/behavior_tree/node/selector/behemoth_tree, /datum/behavior_tree/node/selector/bigrat_tree, 	/datum/behavior_tree/node/selector/chicken_tree, /datum/behavior_tree/node/selector/colossus_tree, 	/datum/behavior_tree/node/selector/deepone_melee_tree, /datum/behavior_tree/node/selector/deepone_ranged_tree, 	/datum/behavior_tree/node/selector/direbear_tree, /datum/behavior_tree/node/selector/dryad_tree, 	/datum/behavior_tree/node/selector/generic_friendly_tree, /datum/behavior_tree/node/selector/generic_hostile_tree, 	/datum/behavior_tree/node/selector/generic_hungry_hostile_tree, /datum/behavior_tree/node/selector/goblin_tree, 	/datum/behavior_tree/node/selector/haunt_tree, /datum/behavior_tree/node/selector/hostile_humanoid_tree, 	/datum/behavior_tree/node/selector/insane_clown_tree, /datum/behavior_tree/node/selector/lamia_tree, 	/datum/behavior_tree/node/selector/leyline_tree, /datum/behavior_tree/node/selector/mimic_tree, 	/datum/behavior_tree/node/selector/mossback_tree, /datum/behavior_tree/node/selector/obelisk_tree, 	/datum/behavior_tree/node/selector/skeleton_spear_tree, /datum/behavior_tree/node/selector/skeleton_tree, 	/datum/behavior_tree/node/selector/volf_tree)
#define VNA_THINK_ITERS 200

GLOBAL_VAR_INIT(vna_started, FALSE)
GLOBAL_LIST_EMPTY(vna_pop)

/// generic_hostile_tree does NOT export natively, so the default bench dummy can never
/// exercise the native VM. This one uses an exporting tree so native-vs-DM is measurable.
/mob/living/simple_animal/vna_native_dummy
	name = "bench native dummy"
	icon_state = "chicken"
	density = FALSE
	wander = 0
	stop_automated_movement = 1

/mob/living/simple_animal/vna_native_dummy/Initialize(mapload)
	. = ..()
	init_ai_root(/datum/behavior_tree/node/selector/generic_hostile_tree)

/proc/vna_bench_requested()
	return world.params["vn_ai_bench"] || world.GetConfig("env", "VN_AI_BENCH") || fexists("data/vn_ai_bench.flag")

/proc/vna_cfg(key, pname, envname, default)
	if(fexists("data/vn_ai_config.json"))
		var/list/cfg = json_decode(file2text("data/vn_ai_config.json"))
		if(islist(cfg) && cfg[key])
			return cfg[key]
	return vns_cfg(pname, envname, default)

/proc/vna_log(msg)
	log_world(msg)
	rustg_file_append("[msg]\n", "data/vn_ai_progress.log")

/proc/vna_teardown()
	for(var/mob/living/M as anything in GLOB.vna_pop)
		if(M && !QDELETED(M))
			SSai.Unregister(M)
			GLOB.npc_list -= M
			GLOB.player_list -= M
			qdel(M)
	GLOB.vna_pop.Cut()

/proc/vna_build_population(count, turf/center, radius)
	. = list()
	for(var/i in 1 to count)
		var/turf/T = locate(
			clamp(center.x + rand(-radius, radius), 2, world.maxx - 1),
			clamp(center.y + rand(-radius, radius), 2, world.maxy - 1),
			center.z)
		if(!istype(T, /turf/open) || isopenspace(T))
			continue
		var/mob/living/simple_animal/vna_native_dummy/D = new(T)
		GLOB.npc_list |= D
		SSquadtree.RefreshKinds(D)
		SSai.Register(D)
		GLOB.vna_pop += D
		. += D
		if(i % 50 == 0)
			sleep(world.tick_lag)

/// Every active mob is forced think-eligible so a tick measures the full population.
/proc/vna_force_think_eligible(list/mobs)
	for(var/mob/living/M as anything in mobs)
		if(!M.ai_root)
			continue
		M.ai_root.next_think_tick = 0
		M.ai_root.next_move_tick = 0

/proc/vna_wiring()
	var/exported = 0
	var/failed = 0
	for(var/key in GLOB.vn_bt_tree_ids)
		if(GLOB.vn_bt_tree_ids[key])
			exported++
		else
			failed++
	return list(
		"vn_bt_native" = GLOB.vn_bt_native ? 1 : 0,
		"vn_ok" = VN_OK ? 1 : 0,
		"mirror_loaded" = SSnative?.mirror_loaded ? 1 : 0,
		"trees_exported" = exported,
		"trees_failed_dm_fallback" = failed,
		"registered_agents" = length(SSai.vn_mobs),
		"active_mobs" = length(SSai.active_mobs),
		"sleeping_mobs" = length(SSai.sleeping_mobs),
	)

/// Times SSai.fire() itself. Actions and the movement subtree are dispatched with
/// INVOKE_ASYNC, so their cost lands AFTER fire() returns - see vna_bench_tick.
/// force=FALSE leaves the natural think/move cadence in place, which is what a
/// live round looks like; forcing every mob eligible every tick is a worst case.
/proc/vna_time_fire(ticks, list/mobs, force = TRUE)
	var/list/per_tick = list()
	for(var/i in 1 to ticks)
		if(force)
			vna_force_think_eligible(mobs)
		rustg_time_reset("vnafire")
		vnq_fire_full(SSai)
		per_tick += rustg_time_microseconds("vnafire")
	return vnq_summarise_steps(per_tick)

/// Times fire() plus the async drain: sleep(0) lets every INVOKE_ASYNC callback run,
/// so this captures the movement subtree and action leaves that fire() hides.
/proc/vna_time_tick_total(ticks, list/mobs)
	var/list/per_tick = list()
	for(var/i in 1 to ticks)
		vna_force_think_eligible(mobs)
		rustg_time_reset("vnatick")
		vnq_fire_full(SSai)
		sleep(0)
		per_tick += rustg_time_microseconds("vnatick")
	return vnq_summarise_steps(per_tick)

/// Synchronous per-mob evaluation, bypassing INVOKE_ASYNC entirely.
/proc/vna_time_think(list/mobs, iters)
	. = list()
	var/n = length(mobs)
	if(!n)
		return
	var/sink = 0

	rustg_time_reset("vnat")
	for(var/i in 1 to iters)
		for(var/mob/living/M as anything in mobs)
			if(M.ai_root)
				sink++
	.["loop_only_ns_per_mob"] = rustg_time_microseconds("vnat") * 1000 / (iters * n)

	rustg_time_reset("vnat")
	for(var/i in 1 to iters)
		for(var/mob/living/M as anything in mobs)
			var/datum/behavior_tree/node/parallel/root/root = M.ai_root
			if(root?.move_node)
				root.move_node.evaluate(M, root.target, root.blackboard)
	.["move_subtree_us_per_mob"] = rustg_time_microseconds("vnat") / (iters * n)

	rustg_time_reset("vnat")
	for(var/i in 1 to iters)
		for(var/mob/living/M as anything in mobs)
			var/datum/behavior_tree/node/parallel/root/root = M.ai_root
			if(root?.main_node)
				root.main_node.evaluate(M, root.target, root.blackboard)
	.["main_subtree_us_per_mob"] = rustg_time_microseconds("vnat") / (iters * n)

	rustg_time_reset("vnat")
	for(var/i in 1 to iters)
		for(var/mob/living/M as anything in mobs)
			M.RunAI()
	.["runai_full_us_per_mob"] = rustg_time_microseconds("vnat") / (iters * n)
	if(sink < 0)
		.["sink"] = sink

/mob/proc/vna_noop_ai()
	return TRUE

/// Prices INVOKE_ASYNC against a direct call and against the real query, so the
/// ablation differences are confirmed rather than inferred.
/proc/vna_micro(list/mobs, iters)
	. = list()
	var/n = length(mobs)
	if(!n)
		return
	var/sink = 0

	rustg_time_reset("vnam")
	for(var/i in 1 to iters)
		for(var/mob/living/M as anything in mobs)
			sink += M.vna_noop_ai()
	.["direct_call_ns"] = rustg_time_microseconds("vnam") * 1000 / (iters * n)

	rustg_time_reset("vnam")
	for(var/i in 1 to iters)
		for(var/mob/living/M as anything in mobs)
			INVOKE_ASYNC(M, TYPE_PROC_REF(/mob, vna_noop_ai))
	.["invoke_async_ns"] = rustg_time_microseconds("vnam") * 1000 / (iters * n)

	rustg_time_reset("vnam")
	for(var/i in 1 to iters)
		for(var/mob/living/M as anything in mobs)
			var/turf/T = get_turf(M)
			sink += length(SSquadtree.players_in_range(M.qt_range, T.z, QTREE_SCAN_MOBS|QTREE_EXCLUDE_OBSERVER))
	.["players_in_range_ns"] = rustg_time_microseconds("vnam") * 1000 / (iters * n)

	rustg_time_reset("vnam")
	for(var/i in 1 to iters)
		for(var/mob/living/M as anything in mobs)
			sink += get_turf(M) ? 1 : 0
	.["get_turf_ns"] = rustg_time_microseconds("vnam") * 1000 / (iters * n)

	rustg_time_reset("vnam")
	for(var/i in 1 to iters)
		for(var/mob/living/M as anything in mobs)
			sink += M.incapacitated(ignore_restraints = 1) ? 1 : 0
	.["incapacitated_ns"] = rustg_time_microseconds("vnam") * 1000 / (iters * n)

	rustg_time_reset("vnam")
	for(var/i in 1 to iters)
		for(var/mob/living/M as anything in mobs)
			sink += (M.stat == DEAD) ? 1 : 0
	.["stat_read_ns"] = rustg_time_microseconds("vnam") * 1000 / (iters * n)

	rustg_time_reset("vnam")
	for(var/i in 1 to iters)
		for(var/mob/living/M as anything in mobs)
			for(var/mob/living/L in view(7, M))
				sink++
	.["view7_mobs_ns"] = rustg_time_microseconds("vnam") * 1000 / (iters * n)

	rustg_time_reset("vnam")
	for(var/i in 1 to iters)
		for(var/mob/living/M as anything in mobs)
			for(var/mob/living/L in oview(9, M))
				sink++
	.["oview9_mobs_ns"] = rustg_time_microseconds("vnam") * 1000 / (iters * n)

	rustg_time_reset("vnam")
	for(var/i in 1 to iters)
		for(var/mob/living/M as anything in mobs)
			sink += length(view(7, M))
	.["view7_all_ns"] = rustg_time_microseconds("vnam") * 1000 / (iters * n)

	var/datum/shape/rectangle/probe = RECT(1, 1, 14, 14)
	rustg_time_reset("vnam")
	for(var/i in 1 to iters)
		for(var/mob/living/M as anything in mobs)
			var/turf/T = get_turf(M)
			if(!T)
				continue
			probe.Recenter(T.x, T.y)
			for(var/mob/living/L as anything in SSquadtree.npcs_in_range(probe, T.z))
				sink++
	.["qt_npcs_r7_ns"] = rustg_time_microseconds("vnam") * 1000 / (iters * n)

	rustg_time_reset("vnam")
	for(var/i in 1 to iters)
		for(var/mob/living/M as anything in mobs)
			var/turf/T = get_turf(M)
			if(!T)
				continue
			probe.Recenter(T.x, T.y)
			for(var/mob/living/L as anything in SSquadtree.npcs_in_range(probe, T.z))
				if(!los_blocked(M, L))
					sink++
	.["qt_npcs_r7_los_ns"] = rustg_time_microseconds("vnam") * 1000 / (iters * n)
	if(sink < 0)
		.["sink"] = sink

/// Confirms the maintained nearby_players counters match a fresh query.
/proc/vna_verify_counters(list/mobs)
	var/mismatches = 0
	var/checked = 0
	var/worst = 0
	for(var/mob/living/M as anything in mobs)
		var/turf/T = get_turf(M)
		if(!T)
			continue
		checked++
		var/actual = length(SSquadtree.players_in_range(M.qt_range, T.z, QTREE_SCAN_MOBS|QTREE_EXCLUDE_OBSERVER))
		if(M.nearby_players != actual)
			mismatches++
			worst = max(worst, abs(M.nearby_players - actual))
	return list("checked" = checked, "mismatches" = mismatches, "worst_delta" = worst)

/// Instantiates every AI tree wired to a mob and tests native exportability.
/// Answers whether the native BT offload applies to anything in a live round.
/proc/vna_tree_export_audit()
	. = list()
	var/list/trees = list()
	for(var/T in subtypesof(/datum/behavior_tree/node/parallel/root))
		trees += T
	var/list/roots = list()
	for(var/mob/living/M as anything in GLOB.vna_pop)
		if(M.ai_root?.tree_typepath)
			roots |= M.ai_root.tree_typepath
	var/exported = 0
	var/failed = 0
	var/list/detail = list()
	for(var/tp in VNA_TREE_TYPES)
		var/datum/behavior_tree/node/tree_root = new tp()
		var/list/out = list()
		var/list/refs = list()
		var/ok = vn_export_node(tree_root, out, refs)
		detail += list(list("tree" = "[tp]", "exports" = ok ? 1 : 0, "nodes" = length(refs)))
		if(ok)
			exported++
		else
			failed++
		qdel(tree_root)
	.["exported"] = exported
	.["failed"] = failed
	.["detail"] = detail

/proc/vna_scenario(count, radius, player_n, label)
	vna_teardown()
	var/turf/center = vnq_placement_turf("scattered")
	if(!center)
		return list("error" = "no spawn turf")
	var/list/mobs = vna_build_population(count, center, radius)
	if(!length(mobs))
		return list("error" = "no mobs")

	for(var/i in 1 to player_n)
		var/turf/T = locate(clamp(center.x + rand(-3, 3), 2, world.maxx - 1), clamp(center.y + rand(-3, 3), 2, world.maxy - 1), center.z)
		if(!T)
			continue
		var/mob/living/carbon/human/species/human/northern/P = new(T)
		GLOB.player_list |= P
		SSquadtree.RefreshKinds(P)
		GLOB.vna_pop += P
	sleep(world.tick_lag)

	var/list/row = list(
		"label" = label,
		"mobs" = length(mobs),
		"players_nearby" = player_n,
		"wiring" = vna_wiring(),
	)

	GLOB.vn_bt_native = FALSE
	SSai.vna_skip = 0
	row["fire_dm"] = vna_time_fire(VNA_TICKS, mobs)

	row["fire_natural_cadence"] = vna_time_fire(VNA_TICKS, mobs, FALSE)

	GLOB.vn_action_us = list()
	GLOB.vn_action_n = list()
	GLOB.vn_action_profile = TRUE
	vna_time_fire(VNA_TICKS, mobs)
	GLOB.vn_action_profile = FALSE
	var/list/act = list()
	for(var/k in GLOB.vn_action_us)
		act += list(list("action" = k, "us" = GLOB.vn_action_us[k], "n" = GLOB.vn_action_n[k]))
	row["action_profile"] = act

	GLOB.vn_ai_view_calls = 0
	row["fire_view_on"] = vna_time_fire(VNA_TICKS, mobs)
	var/view_calls = GLOB.vn_ai_view_calls
	GLOB.vn_ai_view_off = TRUE
	row["fire_view_off"] = vna_time_fire(VNA_TICKS, mobs)
	GLOB.vn_ai_view_off = FALSE
	row["view_calls_per_mob_tick"] = view_calls / max(length(mobs) * VNA_TICKS, 1)

	GLOB.vn_move_sync = FALSE
	row["fire_move_async"] = vna_time_fire(VNA_TICKS, mobs)
	row["tick_move_async"] = vna_time_tick_total(VNA_TICKS, mobs)
	GLOB.vn_move_sync = TRUE
	row["fire_move_sync"] = vna_time_fire(VNA_TICKS, mobs)
	row["tick_move_sync"] = vna_time_tick_total(VNA_TICKS, mobs)

	SSai.vna_legacy_query = TRUE
	row["fire_legacy_query"] = vna_time_fire(VNA_TICKS, mobs)
	SSai.vna_legacy_query = FALSE
	row["counter_check"] = vna_verify_counters(mobs)

	SSai.vna_skip = VNA_SKIP_DISPATCH
	row["fire_no_dispatch"] = vna_time_fire(VNA_TICKS, mobs)
	SSai.vna_skip = VNA_SKIP_DISPATCH | VNA_SKIP_QUERY
	row["fire_no_dispatch_no_query"] = vna_time_fire(VNA_TICKS, mobs)
	SSai.vna_skip = VNA_SKIP_QUERY
	row["fire_no_query"] = vna_time_fire(VNA_TICKS, mobs)
	SSai.vna_skip = VNA_SKIP_DISPATCH | VNA_SKIP_QUERY | VNA_SKIP_SQUADS
	row["fire_loop_only"] = vna_time_fire(VNA_TICKS, mobs)
	SSai.vna_skip = 0
	row["tick_total_dm"] = vna_time_tick_total(VNA_TICKS, mobs)
	row["think_dm"] = vna_time_think(mobs, VNA_THINK_ITERS)
	row["micro"] = vna_micro(mobs, 40)

	if(VN_OK && SSnative?.mirror_loaded)
		GLOB.vn_bt_native = TRUE
		row["fire_native"] = vna_time_fire(VNA_TICKS, mobs)
		row["tick_total_native"] = vna_time_tick_total(VNA_TICKS, mobs)
		row["wiring_native"] = vna_wiring()
		GLOB.vn_bt_native = FALSE

	vna_teardown()
	return row

/proc/vna_run_bench()
	set waitfor = FALSE
	var/tag = vna_cfg("tag", "vn_ai_tag", "VN_AI_TAG", "ai")
	fdel("data/vn_ai_progress.log")
	vna_log("AIBENCH start tag=[tag] maxx=[world.maxx] maxy=[world.maxy] tick_lag=[world.tick_lag]")

	// SSnative loads the map mirror incrementally and only then sets mirror_loaded,
	// which gates the native BT path. Freezing it first would make native unmeasurable.
	if(GLOB.vn_available && !GLOB.vn_safe_mode)
		var/pumps = 0
		var/old_limit = Master.current_ticklimit
		while(!SSnative.mirror_loaded && pumps < 20000)
			Master.current_ticklimit = 100000
			SSnative.BulkLoadGrid()
			Master.current_ticklimit = old_limit
			pumps++
			if(!SSnative.grid_inited && pumps > 3)
				break
			if(pumps % 20 == 0)
				sleep(world.tick_lag)
		vna_log("AIBENCH native mirror pumps=[pumps] mirror_loaded=[SSnative.mirror_loaded ? 1 : 0] vn_available=[GLOB.vn_available ? 1 : 0] safe_mode=[GLOB.vn_safe_mode ? 1 : 0] grid_inited=[SSnative.grid_inited ? 1 : 0] init_complete=[Master.init_complete ? 1 : 0] can_fire=[SSnative.can_fire ? 1 : 0] load_z=[SSnative.load_z] load_y=[SSnative.load_y] maxy=[world.maxy]")
	else
		vna_log("AIBENCH native unavailable: vn_available=[GLOB.vn_available ? 1 : 0] safe_mode=[GLOB.vn_safe_mode ? 1 : 0]")

	vnq_freeze_world()
	SSai.wait = 100000
	SSai.next_fire = world.time + 1000000
	sleep(world.tick_lag * 3)

	var/list/audit = vna_tree_export_audit()
	vna_log("AIBENCH TREE EXPORT AUDIT exported=[audit["exported"]] failed=[audit["failed"]]")
	for(var/list/d in audit["detail"])
		vna_log("AIBENCH   tree [d["tree"]] exports=[d["exports"]] nodes=[d["nodes"]]")

	var/list/results = list("meta" = list("tag" = tag, "ticks" = VNA_TICKS, "think_iters" = VNA_THINK_ITERS), "scenarios" = list(), "tree_audit" = audit)

	for(var/list/spec in list(list(50, 12, 0, "idle_50"), list(300, 30, 1, "engaged_300"), list(500, 40, 2, "engaged_500"), list(800, 52, 3, "engaged_800")))
		var/list/row = vna_scenario(spec[1], spec[2], spec[3], spec[4])
		results["scenarios"] += list(row)
		var/list/w = row["wiring"]
		var/list/fd = row["fire_dm"]
		var/list/td = row["tick_total_dm"]
		var/list/th = row["think_dm"]
		var/list/fnd = row["fire_no_dispatch"]
		var/list/fndq = row["fire_no_dispatch_no_query"]
		var/list/flo = row["fire_loop_only"]
		var/list/mi = row["micro"]
		var/list/cc = row["counter_check"]
		var/list/flq = row["fire_legacy_query"]
		var/list/fma = row["fire_move_async"]
		var/list/fms = row["fire_move_sync"]
		var/list/tma = row["tick_move_async"]
		var/list/tms = row["tick_move_sync"]
		vna_log("AIBENCH [row["label"]] MOVE A/B mobs=[row["mobs"]] fire async=[fma?["mean_us"]] sync=[fms?["mean_us"]] | tick async=[tma?["mean_us"]] sync=[tms?["mean_us"]]")
		vna_log("AIBENCH [row["label"]] COUNTERS checked=[cc?["checked"]] mismatches=[cc?["mismatches"]] worst=[cc?["worst_delta"]] | fire legacy_query=[flq?["mean_us"]] maintained=[fd?["mean_us"]]")
		var/list/von = row["fire_view_on"]
		var/list/voff = row["fire_view_off"]
		var/list/nc = row["fire_natural_cadence"]
		vna_log("AIBENCH [row["label"]] NATURAL CADENCE mobs=[row["mobs"]] fire=[nc?["mean_us"]]us (forced-eligible fire=[fd?["mean_us"]]us)")
		var/list/ap = row["action_profile"]
		if(length(ap))
			var/list/sorted = list()
			for(var/list/e in ap)
				sorted += list(e)
			for(var/i in 1 to length(sorted))
				for(var/j in 1 to length(sorted) - i)
					var/list/x = sorted[j]
					var/list/y = sorted[j + 1]
					if(x["us"] < y["us"])
						sorted[j] = y
						sorted[j + 1] = x
			var/shown = 0
			for(var/list/e in sorted)
				shown++
				if(shown > 10)
					break
				vna_log("AIBENCH [row["label"]] ACTION [e["action"]] total=[e["us"]]us calls=[e["n"]] avg=[e["n"] ? round(e["us"] * 1000 / e["n"]) : 0]ns")
		vna_log("AIBENCH [row["label"]] VIEW ABLATION mobs=[row["mobs"]] with_view=[von?["mean_us"]] without_view=[voff?["mean_us"]] calls/mob/tick=[row["view_calls_per_mob_tick"]]")
		vna_log("AIBENCH [row["label"]] GUARDCOST incapacitated=[mi?["incapacitated_ns"]]ns stat_read=[mi?["stat_read_ns"]]ns per mob")
		vna_log("AIBENCH [row["label"]] VIEWCOST view7_mobs=[mi?["view7_mobs_ns"]] oview9_mobs=[mi?["oview9_mobs_ns"]] view7_all=[mi?["view7_all_ns"]] qt_r7=[mi?["qt_npcs_r7_ns"]] qt_r7_los=[mi?["qt_npcs_r7_los_ns"]] ns/mob")
		vna_log("AIBENCH [row["label"]] MICRO direct=[mi?["direct_call_ns"]]ns invoke_async=[mi?["invoke_async_ns"]]ns players_in_range=[mi?["players_in_range_ns"]]ns get_turf=[mi?["get_turf_ns"]]ns per mob")
		vna_log("AIBENCH [row["label"]] ABLATION full=[fd?["mean_us"]] no_dispatch=[fnd?["mean_us"]] no_disp_no_query=[fndq?["mean_us"]] loop_only=[flo?["mean_us"]] us/tick over [row["mobs"]] mobs")
		vna_log("AIBENCH [row["label"]] mobs=[row["mobs"]] native_trees=[w?["trees_exported"]]/[(w?["trees_exported"] || 0) + (w?["trees_failed_dm_fallback"] || 0)] fire=[fd?["mean_us"]]us tick_total=[td?["mean_us"]]us runai=[th?["runai_full_us_per_mob"]]us/mob move=[th?["move_subtree_us_per_mob"]] main=[th?["main_subtree_us_per_mob"]]")
		sleep(world.tick_lag)

	fdel("data/vn_ai_results_[tag].json")
	text2file(json_encode(results), "data/vn_ai_results_[tag].json")
	vna_log("AIBENCH COMPLETE")

#undef VNA_TICKS
#undef VNA_THINK_ITERS
