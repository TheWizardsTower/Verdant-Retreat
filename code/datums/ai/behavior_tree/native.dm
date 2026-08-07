// ==============================================================================
// NATIVE BEHAVIOR-TREE OFFLOAD (verdant_native)
// ==============================================================================
// The native VM evaluates the per-mob MAIN tree (composites, decorators,
// observers, monitor services); every /bt_action leaf still runs in DM via
// intents, and the movement subtree stays fully DM.
//
// A tree type is exported once by walking a live instance in preorder; each
// mob keeps a same-order node list so intents (node ids) map back to its own
// node instances. Trees containing unsupported node types keep the DM
// evaluator (per-tree rollout).

/datum/behavior_tree/node/parallel/root
	/// native agent id (0 = not registered with the VM)
	var/vn_id = 0
	/// native tree id this mob runs
	var/vn_tree_id = 0
	/// preorder node instances; index = native node_id + 1
	var/list/vn_node_map
	/// TRUE once mob signals are bridged to the VM
	var/vn_signals_bound = FALSE
	/// weakref of the target watched for COMSIG_LIVING_DEATH
	var/datum/weakref/vn_death_watch

/// Serializes a node subtree in preorder ([type,p0,p1,p2,nchildren] per
/// node) and collects the instances into node_refs. Returns FALSE when any
/// node type has no native mapping - the whole tree then stays DM.
/proc/vn_export_node(datum/behavior_tree/node/N, list/out, list/node_refs)
	if(!istype(N))
		return FALSE
	node_refs += N
	var/ntype = 0
	var/p0 = 0
	var/p1 = 0
	var/p2 = 0
	var/list/children = list()

	if(istype(N, /datum/behavior_tree/node/action))
		var/datum/behavior_tree/node/action/A = N
		if(!A.my_action)
			return FALSE
		ntype = VN_BT_ACTION
		p0 = A.invert ? 1 : 0
	else if(istype(N, /datum/behavior_tree/node/selector))
		var/datum/behavior_tree/node/selector/S = N
		ntype = VN_BT_SELECTOR
		children = S.my_nodes
	else if(istype(N, /datum/behavior_tree/node/parallel/fail_early))
		var/datum/behavior_tree/node/parallel/P = N
		ntype = VN_BT_PARALLEL_FAIL_EARLY
		children = P.my_nodes
	else if(istype(N, /datum/behavior_tree/node/parallel))
		if(istype(N, /datum/behavior_tree/node/parallel/root))
			return FALSE // roots are never exported
		var/datum/behavior_tree/node/parallel/P = N
		ntype = VN_BT_PARALLEL
		children = P.my_nodes
	else if(istype(N, /datum/behavior_tree/node/sequence))
		var/datum/behavior_tree/node/sequence/Q = N
		ntype = VN_BT_SEQUENCE
		children = Q.my_nodes
	else if(istype(N, /datum/behavior_tree/node/decorator))
		var/datum/behavior_tree/node/decorator/D = N
		if(!D.child)
			return FALSE
		children = list(D.child)
		// most-derived checks first
		if(istype(N, /datum/behavior_tree/node/decorator/timeout/pursue_timeout))
			return FALSE // reads live target state mid-evaluate; DM-only
		else if(istype(N, /datum/behavior_tree/node/decorator/timeout))
			var/datum/behavior_tree/node/decorator/timeout/T = N
			ntype = VN_BT_TIMEOUT
			p0 = T.limit
		else if(istype(N, /datum/behavior_tree/node/decorator/progress_validator/stuck_sensor))
			var/datum/behavior_tree/node/decorator/progress_validator/stuck_sensor/S = N
			ntype = VN_BT_STUCK_SENSOR
			p0 = S.stuck_limit
		else if(istype(N, /datum/behavior_tree/node/decorator/progress_validator/target_persistence))
			var/datum/behavior_tree/node/decorator/progress_validator/target_persistence/T = N
			ntype = VN_BT_TARGET_PERSISTENCE
			p0 = T.persistence_time
		else if(istype(N, /datum/behavior_tree/node/decorator/progress_validator))
			if(N.type != /datum/behavior_tree/node/decorator/progress_validator)
				return FALSE // unknown validator subtype with custom check_progress
			ntype = VN_BT_PROGRESS_PASS
		else if(istype(N, /datum/behavior_tree/node/decorator/retry))
			var/datum/behavior_tree/node/decorator/retry/R = N
			ntype = VN_BT_RETRY
			p0 = R.cooldown
			p1 = R.max_failures
		else if(istype(N, /datum/behavior_tree/node/decorator/cooldown))
			var/datum/behavior_tree/node/decorator/cooldown/C = N
			ntype = VN_BT_COOLDOWN
			p0 = C.cooldown_time
		else if(istype(N, /datum/behavior_tree/node/decorator/observer))
			if(istype(N, /datum/behavior_tree/node/decorator/observer/bait_validation))
				return FALSE // watches a blackboard datum; DM-only
			var/datum/behavior_tree/node/decorator/observer/O = N
			ntype = VN_BT_OBSERVER
			p1 = O.reaction ? 1 : 0
			if(istype(N, /datum/behavior_tree/node/decorator/observer/target_lost))
				p0 = VN_SIG_TARGET_LOST
			else if(istype(N, /datum/behavior_tree/node/decorator/observer/self_preservation))
				p0 = VN_SIG_LOW_HEALTH
			else if(istype(N, /datum/behavior_tree/node/decorator/observer/squad_update))
				p0 = VN_SIG_SQUAD_CHANGED
			else if(istype(N, /datum/behavior_tree/node/decorator/observer/pain_crit))
				p0 = VN_SIG_PAIN_CRIT
			else if(istype(N, /datum/behavior_tree/node/decorator/observer/hungry))
				p0 = VN_SIG_HUNGRY
			else if(istype(N, /datum/behavior_tree/node/decorator/observer/target_death))
				p0 = VN_SIG_TARGET_DEATH
			else if(istype(N, /datum/behavior_tree/node/decorator/observer/aggressor_reaction))
				p0 = VN_SIG_ATTACKED
			else if(istype(N, /datum/behavior_tree/node/decorator/observer/path_blocked))
				p0 = VN_SIG_PATH_BLOCKED
			else
				return FALSE // custom signal observer
		else if(istype(N, /datum/behavior_tree/node/decorator/service))
			var/datum/behavior_tree/node/decorator/service/V = N
			p0 = V.interval
			if(istype(N, /datum/behavior_tree/node/decorator/service/health_monitor))
				var/datum/behavior_tree/node/decorator/service/health_monitor/H = N
				ntype = VN_BT_SERVICE_NATIVE
				p1 = VN_MON_HEALTH
				p2 = round(H.threshold * 1000)
			else if(istype(N, /datum/behavior_tree/node/decorator/service/pain_monitor))
				ntype = VN_BT_SERVICE_NATIVE
				p1 = VN_MON_PAIN
			else if(istype(N, /datum/behavior_tree/node/decorator/service/hunger_monitor))
				ntype = VN_BT_SERVICE_NATIVE
				p1 = VN_MON_HUNGER
				p2 = 20
			else
				// any other service dispatches its service_tick via intent
				ntype = VN_BT_SERVICE_INTENT
		else
			return FALSE // unknown decorator
	else
		return FALSE // unknown node family

	out += ntype
	out += p0
	out += p1
	out += p2
	out += length(children)
	for(var/datum/behavior_tree/node/child as anything in children)
		if(!vn_export_node(child, out, node_refs))
			return FALSE
	return TRUE

