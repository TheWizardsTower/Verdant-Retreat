#define VNQ_WARMUP_PUMPS 3
#define VNQ_PUMPS 40
#define VNQ_QUERIES 300
#define VNQ_MICRO_ITERS 100000
#define VNQ_MOVES 1500
#define VNQ_CADENCE_TICKS 160
#define VNQ_CLUSTER_SPOTS 6
#define VNQ_CLUSTER_RADIUS 12
#define VNQ_SPAWN_TURF_POOL 4000
#define VNQ_PLAYERS 40

GLOBAL_VAR_INIT(vnq_started, FALSE)
GLOBAL_LIST_EMPTY(vnq_pop)
GLOBAL_LIST_EMPTY(vnq_cluster_centers)
GLOBAL_LIST_EMPTY(vnq_spawn_turfs)

/datum/controller/subsystem/stress_tests
	var/vnq_nodes = 0
	var/vnq_intersects = 0
	var/vnq_contains = 0
	var/vnq_results = 0

/mob/living/simple_animal/vnq_dummy
	name = "bench dummy"
	icon_state = "chicken"
	density = FALSE
	wander = 0
	stop_automated_movement = 1

/mob/living/simple_animal/vnq_ai_dummy
	name = "bench ai dummy"
	icon_state = "chicken"
	density = FALSE
	wander = 0
	stop_automated_movement = 1

/mob/living/simple_animal/vnq_ai_dummy/Initialize(mapload)
	. = ..()
	init_ai_root(/datum/behavior_tree/node/selector/generic_hostile_tree)

/proc/vnq_bench_requested()
	return world.params["vn_qt_bench"] || world.GetConfig("env", "VN_QT_BENCH") || fexists("data/vn_qt_bench.flag")

/proc/vnq_cfg(key, pname, envname, default)
	if(fexists("data/vn_qt_config.json"))
		var/list/cfg = json_decode(file2text("data/vn_qt_config.json"))
		if(islist(cfg) && cfg[key])
			return cfg[key]
	return vns_cfg(pname, envname, default)

/proc/vnq_log(msg)
	log_world(msg)
	rustg_file_append("[msg]\n", "data/vn_qt_progress.log")

/proc/vnq_fire_full(datum/controller/subsystem/SS)
	var/old_limit = Master.current_ticklimit
	var/old_state = SS.state
	Master.current_ticklimit = 100000
	SS.state = SS_RUNNING
	SS.fire(FALSE)
	SS.state = old_state
	Master.current_ticklimit = old_limit

/proc/vnq_fire_budgeted(datum/controller/subsystem/quadtree/SS, budget, resumed)
	var/old_limit = Master.current_ticklimit
	var/old_state = SS.state
	Master.current_ticklimit = budget
	SS.state = SS_RUNNING
	SS.fire(resumed)
	. = (SS.state == SS_PAUSED)
	SS.state = old_state
	Master.current_ticklimit = old_limit

/proc/vnq_freeze_world()
	for(var/datum/controller/subsystem/SS as anything in Master.subsystems)
		if(SS == SSstress_tests || SS == SSgarbage)
			continue
		SS.wait = 100000
		SS.next_fire = world.time + 1000000
	Master.sleep_offline_after_initializations = FALSE
	world.sleep_offline = FALSE

// ==============================================================================
// POPULATION
// ==============================================================================

/proc/vnq_collect_spawn_turfs()
	if(length(GLOB.vnq_spawn_turfs))
		return
	for(var/try_i in 1 to 60000)
		if(length(GLOB.vnq_spawn_turfs) >= VNQ_SPAWN_TURF_POOL)
			break
		var/turf/T = locate(rand(5, world.maxx - 5), rand(5, world.maxy - 5), rand(1, world.maxz))
		if(!istype(T, /turf/open) || isopenspace(T))
			continue
		GLOB.vnq_spawn_turfs += T

/proc/vnq_cluster_center()
	if(!length(GLOB.vnq_cluster_centers))
		vnq_collect_spawn_turfs()
		for(var/i in 1 to VNQ_CLUSTER_SPOTS)
			if(length(GLOB.vnq_spawn_turfs))
				GLOB.vnq_cluster_centers += pick(GLOB.vnq_spawn_turfs)
	return length(GLOB.vnq_cluster_centers) ? pick(GLOB.vnq_cluster_centers) : null

/proc/vnq_placement_turf(distribution)
	vnq_collect_spawn_turfs()
	if(!length(GLOB.vnq_spawn_turfs))
		return null
	if(distribution != "clustered")
		return pick(GLOB.vnq_spawn_turfs)
	var/turf/center = vnq_cluster_center()
	if(!center)
		return null
	for(var/try_i in 1 to 12)
		var/turf/T = locate(
			clamp(center.x + rand(-VNQ_CLUSTER_RADIUS, VNQ_CLUSTER_RADIUS), 2, world.maxx - 1),
			clamp(center.y + rand(-VNQ_CLUSTER_RADIUS, VNQ_CLUSTER_RADIUS), 2, world.maxy - 1),
			center.z)
		if(istype(T, /turf/open) && !isopenspace(T))
			return T
	return center

