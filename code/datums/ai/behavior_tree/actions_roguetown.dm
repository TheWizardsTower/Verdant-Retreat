// ==============================================================================
// ROGUETOWN BEHAVIOR TREE ACTIONS
// ==============================================================================

// ------------------------------------------------------------------------------
// SERVICES
// ------------------------------------------------------------------------------

// TARGET SCANNER SERVICE
// Periodically scans for targets and updates the blackboard
/datum/behavior_tree/node/decorator/service/target_scanner
	interval = 2 SECONDS
	var/scan_range = 7
	var/search_objects = FALSE

/datum/behavior_tree/node/decorator/service/target_scanner/service_tick(mob/living/npc, list/blackboard)
	var/list/targets = list()
	
	// Check simple_animal vars if applicable
	var/mob/living/simple_animal/hostile/H = npc
	var/should_search_objects = search_objects
	if(istype(H))
		should_search_objects = H.search_objects
		scan_range = H.vision_range

	if(!should_search_objects)
		targets = get_nearby_entities(npc, scan_range)
	else
		var/list/candidates = get_nearby_entities(npc, scan_range)
		for(var/mob/living/L in candidates)
			if(!los_blocked(npc, L))
				targets += L
	
	blackboard[AIBLK_POSSIBLE_TARGETS] = targets

// AGGRESSOR MANAGER SERVICE
// Cleans up the aggressor list periodically
/datum/behavior_tree/node/decorator/service/aggressor_manager
	interval = 2 SECONDS

/datum/behavior_tree/node/decorator/service/aggressor_manager/service_tick(mob/living/npc, list/blackboard)
	var/list/aggressors = blackboard[AIBLK_AGGRESSORS]
	if(!aggressors) return

	for(var/mob/living/L in aggressors)
		if(QDELETED(L) || L.stat == DEAD || get_dist(npc, L) > (npc.client?.view || 7))
			aggressors -= L

	if(!length(aggressors))
		blackboard -= AIBLK_AGGRESSORS

/datum/behavior_tree/node/decorator/service/chatter
	interval = 2 SECONDS

/datum/behavior_tree/node/decorator/service/chatter/service_tick(mob/living/npc, list/blackboard)
	var/mob/living/simple_animal/SA = npc
	if(!istype(SA))
		return
	SA.handle_automated_speech()

// ------------------------------------------------------------------------------
// OBSERVERS
// ------------------------------------------------------------------------------

// AGGRESSOR REACTION OBSERVER
// Triggers when the mob is attacked (via COMSIG_AI_ATTACKED)
/datum/behavior_tree/node/decorator/observer/aggressor_reaction
	observed_signal = COMSIG_AI_ATTACKED

// ------------------------------------------------------------------------------
// TARGETING
// ------------------------------------------------------------------------------

/bt_action/pick_best_target
	var/check_vision = TRUE

/bt_action/pick_best_target/evaluate(mob/living/user, mob/living/target, list/blackboard)
	var/list/candidates = blackboard[AIBLK_POSSIBLE_TARGETS]
	if(!candidates || !length(candidates))
		return NODE_FAILURE

	var/mob/living/simple_animal/hostile/H = user
	if(!istype(H)) return NODE_FAILURE

	var/list/current_aggressors = blackboard[AIBLK_AGGRESSORS]
	var/retaliate_only = !H.aggressive && istype(H, /mob/living/simple_animal/hostile/retaliate)

	var/list/valid_targets = list()

	for(var/atom/A in candidates)
		// Basic Checks
		if(A == user) continue
		if(isturf(A)) continue
		if(A.type == /atom/movable/lighting_object) continue
		var/is_wanted_prey = isliving(A) && length(H.wanted_prey) && is_type_in_typecache(A, H.wanted_prey)
		if(retaliate_only && !is_wanted_prey && !(current_aggressors && (A in current_aggressors))) continue

		// Hostile Checks
		if(ismob(A))
			var/mob/M = A
			if(M.stat == DEAD) continue
			if(world.time < M.mob_timers[MT_INVISIBILITY] && !H.see_invisible) continue
			if(M.status_flags & GODMODE) continue
			if(M.name in H.friends) continue
			
			// Sneak Check
			if(isliving(M))
				var/mob/living/L = M
				if(L.alpha == 0 && L.rogue_sneaking)
					if(!H.npc_detect_sneak(L, H.simple_detect_bonus))
						continue

		if(isliving(A) && !is_wanted_prey)
			if(H.search_objects >= 2) continue
			var/mob/living/L = A
			var/faction_check = H.faction_check_mob(L)
			if(H.robust_searching)
				if(faction_check && !H.attack_same) continue
				if(L.stat > H.stat_attack) continue
			else
				if((faction_check && !H.attack_same) || L.stat) continue
		
		if(isobj(A))
			if(!H.attack_all_objects && !is_type_in_typecache(A, H.wanted_objects))
				continue
				
		// Vision Check
		if(check_vision && los_blocked(user, A, TRUE))
			continue

		valid_targets += A

	if(!length(valid_targets))
		return NODE_FAILURE

	// Pick closest
	var/atom/best = null
	var/best_dist = 999
	
	for(var/atom/A in valid_targets)
		var/dist = get_dist(user, A)
		if(dist < best_dist)
			best_dist = dist
			best = A
	
	if(best)
		user.GiveTarget(best)
		H.LosePatience()
		H.GainPatience() // Reset patience logic
		H.last_aggro_loss = 0
		H.vision_range = H.aggro_vision_range

		// Add target to aggressors list if it's a living mob
		if(isliving(best))
			if(!blackboard[AIBLK_AGGRESSORS])
				blackboard[AIBLK_AGGRESSORS] = list()
			blackboard[AIBLK_AGGRESSORS] |= best

		// Taunt Logic
		if(H.emote_taunt.len && prob(H.taunt_chance))
			H.emote("me", 1, "[pick(H.emote_taunt)] at [best].")
			H.taunt_chance = max(H.taunt_chance-7,2)
		H.emote("aggro")

		return NODE_SUCCESS
		
	return NODE_FAILURE

/bt_action/switch_to_aggressor
	var/switch_threshold_dist = 2 // Switch if new aggressor is this much closer