/// Registers this mob's main tree with the VM. Exports the tree type on
/// first sight; returns FALSE when the tree is unsupported (DM keeps it).
/datum/behavior_tree/node/parallel/root/proc/vn_register(mob/living/M)
	if(vn_id)
		return TRUE
	var/datum/behavior_tree/node/sequence/main/main_seq = main_node
	if(!istype(main_seq) || length(main_seq.my_nodes) < 2)
		return FALSE
	var/datum/behavior_tree/node/tree_root = main_seq.my_nodes[2]
	var/tree_key = "[tree_root.type]"

	var/tree_id = GLOB.vn_bt_tree_ids[tree_key]
	if(isnull(tree_id))
		var/list/out = list()
		var/list/refs = list()
		if(!vn_export_node(tree_root, out, refs))
			GLOB.vn_bt_tree_ids[tree_key] = 0
			log_world("verdant_native: BT tree [tree_key] has unsupported nodes; staying DM")
			return FALSE
		var/res = vn_bt_load(out)
		if(!isnum(res))
			vn_check_result(res, "bt_load")
			return FALSE
		tree_id = res
		GLOB.vn_bt_tree_ids[tree_key] = tree_id
		log_world("verdant_native: BT tree [tree_key] exported as id [tree_id] ([length(refs)] nodes)")
	if(!tree_id)
		return FALSE // known-unsupported

	// this instance's node list, same preorder as the export
	var/list/scratch = list()
	vn_node_map = list()
	if(!vn_export_node(tree_root, scratch, vn_node_map))
		vn_node_map = null
		return FALSE

	var/new_id = ++SSai.vn_next_id
	if(!vn_check_result(vn_bt_mob_add(new_id, tree_id), "bt_mob_add"))
		return FALSE
	vn_id = new_id
	vn_tree_id = tree_id
	SSai.vn_mobs["[vn_id]"] = M
	vn_bind_signals(M)
	return TRUE

