//Here are the procs used to modify status effects of a mob.


//////////////////// LIFE COUNTER HELPERS ////////////////////
//Amounts are in legacy counter units: one unit = one 2-second Life tick = STATUS_COUNTER_UNIT deciseconds.

///Remaining legacy units of a life_counter effect on this mob.
/mob/living/proc/get_counter_units(effect_type)
	var/datum/status_effect/life_counter/E = has_status_effect(effect_type)
	return E ? E.units() : 0

///Set the slowdown of a mob
/mob/living/Slowdown(amount)
	if(amount > 0 && (!(status_flags & CANSTUN) || HAS_TRAIT(src, TRAIT_STUNIMMUNE)))
		return
	set_timed_status_effect(amount * STATUS_COUNTER_UNIT, /datum/status_effect/life_counter/slowed, only_if_higher = TRUE)

///Raise the dizziness of a mob to at least the passed amount
/mob/living/proc/Dizzy(amount)
	set_timed_status_effect(amount * STATUS_COUNTER_UNIT, /datum/status_effect/life_counter/dizziness, only_if_higher = TRUE)

///Force set the dizziness of a mob
/mob/living/proc/set_dizziness(amount)
	set_timed_status_effect(amount * STATUS_COUNTER_UNIT, /datum/status_effect/life_counter/dizziness)

///Raise the jitteriness of a mob to at least the passed amount
/mob/living/proc/Jitter(amount)
	set_timed_status_effect(amount * STATUS_COUNTER_UNIT, /datum/status_effect/life_counter/jitter, only_if_higher = TRUE)

///Adjust the drowsyness of a mob
/mob/living/proc/adjust_drowsyness(amount)
	adjust_timed_status_effect(amount * STATUS_COUNTER_UNIT, /datum/status_effect/life_counter/drowsiness)

///Adjust the drugginess of a mob
/mob/living/proc/adjust_drugginess(amount)
	adjust_timed_status_effect(amount * STATUS_COUNTER_UNIT, /datum/status_effect/life_counter/drugged)

///Set the drugginess of a mob
/mob/living/proc/set_drugginess(amount)
	set_timed_status_effect(amount * STATUS_COUNTER_UNIT, /datum/status_effect/life_counter/drugged)

/mob/living/is_blind()
	return HAS_TRAIT(src, TRAIT_BLIND) || has_status_effect(/datum/status_effect/life_counter/blindness)

///Blind a mobs eyes by amount
/mob/living/proc/blind_eyes(amount)
	adjust_blindness(amount)

///Adjust a mobs blindness by an amount of legacy units
/mob/living/proc/adjust_blindness(amount)
	adjust_timed_status_effect(amount * STATUS_COUNTER_UNIT, /datum/status_effect/life_counter/blindness)

///Force set the blindness of a mob to some level
/mob/living/proc/set_blindness(amount)
	set_timed_status_effect(amount * STATUS_COUNTER_UNIT, /datum/status_effect/life_counter/blindness)

///Adds and removes blindness overlays when necessary
/mob/living/proc/update_blindness()
	if(stat == UNCONSCIOUS || is_blind())
		if(stat == CONSCIOUS)
			overlay_fullscreen("blind", /atom/movable/screen/fullscreen/blind)
		else
			overlay_fullscreen("blind", /atom/movable/screen/fullscreen/blackimageoverlay)
	else
		clear_fullscreen("blind")

/mob/living/get_eye_blur_units()
	return get_counter_units(/datum/status_effect/life_counter/eye_blur)

///Make the mobs vision blurry, raising it to at least amount
/mob/living/proc/blur_eyes(amount)
	if(amount > 0)
		set_timed_status_effect(amount * STATUS_COUNTER_UNIT, /datum/status_effect/life_counter/eye_blur, only_if_higher = TRUE)
	update_eye_blur()

///Adjust the current blurriness of the mobs vision by amount
/mob/living/proc/adjust_blurriness(amount)
	adjust_timed_status_effect(amount * STATUS_COUNTER_UNIT, /datum/status_effect/life_counter/eye_blur)
	update_eye_blur()

///Set the mobs blurriness of vision to an amount
/mob/living/proc/set_blurriness(amount)
	set_timed_status_effect(amount * STATUS_COUNTER_UNIT, /datum/status_effect/life_counter/eye_blur)
	update_eye_blur()

