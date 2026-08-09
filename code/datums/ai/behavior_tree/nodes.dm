// ==============================================================================
// BEHAVIOR TREE FRAMEWORK
// ==============================================================================

// The root node is also a general data holder for the mob's AI. It holds information about the mob's state, such as where it's going, who it's killing, etc. and tracks simple timestamp-based cooldown timers for various actions.
// Please make sure you only instantiate variables ON the root node... You could describe doing otherwise as "memory pollution."

/datum/behavior_tree/node
	var/node_state = NODE_FAILURE
	var/active_node_text // Debug text showing the currently running node

	#ifdef BT_DEBUG
	var/next_log_tick = 0
	var/next_log_delay = 5 SECONDS
	#endif

/datum/behavior_tree/node/parallel/root
	var/tree_typepath
	var/list/path // This should always be instantiated if we're creating a mob that has one of these anyways, but still do it in InitAI, not in a node definition.
	var/atom/move_destination // This is where we're going.
	var/path_request_id = 0
	var/atom/path_request_dest
	var/atom/target // And this is who we're KILLING.
	var/atom/obj_target // And if we're targeting an object, we'll cast it here.
	var/datum/behavior_tree/node/main_node // Reference to the node that handles the main behavior tree
	var/datum/behavior_tree/node/move_node // Reference to the node that handles processing the mob's movement.

	var/alist/blackboard

	// STATEFUL EXECUTION: The Pointer
	// Instead of re-traversing the entire tree every tick, we cache the currently running node
	// When a node returns RUNNING, we store it here and call it directly on the next tick
	// When it returns SUCCESS or FAILURE, we clear this and traverse from root again
	var/datum/behavior_tree/node/running_node

	// These are timestamp variables to track when commonly-done things should happen. Very lightweight compared to a timer datum. These can get randomized later.
	// Anything that needs to be checked every tick should be stored here, rather than in the blackboard, to minimize list operations.

	var/next_think_tick = 0 // The world.time when this mob can think again.
	var/next_chatter_tick = 0
	var/next_wander_tick = 0
	var/next_emote_tick = 0
	var/next_attack_tick = 0
	var/next_move_tick = 0
	var/next_repath_tick = 0
	var/next_sleep_tick = 0

	var/next_think_delay = AI_DEFAULT_THINK_DELAY
	var/next_chatter_delay = AI_DEFAULT_CHATTER_DELAY
	var/next_emote_delay = AI_DEFAULT_EMOTE_DELAY
	var/next_attack_delay = AI_DEFAULT_ATTACK_DELAY
	var/next_move_delay = AI_DEFAULT_MOVE_DELAY
	var/next_repath_delay = AI_DEFAULT_REPATH_DELAY
	var/next_sleep_delay = AI_DEFAULT_SLEEP_DELAY

	var/ai_flags // A bitfield
	var/current_command // If the mob is carrying out a command given by AI commander, we store its state here.

/// DJB2 hash for blackboard keys - converts strings to integers for faster lookup
/// Use this if you don't want to calculate the hash yourself for a define, or if you're using
/// Blackboard keys that don't have defines
/datum/behavior_tree/node/parallel/root/proc/hash_key(key)
	if(isnum(key))
		return key
	var/hash = 5381
	var/text_key = "[key]"
	for(var/i = 1, i <= length(text_key), i++)
		hash = ((hash << 5) + hash) + text2ascii(text_key, i)
	return hash & 0xFFFFFF
/*
	var/list/bt_action_cache // For goap stuff.

	// These are caches that hold an instance of every goap_goal and goap_action subtype so the NPC can use them at will. This helps with performance by preventing either A)
	// having to create a new instance of a goap_goal or goap_action every time it's needed, or B) having to share the same instance of a goap_goal or goap_action between multiple NPCs and cause memory leaks and race conditions.
	var/list/goap_goals_cache
	var/list/goap_actions_cache
*/
/mob/living/proc/init_ai_root(typepath)
	if(ai_root)
		if(ai_root.tree_typepath == typepath)
			return
		SSai.Unregister(src)

	ai_root = new /datum/behavior_tree/node/parallel/root(typepath, src)
	ai_root.blackboard = new
	configure_ai_root()
	SSai.Register(src)

/mob/living/proc/configure_ai_root()
	return


