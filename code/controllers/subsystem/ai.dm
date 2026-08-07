// ==============================================================================
// AI SUBSYSTEM
// ==============================================================================

#define AI_SQUADS // Enable AI squad functionality. Comment out to disable.

GLOBAL_LIST_EMPTY(ai_init_queue)

#ifdef VN_BENCH
#define VNA_SKIP_QUERY    (1<<0)
#define VNA_SKIP_DISPATCH (1<<1)
#define VNA_SKIP_SQUADS   (1<<2)
#define VNA_QUERY_ON      (!(vna_skip & VNA_SKIP_QUERY))
#define VNA_DISPATCH_ON   (!(vna_skip & VNA_SKIP_DISPATCH))
#define VNA_SQUADS_ON     (!(vna_skip & VNA_SKIP_SQUADS))
#else
#define VNA_QUERY_ON      TRUE
#define VNA_DISPATCH_ON   TRUE
#define VNA_SQUADS_ON     TRUE
#endif

PROCESSING_SUBSYSTEM_DEF(ai)
	name = "AI"
	priority = SS_PRIORITY_AI
	flags = SS_KEEP_TIMING
	runlevels = RUNLEVEL_GAME
	wait = 1 // Process every tick to check for thonk delays. This is insanely fast anyway compared to the other subsystems.

	// Using associative lists for performance. Checking for a key is much faster than searching a list. We learned this from liquids, lads.
#ifdef VN_BENCH
	var/vna_skip = 0
	var/vna_legacy_query = FALSE
	var/list/vna_dummy_players = list(1)
#endif
	var/list/active_mobs = list()
	var/list/sleeping_mobs = list()
	var/list/unregister_queue = list()
	var/list/sleep_queue = list()
	#ifdef AI_SQUADS
	var/list/squads
	var/list/squads_to_remove
	var/next_squad_update_tick = 0
	#endif

	// Pathfinding reservation system - maps turf hash to claiming mob
	var/alist/claimed_turfs

	// Native behavior-tree offload (GLOB.vn_bt_native)
	var/vn_next_id = 0
	var/list/vn_mobs = list()			// "[vn_id]" -> mob
	var/list/vn_signal_queue = list()	// flat [vn_id, slot]
	var/list/vn_report_queue = list()	// flat [vn_id, node_id, status]
	var/list/vn_tick_ids				// per-fire batch (rebuilt each fire)
	var/list/vn_sync_batch
	var/vn_intents_dispatched = 0
	var/vn_next_target_token = 0
	var/list/vn_target_tokens = list()	// "[REF(atom)]" -> stable token

/datum/controller/subsystem/processing/ai/Initialize()
	..()
	NEW_SS_GLOBAL(SSai)

	active_mobs = list()
	sleeping_mobs = list()
	unregister_queue = list()
	sleep_queue = list()
	squads = list()
	squads_to_remove = list()
	claimed_turfs = alist()
	// Register movement tracking for player mobs - this will be set up as players log in/spawn
	
	for(var/mob/living/M in GLOB.ai_init_queue)
		Register(M)
	
	GLOB.ai_init_queue.len = 0
	GLOB.ai_init_queue = null

/datum/controller/subsystem/processing/ai/proc/Register(mob/living/M)
	if(!can_fire || !initialized)
		GLOB.ai_init_queue += M
		return
		
	if(M && M.ai_root && !sleeping_mobs[M]) // Only register if it's not already sleeping.
		if(!M.ai_root.blackboard)
			M.ai_root.blackboard = new
		active_mobs[M] = TRUE
		SSquadtree.SetSleeping(M, FALSE)
		M.ai_root.next_think_tick = world.time + M.ai_root.next_think_delay
		M.ai_root.next_move_tick = world.time + M.ai_root.next_move_delay
		GLOB.npc_list |= M
		SSquadtree.RefreshKinds(M)