/bt_action/switch_to_aggressor/evaluate(mob/living/user, mob/living/target, list/blackboard)
	var/list/aggressors = blackboard[AIBLK_AGGRESSORS]
	if(!aggressors) return NODE_FAILURE
	
	var/mob/living/current = user.ai_root.target
	var/mob/living/best_aggressor = null
	var/best_dist = 999
	var/mob/living/simple_animal/hostile/H = user
	var/is_hostile = istype(H)

	if(current)
		best_dist = get_dist(user, current)

	for(var/mob/living/A in aggressors)
		if(A == current) continue
		if(A.stat == DEAD) continue
		if(is_hostile)
			if(H.robust_searching)
				if(A.stat > H.stat_attack) continue
			else if(A.stat)
				continue

		var/dist = get_dist(user, A)
		if(dist < best_dist - switch_threshold_dist)
			best_dist = dist
			best_aggressor = A
	
	if(best_aggressor)
		user.GiveTarget(best_aggressor)
		blackboard[AIBLK_LAST_KNOWN_TARGET_LOC] = get_turf(best_aggressor)
		return NODE_SUCCESS
		
	return NODE_FAILURE

// ------------------------------------------------------------------------------
// MOVEMENT
// ------------------------------------------------------------------------------

/bt_action/set_movement_target
	var/target_key = AIBLK_LAST_KNOWN_TARGET_LOC

/bt_action/set_movement_target/evaluate(mob/living/user, mob/living/target, list/blackboard)
	var/dest = blackboard[target_key]
	if(!dest)
		if(user.ai_root.target)
			dest = user.ai_root.target
		else
			return NODE_FAILURE

	if(user.set_ai_path_to(dest))
		return NODE_SUCCESS // Path set, not running yet (movement node handles running)
	return NODE_FAILURE

/bt_action/check_path_progress
/bt_action/check_path_progress/evaluate(mob/living/user, mob/living/target, list/blackboard)
	if(!length(user.ai_root.path))
		return NODE_FAILURE
	return NODE_SUCCESS

// ------------------------------------------------------------------------------
// COMBAT
// ------------------------------------------------------------------------------

/bt_action/face_target
/bt_action/face_target/evaluate(mob/living/user, mob/living/target, list/blackboard)
	if(target)
		user.face_atom(target)
		return NODE_SUCCESS
	return NODE_FAILURE

/bt_action/do_melee_attack
/bt_action/do_melee_attack/evaluate(mob/living/user, mob/living/target, list/blackboard)
	if(!target) return NODE_FAILURE
	
	var/mob/living/simple_animal/hostile/H = user
	if(!istype(H)) return NODE_FAILURE
	
	if(world.time < user.ai_root.next_attack_tick)
		return NODE_FAILURE
	if(world.time < H.next_move)
		return NODE_FAILURE
	if(H.swinging)
		return NODE_FAILURE

	H.face_atom(target)
	if(length(H.possible_a_intents))
		H.a_intent = pick(H.possible_a_intents)
	H.ClickOn(target, list())
	if(!user.ai_root)
		return NODE_FAILURE
	user.ai_root.next_attack_tick = world.time + (user.ai_root.next_attack_delay || 10)
	return NODE_SUCCESS

/bt_action/do_ranged_attack
/bt_action/do_ranged_attack/evaluate(mob/living/user, mob/living/target, list/blackboard)
	if(!target) return NODE_FAILURE
	
	var/mob/living/simple_animal/hostile/H = user
	if(!istype(H)) return NODE_FAILURE
	
	if(H.ranged_cooldown > world.time)
		return NODE_FAILURE

	H.OpenFire(target)
	return NODE_SUCCESS

/bt_action/do_ranged_attack/passthrough/evaluate(mob/living/user, mob/living/target, list/blackboard)
	var/mob/living/simple_animal/hostile/H = user
	if(!istype(H) || !H.ranged || !target)
		return NODE_FAILURE
	if(get_dist(user, target) <= 1)
		return NODE_FAILURE
	..()
	return NODE_FAILURE

// ------------------------------------------------------------------------------
// UTILITY ACTIONS
// ------------------------------------------------------------------------------

/bt_action/move_to_destination
/bt_action/move_to_destination/evaluate(mob/living/user, atom/target, list/blackboard)
	if(!user.ai_root) return NODE_FAILURE

	var/atom/destination = user.ai_root.move_destination
	if(!destination)
		if(target && target != user)
			if(user.set_ai_path_to(target))
				return NODE_RUNNING
		return NODE_FAILURE

	var/distcheck = isturf(destination) ? 0 : 1
	if(get_dist(user, destination) <= distcheck || get_turf(user) == get_turf(destination))
		user.set_ai_path_to(null)
		return NODE_SUCCESS

	if(length(user.ai_root.path))
		return NODE_RUNNING
	if(user.set_ai_path_to(destination))
		return NODE_RUNNING

	return NODE_FAILURE

/bt_action/find_food
	var/search_range = 5
/bt_action/find_food/evaluate(mob/living/user, mob/living/target, list/blackboard)
	if(!user.ai_root) return NODE_FAILURE
	var/mob/living/simple_animal/SA = user
	if(!istype(SA) || !length(SA.food_type)) return NODE_FAILURE

	var/atom/current_food = blackboard[AIBLK_FOOD_TARGET]
	if(current_food && !QDELETED(current_food) && get_dist(user, current_food) <= search_range)
		if(current_food.loc) return NODE_SUCCESS

	blackboard -= AIBLK_FOOD_TARGET
	for(var/obj/item/F in ai_view(search_range, user))
		if(is_type_in_list(F, SA.food_type))
			blackboard[AIBLK_FOOD_TARGET] = F
			return NODE_SUCCESS
	return NODE_FAILURE

/bt_action/eat_food/evaluate(mob/living/user, mob/living/target, list/blackboard)
	if(!user.ai_root) return NODE_FAILURE
	var/atom/movable/food = blackboard[AIBLK_FOOD_TARGET]
	if(!food || QDELETED(food)) return NODE_FAILURE

	if(get_dist(user, food) > 1)
		user.ai_root.move_destination = food
		return NODE_FAILURE

	user.face_atom(food)
	playsound(user, 'sound/misc/eat.ogg', rand(30,60), TRUE)
	qdel(food)
	blackboard -= AIBLK_FOOD_TARGET

	if(istype(user, /mob/living/simple_animal))
		var/mob/living/simple_animal/SA = user
		SA.food = max(SA.food + 30, 100)

	return NODE_SUCCESS

/bt_action/check_hunger
/bt_action/check_hunger/evaluate(mob/living/user, mob/living/target, list/blackboard)
	var/mob/living/simple_animal/SA = user
	if(!istype(SA) || !length(SA.food_type)) return NODE_FAILURE
	if(SA.stat) return NODE_FAILURE
	var/threshold = 50
	if(istype(SA, /mob/living/simple_animal/hostile/retaliate/rogue))
		var/mob/living/simple_animal/hostile/retaliate/rogue/R = SA
		if(R.eat_forever)
			return NODE_SUCCESS
		threshold = R.food_max
	if(SA.food > threshold)
		return NODE_FAILURE
	return NODE_SUCCESS