/proc/vnq_build_population(count, carbon_share, distribution, player_n = 0)
	vnq_teardown_population()
	for(var/i in 1 to player_n)
		var/turf/T = vnq_placement_turf(distribution)
		if(!T)
			continue
		var/mob/living/carbon/human/species/human/northern/P = new(T)
		GLOB.player_list |= P
		SSquadtree.RefreshKinds(P)
		GLOB.vnq_pop += P
		if(i % 50 == 0)
			sleep(world.tick_lag)
	if(count <= 0)
		return length(GLOB.vnq_pop)
	var/carbon_n = round(count * carbon_share)
	var/simple_n = count - carbon_n
	for(var/i in 1 to simple_n)
		var/turf/T = vnq_placement_turf(distribution)
		if(!T)
			continue
		var/mob/living/simple_animal/vnq_dummy/D = new(T)
		GLOB.npc_list |= D
		SSquadtree.RefreshKinds(D)
		GLOB.vnq_pop += D
		if(i % 200 == 0)
			sleep(world.tick_lag)
	for(var/i in 1 to carbon_n)
		var/turf/T = vnq_placement_turf(distribution)
		if(!T)
			continue
		var/mob/living/carbon/human/species/human/northern/H = new(T)
		GLOB.npc_list |= H
		SSquadtree.RefreshKinds(H)
		GLOB.vnq_pop += H
		if(i % 50 == 0)
			sleep(world.tick_lag)
	return length(GLOB.vnq_pop)

/proc/vnq_teardown_population()
	for(var/mob/living/M as anything in GLOB.vnq_pop)
		if(M && !QDELETED(M))
			GLOB.npc_list -= M
			GLOB.player_list -= M
			qdel(M)
	GLOB.vnq_pop.Cut()

// ==============================================================================
// TREE SHAPE PROBE
// ==============================================================================

/datum/quadtree/proc/vnq_walk(depth, list/stats)
	stats["nodes"] += 1
	stats["max_depth"] = max(stats["max_depth"], depth)
	var/here = length(players) + length(npc_carbons) + length(npc_simples) + length(hearables)
	stats["entries"] += here
	if(here)
		stats["occupied_nodes"] += 1
		stats["max_node_entries"] = max(stats["max_node_entries"], here)
	if(here > QUADTREE_CAPACITY)
		stats["overflow_nodes"] += 1
		stats["overflow_entries"] += here - QUADTREE_CAPACITY
	if(!is_divided)
		return
	stats["divided_nodes"] += 1
	nw_branch.vnq_walk(depth + 1, stats)
	ne_branch.vnq_walk(depth + 1, stats)
	sw_branch.vnq_walk(depth + 1, stats)
	se_branch.vnq_walk(depth + 1, stats)

/proc/vnq_tree_stats(list/trees)
	. = list("nodes" = 0, "max_depth" = 0, "entries" = 0, "occupied_nodes" = 0,
		"max_node_entries" = 0, "overflow_nodes" = 0, "overflow_entries" = 0, "divided_nodes" = 0)
	if(!islist(trees))
		return
	for(var/datum/quadtree/Q in trees)
		Q.vnq_walk(1, .)

// ==============================================================================
// INSTRUMENTED QUERY
// ==============================================================================

/datum/quadtree/proc/vnq_count_query_npcs(datum/shape/range)
	SSstress_tests.vnq_nodes++
	SSstress_tests.vnq_intersects++
	if(!range.overlaps_box(min_x, max_x, min_y, max_y))
		return
	if(is_divided)
		nw_branch.vnq_count_query_npcs(range)
		ne_branch.vnq_count_query_npcs(range)
		sw_branch.vnq_count_query_npcs(range)
		se_branch.vnq_count_query_npcs(range)
		return
	for(var/datum/qt_entry/N as anything in npc_simples)
		SSstress_tests.vnq_contains++
		if(N.target && range.contains_point(N.x_pos, N.y_pos))
			SSstress_tests.vnq_results++

/proc/vnq_query_call_counts(list/trees, radius, samples)
	SSstress_tests.vnq_nodes = 0
	SSstress_tests.vnq_intersects = 0
	SSstress_tests.vnq_contains = 0
	SSstress_tests.vnq_results = 0
	if(!islist(trees) || !length(trees))
		return list("nodes_visited" = 0, "intersects_calls" = 0, "contains_calls" = 0, "results" = 0)
	var/datum/shape/rectangle/R = RECT(0, 0, radius * 2, radius * 2)
	var/ran = 0
	for(var/i in 1 to samples)
		var/turf/T = vnq_placement_turf("scattered")
		if(!T || T.z > length(trees))
			continue
		R.center_x = T.x
		R.center_y = T.y
		var/datum/quadtree/Q = trees[T.z]
		if(!Q)
			continue
		ran++
		Q.vnq_count_query_npcs(R)
	if(!ran)
		ran = 1
	return list(
		"nodes_visited" = SSstress_tests.vnq_nodes / ran,
		"intersects_calls" = SSstress_tests.vnq_intersects / ran,
		"contains_calls" = SSstress_tests.vnq_contains / ran,
		"results" = SSstress_tests.vnq_results / ran,
	)