/datum/controller/subsystem/processing/ai/proc/Unregister(mob/living/M)
	if(!M) return
	if(GLOB.ai_init_queue)
		GLOB.ai_init_queue -= M

	if(M.ai_root?.vn_id)
		vn_mobs -= "[M.ai_root.vn_id]"
		vn_bt_mob_remove(M.ai_root.vn_id)
		M.ai_root.vn_id = 0

	if(!M.ai_root)
		active_mobs -= M
		sleeping_mobs -= M
		SSquadtree.SetSleeping(M, FALSE)
		GLOB.npc_list -= M
		SSquadtree.RefreshKinds(M)
		return
	else
		#ifdef AI_SQUADS
		if(M.ai_root.blackboard && M.ai_root.blackboard[AIBLK_SQUAD_DATUM])
			var/ai_squad/squad = M.ai_root.blackboard[AIBLK_SQUAD_DATUM]
			squad.RemoveMember(M)
		#endif
		
		if(M.ai_root.move_destination)
			M.set_ai_path_to(null)

		active_mobs -= M
		sleeping_mobs -= M
		SSquadtree.SetSleeping(M, FALSE)
		GLOB.npc_list -= M
		SSquadtree.RefreshKinds(M)
		QDEL_NULL(M.ai_root)

/datum/controller/subsystem/processing/ai/proc/WakeUp(mob/living/M, forced = FALSE)
	if(!M || !M.ai_root) return
	if(forced) M.ai_root.ai_flags &= ~AI_FLAG_FORCESLEEP
	if(M.ai_root.ai_flags & AI_FLAG_FORCESLEEP) return
	if(sleeping_mobs[M]) sleeping_mobs.Remove(M)
	else return // Defensive programming, should never hit this condition afaik
	SSquadtree.SetSleeping(M, FALSE)

	active_mobs[M] = TRUE
	if(M.ai_root.blackboard)
		M.ai_root.blackboard -= AIBLK_HIBERNATION_TIMER
	M.ai_root.next_think_tick = world.time // Let it think immediately
	M.ai_root.next_sleep_tick = world.time + M.ai_root.next_sleep_delay

/datum/controller/subsystem/processing/ai/proc/GoToSleep(mob/living/M, forced = FALSE)
	if(!active_mobs[M]) return
	if(forced) M.ai_root.ai_flags |= AI_FLAG_FORCESLEEP
	if(M.ai_root.next_sleep_tick < world.time) 
		sleeping_mobs[M] = TRUE
		active_mobs.Remove(M)
		SSquadtree.SetSleeping(M, TRUE)

// Processing our active mobs
/datum/controller/subsystem/processing/ai/fire(var/time_delta)
	var/current_time = world.time

	var/vn_native = GLOB.vn_bt_native && VN_OK && SSnative?.mirror_loaded
	if(vn_native)
		VN_Collect()
		vn_tick_ids = list()
		vn_sync_batch = list()

	for(var/mob/living/M in active_mobs)
		if(!M || M.stat == DEAD || M.client)
			unregister_queue |= M
			continue

		var/turf/T = get_turf(M)
		if(!T) // How the fuck could this even happen? Let's not process it, just in case. Jesus Christ.
			unregister_queue |= M
			continue

		// Check if enough time has passed for the mob to think/move again.
		if(current_time >= M.ai_root.next_think_tick || current_time >= M.ai_root.next_move_tick)
			if(!(M.ai_root.ai_flags & (AI_FLAG_PERSISTENT|AI_FLAG_ASSUMEDIRECTCONTROL|AI_FLAG_FORCESLEEP)))

				var/players_near = M.nearby_players
#ifdef VN_BENCH
				if(!VNA_QUERY_ON)
					players_near = 1
				else if(vna_legacy_query)
					players_near = length(SSquadtree.players_in_range(M.qt_range, T.z, QTREE_SCAN_MOBS|QTREE_EXCLUDE_OBSERVER))
