#ifdef VN_BENCH
/// Per-action-type attribution. The macro compiles to a direct call outside VN_BENCH.
/proc/vn_action_eval(bt_action/A, mob/living/npc, atom/target, list/blackboard)
	if(!GLOB.vn_action_profile)
		return A.evaluate(npc, target, blackboard)
	var/key = "[A.type]"
	rustg_time_reset("vnact")
	. = A.evaluate(npc, target, blackboard)
	GLOB.vn_action_us[key] += rustg_time_microseconds("vnact")
	GLOB.vn_action_n[key] += 1
#endif


/// All BT-side visibility scans funnel through these: they cache per viewer per
/// tick (several actions in one think ask for the same view) and let the bench
/// count and ablate them. Accepts BYOND's (Dist, Center) or bare (Center) forms.
/proc/ai_view(a, b)
	return ai_visibility_scan(a, b, FALSE)

/proc/ai_oview(a, b)
	return ai_visibility_scan(a, b, TRUE)

/proc/ai_visibility_scan(a, b, exclude_self)
	var/range
	var/atom/center
	if(isnum(a))
		range = a
		center = b
	else
		center = a
		range = world.view
#ifdef VN_BENCH
	GLOB.vn_ai_view_calls++
	if(GLOB.vn_ai_view_off)
		return list()
#endif
	if(!ismob(center))
		return exclude_self ? oview(range, center) : view(range, center)
	var/mob/M = center
	if(M.ai_view_cache_time != world.time)
		M.ai_view_cache_time = world.time
		M.ai_view_cache = list()
	var/key = "[exclude_self ? "o" : "v"][range]"
	var/list/hit = M.ai_view_cache[key]
	if(hit)
		return hit
	var/list/res = exclude_self ? oview(range, center) : view(range, center)
	M.ai_view_cache[key] = res
	return res

// ==============================================================================
// BEHAVIOR TREE ACTIONS
// ==============================================================================
// This file contains the base bt_action class and generic action implementations.
// IS12-specific actions have been removed. Implement roguetown-specific actions here as needed.

//================================================================
// BASE ACTION DATUM
//================================================================
// All specific actions (like attacking, finding targets, etc.) inherit from this.
/bt_action
	parent_type = /datum

/bt_action/proc/evaluate(mob/living/user, atom/target, list/blackboard)
	return NODE_FAILURE

/// Helper to simulate carbon NPC ClickOn with less overhead for AI
/// Note that this is only for adjacent targets
/// At range, clicks should probably be bypassed entirely
/proc/npc_click_on(mob/living/user, atom/target, params)
	var/list/modifiers = params2list(params)
	if(!user || !user.ai_root || !target)
		return
	
	if(!modifiers["catcher"] && target.IsObscured())
		return

	if(!user.loc.AllowClick())
		return

	if(user.dir == get_dir(target,user))
		user.face_atom(target)
		return

	if(world.time < user.ai_root.next_attack_tick)
		return
	user.ai_root.next_attack_tick = world.time + user.ai_root.next_attack_delay

	if(user.next_move > world.time)
		return

	if(user.incapacitated(ignore_restraints = 1))
		return
	
	if(user.restrained())
		user.changeNext_move(CLICK_CD_HANDCUFFED)
		return

	if(!user.atkswinging)
		user.face_atom(target)

	if(user.in_throw_mode)
		if(modifiers["right"])
			if(user.oactive)
				user.throw_item(target, TRUE)
				return
		user.throw_item(target)
		return

	if(!user.Adjacent(target))
		return

	var/obj/item/W = user.get_active_held_item()
	
	// Simulate cooldowns based on intent
	if(W)
		var/adf = user.used_intent.clickcd
		if(istype(user.rmb_intent, /datum/rmb_intent/aimed))
			adf = round(adf * CLICK_CD_MOD_AIMED)
		else if(istype(user.rmb_intent, /datum/rmb_intent/swift))
			adf = max(round(adf * CLICK_CD_MOD_SWIFT), CLICK_CD_INTENTCAP)
		user.changeNext_move(adf)

	// Attack animation
	if(W && ismob(target))
		if(!user.used_intent.noaa)
			user.do_attack_animation(get_turf(target), user.used_intent.animname, W, used_intent = user.used_intent)

	user.resolveAdjacentClick(target, W, params)

// ==============================================================================
// MOVEMENT ACTIONS
// ==============================================================================

/bt_action/check_move_valid/evaluate(mob/living/user, atom/target, list/blackboard)
	if(user.stat == DEAD || world.time < user.ai_root.next_move_tick || user.doing || user.incapacitated(ignore_restraints = 1))
		return NODE_FAILURE
	return NODE_SUCCESS

/bt_action/check_has_path/evaluate(mob/living/user, atom/target, list/blackboard)
	if(!user.ai_root)
		return NODE_FAILURE
	if(user.ai_root.path_request_id)
		user.collect_ai_path()
	if(!user.ai_root.path || !length(user.ai_root.path))
		return NODE_FAILURE
	return NODE_SUCCESS

/bt_action/process_movement/evaluate(mob/living/user, atom/target, list/blackboard)
	var/turf/next_step = user.ai_root.path[1]
	if(get_turf(user) == next_step)
		user.ai_root.path.Cut(1, 2)
		if(!length(user.ai_root.path))
			user.set_ai_path_to(null)
			return NODE_SUCCESS
		next_step = user.ai_root.path[1]

	if(next_step && get_dist(user, next_step) <= 1)
		if(user.Move(next_step, get_dir(user, next_step)))
			user.ai_root.next_move_tick = world.time + user.ai_root.next_move_delay
			return NODE_SUCCESS
		else
			// Movement failed - return failure to let the tree handle retries
			SEND_SIGNAL(user, COMSIG_AI_PATH_BLOCKED, next_step)
			return NODE_FAILURE
	else
		// Path is invalid, clear it
		user.set_ai_path_to(null)
		SEND_SIGNAL(user, COMSIG_AI_MOVEMENT_FAILED)
		return NODE_FAILURE


// =============================================================================
// THINKING ACTIONS
// =============================================================================
/bt_action/check_think_valid/evaluate(mob/living/user, atom/target, list/blackboard)
	if(user.stat == DEAD || world.time < user.ai_root.next_think_tick || user.incapacitated(ignore_restraints = 1))
		return NODE_FAILURE
	
	user.ai_root.next_think_tick = world.time + user.ai_root.next_think_delay
	return NODE_SUCCESS