// ==============================================================================
// MICRO BENCHMARKS
// ==============================================================================

/proc/vnq_faction_check_legacy(mob/source, mob/target)
	var/list/faction2use = target.faction.Copy()
	faction2use += target.name
	var/list/match_list = source.faction & faction2use
	return LAZYLEN(match_list)

/proc/vnq_micro_baseline(iters)
	rustg_time_reset("vnqm")
	var/sink = 0
	for(var/i in 1 to iters)
		sink += 1
	. = rustg_time_microseconds("vnqm")
	if(sink < 0)
		. = 0

/proc/vnq_micro_row(op, iters, us, baseline)
	var/net = max(0, us - baseline)
	return list("op" = op, "iters" = iters, "us" = us, "net_us" = net, "ns_per_op" = iters ? (net * 1000 / iters) : 0)

/proc/vnq_micro_all(iters)
	. = list()
	var/baseline = vnq_micro_baseline(iters)
	. += list(list("op" = "loop_baseline", "iters" = iters, "us" = baseline, "net_us" = baseline, "ns_per_op" = baseline * 1000 / iters))

	var/datum/shape/rectangle/probe = RECT(50, 50, 30, 30)
	var/datum/shape/rectangle/node = RECT(64, 64, 128, 128)
	var/sink = 0

	rustg_time_reset("vnqm")
	for(var/i in 1 to iters)
		sink += probe.overlaps_box(node.min_x, node.max_x, node.min_y, node.max_y)
	. += list(vnq_micro_row("intersects_rect_rect", iters, rustg_time_microseconds("vnqm"), baseline))

	rustg_time_reset("vnqm")
	for(var/i in 1 to iters)
		sink += probe.contains_point(55, 55)
	. += list(vnq_micro_row("contains_rect", iters, rustg_time_microseconds("vnqm"), baseline))

	rustg_time_reset("vnqm")
	for(var/i in 1 to iters)
		sink += istype(node, /datum/shape/rectangle)
	. += list(vnq_micro_row("istype_rect_direct", iters, rustg_time_microseconds("vnqm"), baseline))

	rustg_time_reset("vnqm")
	for(var/i in 1 to iters)
		switch(node.type)
			if(/datum/shape/rectangle)
				sink += 1
			if(/datum/shape/circle)
				sink += 2
	. += list(vnq_micro_row("switch_on_type", iters, rustg_time_microseconds("vnqm"), baseline))

	var/list/holder = list()
	rustg_time_reset("vnqm")
	for(var/i in 1 to iters)
		holder += new /datum/qt_entry
	. += list(vnq_micro_row("new_coords_qtnpc", iters, rustg_time_microseconds("vnqm"), baseline))

	rustg_time_reset("vnqm")
	holder = null
	. += list(vnq_micro_row("free_coords_batch", iters, rustg_time_microseconds("vnqm"), 0))

	holder = list()
	rustg_time_reset("vnqm")
	for(var/i in 1 to iters)
		holder += RECT(1, 1, 8, 8)
	. += list(vnq_micro_row("new_rect_shape", iters, rustg_time_microseconds("vnqm"), baseline))
	holder = null

	holder = list()
	rustg_time_reset("vnqm")
	for(var/i in 1 to iters)
		holder += new /datum/quadtree(0, 8, 0, 8, 1, null)
	. += list(vnq_micro_row("new_quadtree_node", iters, rustg_time_microseconds("vnqm"), baseline))
	holder = null

	var/subdiv_iters = max(1, round(iters / 10))
	var/subdiv_baseline = vnq_micro_baseline(subdiv_iters)
	var/list/roots = list()
	for(var/i in 1 to subdiv_iters)
		roots += new /datum/quadtree(0, 256, 0, 256, 1, null)
	rustg_time_reset("vnqm")
	for(var/datum/quadtree/Q as anything in roots)
		Q.Subdivide()
	. += list(vnq_micro_row("subdivide_node", subdiv_iters, rustg_time_microseconds("vnqm"), subdiv_baseline))
	roots = null

	var/list/adds = list()
	rustg_time_reset("vnqm")
	for(var/i in 1 to iters)
		adds.Add(i)
	. += list(vnq_micro_row("list_Add", iters, rustg_time_microseconds("vnqm"), baseline))
	adds = list()
	rustg_time_reset("vnqm")
	for(var/i in 1 to iters)
		adds += i
	. += list(vnq_micro_row("list_plus_equals", iters, rustg_time_microseconds("vnqm"), baseline))
	adds = null

	var/list/source_list = list()
	for(var/i in 1 to 1000)
		source_list += i
	var/big_iters = max(1, round(iters / 100))
	var/big_baseline = vnq_micro_baseline(big_iters)
	rustg_time_reset("vnqm")
	for(var/i in 1 to big_iters)
		var/list/dup = source_list.Copy()
		sink += length(dup)
	. += list(vnq_micro_row("list_Copy_1000", big_iters, rustg_time_microseconds("vnqm"), big_baseline))

	var/list/a = list()
	var/list/b = list()
	for(var/i in 1 to 50)
		a += i
		b += i + 100
	rustg_time_reset("vnqm")
	for(var/i in 1 to big_iters)
		var/list/joined = a + b
		sink += length(joined)
	. += list(vnq_micro_row("list_concat_50_50", big_iters, rustg_time_microseconds("vnqm"), big_baseline))

	var/mob/probe_mob = length(GLOB.vnq_pop) ? GLOB.vnq_pop[1] : null
	if(probe_mob)
		rustg_time_reset("vnqm")
		for(var/i in 1 to iters)
			if(get_turf(probe_mob))
				sink++
		. += list(vnq_micro_row("get_turf_mob", iters, rustg_time_microseconds("vnqm"), baseline))

		rustg_time_reset("vnqm")
		for(var/i in 1 to iters)
			sink += iscarbon(probe_mob)
		. += list(vnq_micro_row("iscarbon", iters, rustg_time_microseconds("vnqm"), baseline))

		rustg_time_reset("vnqm")
		for(var/i in 1 to iters)
			sink += issimple(probe_mob)
		. += list(vnq_micro_row("issimple", iters, rustg_time_microseconds("vnqm"), baseline))

		var/mob/probe_other = length(GLOB.vnq_pop) > 1 ? GLOB.vnq_pop[2] : null
		if(probe_other)
			rustg_time_reset("vnqm")
			for(var/i in 1 to iters)
				sink += vnq_faction_check_legacy(probe_mob, probe_other)
			. += list(vnq_micro_row("faction_LEGACY_same", iters, rustg_time_microseconds("vnqm"), baseline))
			rustg_time_reset("vnqm")
			for(var/i in 1 to iters)
				sink += probe_mob.faction_check_mob(probe_other)
			. += list(vnq_micro_row("faction_FIXED_same", iters, rustg_time_microseconds("vnqm"), baseline))

			var/list/saved_faction = probe_other.faction
			probe_other.faction = list("vnq_other_faction")
			rustg_time_reset("vnqm")
			for(var/i in 1 to iters)
				sink += vnq_faction_check_legacy(probe_mob, probe_other)
			. += list(vnq_micro_row("faction_LEGACY_diff", iters, rustg_time_microseconds("vnqm"), baseline))
			rustg_time_reset("vnqm")
			for(var/i in 1 to iters)
				sink += probe_mob.faction_check_mob(probe_other)
			. += list(vnq_micro_row("faction_FIXED_diff", iters, rustg_time_microseconds("vnqm"), baseline))
			probe_other.faction = saved_faction

			. += list(list("op" = "faction_list_len_source", "iters" = length(probe_mob.faction), "us" = 0, "net_us" = 0, "ns_per_op" = 0))
			. += list(list("op" = "faction_list_len_target", "iters" = length(probe_other.faction), "us" = 0, "net_us" = 0, "ns_per_op" = 0))

	if(sink < 0)
		. = list()