#endif

				if(!players_near)
					if(M.ai_root.blackboard)
						if(!M.ai_root.blackboard[AIBLK_HIBERNATION_TIMER])
							M.ai_root.blackboard[AIBLK_HIBERNATION_TIMER] = current_time + AI_HIBERNATION_DELAY

						if(current_time >= M.ai_root.blackboard[AIBLK_HIBERNATION_TIMER])
							sleep_queue |= M
							continue
				else
					if(M.ai_root.blackboard && M.ai_root.blackboard[AIBLK_HIBERNATION_TIMER])
						M.ai_root.blackboard -= AIBLK_HIBERNATION_TIMER
			
			if(!VNA_DISPATCH_ON)
				continue
			if(vn_native)
				VN_Think(M, current_time)
			else
				INVOKE_ASYNC(M, TYPE_PROC_REF(/mob/living, RunAI))

	if(vn_native)
		VN_FlushTick(current_time)

	for(var/mob/living/M as anything in unregister_queue)
#ifdef AI_SQUADS
		if(M.ai_root.blackboard)
			var/ai_squad/squad = M.ai_root.blackboard[AIBLK_SQUAD_DATUM]
			if(squad)
				squad.RemoveMember(M)
#endif
		Unregister(M)

	for(var/mob/living/M as anything in sleep_queue)
		GoToSleep(M)

	unregister_queue.len = 0
	sleep_queue.len = 0
#ifdef AI_SQUADS
	if(VNA_SQUADS_ON && current_time > next_squad_update_tick)
		for(var/ai_squad/S as anything in squads)
			if(length(S.members))
				INVOKE_ASYNC(S, TYPE_PROC_REF(/ai_squad, RunAI))
			else
				squads_to_remove |= S

				if(S)
					S.update_center_of_mass()

					// Check if squad should split
					if(length(S.members) > S.max_size)
						SplitSquad(S)
						continue // Skip to next squad as this one is now gone.

					// Check if squad should merge with another
					for(var/ai_squad/other_squad as anything in squads)
						// Removed IS12-specific /ai_squad/sweepers type check
						if(S == other_squad) continue
						if(S.squad_type != other_squad.squad_type) continue

						if(get_dist(S.center_of_mass, other_squad.center_of_mass) < AI_SQUAD_MERGE_DIST)
							if(length(S.members) + length(other_squad.members) <= S.max_size)
								// Merge the smaller squad into the larger one.
								if(length(S.members) > length(other_squad.members))
									MergeSquads(S, other_squad)
								else
									MergeSquads(other_squad, S)
								break // Stop checking this squad as it has changed.

			next_squad_update_tick = current_time + 2 SECONDS

	for(var/ai_squad/squad as anything in squads_to_remove)
		squads -= squad
		qdel(squad)

// ==============================================================================
// NATIVE BEHAVIOR-TREE OFFLOAD
// ==============================================================================

/datum/controller/subsystem/processing/ai/proc/vn_queue_signal(vid, slot)
	if(!vid)
		return
	vn_signal_queue += vid
	vn_signal_queue += slot

/datum/controller/subsystem/processing/ai/proc/vn_queue_report(vid, node_id, status)
	if(!vid)
		return
	vn_report_queue += vid
	vn_report_queue += node_id
	vn_report_queue += status

/// Stable identity token for target-change detection in the VM.
/datum/controller/subsystem/processing/ai/proc/VN_TargetToken(atom/tgt)
	if(!tgt)
		return 0
	var/key = "[REF(tgt)]"
	var/tok = vn_target_tokens[key]
	if(!tok)
		tok = ++vn_next_target_token
		vn_target_tokens[key] = tok
	return tok