///Apply the blurry overlays to a mobs clients screen
/mob/living/proc/update_eye_blur()
	if(!client)
		return
	var/atom/movable/screen/plane_master/floor/OT = locate(/atom/movable/screen/plane_master/floor) in client.screen
	var/atom/movable/screen/plane_master/game_world/GW = locate(/atom/movable/screen/plane_master/game_world) in client.screen
	if(GW)
		GW.backdrop(src)
	if(OT)
		OT.backdrop(src)
	GW = locate(/atom/movable/screen/plane_master/game_world_fov_hidden) in client.screen
	if(GW)
		GW.backdrop(src)
	GW = locate(/atom/movable/screen/plane_master/game_world_above) in client.screen
	if(GW)
		GW.backdrop(src)

//////////////////// COMBAT COOLDOWNS ////////////////////
//Lightweight world.time timestamps with a HUD alert; replaces the old datum-churning cooldown status effects.

///Starts (or restarts) a named cooldown for duration deciseconds, throwing alert_type for its length if given.
/mob/living/proc/set_combat_cooldown(key, duration, alert_type)
	if(duration <= 0)
		return
	LAZYINITLIST(combat_cooldowns)
	combat_cooldowns[key] = world.time + duration
	if(alert_type)
		throw_alert(key, alert_type)
	addtimer(CALLBACK(src, PROC_REF(end_combat_cooldown), key), duration, TIMER_UNIQUE | TIMER_OVERRIDE)

/mob/living/proc/end_combat_cooldown(key)
	if(!combat_cooldowns)
		return
	if(combat_cooldowns[key] > world.time) //restarted since this timer was armed
		return
	combat_cooldowns -= key
	clear_alert(key)
	if(!length(combat_cooldowns))
		combat_cooldowns = null

///Whether the named cooldown is still running.
/mob/living/proc/combat_cooldown_active(key)
	return combat_cooldowns && combat_cooldowns[key] > world.time

///Ends the named cooldown early.
/mob/living/proc/clear_combat_cooldown(key)
	if(!combat_cooldowns)
		return
	combat_cooldowns -= key
	clear_alert(key)
	if(!length(combat_cooldowns))
		combat_cooldowns = null

///Click cooldown: delays the next action and shows the delay on the HUD.
/mob/living/proc/apply_click_cooldown(duration)
	set_combat_cooldown("clickcd", duration, /atom/movable/screen/alert/status_effect/debuff/clickcd)
	changeNext_move(duration)

//////////////////// TIMED INCAPACITATION CORE ////////////////////

#define INCAP_EXTEND 1	//never shortens an existing effect
#define INCAP_SET 2	//sets the remaining time exactly; 0 or less removes
#define INCAP_ADJUST 3	//adds to (or subtracts from) the remaining time

/mob/living/proc/apply_incapacitating(effect_type, amount, updating, mode, signal, check_flag, immune_trait, ignore_canstun, absorbable = TRUE)
	if(SEND_SIGNAL(src, signal, amount, updating, ignore_canstun) & COMPONENT_NO_STUN)
		return
	if(!ignore_canstun)
		if(check_flag && !(status_flags & check_flag))
			return
		if(immune_trait && HAS_TRAIT(src, immune_trait))
			return
	var/datum/status_effect/incapacitating/existing = get_status_effect_exact(effect_type)
	if(mode == INCAP_SET && amount <= 0)
		if(existing)
			qdel(existing)
		return
	if(absorbable && absorb_stun(amount, ignore_canstun))
		return
	if(existing)
		switch(mode)
			if(INCAP_EXTEND)
				existing.extend_to(amount)
			if(INCAP_SET)
				existing.set_remaining(amount)
			if(INCAP_ADJUST)
				existing.adjust_remaining(amount)
		return existing
	if(amount > 0)
		return apply_status_effect(effect_type, amount, updating)

////////////////////////////// STUN ////////////////////////////////////

/mob/living/proc/IsStun() //If we're stunned
	return has_status_effect(STATUS_EFFECT_STUN)

/mob/living/proc/AmountStun() //How many deciseconds remain in our stun
	var/datum/status_effect/S = IsStun()
	return S ? S.remaining() : 0

/mob/living/proc/Stun(amount, updating = TRUE, ignore_canstun = FALSE) //Can't go below remaining duration
	return apply_incapacitating(STATUS_EFFECT_STUN, amount, updating, INCAP_EXTEND, COMSIG_LIVING_STATUS_STUN, CANSTUN, TRAIT_STUNIMMUNE, ignore_canstun)