// =============================================================================
// UNUSED GOAP STUFF
// =============================================================================
// This comes from the GOAP implementation I wrote for IS12 Reborn. This is not
// currently used on this codebase, but may be useful in the future. If you're
// interested in GOAP, you will need to refactor these helpers to run on the
// parallel/root node.
/*
/datum/behavior_tree/node/proc/build_bt_action_index()
	if(!bt_action_cache)
		bt_action_cache = list()

	if(length(bt_action_cache))
		return
	_bt_index_walk(src)

/datum/behavior_tree/node/proc/_bt_index_walk(datum/behavior_tree/node/N)
	if(!N) return

	// If this is an action node, index the instance and key it to its typepath for easy access later.
	if(istype(N, /datum/behavior_tree/node/action))
		var/datum/behavior_tree/node/action/A = N
		if(A.my_action)
			var/path = A.my_action.type
			if(path && !bt_action_cache[path])
				bt_action_cache[path] = A.my_action
	else if(istype(N, /datum/behavior_tree/node/decorator))
		var/datum/behavior_tree/node/decorator/D = N
		_bt_index_walk(D.child)
	else if(istype(N, /datum/behavior_tree/node/sequence) || istype(N, /datum/behavior_tree/node/selector))
		var/list/nodes = N:my_nodes
		if(!nodes || !islist(nodes)) return
		for(var/datum/behavior_tree/node/child as anything in nodes)
			_bt_index_walk(child)

/datum/behavior_tree/node/proc/get_bt_action_instance(action_path)
	if(!ispath(action_path))
		return null
	return bt_action_cache[action_path]
*/

/datum/behavior_tree/node/proc/evaluate(mob/living/npc, atom/target, list/blackboard)
	return NODE_FAILURE

// This is a helper to check the timeout for special actions, like climbing ladders etc. It should only ever be called on a mob's ai_root node.
/datum/behavior_tree/node/parallel/root/proc/check_action_timeout(mob/living/user, duration = 2 SECONDS)
	if(!user.ai_root.blackboard[AIBLK_ACTION_TIMEOUT])
		user.ai_root.blackboard[AIBLK_ACTION_TIMEOUT] = world.time + duration
		return AI_ACTION_FIRST_ATTEMPT

	if(world.time > user.ai_root.blackboard[AIBLK_ACTION_TIMEOUT])
		return AI_ACTION_TIMED_OUT

	return AI_ACTION_WAITING

// SELECTOR (equivalent to logical OR)
// Tries each child node in order until one succeeds or is running. Fails if all children fail.
/datum/behavior_tree/node/selector
	var/list/my_nodes = list()

/datum/behavior_tree/node/selector/New()
	..()
	var/list/created = list()
	for (var/type in my_nodes)
		created += new type()
	my_nodes = created

/datum/behavior_tree/node/selector/evaluate(mob/living/npc, atom/target, list/blackboard)
	for(var/datum/behavior_tree/node/L as anything in my_nodes)
		switch(L.evaluate(npc, target, blackboard))
			if(NODE_FAILURE)
				continue
			if(NODE_SUCCESS)
				node_state = NODE_SUCCESS
				#ifdef BT_DEBUG
				if(world.time > next_log_tick)
					next_log_tick = world.time + next_log_delay
					var/state_string = "UNKNOWN"
					switch(node_state)
						if(NODE_SUCCESS) state_string = "SUCCESS"
						if(NODE_FAILURE) state_string = "FAILURE"
						if(NODE_RUNNING) state_string = "RUNNING"
					world.log << "BT DEBUG: [npc] -> Selector ([src.type]) -> [state_string]"
				#endif
				return node_state
			if(NODE_RUNNING)
				#ifdef BT_DEBUG
				if(world.time > next_log_tick)
					next_log_tick = world.time + next_log_delay
					var/state_string = "UNKNOWN"
					switch(node_state)
						if(NODE_SUCCESS) state_string = "SUCCESS"
						if(NODE_FAILURE) state_string = "FAILURE"
						if(NODE_RUNNING) state_string = "RUNNING"
					world.log << "BT DEBUG: [npc] -> Selector ([src.type]) -> [state_string]"
				#endif
				node_state = NODE_RUNNING
				return node_state
	node_state = NODE_FAILURE
	#ifdef BT_DEBUG
	if(world.time > next_log_tick)
		next_log_tick = world.time + next_log_delay
		var/state_string = "UNKNOWN"
		switch(node_state)
			if(NODE_SUCCESS) state_string = "SUCCESS"
			if(NODE_FAILURE) state_string = "FAILURE"
			if(NODE_RUNNING) state_string = "RUNNING"
		world.log << "BT DEBUG: [npc] -> Selector ([src.type]) -> [state_string]"
	#endif

	return node_state

/datum/behavior_tree/node/selector/Destroy()
	for(var/datum/D as anything in my_nodes)
		D.Destroy()
	my_nodes.len = 0
	. = ..()


// SEQUENCE (equivalent to logical AND)
// Runs each child node in order. Fails if any of its children do.
/datum/behavior_tree/node/sequence
	var/list/my_nodes = list()

/datum/behavior_tree/node/sequence/New()
	..()
	var/list/created = list()
	for (var/type in my_nodes)
		created += new type()
	my_nodes = created

