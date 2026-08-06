/mob/living/simple_animal/qt_test_dummy
	name = "quadtree test dummy"
	icon_state = "chicken"
	density = FALSE
	wander = 0
	stop_automated_movement = 1

/mob/living/simple_animal/qt_test_ai_dummy
	name = "quadtree test ai dummy"
	icon_state = "chicken"
	density = FALSE
	wander = 0
	stop_automated_movement = 1

/mob/living/simple_animal/qt_test_ai_dummy/Initialize(mapload)
	. = ..()
	init_ai_root(/datum/behavior_tree/node/selector/generic_hostile_tree)

/datum/unit_test/quadtree
	var/list/spawned = list()

/datum/unit_test/quadtree/proc/spawn_dummy(x, y, z)
	var/turf/T = locate(x, y, z)
	if(!T)
		return null
	var/mob/living/simple_animal/qt_test_dummy/D = new(T)
	GLOB.npc_list |= D
	SSquadtree.RefreshKinds(D)
	spawned += D
	return D

/datum/unit_test/quadtree/proc/cleanup()
	for(var/mob/living/M as anything in spawned)
		if(M && !QDELETED(M))
			GLOB.npc_list -= M
			qdel(M)
	spawned.Cut()

/datum/unit_test/quadtree/proc/check_conservation(context)
	var/list/stats = list("seen" = list(), "duplicates" = 0, "in_divided" = 0)
	for(var/datum/quadtree/root as anything in SSquadtree.trees)
		walk_node(root, stats)
	var/list/seen = stats["seen"]
	var/registry_size = 0
	var/orphans = 0
	for(var/atom/movable/AM as anything in SSquadtree.entries)
		registry_size++
		var/datum/qt_entry/entry = SSquadtree.entries[AM]
		if(!entry.node || !seen[entry])
			orphans++
	if(stats["duplicates"])
		TEST_FAIL("[context]: [stats["duplicates"]] entries appear in more than one node")
	if(stats["in_divided"])
		TEST_FAIL("[context]: [stats["in_divided"]] entries are held by a divided node (entries must only live in leaves)")
	if(orphans)
		TEST_FAIL("[context]: [orphans] registry entries are missing from the tree")
	if(length(seen) != registry_size)
		TEST_FAIL("[context]: tree holds [length(seen)] entries but the registry holds [registry_size]")

	var/counted_sleepers = 0
	for(var/atom/movable/AM as anything in SSquadtree.entries)
		var/datum/qt_entry/entry = SSquadtree.entries[AM]
		if(entry.kinds & QT_KIND_AI_SLEEPING)
			counted_sleepers++
	var/root_total = 0
	for(var/datum/quadtree/root as anything in SSquadtree.trees)
		root_total += root.subtree_sleeping
	if(root_total != counted_sleepers)
		TEST_FAIL("[context]: roots report [root_total] sleepers but [counted_sleepers] entries carry the sleeping bit")

/datum/unit_test/quadtree/proc/walk_node(datum/quadtree/node, list/stats)
	if(!node)
		return
	var/list/here = list()
	if(node.players)
		here |= node.players
	if(node.npc_carbons)
		here |= node.npc_carbons
	if(node.npc_simples)
		here |= node.npc_simples
	if(node.hearables)
		here |= node.hearables
	if(node.is_divided && length(here))
		stats["in_divided"] += length(here)
	var/list/seen = stats["seen"]
	for(var/datum/qt_entry/entry as anything in here)
		if(seen[entry])
			stats["duplicates"] += 1
		seen[entry] = TRUE
	if(!node.is_divided)
		return
	walk_node(node.nw_branch, stats)
	walk_node(node.ne_branch, stats)
	walk_node(node.sw_branch, stats)
	walk_node(node.se_branch, stats)