/mob/living/proc/SetStun(amount, updating = TRUE, ignore_canstun = FALSE) //Sets remaining duration
	return apply_incapacitating(STATUS_EFFECT_STUN, amount, updating, INCAP_SET, COMSIG_LIVING_STATUS_STUN, CANSTUN, TRAIT_STUNIMMUNE, ignore_canstun)

/mob/living/proc/AdjustStun(amount, updating = TRUE, ignore_canstun = FALSE) //Adds to remaining duration
	return apply_incapacitating(STATUS_EFFECT_STUN, amount, updating, INCAP_ADJUST, COMSIG_LIVING_STATUS_STUN, CANSTUN, TRAIT_STUNIMMUNE, ignore_canstun)

///////////////////////////////// KNOCKDOWN /////////////////////////////////////

/mob/living/proc/IsKnockdown() //If we're knocked down
	return has_status_effect(STATUS_EFFECT_KNOCKDOWN)

/mob/living/proc/AmountKnockdown() //How many deciseconds remain in our knockdown
	var/datum/status_effect/S = IsKnockdown()
	return S ? S.remaining() : 0

/mob/living/proc/Knockdown(amount, updating = TRUE, ignore_canstun = FALSE) //Can't go below remaining duration
	return apply_incapacitating(STATUS_EFFECT_KNOCKDOWN, amount, updating, INCAP_EXTEND, COMSIG_LIVING_STATUS_KNOCKDOWN, CANKNOCKDOWN, TRAIT_STUNIMMUNE, ignore_canstun)

/mob/living/proc/SetKnockdown(amount, updating = TRUE, ignore_canstun = FALSE) //Sets remaining duration
	return apply_incapacitating(STATUS_EFFECT_KNOCKDOWN, amount, updating, INCAP_SET, COMSIG_LIVING_STATUS_KNOCKDOWN, CANKNOCKDOWN, TRAIT_STUNIMMUNE, ignore_canstun)

/mob/living/proc/AdjustKnockdown(amount, updating = TRUE, ignore_canstun = FALSE) //Adds to remaining duration
	return apply_incapacitating(STATUS_EFFECT_KNOCKDOWN, amount, updating, INCAP_ADJUST, COMSIG_LIVING_STATUS_KNOCKDOWN, CANKNOCKDOWN, TRAIT_STUNIMMUNE, ignore_canstun)

///////////////////////////////// IMMOBILIZED ////////////////////////////////////

/mob/living/proc/IsImmobilized() //If we're immobilized
	var/datum/status_effect/S = has_status_effect(STATUS_EFFECT_IMMOBILIZED)
	if(S)
		doing = 0
	return S

/mob/living/proc/AmountImmobilized() //How many deciseconds remain in our Immobilized status effect
	var/datum/status_effect/S = has_status_effect(STATUS_EFFECT_IMMOBILIZED)
	return S ? S.remaining() : 0

/mob/living/proc/Immobilize(amount, updating = TRUE, ignore_canstun = FALSE) //Can't go below remaining duration
	return apply_incapacitating(STATUS_EFFECT_IMMOBILIZED, amount, updating, INCAP_EXTEND, COMSIG_LIVING_STATUS_IMMOBILIZE, CANKNOCKDOWN, TRAIT_STUNIMMUNE, ignore_canstun)

/mob/living/proc/SetImmobilized(amount, updating = TRUE, ignore_canstun = FALSE) //Sets remaining duration
	return apply_incapacitating(STATUS_EFFECT_IMMOBILIZED, amount, updating, INCAP_SET, COMSIG_LIVING_STATUS_IMMOBILIZE, CANKNOCKDOWN, TRAIT_STUNIMMUNE, ignore_canstun)

/mob/living/proc/AdjustImmobilized(amount, updating = TRUE, ignore_canstun = FALSE) //Adds to remaining duration
	return apply_incapacitating(STATUS_EFFECT_IMMOBILIZED, amount, updating, INCAP_ADJUST, COMSIG_LIVING_STATUS_IMMOBILIZE, CANKNOCKDOWN, TRAIT_STUNIMMUNE, ignore_canstun)

///////////////////////////////// PARALYZED //////////////////////////////////