// ==============================================================================
// QUERY BENCHMARKS
// ==============================================================================

/proc/vnq_time_queries(kind, radius, samples)
	var/datum/shape/rectangle/R = RECT(0, 0, radius * 2, radius * 2)
	var/list/centers = list()
	for(var/i in 1 to samples)
		var/turf/T = vnq_placement_turf("scattered")
		if(T)
			centers += T
	var/hits = 0
	var/ran = 0
	rustg_time_reset("vnqq")
	for(var/turf/T as anything in centers)
		R.center_x = T.x
		R.center_y = T.y
		ran++
		switch(kind)
			if("players")
				hits += length(SSquadtree.players_in_range(R, T.z, QTREE_SCAN_MOBS|QTREE_EXCLUDE_OBSERVER))
			if("npc_carbons")
				hits += length(SSquadtree.npc_carbons_in_range(R, T.z))
			if("npc_simples")
				hits += length(SSquadtree.npc_simples_in_range(R, T.z))
			if("npcs_combined")
				hits += length(SSquadtree.npcs_in_range(R, T.z))
			if("hearables")
				hits += length(SSquadtree.hearables_in_range(R, T.z))
	var/us = rustg_time_microseconds("vnqq")
	return list(
		"kind" = kind,
		"radius" = radius,
		"samples" = ran,
		"total_us" = us,
		"us_per_query" = ran ? (us / ran) : 0,
		"avg_results" = ran ? (hits / ran) : 0,
	)

/proc/vnq_run_queries(list/out, tier_name, distribution)
	for(var/radius in list(7, 15, 30))
		for(var/kind in list("players", "npc_carbons", "npc_simples", "npcs_combined", "hearables"))
			var/list/row = vnq_time_queries(kind, radius, VNQ_QUERIES)
			row["tier"] = tier_name
			row["distribution"] = distribution
			out += list(row)
		sleep(world.tick_lag)
	var/list/counts = vnq_query_call_counts(SSquadtree.trees, 15, 200)
	counts["tier"] = tier_name
	counts["distribution"] = distribution
	counts["kind"] = "npc_simple_callcounts"
	counts["radius"] = 15
	out += list(counts)

// ==============================================================================
// MOVEMENT PATH
// ==============================================================================