/datum/behavior_tree/node/sequence/evaluate(mob/living/npc, atom/target, list/blackboard)
	for(var/datum/behavior_tree/node/L as anything in my_nodes)
		switch(L.evaluate(npc, target, blackboard))
			if(NODE_FAILURE)
				node_state = NODE_FAILURE
				#ifdef BT_DEBUG
				if(world.time > next_log_tick)
					next_log_tick = world.time + next_log_delay
					var/state_string = "UNKNOWN"
					switch(node_state)
						if(NODE_SUCCESS) state_string = "SUCCESS"
						if(NODE_FAILURE) state_string = "FAILURE"
						if(NODE_RUNNING) state_string = "RUNNING"
					world.log << "BT DEBUG: [npc] -> Sequence ([src.type]) -> [state_string]"
				#endif
				return node_state
			if(NODE_SUCCESS)
				continue
			if(NODE_RUNNING)
				node_state = NODE_RUNNING
				#ifdef BT_DEBUG
				if(world.time > next_log_tick)
					next_log_tick = world.time + next_log_delay
					var/state_string = "UNKNOWN"
					switch(node_state)
						if(NODE_SUCCESS) state_string = "SUCCESS"
						if(NODE_FAILURE) state_string = "FAILURE"
						if(NODE_RUNNING) state_string = "RUNNING"
					world.log << "BT DEBUG: [npc] -> Sequence ([src.type]) -> [state_string]"
				#endif
				return node_state
	node_state = NODE_SUCCESS
	#ifdef BT_DEBUG
	if(world.time > next_log_tick)
		next_log_tick = world.time + next_log_delay
		var/state_string = "UNKNOWN"
		switch(node_state)
			if(NODE_SUCCESS) state_string = "SUCCESS"
			if(NODE_FAILURE) state_string = "FAILURE"
			if(NODE_RUNNING) state_string = "RUNNING"
		world.log << "BT DEBUG: [npc] -> Sequence ([src.type]) -> [state_string]"
	#endif
	return node_state

/datum/behavior_tree/node/sequence/Destroy()
	// When a sequence is deleted, it tells all its children to delete themselves.
	for(var/datum/D as anything in my_nodes)
		D.Destroy()
	my_nodes.len = 0
	. = ..()

// PARALLEL
// Special node for situations where it is desirable to always run multiple nodes regardless of their state or return value.
// This is primarily used for attaching services to existing node branches.
// Always runs all children, always succeeds. Runs asynchronously.
/datum/behavior_tree/node/parallel
	var/list/my_nodes = list()

/datum/behavior_tree/node/parallel/New()
	..()
	var/list/created = list()
	for (var/type in my_nodes)
		created += new type()
	my_nodes = created

/datum/behavior_tree/node/parallel/evaluate(mob/living/npc, atom/target, list/blackboard)
	for(var/datum/behavior_tree/node/L as anything in my_nodes)
		INVOKE_ASYNC(L, PROC_REF(evaluate), npc, target, blackboard)
		
	return NODE_SUCCESS

/datum/behavior_tree/node/parallel/Destroy()
	for(var/datum/D as anything in my_nodes)
		D.Destroy()
	my_nodes.len = 0
	. = ..()

/// Special override for the root node. Handles running the movement tree in parallel
/// with the thinking tree. Skips over nodes to jump back to the last running node and
/// clears the running node if the node returns anything other than NODE_RUNNING.
/datum/behavior_tree/node/parallel/root/evaluate(mob/living/npc, atom/target, list/blackboard)
	if(GLOB.vn_move_sync)
		move_node.evaluate(npc, target, blackboard)
	else
		INVOKE_ASYNC(move_node, PROC_REF(evaluate), npc, target, blackboard)

	if(running_node)
		var/result = running_node.evaluate(npc, target, blackboard)
		if(result != NODE_RUNNING)
			running_node = null
	else
		main_node.evaluate(npc, target, blackboard)

	return NODE_SUCCESS

// ACTION (These are the "leaf" nodes that do the actual work by running bt_action datums.)
// This is a wrapper class. Each instance can hold a specific action datum.
/datum/behavior_tree/node/action
	var/bt_action/my_action
	var/invert = FALSE // If TRUE, success becomes failure and vice-versa.

/datum/behavior_tree/node/action/New(set_invert)
	..()
	if(my_action)
		my_action = new my_action()
	if(set_invert)
		invert = set_invert