/mob/living/proc/IsParalyzed(include_stamcrit = TRUE)
	return has_status_effect(STATUS_EFFECT_PARALYZED)

/mob/living/proc/AmountParalyzed() //How many deciseconds remain in our Paralyzed status effect
	var/datum/status_effect/S = IsParalyzed(FALSE)
	return istype(S) ? S.remaining() : 0

/mob/living/proc/Paralyze(amount, updating = TRUE, ignore_canstun = FALSE) //Can't go below remaining duration
	return apply_incapacitating(STATUS_EFFECT_PARALYZED, amount, updating, INCAP_EXTEND, COMSIG_LIVING_STATUS_PARALYZE, CANKNOCKDOWN, TRAIT_STUNIMMUNE, ignore_canstun)

/mob/living/proc/SetParalyzed(amount, updating = TRUE, ignore_canstun = FALSE) //Sets remaining duration
	return apply_incapacitating(STATUS_EFFECT_PARALYZED, amount, updating, INCAP_SET, COMSIG_LIVING_STATUS_PARALYZE, CANKNOCKDOWN, TRAIT_STUNIMMUNE, ignore_canstun)

/mob/living/proc/AdjustParalyzed(amount, updating = TRUE, ignore_canstun = FALSE) //Adds to remaining duration
	return apply_incapacitating(STATUS_EFFECT_PARALYZED, amount, updating, INCAP_ADJUST, COMSIG_LIVING_STATUS_PARALYZE, CANKNOCKDOWN, TRAIT_STUNIMMUNE, ignore_canstun)

///////////////////////////////// OFF-BALANCED //////////////////////////////////

/mob/living/proc/IsOffBalanced() //If we're knocked down
	return has_status_effect(STATUS_EFFECT_OFFBALANCED)

/mob/living/proc/AmountOffBalanced() //How many deciseconds remain in our knockdown
	var/datum/status_effect/S = IsOffBalanced()
	return S ? S.remaining() : 0

/mob/living/proc/OffBalance(amount, updating = TRUE) //Can't go below remaining duration
	if(SEND_SIGNAL(src, COMSIG_LIVING_STATUS_OFFBALANCED, amount, updating))
		return
	var/datum/status_effect/incapacitating/off_balanced/O = IsOffBalanced()
	if(O)
		O.extend_to(amount)
	else if(amount > 0)
		O = apply_status_effect(STATUS_EFFECT_OFFBALANCED, amount, updating)
	return O

///////////////Blanket
/mob/living/proc/AllImmobility(amount, updating)
	Paralyze(amount, FALSE)
	Knockdown(amount, FALSE)
	Stun(amount, FALSE)
	Immobilize(amount, FALSE)
	if(updating)
		update_mobility()

/mob/living/proc/SetAllImmobility(amount, updating)
	SetParalyzed(amount, FALSE)
	SetKnockdown(amount, FALSE)
	SetStun(amount, FALSE)
	SetImmobilized(amount, FALSE)
	if(updating)
		update_mobility()

/mob/living/proc/AdjustAllImmobility(amount, updating)
	AdjustParalyzed(amount, FALSE)
	AdjustKnockdown(amount, FALSE)
	AdjustStun(amount, FALSE)
	AdjustImmobilized(amount, FALSE)
	if(updating)
		update_mobility()

//////////////////UNCONSCIOUS
/mob/living/proc/IsUnconscious() //If we're unconscious
	return has_status_effect(STATUS_EFFECT_UNCONSCIOUS)

/mob/living/proc/AmountUnconscious() //How many deciseconds remain in our unconsciousness
	var/datum/status_effect/S = IsUnconscious()
	return S ? S.remaining() : 0

/mob/living/proc/Unconscious(amount, updating = TRUE, ignore_canstun = FALSE) //Can't go below remaining duration
	return apply_incapacitating(STATUS_EFFECT_UNCONSCIOUS, amount, updating, INCAP_EXTEND, COMSIG_LIVING_STATUS_UNCONSCIOUS, CANUNCONSCIOUS, TRAIT_STUNIMMUNE, ignore_canstun, absorbable = FALSE)

/mob/living/proc/SetUnconscious(amount, updating = TRUE, ignore_canstun = FALSE) //Sets remaining duration
	return apply_incapacitating(STATUS_EFFECT_UNCONSCIOUS, amount, updating, INCAP_SET, COMSIG_LIVING_STATUS_UNCONSCIOUS, CANUNCONSCIOUS, TRAIT_STUNIMMUNE, ignore_canstun, absorbable = FALSE)