/proc/vnq_probe_movement_wiring()
	var/turf/T1 = vnq_placement_turf("scattered")
	if(!T1)
		return list("error" = "no spawn turf")
	var/mob/living/simple_animal/vnq_dummy/D = new(T1)
	var/rect_x0 = D.qt_range ? D.qt_range.center_x : -1
	var/rect_y0 = D.qt_range ? D.qt_range.center_y : -1
	var/datum/qt_entry/entry = SSquadtree.entries[D]
	var/tracked_before = entry ? "[entry.x_pos],[entry.y_pos]" : "none"
	var/turf/T2 = locate(clamp(T1.x + 5, 2, world.maxx - 1), clamp(T1.y + 5, 2, world.maxy - 1), T1.z)
	D.forceMove(T2)
	var/rect_x1 = D.qt_range ? D.qt_range.center_x : -1
	var/rect_y1 = D.qt_range ? D.qt_range.center_y : -1
	entry = SSquadtree.entries[D]
	var/tracked_after = entry ? "[entry.x_pos],[entry.y_pos]" : "none"

	var/datum/shape/rectangle/probe = RECT(T2.x, T2.y, 3, 3)
	var/found_new = (D in SSquadtree.npc_simples_in_range(probe, T2.z)) ? 1 : 0
	probe.Recenter(T1.x, T1.y)
	var/found_old = (D in SSquadtree.npc_simples_in_range(probe, T1.z)) ? 1 : 0

	. = list(
		"has_qt_range" = D.qt_range ? 1 : 0,
		"mob_x" = D.x,
		"mob_y" = D.y,
		"rect_before_move" = "[rect_x0],[rect_y0]",
		"rect_after_move" = "[rect_x1],[rect_y1]",
		"tracked_before" = tracked_before,
		"tracked_after" = tracked_after,
		"signal_reaches_handler" = (rect_x1 == D.x && rect_y1 == D.y) ? 1 : 0,
		"found_at_new_position" = found_new,
		"still_found_at_old_position" = found_old,
	)
	qdel(D)

/proc/vnq_bench_movement(moves)
	var/list/movers = list()
	for(var/i in 1 to min(moves, length(GLOB.vnq_pop)))
		var/mob/living/M = GLOB.vnq_pop[i]
		if(M && !QDELETED(M) && get_turf(M))
			movers += M
	var/n = length(movers)
	if(!n)
		return list("moves" = 0)

	var/relocations_before = SSquadtree.relocations
	var/applied_before = SSquadtree.moves_applied

	rustg_time_reset("vnqmv")
	for(var/mob/living/M as anything in movers)
		var/turf/T = get_step(M, pick(GLOB.cardinals))
		if(T)
			M.forceMove(T)
	var/us_step = rustg_time_microseconds("vnqmv")

	var/stepped = SSquadtree.moves_applied - applied_before
	var/relocated = SSquadtree.relocations - relocations_before

	rustg_time_reset("vnqmv")
	for(var/mob/living/M as anything in movers)
		SSquadtree.OnMoved(M)
	var/us_noop = rustg_time_microseconds("vnqmv")

	rustg_time_reset("vnqmv")
	for(var/mob/living/M as anything in movers)
		SSquadtree.WakeNearbySleepers(M, M.z)
	var/us_wake_none = rustg_time_microseconds("vnqmv")

	var/marked = 0
	for(var/i in 1 to length(GLOB.vnq_pop))
		if(i % 2)
			continue
		var/mob/living/S = GLOB.vnq_pop[i]
		if(S && !QDELETED(S))
			SSquadtree.SetSleeping(S, TRUE)
			marked++
	rustg_time_reset("vnqmv")
	for(var/mob/living/M as anything in movers)
		SSquadtree.WakeNearbySleepers(M, M.z)
	var/us_wake_half = rustg_time_microseconds("vnqmv")
	for(var/i in 1 to length(GLOB.vnq_pop))
		var/mob/living/S = GLOB.vnq_pop[i]
		if(S && !QDELETED(S))
			SSquadtree.SetSleeping(S, FALSE)

	return list(
		"moves" = n,
		"positions_changed" = stepped,
		"node_relocations" = relocated,
		"relocation_rate" = stepped ? (relocated / stepped) : 0,
		"us_forcemove_plus_tracking_per_move" = us_step / n,
		"us_unchanged_position_handler" = us_noop / n,
		"us_wake_check_no_sleepers" = us_wake_none / n,
		"us_wake_check_half_asleep" = us_wake_half / n,
		"sleepers_marked" = marked,
	)

// ==============================================================================
// WAKE-ON-PROXIMITY BENCHMARK
// ==============================================================================

/proc/vnq_force_sleep(mob/living/M)
	if(!M || !M.ai_root)
		return FALSE
	if(!SSai.active_mobs[M])
		SSai.active_mobs[M] = TRUE
		SSai.sleeping_mobs -= M
	M.ai_root.next_sleep_tick = 0
	SSai.GoToSleep(M)
	return SSai.sleeping_mobs[M] ? TRUE : FALSE