/bt_action/clear_target
/bt_action/clear_target/evaluate(mob/living/user, mob/living/target, list/blackboard)
	// Remove current target from aggressors before clearing
	if(user.ai_root.target && blackboard[AIBLK_AGGRESSORS])
		blackboard[AIBLK_AGGRESSORS] -= user.ai_root.target
		if(!length(blackboard[AIBLK_AGGRESSORS]))
			blackboard -= AIBLK_AGGRESSORS

	user.ai_root.target = null
	return NODE_SUCCESS

/bt_action/has_valid_target
/bt_action/has_valid_target/evaluate(mob/living/user, mob/living/target, list/blackboard)
	if(!target || target.stat == DEAD)
		return NODE_FAILURE
	var/mob/living/simple_animal/hostile/H = user
	if(istype(H))
		if(H.robust_searching)
			if(target.stat > H.stat_attack)
				return NODE_FAILURE
		else if(target.stat)
			return NODE_FAILURE
	return NODE_SUCCESS


// ==============================================================================
// SPECIALIZED ACTIONS
// ==============================================================================

/bt_action/simple_animal_pursue_last_known/evaluate(mob/living/user, mob/living/target, list/blackboard)
	if(!user.ai_root) return NODE_FAILURE
	if(user.ai_root.target) return NODE_FAILURE // Only pursue if no target
	var/turf/last_known = blackboard[AIBLK_LAST_KNOWN_TARGET_LOC]
	if(!last_known) return NODE_FAILURE
	if(get_turf(user) == last_known)
		blackboard -= AIBLK_LAST_KNOWN_TARGET_LOC
		return NODE_SUCCESS
	if(user.set_ai_path_to(last_known)) return NODE_RUNNING
	return NODE_FAILURE

/bt_action/simple_animal_search_area/evaluate(mob/living/user, mob/living/target, list/blackboard)
	if(!user.ai_root) return NODE_FAILURE
	if(user.ai_root.target) return NODE_SUCCESS

	if(prob(40) && world.time >= user.ai_root.next_move_tick)
		var/list/dirs = GLOB.cardinals.Copy()
		for(var/move_dir in dirs)
			var/turf/T = get_step(user, move_dir)
			if(T && !T.density)
				if(user.Move(T, get_dir(user, T)))
					user.ai_root.next_move_tick = world.time + user.ai_root.next_move_delay
					return NODE_SUCCESS
				break
	return NODE_FAILURE





/bt_action/target_in_range
	var/range = 1
/bt_action/target_in_range/evaluate(mob/living/user, mob/living/target, list/blackboard)
	if(target && get_dist(user, target) <= range) return NODE_SUCCESS
	return NODE_FAILURE

/bt_action/target_in_range/reach2
	range = 2

/bt_action/move_to_target/evaluate(mob/living/user, mob/living/target, list/blackboard)
	if(!target) return NODE_FAILURE
	var/stop_dist = 1
	var/mob/living/simple_animal/hostile/H = user
	if(istype(H) && H.minimum_distance > 1)
		stop_dist = H.minimum_distance
	if(stop_dist > 1)
		if(get_dist(user, target) <= stop_dist) return NODE_SUCCESS
	else if(get_dist(user, target) <= 1 && user.Adjacent(target))
		return NODE_SUCCESS
	if(user.set_ai_path_to(target)) return NODE_RUNNING
	return NODE_FAILURE

/mob/living/simple_animal/proc/handle_automated_speech()
	if(!ai_root)
		return
	if(world.time < ai_root.next_chatter_tick)
		return
	ai_root.next_chatter_tick = world.time + 2 SECONDS
	if(!speak_chance || !prob(speak_chance))
		return
	if(speak && speak.len)
		if((emote_hear && emote_hear.len) || (emote_see && emote_see.len))
			var/total = speak.len
			if(emote_hear && emote_hear.len)
				total += emote_hear.len
			if(emote_see && emote_see.len)
				total += emote_see.len
			var/randomValue = rand(1, total)
			if(randomValue <= speak.len)
				say(pick(speak))
			else
				randomValue -= speak.len
				if(emote_see && randomValue <= emote_see.len)
					emote("me", 1, pick(emote_see))
				else
					emote("me", 2, pick(emote_hear))
		else
			say(pick(speak))
	else
		if(!(emote_hear && emote_hear.len) && (emote_see && emote_see.len))
			emote("me", 1, pick(emote_see))
		if((emote_hear && emote_hear.len) && !(emote_see && emote_see.len))
			emote("me", 2, pick(emote_hear))
		if((emote_hear && emote_hear.len) && (emote_see && emote_see.len))
			var/total = emote_hear.len + emote_see.len
			var/pickv = rand(1, total)
			if(pickv <= emote_see.len)
				emote("me", 1, pick(emote_see))
			else
				emote("me", 2, pick(emote_hear))

/bt_action/idle_chatter
/bt_action/idle_chatter/evaluate(mob/living/user, mob/living/target, list/blackboard)
	var/mob/living/simple_animal/SA = user
	if(istype(SA))
		SA.handle_automated_speech()
	return NODE_SUCCESS

/bt_action/idle_wander/evaluate(mob/living/user, mob/living/target, list/blackboard)
	var/mob/living/simple_animal/SA = user
	if(!istype(SA)) return NODE_FAILURE

	if(!SA.wander || SA.stop_automated_movement || SA.doing)
		return NODE_FAILURE
	if(SA.stop_automated_movement_when_pulled && SA.pulledby)
		return NODE_FAILURE
	if(world.time < user.ai_root.next_wander_tick)
		return NODE_FAILURE
	user.ai_root.next_wander_tick = world.time + max(1, SA.turns_per_move) * 2 SECONDS

	if(world.time >= user.ai_root.next_move_tick)
		var/turf/T = get_step(user, pick(GLOB.cardinals))
		if(T && !T.density)
			if(user.Move(T, get_dir(user, T)))
				user.ai_root.next_move_tick = world.time + user.ai_root.next_move_delay
				return NODE_SUCCESS
	return NODE_FAILURE





/bt_action/dreamfiend_blink
	var/blink_range = 5
/bt_action/dreamfiend_blink/evaluate(mob/living/user, mob/living/target, list/blackboard)
	var/mob/living/simple_animal/hostile/rogue/dreamfiend/D = user
	if(!istype(D) || !target) return NODE_FAILURE
	if(get_dist(user, target) <= blink_range) return NODE_FAILURE
	if(D.blink_to_target(target))
		return NODE_SUCCESS
	return NODE_FAILURE