/mob/living/proc/AdjustUnconscious(amount, updating = TRUE, ignore_canstun = FALSE) //Adds to remaining duration
	return apply_incapacitating(STATUS_EFFECT_UNCONSCIOUS, amount, updating, INCAP_ADJUST, COMSIG_LIVING_STATUS_UNCONSCIOUS, CANUNCONSCIOUS, TRAIT_STUNIMMUNE, ignore_canstun, absorbable = FALSE)

/////////////////////////////////// SLEEPING ////////////////////////////////////

/mob/proc/IsSleeping()
	return FALSE

/mob/living/IsSleeping() //If we're asleep
	return has_status_effect(STATUS_EFFECT_SLEEPING)

/mob/living/proc/AmountSleeping() //How many deciseconds remain in our sleep
	var/datum/status_effect/S = IsSleeping()
	return S ? S.remaining() : 0

/mob/living/proc/Sleeping(amount, updating = TRUE, ignore_canstun = FALSE) //Can't go below remaining duration
	return apply_incapacitating(STATUS_EFFECT_SLEEPING, amount, updating, INCAP_EXTEND, COMSIG_LIVING_STATUS_SLEEP, null, TRAIT_SLEEPIMMUNE, ignore_canstun, absorbable = FALSE)

/mob/living/proc/SetSleeping(amount, updating = TRUE, ignore_canstun = FALSE) //Sets remaining duration
	return apply_incapacitating(STATUS_EFFECT_SLEEPING, amount, updating, INCAP_SET, COMSIG_LIVING_STATUS_SLEEP, null, TRAIT_SLEEPIMMUNE, ignore_canstun, absorbable = FALSE)

/mob/living/proc/AdjustSleeping(amount, updating = TRUE, ignore_canstun = FALSE) //Adds to remaining duration
	return apply_incapacitating(STATUS_EFFECT_SLEEPING, amount, updating, INCAP_ADJUST, COMSIG_LIVING_STATUS_SLEEP, null, TRAIT_SLEEPIMMUNE, ignore_canstun, absorbable = FALSE)

#undef INCAP_EXTEND
#undef INCAP_SET
#undef INCAP_ADJUST

///////////////////////////////// FROZEN /////////////////////////////////////

/mob/living/proc/IsFrozen()
	return has_status_effect(/datum/status_effect/freon)

///////////////////////////////////// STUN ABSORPTION /////////////////////////////////////

/mob/living/proc/add_stun_absorption(key, duration, priority, message, self_message, examine_message)
//adds a stun absorption with a key, a duration in deciseconds, its priority, and the messages it makes when you're stun/examined, if any
	if(!islist(stun_absorption))
		stun_absorption = list()
	if(stun_absorption[key])
		stun_absorption[key]["end_time"] = world.time + duration
		stun_absorption[key]["priority"] = priority
		stun_absorption[key]["stuns_absorbed"] = 0
	else
		stun_absorption[key] = list("end_time" = world.time + duration, "priority" = priority, "stuns_absorbed" = 0, \
		"visible_message" = message, "self_message" = self_message, "examine_message" = examine_message)

/mob/living/proc/absorb_stun(amount, ignoring_flag_presence)
	if(amount < 0 || stat || ignoring_flag_presence || !islist(stun_absorption))
		return FALSE
	if(!amount)
		amount = 0
	var/priority_absorb_key
	var/highest_priority
	for(var/i in stun_absorption)
		if(stun_absorption[i]["end_time"] > world.time && (!priority_absorb_key || stun_absorption[i]["priority"] > highest_priority))
			priority_absorb_key = stun_absorption[i]
			highest_priority = priority_absorb_key["priority"]
	if(priority_absorb_key)
		if(amount) //don't spam up the chat for continuous stuns
			if(priority_absorb_key["visible_message"] || priority_absorb_key["self_message"])
				if(priority_absorb_key["visible_message"] && priority_absorb_key["self_message"])
					visible_message(span_warning("[src][priority_absorb_key["visible_message"]]"), span_boldwarning("[priority_absorb_key["self_message"]]"))
				else if(priority_absorb_key["visible_message"])
					visible_message(span_warning("[src][priority_absorb_key["visible_message"]]"))
				else if(priority_absorb_key["self_message"])
					to_chat(src, span_boldwarning("[priority_absorb_key["self_message"]]"))
			priority_absorb_key["stuns_absorbed"] += amount
		return TRUE

