// ==============================================================================
// MOB AI VARIABLES
// ==============================================================================

/mob
	var/datum/behavior_tree/node/parallel/root/ai_root

/mob/living
	var/mob/living/target

// ==============================================================================
// AI HELPER PROCS FOR MOBS
// ==============================================================================

/mob/living/proc/GiveTarget(atom/target)
	if(!ai_root || stat == DEAD)
		return FALSE
	if(ismob(target))
		ai_root.target = target
		src.target = target
		SEND_SIGNAL(src, COMSIG_AI_TARGET_CHANGED, target)
	else if(isturf(target) || isobj(target))
		ai_root.obj_target = target
		SEND_SIGNAL(src, COMSIG_AI_TARGET_CHANGED, target)
	else
		return FALSE

/mob/living/proc/LoseTarget()
	if(ai_root)
		// Remove the current target from aggressors list if present
		if(ai_root.target && ai_root.blackboard[AIBLK_AGGRESSORS])
			ai_root.blackboard[AIBLK_AGGRESSORS] -= ai_root.target
			if(!length(ai_root.blackboard[AIBLK_AGGRESSORS]))
				ai_root.blackboard -= AIBLK_AGGRESSORS

		ai_root.target = null
		target = null
		SEND_SIGNAL(src, COMSIG_AI_TARGET_CHANGED, null)

/mob/living/proc/RunAI()
	if(!ai_root || stat == DEAD)
		return FALSE
		
	ai_root.evaluate(src, ai_root.target, ai_root.blackboard)
	return TRUE
	
/*
/mob/living/proc/RunMovement()
	if(!ai_root || stat == DEAD)
		return FALSE
	
	return (ai_root.move_node.evaluate(src, ai_root.target, ai_root.blackboard) == NODE_SUCCESS)
*/

/// Collects an in-flight native path request. Never sleeps. Returns TRUE if a
/// usable path landed this call.
/mob/living/proc/collect_ai_path()
	if(!ai_root?.path_request_id)
		return FALSE
	var/result = SSpathfinding.PollPath(ai_root.path_request_id)
	if(result == PATH_PENDING)
		return FALSE
	ai_root.path_request_id = 0
	var/atom/dest = ai_root.path_request_dest
	ai_root.path_request_dest = null
	if(!islist(result) || !length(result) || !dest || QDELETED(dest))
		if(ai_root.blackboard && dest)
			ai_root.blackboard[AIBLK_FAILED_PATH_DEST] = dest
			ai_root.blackboard[AIBLK_FAILED_PATH_TIME] = world.time
		return FALSE
	ai_root.path = result
	ai_root.move_destination = dest
	SSai.claim_turf(get_turf(dest), src)
	if(ai_root.blackboard)
		ai_root.blackboard -= AIBLK_FAILED_PATH_DEST
		ai_root.blackboard -= AIBLK_FAILED_PATH_TIME
	return TRUE