/bt_action/dreamfiend_kick
	var/kick_cooldown = 20 SECONDS
	var/next_kick = 0
/bt_action/dreamfiend_kick/evaluate(mob/living/user, mob/living/target, list/blackboard)
	var/mob/living/simple_animal/hostile/rogue/dreamfiend/ancient/A = user
	if(!istype(A) || !target || !ishuman(target)) return NODE_FAILURE
	if(get_dist(user, target) > 1) return NODE_FAILURE
	if(world.time < next_kick) return NODE_FAILURE
	next_kick = world.time + kick_cooldown
	var/mob/living/carbon/human/H = target
	user.face_atom(H)
	user.visible_message(span_danger("[user] kicks [H]!"))
	var/turf/shove_turf = get_step(H, get_dir(user, H))
	if(shove_turf && !shove_turf.density && H.Move(shove_turf, get_dir(user, H)))
		H.Knockdown(20)
	else
		H.Knockdown(40)
	H.apply_damage(50, BRUTE, BODY_ZONE_CHEST)
	return NODE_SUCCESS

/bt_action/dreamfiend_desummon
	var/idle_grace = 3 SECONDS
	var/idle_since = 0
	var/desummon_started = FALSE
/bt_action/dreamfiend_desummon/evaluate(mob/living/user, mob/living/target, list/blackboard)
	var/mob/living/simple_animal/hostile/rogue/dreamfiend/D = user
	if(!istype(D) || !D.desummons_when_idle) return NODE_FAILURE
	if(desummon_started) return NODE_FAILURE
	var/list/aggressors = blackboard[AIBLK_AGGRESSORS]
	if(target || (aggressors && length(aggressors)))
		idle_since = 0
		desummon_started = FALSE
		return NODE_FAILURE
	if(!idle_since)
		idle_since = world.time
		return NODE_FAILURE
	if(world.time - idle_since < idle_grace)
		return NODE_FAILURE
	desummon_started = TRUE
	INVOKE_ASYNC(D, TYPE_PROC_REF(/mob/living/simple_animal/hostile/rogue/dreamfiend, return_to_abyssor))
	return NODE_SUCCESS

/bt_action/escape_confinement/evaluate(mob/living/user, mob/living/target, list/blackboard)
	var/mob/living/simple_animal/hostile/H = user
	if(!istype(H)) return NODE_FAILURE
	if(H.buckled)
		H.buckled.attack_animal(H)
		return NODE_SUCCESS
	if(!H.targets_from.loc) return NODE_FAILURE
	if(!isturf(H.targets_from.loc))
		var/atom/A = H.targets_from.loc
		A.attack_animal(H)
		return NODE_SUCCESS
	return NODE_FAILURE

/bt_action/destroy_path
	var/next_smash = 0
/bt_action/destroy_path/evaluate(mob/living/user, mob/living/target, list/blackboard)
	var/mob/living/simple_animal/hostile/H = user
	if(!istype(H) || !target) return NODE_FAILURE
	if(!H.environment_smash) return NODE_FAILURE
	if(world.time < next_smash) return NODE_FAILURE
	next_smash = world.time + 2 SECONDS
	var/dir_to_target = get_dir(H.targets_from, target)
	var/turf/V = get_turf(H)
	for (var/obj/structure/O in V.contents)
		if(isstructure(O) && !(O in H.favored_structures))
			O.attack_animal(H)
			return NODE_SUCCESS
	var/list/dir_list = list()
	if(dir_to_target in GLOB.diagonals)
		for(var/direction in GLOB.cardinals)
			if(direction & dir_to_target) dir_list += direction
	else dir_list += dir_to_target
	for(var/direction in dir_list)
		var/turf/T = get_step(H.targets_from, direction)
		if(QDELETED(T)) continue
		if(T.Adjacent(H.targets_from))
			if(H.CanSmashTurfs(T))
				T.attack_animal(H)
				return NODE_SUCCESS
		for(var/obj/O in T.contents)
			if(!O.Adjacent(H.targets_from)) continue
			if(O in H.favored_structures) continue
			if((ismachinery(O) || isstructure(O)) && H.environment_smash >= ENVIRONMENT_SMASH_STRUCTURES && !O.IsObscured())
				O.attack_animal(H)
				return NODE_SUCCESS
	for(var/obj/structure/O in get_step(H, dir_to_target))
		if(O.density && O.climbable)
			O.climb_structure(H)
			return NODE_SUCCESS
	return NODE_FAILURE

/bt_action/find_hidden/evaluate(mob/living/user, mob/living/target, list/blackboard)
	var/mob/living/simple_animal/hostile/H = user
	if(!istype(H) || !target) return NODE_FAILURE
	if(istype(target.loc, /obj/structure/closet))
		var/atom/A = target.loc
		if(user.set_ai_path_to(A))
			if(A.Adjacent(H.targets_from))
				A.attack_animal(H)
				return NODE_SUCCESS
			return NODE_RUNNING
	return NODE_FAILURE

/bt_action/flee_target
	var/run_distance = 8
	var/until_destination = FALSE
/bt_action/flee_target/evaluate(mob/living/user, mob/living/target, list/blackboard)
	if(!target) return NODE_FAILURE
	var/escaped = QDELETED(target) || !can_see(user, target, run_distance)
	if(escaped)
		user.set_ai_path_to(null)
		return NODE_SUCCESS
	if(until_destination && user.ai_root && user.ai_root.move_destination)
		if(get_dist(user, user.ai_root.move_destination) <= 1)
			user.set_ai_path_to(null)
			return NODE_SUCCESS
		return NODE_RUNNING
	var/turf/best_dest = get_ranged_target_turf(user, get_dir(target, user), run_distance)
	if(user.set_ai_path_to(best_dest)) return NODE_RUNNING
	return NODE_FAILURE

/bt_action/flee_target/injured
	var/flee_duration = 6 SECONDS
	var/reflee_cooldown = 60 SECONDS
	var/stop_health_fraction = 0.75