/datum/unit_test/quadtree/proc/reference_npcs(cx, cy, w, h, z)
	. = list()
	var/min_x = cx - w * 0.5
	var/max_x = cx + w * 0.5
	var/min_y = cy - h * 0.5
	var/max_y = cy + h * 0.5
	for(var/mob/M as anything in GLOB.npc_list)
		if(QDELETED(M) || M.client)
			continue
		if(iscarbon(M) || !issimple(M))
			continue
		var/turf/T = get_turf(M)
		if(!T || T.z != z)
			continue
		if(T.x >= min_x && T.x <= max_x && T.y >= min_y && T.y <= max_y)
			. += M

/datum/unit_test/quadtree/proc/compare_sets(list/got, list/expected, context)
	var/list/missing = expected - got
	var/list/extra = got - expected
	if(length(missing))
		TEST_FAIL("[context]: quadtree missed [length(missing)] of [length(expected)] entities")
		return FALSE
	if(length(extra))
		TEST_FAIL("[context]: quadtree returned [length(extra)] entities outside the range")
		return FALSE
	if(length(got) != length(expected))
		TEST_FAIL("[context]: quadtree returned [length(got)] entities, expected [length(expected)] (duplicates)")
		return FALSE
	return TRUE

/datum/unit_test/quadtree/Run()
	var/z = 1
	var/max_x = min(world.maxx, 60)
	var/max_y = min(world.maxy, 60)

	for(var/x in 2 to max_x - 1)
		for(var/y in 2 to max_y - 1)
			if((x + y) % 3)
				continue
			spawn_dummy(x, y, z)

	if(length(spawned) < 50)
		TEST_FAIL("quadtree test could not place enough dummies ([length(spawned)]) - map too small")
		cleanup()
		return

	check_conservation("after bulk insert")
	var/resyncs_at_start = SSquadtree.resyncs

	var/checked = 0
	for(var/cx in 4 to max_x - 4 step 7)
		for(var/cy in 4 to max_y - 4 step 7)
			for(var/size in list(3, 8, 15, 31))
				var/datum/shape/rectangle/R = RECT(cx, cy, size, size)
				var/list/got = SSquadtree.npc_simples_in_range(R, z)
				var/list/expected = reference_npcs(cx, cy, size, size, z)
				checked++
				if(!compare_sets(got, expected, "query ([cx],[cy]) size [size]"))
					cleanup()
					return
	if(!checked)
		TEST_FAIL("quadtree query sweep ran no comparisons")

	for(var/list/edge in list(list(1, 1), list(1, max_y), list(max_x, 1), list(max_x, max_y)))
		var/datum/shape/rectangle/R = RECT(edge[1], edge[2], 9, 9)
		if(!compare_sets(SSquadtree.npc_simples_in_range(R, z), reference_npcs(edge[1], edge[2], 9, 9, z), "edge query ([edge[1]],[edge[2]])"))
			cleanup()
			return

	var/datum/shape/rectangle/whole = RECT(world.maxx * 0.5, world.maxy * 0.5, world.maxx * 2, world.maxy * 2)
	compare_sets(SSquadtree.npc_simples_in_range(whole, z), reference_npcs(world.maxx * 0.5, world.maxy * 0.5, world.maxx * 2, world.maxy * 2, z), "whole-map query")

	var/moved_ok = 0
	var/list/movers = list()
	for(var/i in 1 to min(40, length(spawned)))
		movers += spawned[i]
	for(var/mob/living/M as anything in movers)
		var/turf/old_turf = get_turf(M)
		var/turf/new_turf = locate(clamp(old_turf.x + 13, 2, max_x - 1), clamp(old_turf.y + 11, 2, max_y - 1), z)
		if(!new_turf || new_turf == old_turf)
			continue
		M.forceMove(new_turf)
		var/datum/shape/rectangle/at_new = RECT(new_turf.x, new_turf.y, 1, 1)
		if(!(M in SSquadtree.npc_simples_in_range(at_new, z)))
			TEST_FAIL("moved mob not found at its new position ([new_turf.x],[new_turf.y])")
			cleanup()
			return
		moved_ok++
	if(!moved_ok)
		TEST_FAIL("quadtree movement test moved nothing")
	check_conservation("after movement")

	for(var/cx in 6 to max_x - 6 step 11)
		for(var/cy in 6 to max_y - 6 step 11)
			var/datum/shape/rectangle/R = RECT(cx, cy, 15, 15)
			if(!compare_sets(SSquadtree.npc_simples_in_range(R, z), reference_npcs(cx, cy, 15, 15, z), "post-move query ([cx],[cy])"))
				cleanup()
				return

	var/mob/living/subject = spawned[1]
	var/turf/subject_turf = get_turf(subject)
	var/datum/shape/rectangle/at_subject = RECT(subject_turf.x, subject_turf.y, 1, 1)
	GLOB.npc_list -= subject
	GLOB.hearables |= subject
	ADD_TRAIT(subject, TRAIT_HEARING_SENSITIVE, "qt_test")
	SSquadtree.RefreshKinds(subject)
	if(subject in SSquadtree.npc_simples_in_range(at_subject, z))
		TEST_FAIL("mob removed from npc_list is still returned by an NPC query")
	if(!(subject in SSquadtree.hearables_in_range(at_subject, z)))
		TEST_FAIL("mob made hearing sensitive is not returned by a hearable query")
	REMOVE_TRAIT(subject, TRAIT_HEARING_SENSITIVE, "qt_test")
	GLOB.hearables -= subject
	GLOB.npc_list |= subject
	SSquadtree.RefreshKinds(subject)
	if(!(subject in SSquadtree.npc_simples_in_range(at_subject, z)))
		TEST_FAIL("mob restored to npc_list is not returned by an NPC query")
	check_conservation("after kind transitions")

	var/registry_before = length(SSquadtree.entries)
	var/spawned_count = length(spawned)
	cleanup()
	var/registry_after = length(SSquadtree.entries)
	if(registry_after > registry_before - spawned_count)
		TEST_FAIL("registry leaked entries on deletion: [registry_before] -> [registry_after] after removing [spawned_count]")
	check_conservation("after cleanup")

	if(SSquadtree.resyncs != resyncs_at_start)
		TEST_FAIL("a full resync ran during the test ([SSquadtree.resyncs - resyncs_at_start]x), so the incremental path was not what got verified")

	var/mob/living/simple_animal/qt_test_dummy/sleeper = spawn_dummy(round(max_x / 2), round(max_y / 2), z)
	var/mob/living/simple_animal/qt_test_dummy/walker = spawn_dummy(2, 2, z)
	if(!sleeper || !walker)
		TEST_FAIL("could not place wake-test mobs")
		cleanup()
		return

	SSquadtree.SetSleeping(sleeper, TRUE)
	var/datum/qt_entry/sleeper_entry = SSquadtree.entries[sleeper]
	if(!(sleeper_entry.kinds & QT_KIND_AI_SLEEPING))
		TEST_FAIL("SetSleeping did not mark the entry")
	var/datum/quadtree/wake_root = SSquadtree.trees[z]
	if(wake_root.subtree_sleeping != 1)
		TEST_FAIL("root reports [wake_root.subtree_sleeping] sleepers, expected 1")

	var/datum/shape/rectangle/wake_probe = RECT(sleeper.x, sleeper.y, 5, 5)
	var/list/found_sleepers = SSquadtree.QueryKinds(wake_probe, z, QT_KIND_AI_SLEEPING)
	if(!(sleeper in found_sleepers))
		TEST_FAIL("sleeper-only query did not return the sleeping mob")
	if(walker in found_sleepers)
		TEST_FAIL("sleeper-only query returned an awake mob")
	check_conservation("with a sleeper indexed")

	SSquadtree.SetSleeping(sleeper, FALSE)
	if(wake_root.subtree_sleeping != 0)
		TEST_FAIL("root still reports [wake_root.subtree_sleeping] sleepers after waking")
	if(length(SSquadtree.QueryKinds(wake_probe, z, QT_KIND_AI_SLEEPING)))
		TEST_FAIL("sleeper-only query still returns a woken mob")
	check_conservation("after waking the sleeper")

	SSquadtree.SetSleeping(sleeper, TRUE)
	var/turf/moved_to = locate(clamp(sleeper.x + 20, 2, max_x - 1), sleeper.y, z)
	if(moved_to && moved_to != get_turf(sleeper))
		sleeper.forceMove(moved_to)
		var/datum/shape/rectangle/moved_probe = RECT(moved_to.x, moved_to.y, 3, 3)
		if(!(sleeper in SSquadtree.QueryKinds(moved_probe, z, QT_KIND_AI_SLEEPING)))
			TEST_FAIL("sleeper not findable after moving")
	check_conservation("after moving a sleeper")
	SSquadtree.SetSleeping(sleeper, FALSE)

	var/turf/wake_spot = null
	for(var/x in 2 to max_x - 1)
		for(var/y in 2 to max_y - 1)
			var/turf/candidate = locate(x, y, z)
			if(istype(candidate, /turf/open) && !candidate.density && !candidate.opacity)
				wake_spot = candidate
				break
		if(wake_spot)
			break
	if(!wake_spot)
		TEST_FAIL("no open turf found for the wake test")
		cleanup()
		return

	var/turf/walker_spot = locate(wake_spot.x + 1, wake_spot.y, z)
	if(!walker_spot)
		walker_spot = wake_spot

	var/mob/living/simple_animal/qt_test_ai_dummy/ai_sleeper = new(wake_spot)
	spawned += ai_sleeper
	var/mob/living/simple_animal/qt_test_dummy/prowler = new(walker_spot)
	spawned += prowler
	SSquadtree.RefreshKinds(ai_sleeper)
	SSquadtree.RefreshKinds(prowler)

	if(!ai_sleeper.ai_root)
		TEST_FAIL("test AI mob has no ai_root, so the wake path cannot be exercised")
		cleanup()
		return

	if(!SSai.active_mobs[ai_sleeper])
		SSai.active_mobs[ai_sleeper] = TRUE
		SSai.sleeping_mobs -= ai_sleeper
	ai_sleeper.ai_root.next_sleep_tick = 0
	SSai.GoToSleep(ai_sleeper)
	if(!SSai.sleeping_mobs[ai_sleeper])
		TEST_FAIL("SSai.GoToSleep did not put the test AI to sleep")
		cleanup()
		return

	var/datum/quadtree/wake_tree = SSquadtree.trees[z]
	if(wake_tree.subtree_sleeping != 1)
		TEST_FAIL("expected 1 indexed sleeper, tree reports [wake_tree.subtree_sleeping]")

	prowler.faction = ai_sleeper.faction.Copy()
	prowler.forceMove(wake_spot)
	if(prowler.ai_root && !SSai.sleeping_mobs[ai_sleeper])
		TEST_FAIL("a same-faction AI mover woke a sleeper it should have ignored")

	prowler.faction = list("qt_test_intruder")
	var/turf/step_off = locate(wake_spot.x + 1, wake_spot.y, z) || wake_spot
	prowler.forceMove(step_off)
	prowler.forceMove(wake_spot)
	if(SSai.sleeping_mobs[ai_sleeper])
		TEST_FAIL("a hostile mob moving onto a sleeping AI in clear line of sight did not wake it")
	if(wake_tree.subtree_sleeping != 0)
		TEST_FAIL("woken AI is still counted in the sleeper index ([wake_tree.subtree_sleeping])")
	check_conservation("after a proximity wake")

	cleanup()
	check_conservation("after wake-test cleanup")