/proc/vnq_build_sleeping_village(turf/center, count, radius)
	. = list()
	for(var/i in 1 to count)
		var/turf/T = locate(
			clamp(center.x + rand(-radius, radius), 2, world.maxx - 1),
			clamp(center.y + rand(-radius, radius), 2, world.maxy - 1),
			center.z)
		if(!istype(T, /turf/open) || isopenspace(T))
			continue
		var/mob/living/simple_animal/vnq_ai_dummy/D = new(T)
		GLOB.vnq_pop += D
		SSquadtree.RefreshKinds(D)
		. += D

/proc/vnq_sleep_all(list/mobs)
	. = 0
	for(var/mob/living/M as anything in mobs)
		if(vnq_force_sleep(M))
			.++

/proc/vnq_walk_and_time(mob/living/walker, turf/from, steps, list/per_step_us, list/per_step_wakes)
	walker.forceMove(from)
	var/z = from.z
	var/datum/quadtree/root = SSquadtree.trees[z]
	for(var/i in 1 to steps)
		var/turf/T = locate(clamp(from.x + i, 2, world.maxx - 1), from.y, z)
		if(!T)
			break
		var/before = root ? root.subtree_sleeping : 0
		rustg_time_reset("vnqwake")
		walker.forceMove(T)
		per_step_us += rustg_time_microseconds("vnqwake")
		var/after = root ? root.subtree_sleeping : 0
		per_step_wakes += (before - after)

/proc/vnq_summarise_steps(list/us_values)
	if(!length(us_values))
		return list("steps" = 0)
	var/total = 0
	var/peak = 0
	for(var/v in us_values)
		total += v
		peak = max(peak, v)
	var/tail_n = min(20, length(us_values))
	var/tail_total = 0
	for(var/i in (length(us_values) - tail_n + 1) to length(us_values))
		tail_total += us_values[i]
	return list(
		"steps" = length(us_values),
		"total_us" = total,
		"first_step_us" = us_values[1],
		"peak_step_us" = peak,
		"mean_us" = total / length(us_values),
		"tail_mean_us" = tail_total / tail_n,
	)

/proc/vnq_bench_wake(village_size, radius, steps)
	vnq_teardown_population()
	var/turf/center = vnq_placement_turf("scattered")
	if(!center)
		return list("error" = "no spawn turf")
	var/z = center.z
	var/list/village = vnq_build_sleeping_village(center, village_size, radius)
	if(!length(village))
		return list("error" = "village empty")
	sleep(world.tick_lag)

	var/datum/quadtree/root = SSquadtree.trees[z]
	var/turf/start = locate(clamp(center.x - steps, 2, world.maxx - 1), center.y, z)
	if(!start)
		return list("error" = "no walk start")

	var/mob/living/simple_animal/vnq_dummy/walker = new(start)
	GLOB.vnq_pop += walker
	walker.faction = list("vnq_intruder")

	var/list/base_us = list()
	var/list/base_wakes = list()
	vnq_walk_and_time(walker, start, steps, base_us, base_wakes)
	var/list/baseline = vnq_summarise_steps(base_us)

	var/asleep = vnq_sleep_all(village)
	var/sleepers_indexed = root ? root.subtree_sleeping : 0
	var/list/walk_us = list()
	var/list/walk_wakes = list()
	vnq_walk_and_time(walker, start, steps, walk_us, walk_wakes)
	var/woken = 0
	for(var/w in walk_wakes)
		woken += w
	var/list/intrusion = vnq_summarise_steps(walk_us)
	var/left_asleep = root ? root.subtree_sleeping : 0

	var/list/second_us = list()
	var/list/second_wakes = list()
	vnq_walk_and_time(walker, start, steps, second_us, second_wakes)
	var/list/settled = vnq_summarise_steps(second_us)

	vnq_sleep_all(village)
	var/mob/living/simple_animal/vnq_ai_dummy/ai_walker = new(start)
	GLOB.vnq_pop += ai_walker
	for(var/mob/living/M as anything in village)
		ai_walker.faction = M.faction.Copy()
		break
	var/list/faction_us = list()
	var/list/faction_wakes = list()
	vnq_walk_and_time(ai_walker, start, steps, faction_us, faction_wakes)
	var/faction_woken = 0
	for(var/w in faction_wakes)
		faction_woken += w
	var/list/same_faction = vnq_summarise_steps(faction_us)

	vnq_teardown_population()
	return list(
		"village_size" = length(village),
		"radius" = radius,
		"steps_per_walk" = steps,
		"put_to_sleep" = asleep,
		"sleepers_indexed" = sleepers_indexed,
		"woken_during_walk" = woken,
		"left_asleep_after_walk" = left_asleep,
		"same_faction_woken" = faction_woken,
		"baseline_no_sleepers" = baseline,
		"walk_into_sleeping_village" = intrusion,
		"second_walk_after_waking" = settled,
		"ai_among_same_faction_sleepers" = same_faction,
		"per_step_us_intrusion" = walk_us,
		"per_step_wakes_intrusion" = walk_wakes,
		"per_step_us_same_faction" = faction_us,
	)