/// Bridges the observer signals into the VM. In native mode the DM node
/// instances never evaluate, so their own RegisterSignal paths never run.
/datum/behavior_tree/node/parallel/root/proc/vn_bind_signals(mob/living/M)
	if(vn_signals_bound)
		return
	vn_signals_bound = TRUE
	RegisterSignal(M, COMSIG_AI_TARGET_CHANGED, PROC_REF(vn_on_target_changed))
	RegisterSignal(M, COMSIG_AI_LOW_HEALTH, PROC_REF(vn_on_low_health))
	RegisterSignal(M, COMSIG_AI_SQUAD_CHANGED, PROC_REF(vn_on_squad_changed))
	RegisterSignal(M, COMSIG_AI_PAIN_CRIT, PROC_REF(vn_on_pain_crit))
	RegisterSignal(M, COMSIG_AI_HUNGRY, PROC_REF(vn_on_hungry))
	RegisterSignal(M, COMSIG_AI_ATTACKED, PROC_REF(vn_on_attacked))
	RegisterSignal(M, COMSIG_AI_PATH_BLOCKED, PROC_REF(vn_on_path_blocked))

/datum/behavior_tree/node/parallel/root/proc/vn_on_target_changed(datum/source, atom/new_target)
	SIGNAL_HANDLER
	if(!new_target)
		SSai.vn_queue_signal(vn_id, VN_SIG_TARGET_LOST)
	// re-arm the target death watch (the DM observer registered per-target)
	var/mob/living/old_watch = vn_death_watch?.resolve()
	if(old_watch && old_watch != new_target)
		UnregisterSignal(old_watch, COMSIG_LIVING_DEATH)
		vn_death_watch = null
	if(isliving(new_target) && new_target != old_watch)
		RegisterSignal(new_target, COMSIG_LIVING_DEATH, PROC_REF(vn_on_target_death))
		vn_death_watch = WEAKREF(new_target)

/datum/behavior_tree/node/parallel/root/proc/vn_on_target_death(datum/source)
	SIGNAL_HANDLER
	SSai.vn_queue_signal(vn_id, VN_SIG_TARGET_DEATH)
	target = null // the DM target_death observer clears the target on trigger
	var/mob/living/watched = vn_death_watch?.resolve()
	if(watched)
		UnregisterSignal(watched, COMSIG_LIVING_DEATH)
	vn_death_watch = null

/datum/behavior_tree/node/parallel/root/proc/vn_on_low_health(datum/source)
	SIGNAL_HANDLER
	SSai.vn_queue_signal(vn_id, VN_SIG_LOW_HEALTH)

/datum/behavior_tree/node/parallel/root/proc/vn_on_squad_changed(datum/source)
	SIGNAL_HANDLER
	SSai.vn_queue_signal(vn_id, VN_SIG_SQUAD_CHANGED)

/datum/behavior_tree/node/parallel/root/proc/vn_on_pain_crit(datum/source)
	SIGNAL_HANDLER
	SSai.vn_queue_signal(vn_id, VN_SIG_PAIN_CRIT)

/datum/behavior_tree/node/parallel/root/proc/vn_on_hungry(datum/source)
	SIGNAL_HANDLER
	SSai.vn_queue_signal(vn_id, VN_SIG_HUNGRY)

/datum/behavior_tree/node/parallel/root/proc/vn_on_attacked(datum/source, mob/living/aggressor)
	SIGNAL_HANDLER
	SSai.vn_queue_signal(vn_id, VN_SIG_ATTACKED)

/datum/behavior_tree/node/parallel/root/proc/vn_on_path_blocked(datum/source, turf/blocked)
	SIGNAL_HANDLER
	SSai.vn_queue_signal(vn_id, VN_SIG_PATH_BLOCKED)

/// Executes one VM intent on this mob and reports leaf outcomes back.
/mob/living/proc/vn_execute_intent(node_id, kind)
	if(!ai_root)
		return
	switch(kind)
		if(VN_INTENT_ACTION)
			if(stat == DEAD)
				SSai.vn_queue_report(ai_root.vn_id, node_id, NODE_FAILURE)
				return
			var/datum/behavior_tree/node/action/A = null
			if(ai_root.vn_node_map && node_id + 1 <= length(ai_root.vn_node_map))
				A = ai_root.vn_node_map[node_id + 1]
			if(!istype(A) || !A.my_action)
				SSai.vn_queue_report(ai_root.vn_id, node_id, NODE_FAILURE)
				return
			var/status = BT_ACTION_EVAL(A.my_action, src, ai_root.target, ai_root.blackboard)
			if(isnull(status))
				status = NODE_FAILURE
			SSai.vn_queue_report(ai_root.vn_id, node_id, status)
		if(VN_INTENT_SERVICE)
			var/datum/behavior_tree/node/decorator/service/S = null
			if(ai_root.vn_node_map && node_id + 1 <= length(ai_root.vn_node_map))
				S = ai_root.vn_node_map[node_id + 1]
			if(istype(S))
				S.service_tick(src, ai_root.blackboard)
		if(VN_INTENT_CLEAR_PATH)
			set_ai_path_to(null)
		if(VN_INTENT_CLEAR_TARGET)
			ai_root.target = null // target_persistence clears without a signal