/bt_action/flee_target/injured/evaluate(mob/living/user, mob/living/target, list/blackboard)
	var/mob/living/simple_animal/SA = user
	if(!istype(SA)) return NODE_FAILURE

	var/flee_until = blackboard[AIBLK_FLEE_UNTIL]
	if(!flee_until)
		if(SA.health >= SA.maxHealth * stop_health_fraction) return NODE_FAILURE
		var/next_allowed = blackboard[AIBLK_NEXT_FLEE_ALLOWED]
		if(next_allowed && world.time < next_allowed) return NODE_FAILURE
		if(!target) return NODE_FAILURE
		blackboard[AIBLK_FLEE_FROM] = get_turf(target)
		blackboard[AIBLK_NEXT_FLEE_ALLOWED] = world.time + reflee_cooldown
		flee_until = world.time + flee_duration
		blackboard[AIBLK_FLEE_UNTIL] = flee_until
		user.LoseTarget()

	if(SA.health >= SA.maxHealth * stop_health_fraction || world.time >= flee_until)
		blackboard -= AIBLK_FLEE_UNTIL
		blackboard -= AIBLK_FLEE_FROM
		user.set_ai_path_to(null)
		return NODE_SUCCESS

	var/turf/away_from = blackboard[AIBLK_FLEE_FROM]
	if(away_from)
		var/turf/best_dest = get_ranged_target_turf(user, get_dir(away_from, user), run_distance)
		user.set_ai_path_to(best_dest)
	return NODE_RUNNING

/bt_action/set_move_target_key
	var/blackboard_key
/bt_action/set_move_target_key/evaluate(mob/living/user, mob/living/target, list/blackboard)
	if(!user.ai_root) return NODE_FAILURE
	var/atom/dest = user.ai_root.blackboard[blackboard_key]
	if(!dest || QDELETED(dest)) return NODE_FAILURE
	if(user.set_ai_path_to(dest))
		return NODE_SUCCESS
	return NODE_FAILURE

/bt_action/check_friendly_fire/evaluate(mob/living/user, mob/living/target, list/blackboard)
	var/mob/living/simple_animal/hostile/H = user
	if(!istype(H) || !target) return NODE_FAILURE
	if(!H.check_friendly_fire) return NODE_FAILURE
	for(var/turf/T in getline(H, target))
		for(var/mob/living/L in T)
			if(L == H || L == target) continue
			if(H.faction_check_mob(L) && !H.attack_same) return NODE_SUCCESS
	return NODE_FAILURE

/bt_action/use_ability
	var/ability_key = "targeted_action"
/bt_action/use_ability/evaluate(mob/living/user, mob/living/target, list/blackboard)
	if(!user.ai_root) return NODE_FAILURE
	var/datum/action/cooldown/ability = user.ai_root.blackboard[ability_key]
	if(!ability) return NODE_FAILURE
	if(!target) return NODE_FAILURE
	if(ability.IsAvailable())
		ability.Trigger(target = target)
		return NODE_SUCCESS
	return NODE_FAILURE

/bt_action/find_and_set
	var/blackboard_key
	var/locate_path
	var/search_range = 7
	var/check_hands = FALSE
/bt_action/find_and_set/evaluate(mob/living/user, mob/living/target, list/blackboard)
	if(!user.ai_root) return NODE_FAILURE
	if(!blackboard_key || !locate_path) return NODE_FAILURE
	var/found_thing = null
	if(check_hands)
		if(locate(locate_path) in user.held_items) found_thing = locate(locate_path) in user.held_items
	if(!found_thing)
		var/list/candidates = ai_view(search_range, user)
		for(var/atom/A in candidates)
			if(istype(A, locate_path))
				found_thing = A
				break
	if(found_thing)
		user.ai_root.blackboard[blackboard_key] = found_thing
		return NODE_SUCCESS
	return NODE_FAILURE

/bt_action/mimic_disguise/evaluate(mob/living/user, mob/living/target, list/blackboard)
	if(istype(user, /mob/living/simple_animal/hostile/retaliate/rogue/mimic))
		var/mob/living/simple_animal/hostile/retaliate/rogue/mimic/M = user
		M.disguise()
		return NODE_SUCCESS
	return NODE_FAILURE

/bt_action/mimic_undisguise/evaluate(mob/living/user, mob/living/target, list/blackboard)
	if(istype(user, /mob/living/simple_animal/hostile/retaliate/rogue/mimic))
		var/mob/living/simple_animal/hostile/retaliate/rogue/mimic/M = user
		M.undisguise()
		return NODE_SUCCESS
	return NODE_FAILURE

/bt_action/follow_target
	var/max_follow_dist = 0
	var/stop_if_leader_has_target = FALSE
/bt_action/follow_target/evaluate(mob/living/user, mob/living/target, list/blackboard)
	var/atom/movable/follow_target = blackboard[AIBLK_FOLLOW_TARGET]
	if(!follow_target || QDELETED(follow_target))
		blackboard -= AIBLK_FOLLOW_TARGET
		return NODE_FAILURE
	var/limit = max_follow_dist || user.client?.view || 7
	if(get_dist(user, follow_target) > limit)
		blackboard -= AIBLK_FOLLOW_TARGET
		return NODE_FAILURE
	if(istype(follow_target, /mob/living) && (follow_target:stat == DEAD))
		blackboard -= AIBLK_FOLLOW_TARGET
		return NODE_SUCCESS
	if(stop_if_leader_has_target && isliving(follow_target))
		var/mob/living/leader = follow_target
		if(leader.ai_root && leader.ai_root.target)
			return NODE_FAILURE
	if(get_dist(user, follow_target) <= 1) return NODE_SUCCESS
	if(user.set_ai_path_to(follow_target))
		return NODE_RUNNING
	return NODE_FAILURE

/bt_action/follow_target/mirespider
	max_follow_dist = 12
	stop_if_leader_has_target = TRUE

/bt_action/perform_emote
	var/emote_id
/bt_action/perform_emote/evaluate(mob/living/user, mob/living/target, list/blackboard)
	var/emote = emote_id ? emote_id : user.ai_root.blackboard[AIBLK_PERFORM_EMOTE_ID]
	if(!emote) return NODE_FAILURE
	user.emote(emote)
	return NODE_SUCCESS

/bt_action/perform_speech
	var/speech_text
/bt_action/perform_speech/evaluate(mob/living/user, mob/living/target, list/blackboard)
	var/speech = speech_text ? speech_text : user.ai_root.blackboard[AIBLK_PERFORM_SPEECH_TEXT]
	if(!speech) return NODE_FAILURE
	user.say(speech, forced = "AI Controller")
	return NODE_SUCCESS

/bt_action/recuperate/evaluate(mob/living/user, mob/living/target, list/blackboard)
	var/mob/living/simple_animal/pawn = user
	if(!istype(pawn) || QDELETED(pawn)) return NODE_FAILURE
	if(pawn.health >= pawn.maxHealth) return NODE_SUCCESS
	if(user.doing) return NODE_RUNNING
	INVOKE_ASYNC(pawn, TYPE_PROC_REF(/mob/living/simple_animal, recuperate))
	return NODE_RUNNING