/mob/living/proc/set_ai_path_to(atom/destination)
	if(!ai_root)
		return FALSE

	// Null safety - can't path if we're not in the world
	if(!src || !get_turf(src))
		return FALSE

	// NPCs should not move while knocked down
	if(IsKnockdown() || IsParalyzed())
		return FALSE

	SSai.WakeUp(src) // Assume if we got this called on us, we want to actually do it.

	if(!destination)
		// Unclaim old destination
		if(ai_root.move_destination)
			SSai.unclaim_turf(get_turf(ai_root.move_destination), src)
		ai_root.path = null
		ai_root.move_destination = null
		if(ai_root.path_request_id)
			SSpathfinding.CancelPath(ai_root.path_request_id)
			ai_root.path_request_id = 0
			ai_root.path_request_dest = null
		return FALSE

	// Check if we recently failed to path to this destination (EARLY CHECK to avoid expensive operations)
	// Only apply cooldown for static destinations (turfs/objects), not moving targets (mobs)
	if(ai_root.blackboard && !ismob(destination))
		var/failed_path_dest = ai_root.blackboard[AIBLK_FAILED_PATH_DEST]
		var/failed_path_time = ai_root.blackboard[AIBLK_FAILED_PATH_TIME]
		if(failed_path_dest == destination && failed_path_time && world.time - failed_path_time < 2 SECONDS)
			// We recently failed to path here, don't spam pathfinding logic
			return FALSE

	// Don't repath if we are already going there and have a path
	if(ai_root.move_destination == destination && length(ai_root.path))
		// For moving targets (mobs), check if they've moved to a different turf
		if(ismob(destination) || isobj(destination))
			var/turf/path_end = ai_root.path[length(ai_root.path)]
			var/turf/dest_turf = get_turf(destination)
			// Null check - if destination is in null space now, clear path
			if(!dest_turf)
				ai_root.path = null
				ai_root.move_destination = null
				return FALSE
			if(path_end == dest_turf)
				// Target hasn't moved, path is still valid
				return TRUE
			// Target has moved, fall through to recalculate path
		else
			// Static destination, path is still valid
			return TRUE

	if(ai_root.target && (ai_root.move_destination == ai_root.target || ai_root.move_destination == get_turf(ai_root.target)))
		if(get_dist(src, ai_root.target) <= 1)
			// Unclaim old destination
			if(ai_root.move_destination)
				SSai.unclaim_turf(get_turf(ai_root.move_destination), src)
			ai_root.path = null
			ai_root.move_destination = null
			return FALSE

	// Unclaim old destination before setting new one
	if(ai_root.move_destination)
		SSai.unclaim_turf(get_turf(ai_root.move_destination), src)

	// For a 1 step path to static destinations, just set it directly for performance
	// For mob/obj targets, only skip pathfinding if we're already adjacent
	if(get_dist(src, destination) <= 1)
		var/turf/T = get_turf(destination)
		if(T && get_turf(src) != T)
			var/target = ai_root.target
			var/obj_target = ai_root.obj_target
			if(!target && !obj_target)
				// Static destination - create simple 1-step path
				var/has_dense_object = FALSE
				for(var/atom/A in T)
					if(A.density)
						has_dense_object = TRUE
						break

				if(!T.density && !has_dense_object && T.CanPass(src, T))
					ai_root.path = list(T)
					ai_root.move_destination = T
					SSai.claim_turf(T, src)
					return TRUE
			else
				// Moving target - only skip pathfinding if already adjacent
				if(target && Adjacent(ai_root.target) || obj_target && Adjacent(ai_root.obj_target))
					ai_root.path = null
					ai_root.move_destination = null
					return FALSE
				// Not adjacent but distance 1 (e.g., diagonal) - fall through to A_Star

		// Can't reach destination
		else
			ai_root.path = null
			ai_root.move_destination = null
			return FALSE

	var/turf/start_turf = get_turf(src)
	var/turf/dest_turf = get_turf(destination)

	// Null safety - if either turf is invalid, we can't path
	if(!start_turf || !dest_turf)
		ai_root.path = null
		ai_root.move_destination = null
		return FALSE
	if(start_turf.z == dest_turf.z && get_dist(start_turf, dest_turf) <= 30)
		ai_root.path = A_Star(src, start_turf, dest_turf)
	else
		var/req = SSpathfinding.RequestPath(src, start_turf, dest_turf)
		if(req)
			if(ai_root.path_request_id)
				SSpathfinding.CancelPath(ai_root.path_request_id)
			ai_root.path_request_id = req
			ai_root.path_request_dest = destination
			return FALSE
		ai_root.path = A_Star(src, start_turf, dest_turf)

	if(length(ai_root.path) > 0)
		ai_root.move_destination = destination
		// Claim the destination turf
		SSai.claim_turf(get_turf(ai_root.move_destination), src)
		// Clear failed path tracking since we succeeded
		if(ai_root.blackboard)
			ai_root.blackboard -= AIBLK_FAILED_PATH_DEST
			ai_root.blackboard -= AIBLK_FAILED_PATH_TIME
		return TRUE
	else
		// Path failed - remember this failure to prevent spam repathing
		if(ai_root.blackboard)
			ai_root.blackboard[AIBLK_FAILED_PATH_DEST] = destination
			ai_root.blackboard[AIBLK_FAILED_PATH_TIME] = world.time
		ai_root.move_destination = null
		ai_root.path = null
		return FALSE


/mob/living/proc/add_aggressor(mob/living/aggressor)
	if(!aggressor)
		return

	if(!ai_root.blackboard[AIBLK_AGGRESSORS])
		ai_root.blackboard[AIBLK_AGGRESSORS] = list()
	ai_root.blackboard[AIBLK_AGGRESSORS] |= aggressor

	// Store last known location
	ai_root.blackboard[AIBLK_LAST_KNOWN_TARGET_LOC] = get_turf(aggressor)

	SEND_SIGNAL(src, COMSIG_AI_ATTACKED, aggressor)

// Check if mob can switch to a new target (respects delay to prevent thrashing)
/mob/living/proc/can_switch_target(atom/new_target, switch_delay = 2 SECONDS)
	if(!ai_root) return FALSE

	// If we have no current target, we can always switch
	if(!ai_root.target) return TRUE

	// If new target is same as current, no switch needed (return TRUE to allow reassignment)
	if(ai_root.target == new_target) return TRUE

	// Check last target switch time in blackboard
	var/last_switch = ai_root.blackboard[AIBLK_LAST_TARGET_SWITCH_TIME]
	if(!last_switch) return TRUE

	return (world.time - last_switch) >= switch_delay

// Record a target switch to enforce delay
/mob/living/proc/record_target_switch()
	if(ai_root)
		ai_root.blackboard[AIBLK_LAST_TARGET_SWITCH_TIME] = world.time