/////////////////////////////////// TRAIT PROCS ////////////////////////////////////

/// Tracks nearsighted overlay severity per trait source.
/mob/living/var/list/nearsighted_severity_by_source

/mob/living/proc/cure_blind(source)
	REMOVE_TRAIT(src, TRAIT_BLIND, source)
	if(!HAS_TRAIT(src, TRAIT_BLIND))
		update_blindness()

/mob/living/proc/become_blind(source)
	if(!HAS_TRAIT(src, TRAIT_BLIND)) // not blind already, add trait then overlay
		ADD_TRAIT(src, TRAIT_BLIND, source)
		update_blindness()
	else
		ADD_TRAIT(src, TRAIT_BLIND, source)

/mob/living/proc/cure_nearsighted(source)
	REMOVE_TRAIT(src, TRAIT_NEARSIGHT, source)
	// If no specific source is provided, assume a global cure and clear all tracked severities.
	if(!source)
		nearsighted_severity_by_source = null
	else if(nearsighted_severity_by_source)
		if(islist(source))
			for(var/_source in source)
				if(_source)
					nearsighted_severity_by_source -= _source
		else
			nearsighted_severity_by_source -= source
		if(nearsighted_severity_by_source && !nearsighted_severity_by_source.len)
			nearsighted_severity_by_source = null
	if(!HAS_TRAIT(src, TRAIT_NEARSIGHT))
		clear_fullscreen("nearsighted")
		return
	update_nearsighted_overlay()

/mob/living/proc/become_nearsighted(source, severity = 1)
	severity = clamp(round(severity), 1, 2)
	if(!source)
		source = "unknown"
	if(!nearsighted_severity_by_source)
		nearsighted_severity_by_source = list()
	var/existing_severity = nearsighted_severity_by_source[source]
	if(!isnum(existing_severity))
		existing_severity = 0
	nearsighted_severity_by_source[source] = max(existing_severity, severity)
	ADD_TRAIT(src, TRAIT_NEARSIGHT, source)
	update_nearsighted_overlay()

/mob/living/proc/update_nearsighted_overlay()
	if(!HAS_TRAIT(src, TRAIT_NEARSIGHT))
		clear_fullscreen("nearsighted")
		return
	var/max_severity = 1
	if(nearsighted_severity_by_source)
		for(var/_source in nearsighted_severity_by_source)
			var/_severity = nearsighted_severity_by_source[_source]
			if(isnum(_severity))
				max_severity = max(max_severity, _severity)
	overlay_fullscreen("nearsighted", /atom/movable/screen/fullscreen/impaired, max_severity)

/mob/living/proc/cure_husk(source)
	REMOVE_TRAIT(src, TRAIT_HUSK, source)
	if(!HAS_TRAIT(src, TRAIT_HUSK))
		REMOVE_TRAIT(src, TRAIT_DISFIGURED, "husk")
		update_body()
		return TRUE

/mob/living/proc/become_husk(source)
	if(!HAS_TRAIT(src, TRAIT_HUSK))
		ADD_TRAIT(src, TRAIT_HUSK, source)
		ADD_TRAIT(src, TRAIT_DISFIGURED, "husk")
		update_body()
	else
		ADD_TRAIT(src, TRAIT_HUSK, source)

/mob/living/proc/cure_fakedeath(source)
	REMOVE_TRAIT(src, TRAIT_FAKEDEATH, source)
	REMOVE_TRAIT(src, TRAIT_DEATHCOMA, source)
	if(stat != DEAD)
		tod = null
	update_stat()

/mob/living/proc/fakedeath(source, silent = FALSE)
	if(stat == DEAD)
		return
	if(!silent)
		emote("deathgasp")
	ADD_TRAIT(src, TRAIT_FAKEDEATH, source)
	ADD_TRAIT(src, TRAIT_DEATHCOMA, source)
	tod = station_time_timestamp()
	update_stat()

/mob/living/proc/unignore_slowdown(source)
	REMOVE_TRAIT(src, TRAIT_IGNORESLOWDOWN, source)
	update_movespeed(FALSE)

/mob/living/proc/ignore_slowdown(source)
	ADD_TRAIT(src, TRAIT_IGNORESLOWDOWN, source)
	update_movespeed(FALSE)