/bt_action/resist/evaluate(mob/living/user, mob/living/target, list/blackboard)
	user.resist()
	return NODE_SUCCESS

/bt_action/use_in_hand/evaluate(mob/living/user, mob/living/target, list/blackboard)
	var/obj/item/held = user.get_active_held_item()
	if(!held) return NODE_FAILURE
	user.activate_hand(user.active_hand_index)
	return NODE_SUCCESS

/bt_action/use_on_object/evaluate(mob/living/user, mob/living/target, list/blackboard)
	var/atom/use_target = user.ai_root.blackboard[AIBLK_USE_TARGET]
	if(!use_target || !user.CanReach(use_target)) return NODE_FAILURE
	var/obj/item/held_item = user.get_active_held_item()
	if(held_item) held_item.melee_attack_chain(user, use_target)
	else user.UnarmedAttack(use_target, TRUE)
	return NODE_SUCCESS

/bt_action/idle_crab_walk
	var/walk_chance = 10
/bt_action/idle_crab_walk/evaluate(mob/living/user, mob/living/target, list/blackboard)
	if(user.ai_root.blackboard[AIBLK_FOOD_TARGET]) return NODE_FAILURE
	if(prob(walk_chance) && (user.mobility_flags & MOBILITY_MOVE) && isturf(user.loc) && !user.pulledby)
		var/move_dir = pick(WEST, EAST)
		step(user, move_dir)
		return NODE_SUCCESS
	return NODE_FAILURE

/bt_action/minion_follow
	var/distance = 12
/bt_action/minion_follow/evaluate(mob/living/user, mob/living/target, list/blackboard)
	var/turf/travel = user.ai_root.blackboard[AIBLK_MINION_TRAVEL_DEST]
	if(travel)
		if(get_dist(user, travel) <= 1)
			user.ai_root.blackboard -= AIBLK_MINION_TRAVEL_DEST
			user.set_ai_path_to(null)
			return NODE_SUCCESS
		user.ai_root.move_destination = travel
		if(user.set_ai_path_to(travel)) return NODE_RUNNING
		return NODE_FAILURE
	var/mob/following = user.ai_root.blackboard[AIBLK_MINION_FOLLOW_TARGET]
	if(following)
		if(get_dist(user, following) > distance)
			user.ai_root.blackboard -= AIBLK_MINION_FOLLOW_TARGET
			return NODE_FAILURE
		if(get_dist(user, following) > 1)
			user.ai_root.move_destination = following
			if(user.set_ai_path_to(following)) return NODE_RUNNING
		return NODE_SUCCESS
	return NODE_FAILURE

/bt_action/call_reinforcements
	var/reinforcements_range = 12
	var/cooldown = 30 SECONDS
/bt_action/call_reinforcements/evaluate(mob/living/user, mob/living/target, list/blackboard)
	if(user.ai_root.blackboard[AIBLK_REINFORCEMENTS_COOLDOWN] > world.time) return NODE_FAILURE
	if(user.ai_root.blackboard[AIBLK_TAMED]) return NODE_FAILURE
	var/atom/current_target = target
	if(!current_target) return NODE_FAILURE
	var/call_say = user.ai_root.blackboard[AIBLK_REINFORCEMENTS_SAY]
	if(call_say) user.say(call_say)
	else user.emote("cries for help!")
	var/mob/living/simple_animal/hostile/H = user
	if(istype(H))
		for(var/mob/living/simple_animal/hostile/other in get_hearers_in_view(reinforcements_range, user))
			if(other == user) continue
			if(H.faction_check_mob(other, exact_match=FALSE) && !other.ai_root?.blackboard[AIBLK_TAMED])
				if(other.ai_root && !other.ai_root.target)
					SSai.WakeUp(other)
					other.ai_root.target = current_target
	user.ai_root.blackboard[AIBLK_REINFORCEMENTS_COOLDOWN] = world.time + cooldown
	return NODE_SUCCESS

/bt_action/random_speech
	var/speech_chance = 15
	var/list/emote_hear
	var/list/emote_see
	var/list/speak
/bt_action/random_speech/evaluate(mob/living/user, mob/living/target, list/blackboard)
	if(world.time < user.ai_root.next_chatter_tick) return NODE_FAILURE
	if(prob(speech_chance))
		if(length(speak))
			user.say(pick(speak))
			user.ai_root.next_chatter_tick = world.time + AI_DEFAULT_CHATTER_DELAY
			return NODE_SUCCESS
	return NODE_FAILURE

/bt_action/keep_distance
/bt_action/keep_distance/evaluate(mob/living/user, mob/living/target, list/blackboard)
	if(!target) return NODE_FAILURE
	var/mob/living/simple_animal/hostile/H = user
	if(!istype(H) || !H.retreat_distance) return NODE_FAILURE
	if(get_dist(user, target) >= H.retreat_distance)
		return NODE_FAILURE
	user.face_atom(target)
	var/turf/T = get_ranged_target_turf(user, get_dir(target, user), 3)
	if(T && !T.density && user.set_ai_path_to(T))
		return NODE_RUNNING
	T = get_step_away(user, target)
	if(T && !T.is_blocked_turf(exclude_mobs = TRUE) && user.set_ai_path_to(T))
		return NODE_RUNNING
	return NODE_FAILURE

/bt_action/maintain_distance
	var/min_dist = 2
	var/max_dist = 4
	var/view_dist = 8
/bt_action/maintain_distance/evaluate(mob/living/user, mob/living/target, list/blackboard)
	if(!user.ai_root || !target) return NODE_FAILURE
	var/dist = get_dist(user, target)
	if(dist < min_dist)
		user.face_atom(target)
		var/turf/T = get_step_away(user, target)
		if(T && !T.is_blocked_turf(exclude_mobs=TRUE))
			if(user.set_ai_path_to(T)) return NODE_RUNNING
		return NODE_FAILURE
	if(dist > max_dist)
		if(user.set_ai_path_to(target)) return NODE_RUNNING
	return NODE_SUCCESS

/bt_action/maintain_distance/hold2
	min_dist = 2
	max_dist = 2

/bt_action/find_dead_body
	var/search_range = 9