/// Dispatches the previous tick's intents to their mobs.
/datum/controller/subsystem/processing/ai/proc/VN_Collect()
	var/list/res = vn_bt_tick_collect()
	if(!islist(res))
		vn_check_result(res, "bt_collect")
		return
	if(!length(res))
		return
	var/cur = 1
	var/n = res[cur++]
	for(var/i in 1 to n)
		var/vid = res[cur++]
		var/node_id = res[cur++]
		var/kind = res[cur++]
		cur++ // param, unused
		var/mob/living/M = vn_mobs["[vid]"]
		if(!M || QDELETED(M) || !M.ai_root)
			continue
		INVOKE_ASYNC(M, TYPE_PROC_REF(/mob/living, vn_execute_intent), node_id, kind)
		vn_intents_dispatched++

/// The native replacement for INVOKE_ASYNC(M, RunAI): the movement subtree
/// keeps its DM cadence; a think-eligible mob joins the VM tick batch.
/// Falls back to the DM evaluator for unsupported trees.
/datum/controller/subsystem/processing/ai/proc/VN_Think(mob/living/M, current_time)
	var/datum/behavior_tree/node/parallel/root/root = M.ai_root
	// root.evaluate() always fires the movement subtree async
	if(GLOB.vn_move_sync)
		root.move_node.evaluate(M, root.target, root.blackboard)
	else
		INVOKE_ASYNC(root.move_node, TYPE_PROC_REF(/datum/behavior_tree/node, evaluate), M, root.target, root.blackboard)

	// think gate, replicating bt_action/check_think_valid
	if(M.stat == DEAD || current_time < root.next_think_tick || M.incapacitated(ignore_restraints = 1))
		return
	if(!root.vn_id && !root.vn_register(M))
		INVOKE_ASYNC(M, TYPE_PROC_REF(/mob/living, RunAI)) // unsupported tree
		return
	root.next_think_tick = current_time + root.next_think_delay

	vn_tick_ids += root.vn_id
	var/turf/T = get_turf(M)
	vn_sync_batch += root.vn_id
	vn_sync_batch += T.x
	vn_sync_batch += T.y
	vn_sync_batch += T.z
	vn_sync_batch += round(1000 * M.health / max(1, M.maxHealth))
	var/pain_pct = 0
	if(iscarbon(M))
		var/mob/living/carbon/C = M
		pain_pct = round(1000 * C.get_complex_pain() / max(1, C.STAEND * 10))
	vn_sync_batch += pain_pct
	var/food = 100
	if(istype(M, /mob/living/simple_animal))
		var/mob/living/simple_animal/SA = M
		food = SA.food
	vn_sync_batch += food
	var/atom/tgt = root.target
	var/turf/TT = tgt ? get_turf(tgt) : null
	vn_sync_batch += VN_TargetToken(tgt)
	vn_sync_batch += TT ? TT.x : 0
	vn_sync_batch += TT ? TT.y : 0
	vn_sync_batch += TT ? TT.z : 0

/// Ships this fire's mirrors to the VM and kicks the evaluation.
/datum/controller/subsystem/processing/ai/proc/VN_FlushTick(current_time)
	if(length(vn_report_queue))
		vn_check_result(vn_bt_report(vn_report_queue), "bt_report")
		vn_report_queue = list()
	if(length(vn_signal_queue))
		vn_check_result(vn_bt_signal(vn_signal_queue), "bt_signal")
		vn_signal_queue = list()
	if(length(vn_sync_batch))
		vn_check_result(vn_bt_sync(vn_sync_batch), "bt_sync")
	if(length(vn_tick_ids))
		vn_check_result(vn_bt_tick_begin(current_time, vn_tick_ids), "bt_begin")

/datum/controller/subsystem/processing/ai/proc/MakeSquad(var/mob/living/leader, special_squad_type)
	var/ai_squad/squad = special_squad_type ? new special_squad_type(leader) : new /ai_squad(leader)
	squads += squad
	AddToSquad(leader, squad)
	return squad