/datum/behavior_tree/node/action/evaluate(mob/living/npc, atom/target, list/blackboard)
	if(!my_action)
		#ifdef BT_DEBUG
		if(world.time > next_log_tick)
			next_log_tick = world.time + next_log_delay
			var/state_string = "UNKNOWN"
			switch(node_state)
				if(NODE_SUCCESS) state_string = "SUCCESS"
				if(NODE_FAILURE) state_string = "FAILURE"
				if(NODE_RUNNING) state_string = "RUNNING"
			world.log << "BT DEBUG: [npc] -> Action ([src.type]) -> [state_string] due to missing bt_action from [src.type]!"
		#endif
		return NODE_FAILURE

	switch(BT_ACTION_EVAL(my_action, npc, target, blackboard))
		if(NODE_SUCCESS)
			node_state = invert ? NODE_FAILURE : NODE_SUCCESS
			#ifdef BT_DEBUG
			if(world.time > next_log_tick)
				next_log_tick = world.time + next_log_delay
				var/state_string = "UNKNOWN"
				switch(node_state)
					if(NODE_SUCCESS) state_string = "SUCCESS"
					if(NODE_FAILURE) state_string = "FAILURE"
					if(NODE_RUNNING) state_string = "RUNNING"
				world.log << "BT DEBUG: [npc] -> Action ([src.type]) -> [state_string]"
			#endif
			return node_state
		if(NODE_FAILURE)
			node_state = invert ? NODE_SUCCESS : NODE_FAILURE
			#ifdef BT_DEBUG
			if(world.time > next_log_tick)
				next_log_tick = world.time + next_log_delay
				var/state_string = "UNKNOWN"
				switch(node_state)
					if(NODE_SUCCESS) state_string = "SUCCESS"
					if(NODE_FAILURE) state_string = "FAILURE"
					if(NODE_RUNNING) state_string = "RUNNING"
				world.log << "BT DEBUG: [npc] -> Action ([src.type]) -> [state_string]"
			#endif
			return node_state
		if(NODE_RUNNING)
			node_state = NODE_RUNNING
			if(npc.ai_root)
				var/txt = "[my_action.type]"
				var/last_slash = findlasttext(txt, "/")
				if(last_slash)
					txt = copytext(txt, last_slash + 1)
				npc.ai_root.active_node_text = txt
				npc.ai_root.running_node = src

			#ifdef BT_DEBUG
			if(world.time > next_log_tick)
				next_log_tick = world.time + next_log_delay
				var/state_string = "UNKNOWN"
				switch(node_state)
					if(NODE_SUCCESS) state_string = "SUCCESS"
					if(NODE_FAILURE) state_string = "FAILURE"
					if(NODE_RUNNING) state_string = "RUNNING"
				world.log << "BT DEBUG: [npc] -> Action ([src.type]) -> [state_string]"
			#endif
			return node_state

	#ifdef BT_DEBUG
	if(world.time > next_log_tick)
		next_log_tick = world.time + next_log_delay
		var/state_string = "UNKNOWN"
		switch(node_state)
			if(NODE_SUCCESS) state_string = "SUCCESS"
			if(NODE_FAILURE) state_string = "FAILURE"
			if(NODE_RUNNING) state_string = "RUNNING"
		world.log << "BT DEBUG: [npc] -> Action ([src.type]) -> [state_string]"
	#endif

	return NODE_FAILURE

/datum/behavior_tree/node/action/Destroy()
	// The action wrapper also needs to clean up the action datum it holds.
	my_action.Destroy()
	. = ..(QDEL_HINT_IWILLGC)

// Decorator node, for things like Inverters, Succeeders, etc.
/datum/behavior_tree/node/decorator
	var/datum/behavior_tree/node/child

/datum/behavior_tree/node/decorator/New()
	..()
	if(child)
		child = new child()

/datum/behavior_tree/node/decorator/Destroy()
	if(child)
		child.Destroy()
	. = ..(QDEL_HINT_IWILLGC)

// TIMEOUT DECORATOR
// Interrupts the child node if it runs longer than the specified limit.
/datum/behavior_tree/node/decorator/timeout
	var/start_time = 0
	var/limit = 10 SECONDS

/datum/behavior_tree/node/decorator/timeout/New(new_limit)
	..()
	if(new_limit)
		limit = new_limit

/datum/behavior_tree/node/decorator/timeout/evaluate(mob/living/npc, atom/target, list/blackboard)
	// If we weren't running before, start the timer
	if(node_state != NODE_RUNNING)
		start_time = world.time

	// Check timeout
	if((world.time - start_time) > limit)
		node_state = NODE_FAILURE
		return node_state

	var/result = child.evaluate(npc, target, blackboard)
	node_state = result
	return result

// PROGRESS VALIDATOR DECORATOR
// Validates progress between ticks using a custom check.
// Override check_progress to implement specific logic.
/datum/behavior_tree/node/decorator/progress_validator
	var/last_state = null // Store generic state here

/datum/behavior_tree/node/decorator/progress_validator/evaluate(mob/living/npc, atom/target, list/blackboard)
	var/result = child.evaluate(npc, target, blackboard)
	
	if(result == NODE_RUNNING)
		if(!check_progress(npc, blackboard))
			node_state = NODE_FAILURE
			return node_state
	
	node_state = result
	return result

/datum/behavior_tree/node/decorator/progress_validator/proc/check_progress(mob/living/npc, list/blackboard)
	// Override me
	return TRUE

// STUCK SENSOR DECORATOR
// Checks if the mob has been stuck in the same location for too long.
// If so, clears the path (forcing a repath) and returns FAILURE.
/datum/behavior_tree/node/decorator/progress_validator/stuck_sensor
	var/turf/last_loc
	var/stuck_since = 0
	var/stuck_limit = 5 SECONDS