/bt_action/find_dead_body/evaluate(mob/living/user, mob/living/target, list/blackboard)
	if(!user.ai_root) return NODE_FAILURE
	if(istype(user, /mob/living/simple_animal/hostile/retaliate/rogue))
		var/mob/living/simple_animal/hostile/retaliate/rogue/R = user
		if(R.food >= R.food_max && !R.eat_forever)
			return NODE_FAILURE
	var/mob/living/current = blackboard[AIBLK_CORPSE_TARGET]
	if(current && !QDELETED(current) && current.stat == DEAD && current.loc && get_dist(user, current) <= search_range)
		return NODE_SUCCESS
	blackboard -= AIBLK_CORPSE_TARGET
	for(var/mob/living/L in ai_oview(search_range, user))
		if(L.stat != DEAD)
			continue
		if(L.ckey || L.mind)
			continue
		if(iscarbon(L))
			var/mob/living/carbon/C = L
			if(C.last_mind)
				continue
		blackboard[AIBLK_CORPSE_TARGET] = L
		return NODE_SUCCESS
	return NODE_FAILURE

/bt_action/eat_dead_body
/bt_action/eat_dead_body/evaluate(mob/living/user, mob/living/target, list/blackboard)
	if(!user.ai_root) return NODE_FAILURE
	var/mob/living/body = blackboard[AIBLK_CORPSE_TARGET]
	if(!body || QDELETED(body))
		body = target
	if(!body || QDELETED(body) || body.stat != DEAD || !body.loc)
		blackboard -= AIBLK_CORPSE_TARGET
		blackboard -= AIBLK_EATING_BODY
		return NODE_FAILURE
	if(body.ckey || body.mind)
		blackboard -= AIBLK_CORPSE_TARGET
		return NODE_FAILURE
	if(get_dist(user, body) > 1)
		blackboard -= AIBLK_EATING_BODY
		if(user.set_ai_path_to(body))
			return NODE_RUNNING
		return NODE_FAILURE
	if(!blackboard[AIBLK_EATING_BODY])
		user.face_atom(body)
		var/mob/living/simple_animal/SA = user
		if(istype(SA) && SA.attack_sound)
			playsound(user, pick(SA.attack_sound), 100, TRUE, -1)
		user.visible_message(span_danger("[user] starts to rip apart [body]!"))
		blackboard[AIBLK_EATING_BODY] = world.time
		return NODE_RUNNING
	if(world.time - blackboard[AIBLK_EATING_BODY] >= 10 SECONDS)
		blackboard -= AIBLK_EATING_BODY
		blackboard -= AIBLK_CORPSE_TARGET
		if(iscarbon(body))
			var/mob/living/carbon/C = body
			var/obj/item/bodypart/limb
			for(var/zone in list(BODY_ZONE_L_ARM, BODY_ZONE_R_ARM, BODY_ZONE_L_LEG, BODY_ZONE_R_LEG))
				limb = C.get_bodypart(zone)
				if(limb)
					limb.dismember()
					return NODE_SUCCESS
			limb = C.get_bodypart(BODY_ZONE_HEAD)
			if(limb)
				limb.dismember()
				return NODE_SUCCESS
			limb = C.get_bodypart(BODY_ZONE_CHEST)
			if(limb)
				if(!limb.dismember())
					C.gib()
				return NODE_SUCCESS
			C.gib()
			return NODE_SUCCESS
		body.gib()
		return NODE_SUCCESS
	return NODE_RUNNING

/bt_action/deadite_migrate
	var/path_key = AIBLK_DEADITE_MIGRATION_PATH
	var/target_key = AIBLK_DEADITE_MIGRATION_TARGET
/bt_action/deadite_migrate/evaluate(mob/living/user, mob/living/target, list/blackboard)
	var/list/path = blackboard[path_key]
	if(!length(path)) return NODE_FAILURE
	var/turf/current_target = blackboard[target_key]
	if(current_target)
		if(user.loc == current_target || get_dist(user, current_target) <= 1)
			var/idx = path.Find(current_target)
			if(idx > 0 && idx < length(path))
				var/turf/next = path[idx+1]
				blackboard[target_key] = next
				if(user.set_ai_path_to(next))
					return NODE_RUNNING
				return NODE_FAILURE
			else if(idx == length(path))
				blackboard -= path_key
				blackboard -= target_key
				return NODE_SUCCESS
		else
			user.ai_root.move_destination = current_target
			if(user.set_ai_path_to(current_target)) return NODE_RUNNING
			return NODE_FAILURE
	else
		var/turf/first = path[1]
		blackboard[target_key] = first
		if(user.set_ai_path_to(first))
			return NODE_RUNNING
		return NODE_FAILURE
	return NODE_FAILURE

/bt_action/colossus_stomp/evaluate(mob/living/user, mob/living/target, list/blackboard)
	if(!target || !istype(user, /mob/living/simple_animal/hostile/retaliate/rogue/elemental/colossus)) return NODE_FAILURE
	var/mob/living/simple_animal/hostile/retaliate/rogue/elemental/colossus/C = user
	if(world.time >= C.stomp_cd + 25 SECONDS && !C.client)
		C.stomp(target)
		return NODE_SUCCESS
	return NODE_FAILURE

/bt_action/behemoth_quake/evaluate(mob/living/user, mob/living/target, list/blackboard)
	if(!target || !istype(user, /mob/living/simple_animal/hostile/retaliate/rogue/elemental/behemoth)) return NODE_FAILURE
	var/mob/living/simple_animal/hostile/retaliate/rogue/elemental/behemoth/B = user
	if(world.time >= B.rock_cd + 200 && !B.client)
		B.quake(target)
		B.rock_cd = world.time
		return NODE_SUCCESS
	return NODE_FAILURE

/bt_action/leyline_teleport/evaluate(mob/living/user, mob/living/target, list/blackboard)
	if(!target || !istype(user, /mob/living/simple_animal/hostile/retaliate/rogue/leylinelycan)) return NODE_FAILURE
	var/mob/living/simple_animal/hostile/retaliate/rogue/leylinelycan/L = user
	if(world.time >= L.teleport_cooldown)
		L.leyline_teleport(target)
		return NODE_SUCCESS
	return NODE_FAILURE

/bt_action/obelisk_activate/evaluate(mob/living/user, mob/living/target, list/blackboard)
	if(!target || !istype(user, /mob/living/simple_animal/hostile/retaliate/rogue/voidstoneobelisk)) return NODE_FAILURE
	var/mob/living/simple_animal/hostile/retaliate/rogue/voidstoneobelisk/O = user
	if(world.time >= O.beam_cooldown)
		O.Activate(target)
		return NODE_SUCCESS
	return NODE_FAILURE

/bt_action/dryad_vine/evaluate(mob/living/user, mob/living/target, list/blackboard)
	if(!target || !istype(user, /mob/living/simple_animal/hostile/retaliate/rogue/fae/dryad)) return NODE_FAILURE
	var/mob/living/simple_animal/hostile/retaliate/rogue/fae/dryad/D = user
	if(world.time >= D.vine_cd + 150 && !D.mind)
		D.vine()
		D.vine_cd = world.time
		return NODE_SUCCESS
	return NODE_FAILURE