/datum/controller/subsystem/processing/ai/proc/AddToSquad(var/mob/living/M, var/ai_squad/squad)
	if(!istype(M) || !istype(squad)) return

	// If the mob was already in a squad, remove it first.
	var/ai_squad/old_squad = M.ai_root.blackboard[AIBLK_SQUAD_DATUM]
	if(old_squad)
		old_squad.RemoveMember(M)

	squad.AddMember(M)

/datum/controller/subsystem/processing/ai/proc/FindOrCreateSquadFor(mob/living/M)
	var/ai_squad/best_squad = find_best_squad_for(M)

	if(best_squad)
		best_squad.AddMember(M)
	else
		var/squad_type = M.get_preferred_squad_type()
		var/ai_squad/new_squad = new squad_type(M)
		squads += new_squad
		new_squad.AddMember(M)

// Helper proc to find the most suitable squad for an NPC to join.
/datum/controller/subsystem/processing/ai/proc/find_best_squad_for(mob/living/M)
	var/ai_squad/best_squad = null
	var/closest_dist = AI_SQUAD_MAX_JOIN_DIST // A global define for max join range

	for(var/ai_squad/S as anything in squads)
		if(S.squad_type != M.type) continue // Must be the same type of NPC.
		if(length(S.members) >= S.max_size) continue // Must not be full.

		if(!S.center_of_mass) S.update_center_of_mass()
		var/atom/ref = S.center_of_mass ? S.center_of_mass : S.leader

		var/dist = get_dist(M, ref)
		if(dist < closest_dist)
			best_squad = S
			closest_dist = dist

	return best_squad

// Merges squad B into squad A.
/datum/controller/subsystem/processing/ai/proc/MergeSquads(ai_squad/A, ai_squad/B)
	for(var/mob/living/M as anything in B.members)
		A.AddMember(M)

	squads -= B
	qdel(B)

// Splits a large squad into two smaller ones.
/datum/controller/subsystem/processing/ai/proc/SplitSquad(ai_squad/S)
	if(S.members.len < 2) return // Can't split a squad of one.

	// Find the two members who are farthest apart to be the new leaders.
	var/mob/living/new_leader_A = S.members[1]
	var/mob/living/new_leader_B
	for(var/mob/living/member as anything in S.members)
		if(member == new_leader_A) continue
		if(!new_leader_B)
			new_leader_B = member
		if(get_dist(new_leader_A, member) > get_dist(new_leader_A, new_leader_B))
			new_leader_B = member

	var/ai_squad/new_squad_A = new /ai_squad(new_leader_A)
	var/ai_squad/new_squad_B = new /ai_squad(new_leader_B)
	squads.Add(new_squad_A, new_squad_B)

	// Re-assign all original members to the closest new leader, but prioritize keeping the squads evenly sized.
	for(var/mob/living/M as anything in S.members)
		if(length(new_squad_A.members) <= (length(new_squad_B.members)))
			if(get_dist(M, new_leader_A) <= get_dist(M, new_leader_B))
				new_squad_A.AddMember(M)
				continue

		new_squad_B.AddMember(M)

	squads -= S
	qdel(S)

// Snowflake Sweeper split logic for the subsystem lol
/datum/controller/subsystem/processing/ai/proc/SplitSquadForHunt(ai_squad/parent_squad, mob/living/hunt_target)
	if (length(parent_squad.members) < 4)
		return // Don't split if the squad is too small

	var/list/candidates_with_dist = list()

	for(var/mob/living/member as anything in parent_squad.members)
		candidates_with_dist += list(list("mob" = member, "dist" = get_dist(member, hunt_target)))

	sortTim(candidates_with_dist, /proc/cmp_dist_list_asc)

	var/list/sorted_candidates = list()
	for (var/list/item as anything in candidates_with_dist)
		sorted_candidates += item["mob"]

	var/list/hunt_team_members = list()
	var/num_hunters = min(3, length(sorted_candidates) - 1)
	for (var/i = 1; i <= num_hunters; i++)
		hunt_team_members += sorted_candidates[i]

	if (!length(hunt_team_members))
		return

	// Create the new hunt squad
	var/mob/living/hunt_leader = hunt_team_members[1]
	var/ai_squad/hunt_squad = new /ai_squad(hunt_leader)
	hunt_squad.squad_type = parent_squad.squad_type
	squads += hunt_squad

	// Move members from the parent squad to the new hunt squad
	for (var/mob/living/hunter as anything in hunt_team_members)
		parent_squad.RemoveMember(hunter)
		hunt_squad.AddMember(hunter)

	// Assign the target to the new squad
	hunt_squad.blackboard[AIBLK_SQUAD_HUNT_TARGET] = hunt_target
	for (var/mob/living/hunter as anything in hunt_squad.members)
		hunter.ai_root.target = hunt_target