/datum/behavior_tree/node/decorator/progress_validator/stuck_sensor/New(limit)
	..()
	if(limit)
		stuck_limit = limit

/datum/behavior_tree/node/decorator/progress_validator/stuck_sensor/check_progress(mob/living/npc, list/blackboard)
	var/turf/T = get_turf(npc)
	if(T != last_loc)
		last_loc = T
		stuck_since = 0
		return TRUE
	
	if(stuck_since == 0)
		stuck_since = world.time
	
	if((world.time - stuck_since) > stuck_limit)
		// Stuck! Force repath.
		if(npc.ai_root) // Just in case, but should never happen
			npc.set_ai_path_to(null)
		
		// Reset timer to give the new path a chance
		stuck_since = 0 
		last_loc = null
		return FALSE // Forces failure
	
	return TRUE


// PARALLEL (FAIL EARLY)
// Like parallel, but returns NODE_FAILURE immediately if ANY child fails.
/datum/behavior_tree/node/parallel/fail_early

/datum/behavior_tree/node/parallel/fail_early/evaluate(mob/living/npc, atom/target, list/blackboard)
	var/any_running = FALSE
	var/any_failed = FALSE
	
	for(var/datum/behavior_tree/node/L as anything in my_nodes)
		var/result = L.evaluate(npc, target, blackboard)
		if(result == NODE_FAILURE)
			any_failed = TRUE
			break
		else if(result == NODE_RUNNING)
			any_running = TRUE
	
	if(any_failed)
		node_state = NODE_FAILURE
	else if(any_running)
		node_state = NODE_RUNNING
	else
		node_state = NODE_SUCCESS
	return node_state

// RETRY DECORATOR (COOLDOWN ON FAILURE)
// If the child returns FAILURE, it tracks the failure.
// After 'max_failures' consecutive failures, it enforces a cooldown ('wait')
// during which it forces the parent selector to proceed (by returning FAILURE immediately).
/datum/behavior_tree/node/decorator/retry
	var/cooldown = 5 SECONDS
	var/max_failures = 1
	var/failure_count = 0
	var/last_fail_time = 0

/datum/behavior_tree/node/decorator/retry/New(new_cooldown, new_max_failures)
	..()
	if(new_cooldown)
		cooldown = new_cooldown
	if(new_max_failures)
		max_failures = new_max_failures

/datum/behavior_tree/node/decorator/retry/evaluate(mob/living/npc, atom/target, list/blackboard)
	// Check if we are on cooldown
	if(last_fail_time > 0 && (world.time - last_fail_time) < cooldown)
		node_state = NODE_FAILURE
		return node_state

	var/result = child.evaluate(npc, target, blackboard)

	if(result == NODE_FAILURE)
		failure_count++
		if(failure_count >= max_failures)
			last_fail_time = world.time
			failure_count = 0 // Reset count so we can try again after cooldown
			// We return FAILURE, effectively "forcing parent selector to proceed" for the duration of the cooldown
	else
		// If success or running, reset failure count?
		// Usually yes, a success breaks the streak of failures.
		failure_count = 0
		// last_fail_time = 0 // Do not reset cooldown on success, it's a cooldown *on failure*.

	node_state = result
	return result

// COOLDOWN DECORATOR
// Only allows child to run if cooldown period has elapsed since last run
// Always returns SUCCESS (non-blocking) so it doesn't interfere with tree flow
/datum/behavior_tree/node/decorator/cooldown
	var/cooldown_time = 2 SECONDS
	var/last_run_time = 0

/datum/behavior_tree/node/decorator/cooldown/New(new_cooldown)
	..()
	if(new_cooldown)
		cooldown_time = new_cooldown

/datum/behavior_tree/node/decorator/cooldown/evaluate(mob/living/npc, atom/target, list/blackboard)
	// Check if we are on cooldown
	if(last_run_time > 0 && (world.time - last_run_time) < cooldown_time)
		node_state = NODE_SUCCESS // Non-blocking, just skip
		return node_state

	// Run child node
	child.evaluate(npc, target, blackboard)
	last_run_time = world.time

	node_state = NODE_SUCCESS // Always return success so we don't block tree flow
	return node_state

// TARGET PERSISTENCE DECORATOR
// Allows the NPC to "remember" a target for a short time after losing sight.
// This prevents rapid target switching and allows the NPC to commit to chasing.
/datum/behavior_tree/node/decorator/progress_validator/target_persistence
	var/persistence_time = 4 SECONDS // How long to remember target after losing sight
	var/lost_sight_at = 0
	var/last_target = null

/datum/behavior_tree/node/decorator/progress_validator/target_persistence/New(new_persistence_time)
	..()
	if(new_persistence_time)
		persistence_time = new_persistence_time