/mob/living/proc/cure_holdbreath(source)
	if(!iscarbon(src))
		return
	var/mob/living/carbon/C = src
	C.holding_breath = FALSE
	C.breath_remaining = C.get_breath_max()

/mob/living/proc/cure_paralysis(source)
	REMOVE_TRAIT(src, TRAIT_PARALYSIS, source)

/**
 * Adjusts a timed status effect on the mob,taking into account any existing timed status effects.
 * This can be any status effect that takes into account "duration" with their initialize arguments.
 *
 * Positive durations will add deciseconds to the duration of existing status effects
 * or apply a new status effect of that duration to the mob.
 *
 * Negative durations will remove deciseconds from the duration of an existing version of the status effect,
 * removing the status effect entirely if the duration becomes less than zero (less than the current world time).
 *
 * duration - the duration, in deciseconds, to add or remove from the effect
 * effect - the type of status effect being adjusted on the mob
 * max_duration - optional - if set, positive durations will only be added UP TO the passed max duration
 */
/mob/living/proc/adjust_timed_status_effect(duration, effect, max_duration)
	if(!isnum(duration))
		CRASH("adjust_timed_status_effect: called with an invalid duration. (Got: [duration])")

	if(!ispath(effect, /datum/status_effect))
		CRASH("adjust_timed_status_effect: called with an invalid effect type. (Got: [effect])")

	// If we have a max duration set, we need to check our duration does not exceed it
	if(isnum(max_duration))
		if(max_duration <= 0)
			CRASH("adjust_timed_status_effect: Called with an invalid max_duration. (Got: [max_duration])")

		if(duration >= max_duration)
			duration = max_duration

	var/datum/status_effect/existing = has_status_effect(effect)
	if(existing)
		if(isnum(max_duration) && duration > 0)
			// Check the duration remaining on the existing status effect
			// If it's greater than / equal to our passed max duration, we don't need to do anything
			var/remaining_duration = existing.remaining()
			if(remaining_duration >= max_duration)
				return

			// Otherwise, add duration up to the max (max_duration - remaining_duration),
			// or just add duration if it doesn't exceed our max at all
			existing.adjust_remaining(min(max_duration - remaining_duration, duration))

		else
			existing.adjust_remaining(duration)

	else if(duration > 0)
		apply_status_effect(effect, duration)

/**
 * Sets a timed status effect of some kind on a mob to a specific value.
 * If only_if_higher is TRUE, it will only set the value up to the passed duration,
 * so any pre-existing status effects of the same type won't be reduced down
 *
 * duration - the duration, in deciseconds, of the effect. 0 or lower will either remove the current effect or do nothing if none are present
 * effect - the type of status effect given to the mob
 * only_if_higher - if TRUE, we will only set the effect to the new duration if the new duration is longer than any existing duration
 */
/mob/living/proc/set_timed_status_effect(duration, effect, only_if_higher = FALSE)
	if(!isnum(duration))
		CRASH("set_timed_status_effect: called with an invalid duration. (Got: [duration])")

	if(!ispath(effect, /datum/status_effect))
		CRASH("set_timed_status_effect: called with an invalid effect type. (Got: [effect])")

	var/datum/status_effect/existing = has_status_effect(effect)
	if(existing)
		// set_timed_status_effect to 0 technically acts as a way to clear effects,
		// though remove_status_effect would achieve the same goal more explicitly.
		if(duration <= 0)
			qdel(existing)
			return

		if(only_if_higher)
			existing.extend_to(duration)
		else
			existing.set_remaining(duration)

	else if(duration > 0)
		apply_status_effect(effect, duration)

/**
 * Gets how many deciseconds are remaining in
 * the duration of the passed status effect on this mob.
 *
 * If the mob is unaffected by the passed effect, returns 0.
 */
/mob/living/proc/get_timed_status_effect_duration(effect)
	if(!ispath(effect, /datum/status_effect))
		CRASH("get_timed_status_effect_duration: called with an invalid effect type. (Got: [effect])")

	var/datum/status_effect/existing = has_status_effect(effect)
	if(!existing)
		return 0
	// Infinite duration status effects technically are not "timed status effects"
	// by name or nature, but support is included just in case.
	var/remaining = existing.remaining()
	if(remaining == -1)
		return INFINITY

	return remaining