#endif

//================================================================
// PATHFINDING CLAIM SYSTEM
//================================================================

// Hash a turf's coordinates to an integer for fast lookup
/datum/controller/subsystem/processing/ai/proc/hash_turf(turf/T)
	if(!T)
		return 0
	// DJB2 hash
	var/hash = 5381
	hash = (hash << 5) + hash + T.x
	hash = (hash << 5) + hash + T.y
	hash = (hash << 5) + hash + T.z
	return hash & 0xFFFFFF

// Claim a turf for pathfinding (called when setting path destination)
/datum/controller/subsystem/processing/ai/proc/claim_turf(turf/T, mob/living/claimer)
	if(!T || !claimer)
		return
	var/hash = hash_turf(T)
	var/datum/weakref/weakclaimer = WEAKREF(claimer)

	if(!weakclaimer)
		return

	claimed_turfs[hash] = weakclaimer

// Unclaim a turf (called when path is cleared or mob dies)
/datum/controller/subsystem/processing/ai/proc/unclaim_turf(turf/T, mob/living/claimer)
	if(!T)
		return
	var/hash = hash_turf(T)
	var/datum/weakref/weakclaimer = claimed_turfs[hash]

	if(!weakclaimer)
		
		return

	var/mob/living/hardclaimer = weakclaimer.resolve() ? weakclaimer.resolve() : null

	if(claimed_turfs[hash] == weakclaimer || !hardclaimer)
		claimed_turfs -= hash

// Check if a turf is claimed by another mob
/datum/controller/subsystem/processing/ai/proc/turf_claimed_by(turf/T, mob/living/exclude)
	if(!T)
		return null
	var/hash = hash_turf(T)
	var/datum/weakref/weakclaimer = claimed_turfs[hash]
	if(!weakclaimer)
		return null
	var/mob/living/hardclaimer = weakclaimer.resolve() ? weakclaimer.resolve() : null
	if(hardclaimer && hardclaimer != exclude && !QDELETED(hardclaimer))
		return hardclaimer
	return null

//================================================================
//SUBSYSTEM HELPERS
//================================================================

// Below are any functions or types that are useful for interacting with this subsystem, or with NPCs in general.

/mob/var/datum/shape/qt_range // Each mob has a single shape datum to define the quadtree's areas of interest for running searches. This is more performant than creating and destroying the shape datums on every tick.

/// Maintained by SSquadtree: non-observer players within AI_HIBERNATION_RANGE.
/// Replaces a per-mob-per-tick players_in_range query in SSai.fire.
/mob/var/nearby_players = 0

/// Per-tick cache of this mob's visibility scans (see ai_visibility_scan).
/mob/var/ai_view_cache_time = 0
/mob/var/list/ai_view_cache

/mob/var/wake_scan_x = 0
/mob/var/wake_scan_y = 0
/mob/var/wake_scan_z = 0
/mob/var/wake_scan_w = 0
/mob/var/wake_scan_epoch = -1
/mob/var/wake_scan_faction_id = -1
/mob/var/list/wake_los_pending

#undef AI_SQUADS