/datum/behavior_tree/node/decorator/progress_validator/target_persistence/check_progress(mob/living/npc, list/blackboard)
	if(!npc.ai_root || !npc.ai_root.target)
		// No target, reset state
		lost_sight_at = 0
		last_target = null
		return TRUE

	var/mob/living/current_target = npc.ai_root.target

	// Target changed, reset timer
	if(current_target != last_target)
		last_target = current_target
		lost_sight_at = 0
		return TRUE

	// Check if we can see the target
	var/can_see_target = (get_dist(npc, current_target) <= 15 && can_see(npc, current_target, 15))

	if(can_see_target)
		// We can see them, reset timer
		lost_sight_at = 0
		return TRUE

	// Can't see them - start or check timer
	if(lost_sight_at == 0)
		lost_sight_at = world.time
		return TRUE // First tick of not seeing them

	// Check if persistence time expired
	if((world.time - lost_sight_at) > persistence_time)
		// Lost them for too long, clear target and fail
		npc.ai_root.target = null
		last_target = null
		lost_sight_at = 0
		return FALSE

	// Still within persistence time
	return TRUE

// PURSUE TO LAST KNOWN LOCATION DECORATOR
// When a target is lost, the NPC will pursue to their last known location for a limited time.
// After arriving, transitions to searching behavior.
/datum/behavior_tree/node/decorator/timeout/pursue_timeout
	var/last_known_loc = null
	var/pursue_started = FALSE

/datum/behavior_tree/node/decorator/timeout/pursue_timeout/New(new_limit)
	if(!new_limit)
		new_limit = 10 SECONDS
	..(new_limit)

/datum/behavior_tree/node/decorator/timeout/pursue_timeout/evaluate(mob/living/npc, atom/target, list/blackboard)
	if(!npc.ai_root)
		return NODE_FAILURE

	var/turf/T = get_turf(npc.ai_root.target)

	// If we have a target in sight, store location and reset
	if(npc.ai_root.target && T)
		last_known_loc = T
		pursue_started = FALSE
		start_time = 0
		return child.evaluate(npc, target, blackboard)

	// No target, but have last known location
	if(last_known_loc && !pursue_started)
		pursue_started = TRUE
		start_time = world.time

	// Call parent timeout logic
	return ..(npc, target, blackboard)

// SEARCH AREA DECORATOR
// After pursuing to last known location, the NPC will search the area for a limited time.
/datum/behavior_tree/node/decorator/timeout/search_timeout

/datum/behavior_tree/node/decorator/timeout/search_timeout/New()
	..(10 SECONDS) // Default 10 second search time


// ==============================================================================
// OBSERVERS
// ==============================================================================
// Decorators that listen for a signal and abort their child (return FAILURE) if triggered.
// They also clear the running_node cache to force a tree re-evaluation.

/datum/behavior_tree/node/decorator/observer
	var/observed_signal
	var/triggered = FALSE
	var/reaction = FALSE
	var/datum/weakref/registered_to // weakref of what we registered to

/datum/behavior_tree/node/decorator/observer/New(signal_id)
	..()
	if(signal_id)
		observed_signal = signal_id

/datum/behavior_tree/node/decorator/observer/proc/register_signal_ref(datum/owner)
	var/datum/cur_owner = registered_to?.resolve()
	if(cur_owner)
		if(cur_owner == owner) return
		UnregisterSignal(cur_owner, observed_signal)
	
	RegisterSignal(owner, observed_signal, PROC_REF(on_signal))
	registered_to = WEAKREF(owner)

/datum/behavior_tree/node/decorator/observer/proc/on_signal(datum/source)
	SIGNAL_HANDLER
	triggered = TRUE
	// Force the tree to re-evaluate from root to catch this interruption
	if(!QDELETED(source) && isliving(source)) // Defensive programming I guess
		var/mob/living/L = source
		L.ai_root?.running_node = null

/datum/behavior_tree/node/decorator/observer/evaluate(mob/living/npc, atom/target, list/blackboard)
	register_signal_ref(npc) // Ensure registered

	if(reaction)
		if(!triggered)
			return NODE_FAILURE
		triggered = FALSE
		return child.evaluate(npc, target, blackboard)

	if(triggered)
		triggered = FALSE
		return NODE_FAILURE

	return child.evaluate(npc, target, blackboard)

/datum/behavior_tree/node/decorator/observer/Destroy()
	var/datum/cur_owner = registered_to?.resolve()
	if(cur_owner)
		UnregisterSignal(cur_owner, observed_signal)
		registered_to = null
	. = ..()


// ==============================================================================
// SERVICES
// ==============================================================================
// Decorators that run a maintenance task periodically while their branch is active.
// Used to update blackboard variables or send signals without interrupting the flow.

/datum/behavior_tree/node/decorator/service
	var/interval = 1 SECONDS
	var/next_fire = 0

/datum/behavior_tree/node/decorator/service/New(new_interval)
	..()
	if(new_interval)
		interval = new_interval