/bt_action/chicken_check_ready/evaluate(mob/living/user, mob/living/target, list/blackboard)
	if(user.ai_root.target || (user.ai_root.blackboard[AIBLK_AGGRESSORS] && length(user.ai_root.blackboard[AIBLK_AGGRESSORS]))) return NODE_FAILURE
	var/mob/living/simple_animal/hostile/retaliate/rogue/chicken/C = user
	if(!istype(C)) return NODE_FAILURE
	if(C.production > 29) return NODE_SUCCESS
	return NODE_FAILURE

/bt_action/chicken_lay_egg/evaluate(mob/living/user, mob/living/target, list/blackboard)
	var/mob/living/simple_animal/hostile/retaliate/rogue/chicken/C = user
	if(!istype(C)) return NODE_FAILURE
	var/obj/structure/fluff/nest/N = locate(/obj/structure/fluff/nest) in C.loc
	if(N)
		C.visible_message(span_alertalien("[C] [pick(C.layMessage)]"))
		C.production = max(C.production - 30, 0)
		var/obj/item/reagent_containers/food/snacks/egg/E = new C.egg_type(get_turf(C))
		E.pixel_x = rand(-6,6)
		E.pixel_y = rand(-6,6)
		if(C.eggsFertile && prob(50)) E.fertile = TRUE
		return NODE_SUCCESS
	return NODE_FAILURE

/bt_action/chicken_find_nest/evaluate(mob/living/user, mob/living/target, list/blackboard)
	var/obj/structure/fluff/nest/N = locate() in ai_oview(user)
	if(N)
		if(user.set_ai_path_to(N))
			return NODE_RUNNING
		return NODE_FAILURE
	return NODE_FAILURE

/bt_action/chicken_check_material/evaluate(mob/living/user, mob/living/target, list/blackboard)
	var/obj/item/natural/fibers/F = locate() in user.loc
	if(F) return NODE_SUCCESS
	var/obj/item/grown/log/tree/stick/S = locate() in user.loc
	if(S) return NODE_SUCCESS
	return NODE_FAILURE

/bt_action/chicken_build_nest/evaluate(mob/living/user, mob/living/target, list/blackboard)
	var/obj/item/natural/fibers/F = locate() in user.loc
	if(F)
		qdel(F)
		new /obj/structure/fluff/nest(user.loc)
		user.visible_message(span_notice("[user] builds a nest."))
		return NODE_SUCCESS
	var/obj/item/grown/log/tree/stick/S = locate() in user.loc
	if(S)
		qdel(S)
		new /obj/structure/fluff/nest(user.loc)
		user.visible_message(span_notice("[user] builds a nest."))
		return NODE_SUCCESS
	return NODE_FAILURE

/bt_action/chicken_find_material/evaluate(mob/living/user, mob/living/target, list/blackboard)
	var/obj/item/natural/fibers/F = locate() in ai_oview(user)
	if(F)
		if(user.set_ai_path_to(F))
			return NODE_RUNNING
		return NODE_FAILURE
	var/obj/item/grown/log/tree/stick/S = locate() in ai_oview(user)
	if(S)
		if(user.set_ai_path_to(S))
			return NODE_RUNNING
		return NODE_FAILURE
	return NODE_FAILURE

/bt_action/find_cocoon_target
	var/search_range = 6
	var/next_scan = 0
/bt_action/find_cocoon_target/evaluate(mob/living/user, mob/living/target, list/blackboard)
	var/mob/living/carbon/current = blackboard[AIBLK_COCOON_TARGET]
	if(current && !QDELETED(current))
		return NODE_SUCCESS
	blackboard -= AIBLK_COCOON_TARGET
	if(world.time < next_scan) return NODE_FAILURE
	next_scan = world.time + 20 SECONDS
	var/list/candidates = list()
	for(var/mob/living/carbon/C in ai_oview(search_range, user))
		if(C.stat == DEAD || C.stat == CONSCIOUS) continue
		if(istype(C.loc, /obj/structure/spider/cocoon)) continue
		candidates += C
	if(!length(candidates)) return NODE_FAILURE
	blackboard[AIBLK_COCOON_TARGET] = pick(candidates)
	return NODE_SUCCESS

/bt_action/mark_cocoon_target/evaluate(mob/living/user, mob/living/target, list/blackboard)
	if(!target || !iscarbon(target)) return NODE_FAILURE
	var/mob/living/carbon/C = target
	if(!((C.stat && C.stat != DEAD) || C.getBruteLoss() > 500)) return NODE_FAILURE
	blackboard[AIBLK_COCOON_TARGET] = C
	return NODE_SUCCESS

/bt_action/cocoon_target
	var/channel_time = 5 SECONDS
/bt_action/cocoon_target/evaluate(mob/living/user, mob/living/target, list/blackboard)
	var/mob/living/carbon/victim = blackboard[AIBLK_COCOON_TARGET]
	if(!victim || QDELETED(victim))
		blackboard -= AIBLK_COCOON_TARGET
		blackboard -= AIBLK_COCOON_CHANNEL_START
		return NODE_FAILURE
	if(istype(victim.loc, /obj/structure/spider/cocoon))
		blackboard -= AIBLK_COCOON_TARGET
		blackboard -= AIBLK_COCOON_CHANNEL_START
		return NODE_SUCCESS
	if(get_dist(user, victim) > 1)
		blackboard -= AIBLK_COCOON_CHANNEL_START
		if(user.set_ai_path_to(victim))
			return NODE_RUNNING
		return NODE_FAILURE
	if(!victim.stat || victim.stat == DEAD)
		blackboard -= AIBLK_COCOON_TARGET
		blackboard -= AIBLK_COCOON_CHANNEL_START
		return NODE_FAILURE
	var/channel_start = blackboard[AIBLK_COCOON_CHANNEL_START]
	if(!channel_start)
		user.face_atom(victim)
		blackboard[AIBLK_COCOON_CHANNEL_START] = world.time
		return NODE_RUNNING
	if(world.time - channel_start < channel_time)
		return NODE_RUNNING
	blackboard -= AIBLK_COCOON_CHANNEL_START
	blackboard -= AIBLK_COCOON_TARGET
	if(istype(victim.loc, /obj/structure/spider/cocoon))
		return NODE_SUCCESS
	var/turf/T = get_turf(victim)
	var/obj/structure/spider/cocoon/cocoon = new(T)
	victim.forceMove(cocoon)
	victim.apply_status_effect(/datum/status_effect/buff/healing/spider_cocoon, 0.25)
	return NODE_SUCCESS