// ==============================================================================
// CADENCE VIABILITY
// ==============================================================================

/proc/vnq_bench_cadence(budget, ticks, tier_name)
	var/paused_fires = 0
	var/completed_rebuilds = 0
	var/resumed = FALSE
	var/usage_sum = 0
	var/usage_max = 0
	var/list/samples = list()
	for(var/i in 1 to ticks)
		var/u0 = world.tick_usage
		var/did_pause = vnq_fire_budgeted(SSquadtree, budget, resumed)
		var/used = world.tick_usage - u0
		if(used > 0)
			usage_sum += used
			usage_max = max(usage_max, used)
			samples += used
		if(did_pause)
			paused_fires++
			resumed = TRUE
		else
			completed_rebuilds++
			resumed = FALSE
		sleep(world.tick_lag)
	return list(
		"tier" = tier_name,
		"budget" = budget,
		"ticks" = ticks,
		"paused_fires" = paused_fires,
		"completed_rebuilds" = completed_rebuilds,
		"ticks_per_rebuild" = completed_rebuilds ? (ticks / completed_rebuilds) : 0,
		"avg_tick_usage" = ticks ? (usage_sum / ticks) : 0,
		"max_tick_usage" = usage_max,
		"p95_tick_usage" = length(samples) ? vns_percentile_us(samples, 0.95) : 0,
	)

// ==============================================================================
// FIRE PUMP TIMING
// ==============================================================================

/proc/vnq_bench_fire(pumps, tier_name, distribution)
	for(var/i in 1 to VNQ_WARMUP_PUMPS)
		vnq_fire_full(SSquadtree)
	var/list/samples = list()
	var/total = 0
	for(var/i in 1 to pumps)
		rustg_time_reset("vnqf")
		vnq_fire_full(SSquadtree)
		var/us = rustg_time_microseconds("vnqf")
		samples += us
		total += us
		if(i % 8 == 0)
			sleep(world.tick_lag)
	var/avg = pumps ? (total / pumps) : 0
	return list(
		"tier" = tier_name,
		"distribution" = distribution,
		"pumps" = pumps,
		"avg_us" = avg,
		"p95_us" = length(samples) ? vns_percentile_us(samples, 0.95) : 0,
		"max_us" = length(samples) ? vns_percentile_us(samples, 1) : 0,
		"pct_of_one_tick" = (world.tick_lag * 100000) ? (avg / (world.tick_lag * 100000) * 100) : 0,
	)

// ==============================================================================
// BOOKKEEPING PROBES
// ==============================================================================

/proc/vnq_probe_bookkeeping()
	var/entries_before = length(SSquadtree.entries)
	var/resyncs_before = SSquadtree.resyncs
	var/list/temps = list()
	for(var/i in 1 to 200)
		var/turf/T = vnq_placement_turf("scattered")
		if(!T)
			continue
		temps += new /mob/living/simple_animal/vnq_dummy(T)
	var/entries_after_spawn = length(SSquadtree.entries)
	for(var/mob/living/M as anything in temps)
		if(M && !QDELETED(M))
			GLOB.npc_list -= M
			qdel(M)
	var/entries_after_delete = length(SSquadtree.entries)

	var/list/shape = vnq_tree_stats(SSquadtree.trees)
	var/tracked_total = 0
	for(var/atom/movable/AM as anything in SSquadtree.entries)
		tracked_total++

	return list(
		"entries_before" = entries_before,
		"entries_after_200_spawns" = entries_after_spawn,
		"entries_after_deleting_them" = entries_after_delete,
		"entries_leaked" = entries_after_delete - entries_before,
		"registry_size" = tracked_total,
		"tree_entries" = shape["entries"],
		"tree_nodes" = shape["nodes"],
		"tree_max_depth" = shape["max_depth"],
		"tree_max_node_entries" = shape["max_node_entries"],
		"resyncs_during_probe" = SSquadtree.resyncs - resyncs_before,
		"total_resyncs" = SSquadtree.resyncs,
	)

// ==============================================================================
// DRIVER
// ==============================================================================

/proc/vnq_tier_list()
	var/cfg = vnq_cfg("tiers", "vn_qt_tiers", "VN_QT_TIERS", "")
	var/list/out = list()
	if(cfg)
		for(var/piece in splittext("[cfg]", ","))
			var/n = text2num(piece)
			if(!isnull(n))
				out += n
	return length(out) ? out : list(0, 150, 400, 800, 1600)