/datum/behavior_tree/node/decorator/service/evaluate(mob/living/npc, atom/target, list/blackboard)
	if(world.time >= next_fire)
		service_tick(npc, blackboard)
		next_fire = world.time + interval
	
	return child.evaluate(npc, target, blackboard)

/datum/behavior_tree/node/decorator/service/proc/service_tick(mob/living/npc, list/blackboard)
	// Override this to do work
	return

// Generic Service implementation for sending signals and updating blackboard keys/values
/datum/behavior_tree/node/decorator/service/generic
	var/signal_to_send
	var/list/argslist
	var/bb_key
	var/bb_value

/datum/behavior_tree/node/decorator/service/generic/New(_signal_to_send, list/_argslist, _bb_key, _bb_value)
	..()
	
	if(_signal_to_send)
		signal_to_send = _signal_to_send
	else
		signal_to_send = COMSIG_AI_BLACKBOARD_KEY_SET(_bb_key)
	
	if(islist(_argslist) && length(_argslist))
		argslist = _argslist

	if(_bb_key && _bb_value)
		bb_key = _bb_key
		bb_value = _bb_value

/datum/behavior_tree/node/decorator/service/generic/service_tick(mob/living/npc, list/blackboard)
	if(bb_key && blackboard[bb_key] && blackboard[bb_key] == bb_value) return

	if(signal_to_send)
		if((argslist && length(argslist)))
			SEND_SIGNAL(npc, signal_to_send, list2params(argslist))
		else
			SEND_SIGNAL(npc, signal_to_send)
			
	if(bb_key)
		blackboard[bb_key] = bb_value

// ==============================================================================
// ADDITIONAL OBSERVERS
// ==============================================================================

// TARGET LOST OBSERVER
// Triggered when target changes to null or is lost
/datum/behavior_tree/node/decorator/observer/target_lost
	observed_signal = COMSIG_AI_TARGET_CHANGED

/datum/behavior_tree/node/decorator/observer/target_lost/on_signal(datum/source, atom/new_target)
	if(!new_target)
		triggered = TRUE
		if(istype(source, /mob/living))
			var/mob/living/L = source
			if(L.ai_root) L.ai_root.running_node = null

// SELF PRESERVATION OBSERVER
// Triggered when health is low
/datum/behavior_tree/node/decorator/observer/self_preservation
	observed_signal = COMSIG_AI_LOW_HEALTH

// SQUAD UPDATE OBSERVER
// Triggered when squad state changes
/datum/behavior_tree/node/decorator/observer/squad_update
	observed_signal = COMSIG_AI_SQUAD_CHANGED

// PAIN CRITICAL OBSERVER
// Triggered when pain levels are critical
/datum/behavior_tree/node/decorator/observer/pain_crit
	observed_signal = COMSIG_AI_PAIN_CRIT

// HUNGRY OBSERVER
// Triggered when hunger is high
/datum/behavior_tree/node/decorator/observer/hungry
	observed_signal = COMSIG_AI_HUNGRY

/datum/behavior_tree/node/decorator/observer/path_blocked
	observed_signal = COMSIG_AI_PATH_BLOCKED

// TARGET DEATH OBSERVER
// Monitors ai_root.target - aborts if target dies
/datum/behavior_tree/node/decorator/observer/target_death
	observed_signal = COMSIG_LIVING_DEATH
	var/datum/weakref/target_ref

/datum/behavior_tree/node/decorator/observer/target_death/evaluate(mob/living/npc, atom/target, list/blackboard)
	// Register to the current target's death signal
	if(target && isliving(target))
		var/mob/living/current_target = target_ref?.resolve()
		if(current_target != target)
			// New target, re-register
			if(current_target)
				UnregisterSignal(current_target, observed_signal)
			RegisterSignal(target, observed_signal, PROC_REF(on_signal))
			target_ref = WEAKREF(target)

	if(triggered)
		triggered = FALSE
		if(npc.ai_root)
			npc.ai_root.running_node = null
			npc.ai_root.target = null
		return NODE_FAILURE

	return child.evaluate(npc, target, blackboard)

/datum/behavior_tree/node/decorator/observer/target_death/Destroy()
	var/mob/living/target = target_ref?.resolve()
	if(target)
		UnregisterSignal(target, observed_signal)
	target_ref = null
	. = ..()

// BAIT VALIDATION OBSERVER
// Monitors monster bait - aborts if bait dies
/datum/behavior_tree/node/decorator/observer/bait_validation
	observed_signal = COMSIG_LIVING_DEATH
	var/datum/weakref/bait_ref

/datum/behavior_tree/node/decorator/observer/bait_validation/evaluate(mob/living/npc, atom/target, list/blackboard)
	var/mob/living/bait = blackboard ? blackboard[AIBLK_MONSTER_BAIT] : null

	// Register to the bait's death signal if we have one
	if(bait)
		var/mob/living/current_bait = bait_ref?.resolve()
		if(current_bait != bait)
			// New bait, re-register
			if(current_bait)
				UnregisterSignal(current_bait, observed_signal)
			RegisterSignal(bait, observed_signal, PROC_REF(on_signal))
			bait_ref = WEAKREF(bait)

	if(triggered)
		triggered = FALSE
		if(npc.ai_root)
			npc.ai_root.running_node = null
			blackboard -= AIBLK_MONSTER_BAIT
		return NODE_FAILURE

	return child.evaluate(npc, target, blackboard)

/datum/behavior_tree/node/decorator/observer/bait_validation/Destroy()
	var/mob/living/bait = bait_ref?.resolve()
	if(bait)
		UnregisterSignal(bait, observed_signal)
	bait_ref = null
	. = ..()

 // ==============================================================================
 // ADDITIONAL SERVICES
 // ==============================================================================

 // HEALTH MONITOR SERVICE
 // Checks health and fires COMSIG_AI_LOW_HEALTH if critically low
/datum/behavior_tree/node/decorator/service/health_monitor
	interval = 1 SECOND
	var/threshold = 0.3 // 30% health default

/datum/behavior_tree/node/decorator/service/health_monitor/service_tick(mob/living/npc, list/blackboard)
	if(npc.health < npc.maxHealth * threshold)
		SEND_SIGNAL(npc, COMSIG_AI_LOW_HEALTH, npc.health)

// SQUAD MONITOR SERVICE
// Updates squad blackboard data and fires SQUAD_CHANGED if needed
/datum/behavior_tree/node/decorator/service/squad_monitor
	interval = 2 SECONDS

/datum/behavior_tree/node/decorator/service/squad_monitor/service_tick(mob/living/npc, list/blackboard)
	var/ai_squad/squad = blackboard[AIBLK_SQUAD_DATUM]

	// Check if we lost our squad
	if(squad && !(npc in squad.members))
		blackboard[AIBLK_SQUAD_DATUM] = null
		SEND_SIGNAL(npc, COMSIG_AI_SQUAD_CHANGED)
		return
	
	if(squad)
		// Update mates list
		var/list/mates = squad.members - npc
		blackboard[AIBLK_SQUAD_MATES] = mates

// SQUAD CLEANUP SERVICE
// Replaces the goblin_cleanup_squad_state polling action
/datum/behavior_tree/node/decorator/service/squad_cleanup
	interval = 3 SECONDS

/datum/behavior_tree/node/decorator/service/squad_cleanup/service_tick(mob/living/npc, list/blackboard)
	// Same logic as the action but as a service
	var/should_cleanup = FALSE
	if(!npc.ai_root.target || (isliving(npc.ai_root.target) && npc.ai_root.target:stat == DEAD))
		should_cleanup = TRUE

	var/ai_squad/squad = blackboard[AIBLK_SQUAD_DATUM]
	if(!squad || !(npc in squad.members))
		// Check fallback squad
		var/list/squad_mates = blackboard[AIBLK_SQUAD_MATES]
		if(!squad_mates || !length(squad_mates))
			should_cleanup = TRUE

	if(should_cleanup)
		blackboard -= AIBLK_SQUAD_ROLE
		blackboard -= AIBLK_SQUAD_MATES
		blackboard -= AIBLK_VIOLATION_INTERRUPTED
		blackboard -= AIBLK_DEFENDING_FROM_INTERRUPT
		blackboard -= AIBLK_IS_PINNING
		blackboard -= AIBLK_RESTRAIN_STATE

		var/mob/living/bait = blackboard[AIBLK_MONSTER_BAIT]
		if(!bait || bait.stat == DEAD || !bait.loc)
			blackboard -= AIBLK_MONSTER_BAIT
			blackboard -= AIBLK_S_ACTION
			blackboard -= AIBLK_DRAG_START_LOC

// PAIN MONITOR SERVICE
/datum/behavior_tree/node/decorator/service/pain_monitor
	interval = 1 SECOND

/datum/behavior_tree/node/decorator/service/pain_monitor/service_tick(mob/living/npc, list/blackboard)
	if(!iscarbon(npc)) return
	var/mob/living/carbon/C = npc
	if(C.get_complex_pain() >= ((C.STAEND * 10) * 0.9))
		SEND_SIGNAL(C, COMSIG_AI_PAIN_CRIT)

// HUNGER MONITOR SERVICE
/datum/behavior_tree/node/decorator/service/hunger_monitor
	interval = 10 SECONDS

/datum/behavior_tree/node/decorator/service/hunger_monitor/service_tick(mob/living/npc, list/blackboard)
	// Assuming simple_animal hunger logic or carbon hunger
	// For simple_animals:
	if(istype(npc, /mob/living/simple_animal))
		var/mob/living/simple_animal/S = npc
		if(S.food < 20) // Arbitrary threshold
			SEND_SIGNAL(S, COMSIG_AI_HUNGRY)