/proc/vnq_run_bench()
	set waitfor = FALSE
	rand_seed(20260806)
	fdel("data/vn_qt_progress.log")
	vnq_freeze_world()

	var/tag = vnq_cfg("tag", "vn_qt_tag", "VN_QT_TAG", "run")
	var/list/tiers = vnq_tier_list()
	var/list/distributions = list("scattered", "clustered")
	var/dist_cfg = vnq_cfg("distribution", "vn_qt_distribution", "VN_QT_DISTRIBUTION", "")
	if(dist_cfg)
		distributions = list(dist_cfg)

	vnq_log("QTBENCH start tag=[tag] maxx=[world.maxx] maxy=[world.maxy] maxz=[world.maxz] tick_lag=[world.tick_lag] ss_wait=[SSquadtree.wait]")
	vnq_log("QTBENCH baseline players=[length(GLOB.player_list)] npcs=[length(GLOB.npc_list)] hearables=[length(GLOB.hearables)] mobs=[length(GLOB.mob_list)]")

	var/list/fire_rows = list()
	var/list/stage_rows = list()
	var/list/query_rows = list()
	var/list/cadence_rows = list()
	var/list/movement_rows = list()
	var/list/micro_rows = list()
	var/list/wake_rows = list()
	var/list/wiring = list()
	var/list/bookkeeping = list()
	var/fail_reason = ""
	var/peak_tier = tiers[length(tiers)]

	try
		wiring = vnq_probe_movement_wiring()
		vnq_log("QTBENCH wiring signal_reaches_handler=[wiring["signal_reaches_handler"]] handler_updates_rect=[wiring["handler_updates_rect"]]")

		for(var/distribution in distributions)
			for(var/tier in tiers)
				var/spawned = vnq_build_population(tier, 0.15, distribution, tier ? VNQ_PLAYERS : 0)
				var/tier_name = "[tier]"
				vnq_log("QTBENCH tier=[tier_name] dist=[distribution] spawned=[spawned] players=[length(GLOB.player_list)] npc_list=[length(GLOB.npc_list)] hearables=[length(GLOB.hearables)]")
				sleep(world.tick_lag)

				fire_rows += list(vnq_bench_fire(VNQ_PUMPS, tier_name, distribution))
				vnq_run_queries(query_rows, tier_name, distribution)

				var/list/mv = vnq_bench_movement(VNQ_MOVES)
				mv["tier"] = tier_name
				mv["distribution"] = distribution
				movement_rows += list(mv)

				var/list/cad = vnq_bench_cadence(80, VNQ_CADENCE_TICKS, tier_name)
				cad["distribution"] = distribution
				cadence_rows += list(cad)

				if(distribution == distributions[1] && tier == peak_tier)
					vnq_log("QTBENCH micro benchmarks")
					micro_rows = vnq_micro_all(VNQ_MICRO_ITERS)
					bookkeeping = vnq_probe_bookkeeping()

		vnq_teardown_population()

		vnq_log("QTBENCH wake-on-proximity benchmark")
		for(var/list/spec in list(list(60, 8), list(200, 12), list(400, 16)))
			var/list/wake_row = vnq_bench_wake(spec[1], spec[2], 40)
			wake_rows += list(wake_row)
			vnq_log("QTBENCH wake village=[wake_row["village_size"]] indexed=[wake_row["sleepers_indexed"]] woken=[wake_row["woken_during_walk"]]")

		vnq_log("QTBENCH per-proc profile at peak tier=[peak_tier]")
		vnq_build_population(peak_tier, 0.15, "scattered", VNQ_PLAYERS)
		sleep(world.tick_lag)
		world.Profile(PROFILE_RESTART, format = "json")
		for(var/i in 1 to VNQ_PUMPS)
			vnq_fire_full(SSquadtree)
		rustg_file_write(world.Profile(PROFILE_REFRESH, format = "json"), "data/vn_qt_profile_fire_[tag].json")

		world.Profile(PROFILE_RESTART, format = "json")
		var/list/discard = list()
		vnq_run_queries(discard, "profile", "scattered")
		rustg_file_write(world.Profile(PROFILE_REFRESH, format = "json"), "data/vn_qt_profile_query_[tag].json")

		world.Profile(PROFILE_RESTART, format = "json")
		vnq_bench_movement(VNQ_MOVES)
		rustg_file_write(world.Profile(PROFILE_REFRESH, format = "json"), "data/vn_qt_profile_moved_[tag].json")

		vnq_teardown_population()
	catch(var/exception/e)
		fail_reason = "[e] at [e?.file]:[e?.line]"

	var/list/payload = list(
		"meta" = list(
			"tag" = tag,
			"maxx" = world.maxx,
			"maxy" = world.maxy,
			"maxz" = world.maxz,
			"tick_lag" = world.tick_lag,
			"fps" = world.fps,
			"quadtree_capacity" = QUADTREE_CAPACITY,
			"boundary_min" = QUADTREE_BOUNDARY_MINIMUM_WIDTH,
			"tiers" = tiers,
			"pumps" = VNQ_PUMPS,
			"queries" = VNQ_QUERIES,
			"micro_iters" = VNQ_MICRO_ITERS,
			"moves" = VNQ_MOVES,
		),
		"wiring" = wiring,
		"bookkeeping" = bookkeeping,
		"fire" = fire_rows,
		"stages" = stage_rows,
		"queries" = query_rows,
		"cadence" = cadence_rows,
		"movement" = movement_rows,
		"micro" = micro_rows,
		"wake" = wake_rows,
	)
	rustg_file_write(json_encode(payload), "data/vn_qt_results_[tag].json")

	if(fail_reason)
		vnq_log("QTBENCH FAIL: [fail_reason]")
	else
		vnq_log("QTBENCH COMPLETE")
	sleep(20)
	del(world)
