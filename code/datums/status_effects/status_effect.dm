//Status effects are used to apply temporary or permanent effects to mobs.
//This file contains their core datum, plus the mob procs for applying and removing them.

/datum/status_effect
	///Text key used for the HUD alert thrown by this effect. Cosmetic only; identity is the typepath.
	var/id = "effect"
	///Length of the effect in deciseconds. Stays relative for the effect's whole lifetime; -1 never ends on its own.
	var/duration = -1
	///Deciseconds between ticks. STATUS_EFFECT_NO_TICK disables tick() and keeps the effect out of processing entirely.
	var/tick_interval = 10
	///The mob affected by the status effect.
	var/mob/living/owner
	///How copies of this effect stack: STATUS_EFFECT_UNIQUE/REPLACE/REFRESH/MULTIPLE, judged against effects sharing the same exclusion key.
	var/status_type = STATUS_EFFECT_UNIQUE
	///Effects sharing this key are mutually exclusive under status_type rules. Null means only the exact same type excludes.
	var/exclusion_group
	///If we call on_remove() when the mob is deleted.
	var/on_remove_on_mob_delete = FALSE
	///If defined, appears when the mob is examined - use "SUBJECTPRONOUN" for he/she etc.
	var/examine_text
	///The alert thrown by the status effect; contains name and description.
	var/alert_type = /atom/movable/screen/alert/status_effect
	var/atom/movable/screen/alert/status_effect/linked_alert = null
	///Stat deltas applied on gain and reversed on loss; change_stat()'s banking handles the 1..20 clamp symmetrically.
	var/list/effectedstats = list()
	///Traits held for the effect's lifetime, added and removed symmetrically with the effect's id as the source.
	var/list/granted_traits
	///Stress event typepath applied for the effect's lifetime (carbon owners only).
	var/stress_event
	///Combat music forced while the effect is active; the previous track comes back on removal.
	var/combat_music
	var/saved_cmode_music
	///FALSE for effects whose whole lifecycle (including expiry) is driven externally; they never tick and never time out on their own.
	var/needs_processing = TRUE

	///Absolute world.time this effect expires at; -1 for never. Engine-managed, use remaining()/set_remaining() instead of poking.
	var/expires_at = -1
	///Absolute world.time of the next tick() while processing.
	var/next_tick = 0
	///Timer handling expiry for effects that do not tick.
	var/expiry_timer

	///Icon path for this effect's on-mob effect.
	var/mob_effect_icon = 'icons/mob/mob_effects.dmi'
	var/mob_effect_icon_state
	///How long the effect is meant to last. Will default to the duration otherwise.
	var/mob_effect_dur
	///The layer for the mob effect, keeping this unique (even by a 0.01) will ensure it gets deleted properly.
	var/mob_effect_layer = ABOVE_MOB_LAYER
	var/mob_effect_offset_x
	var/mob_effect_offset_y
	///A direct reference to the generated mob effect post-creation. Used for manipulation (or deletion) of the effect. Normally expires.
	var/mutable_appearance/mob_effect


/// Maintained count of the three effects incapacitated() cares about, so that
/// check is one field read instead of six proc calls. A COUNT, not an OR-mask:
/// removal has to be exactly reversible.
/datum/status_effect/proc/vn_incapacity_weight()
	return (istype(src, STATUS_EFFECT_UNCONSCIOUS) || istype(src, STATUS_EFFECT_STUN) || istype(src, STATUS_EFFECT_PARALYZED)) ? 1 : 0

/datum/status_effect/New(list/arguments)
	on_creation(arglist(arguments))

/datum/status_effect/proc/on_creation(mob/living/new_owner, ...)
	if(new_owner)
		owner = new_owner
	if(owner)
		LAZYADD(owner.status_effects, src)
		owner.incapacity_count += vn_incapacity_weight()

	if(!owner || !on_apply())
		qdel(src)
		return

	if(mob_effect_icon_state)
		if(!mob_effect_dur)
			mob_effect_dur = (duration - 1)	//-1 tick juuust in case something goes wrong between status effect deletion and the callback of the appearance itself.
		mob_effect = owner.play_overhead_indicator_flick(mob_effect_icon, mob_effect_icon_state, mob_effect_dur, mob_effect_layer, null, mob_effect_offset_y, mob_effect_offset_x)

	schedule()

	if(alert_type)
		var/atom/movable/screen/alert/status_effect/A = owner.throw_alert(id, alert_type)
		A?.attached_effect = src //so the alert can reference us, if it needs to
		linked_alert = A //so we can reference the alert, if we need to
	return TRUE

///Sets up expiry and tick scheduling from the current (relative) duration and tick_interval.
/datum/status_effect/proc/schedule()
	if(!needs_processing)
		return
	expires_at = (duration == -1) ? -1 : world.time + duration
	if(tick_interval == STATUS_EFFECT_NO_TICK)
		if(expires_at != -1)
			expiry_timer = addtimer(CALLBACK(src, PROC_REF(expire)), duration, TIMER_STOPPABLE)
	else
		next_tick = world.time + tick_interval
		START_PROCESSING(SSstatuseffects, src)

/datum/status_effect/proc/expire()
	expiry_timer = null
	qdel(src)

///Deciseconds until this effect expires; -1 if it never does.
/datum/status_effect/proc/remaining()
	if(expires_at == -1)
		return -1
	return expires_at - world.time

///Sets the remaining time to exactly ds deciseconds, removing the effect if ds is zero or negative.
/datum/status_effect/proc/set_remaining(ds)
	if(ds <= 0)
		qdel(src)
		return
	expires_at = world.time + ds
	reschedule_expiry()

///Adds ds deciseconds to the remaining time. No effect on permanent effects.
/datum/status_effect/proc/adjust_remaining(ds)
	if(expires_at == -1)
		return
	set_remaining(remaining() + ds)

///Extends the remaining time up to ds deciseconds, never shortening it.
/datum/status_effect/proc/extend_to(ds)
	if(expires_at == -1)
		return
	if(remaining() < ds)
		set_remaining(ds)

/datum/status_effect/proc/reschedule_expiry()
	if(!needs_processing || tick_interval != STATUS_EFFECT_NO_TICK)
		return //ticking effects poll expires_at in process()
	if(expiry_timer)
		deltimer(expiry_timer)
		expiry_timer = null
	if(expires_at != -1)
		expiry_timer = addtimer(CALLBACK(src, PROC_REF(expire)), expires_at - world.time, TIMER_STOPPABLE)

/datum/status_effect/Destroy()
	STOP_PROCESSING(SSstatuseffects, src)
	if(expiry_timer)
		deltimer(expiry_timer)
		expiry_timer = null
	if(owner)
		linked_alert = null
		owner.clear_alert(id)
		LAZYREMOVE(owner.status_effects, src)
		owner.incapacity_count -= vn_incapacity_weight()
		on_remove()
		owner = null
	effectedstats = null
	. = ..()
	return QDEL_HINT_IWILLGC

/datum/status_effect/process(wait)
	if(QDELETED(owner))
		qdel(src)
		return
	if(next_tick <= world.time)
		tick(wait)
		next_tick = world.time + tick_interval
	if(expires_at != -1 && expires_at < world.time)
		qdel(src)

/datum/status_effect/proc/on_apply() //Called whenever the effect is applied; returning FALSE will cause it to autoremove itself.
	for(var/S in effectedstats)
		owner.change_stat(S, effectedstats[S])
	for(var/trait in granted_traits)
		ADD_TRAIT(owner, trait, id)
	if(stress_event && iscarbon(owner))
		owner.add_stress(stress_event)
	if(combat_music)
		saved_cmode_music = owner.cmode_music
		owner.cmode_music = combat_music
	return TRUE

/datum/status_effect/proc/tick() //Called every tick_interval while processing.

/datum/status_effect/proc/on_remove() //Called whenever the effect expires or is removed; at that point it is out of the owner's status_effects but owner is not yet null
	for(var/S in effectedstats)
		owner.change_stat(S, -(effectedstats[S]))
	for(var/trait in granted_traits)
		REMOVE_TRAIT(owner, trait, id)
	if(stress_event && iscarbon(owner))
		owner.remove_stress(stress_event)
	if(combat_music)
		owner.cmode_music = saved_cmode_music
	if(mob_effect)
		owner.clear_overhead_indicator(mob_effect, mob_effect_layer)

///Tears the effect down without running on_remove(); only used when the owning mob is deleted and on_remove_on_mob_delete is FALSE.
/datum/status_effect/proc/be_replaced()
	for(var/S in effectedstats)
		owner.change_stat(S, -(effectedstats[S]))
	owner.clear_alert(id)
	if(owner)
		LAZYREMOVE(owner.status_effects, src)
		owner.incapacity_count -= vn_incapacity_weight()
		owner = null
	qdel(src)

///Called on re-application for STATUS_EFFECT_REFRESH effects, with the same arguments the new application was made with.
/datum/status_effect/proc/refresh(mob/living/new_owner, set_duration)
	if(isnum(set_duration))
		duration = set_duration
	if(duration != -1)
		set_remaining(duration)

//clickdelay/nextmove modifiers!
/datum/status_effect/proc/nextmove_modifier()
	return 1

/datum/status_effect/proc/nextmove_adjust()
	return 0

////////////////
// ALERT HOOK //
////////////////

/atom/movable/screen/alert/status_effect
	name = "Curse of Mundanity"
	desc = ""
	var/datum/status_effect/attached_effect

/atom/movable/screen/alert/status_effect/examine_ui(mob/user)
	var/list/inspec = list("----------------------")
	inspec += "<br><span class='notice'><b>[name]</b></span>"
	if(desc)
		inspec += "<br>[desc]"

	for(var/S in attached_effect?.effectedstats)
		if(attached_effect.effectedstats[S] > 0)
			inspec += "<br><span class='purple'>[S]</span> \Roman [attached_effect.effectedstats[S]]"
		if(attached_effect.effectedstats[S] < 0)
			var/newnum = attached_effect.effectedstats[S] * -1
			inspec += "<br><span class='danger'>[S]</span> \Roman [newnum]"

	inspec += "<br>----------------------"
	to_chat(user, "[inspec.Join()]")

/atom/movable/screen/alert/status_effect/Destroy()
	attached_effect = null
	return ..()

//////////////////
// HELPER PROCS //
//////////////////

///Finds a live effect that excludes applying effect_type: same exclusion_group if one is declared, exact same type otherwise.
/mob/living/proc/find_exclusive_effect(datum/status_effect/effect_type)
	if(!length(status_effects))
		return null
	var/group = initial(effect_type.exclusion_group)
	for(var/datum/status_effect/S as anything in status_effects)
		if(group ? (S.exclusion_group == group) : (S.type == effect_type))
			return S
	return null

///Finds a live effect of exactly the given type, ignoring subtypes.
/mob/living/proc/get_status_effect_exact(datum/status_effect/effect_type)
	RETURN_TYPE(/datum/status_effect)
	if(!length(status_effects))
		return null
	for(var/datum/status_effect/S as anything in status_effects)
		if(S.type == effect_type)
			return S
	return null

///Removes effects of exactly the given type, ignoring subtypes. Returns TRUE if any were removed.
/mob/living/proc/remove_status_effect_exact(effect_type)
	. = FALSE
	if(!length(status_effects))
		return
	for(var/datum/status_effect/S as anything in status_effects.Copy())
		if(S.type == effect_type)
			qdel(S)
			. = TRUE

// applies a given status effect to this mob, returning the effect if one was created or refreshed
/mob/living/proc/apply_status_effect(effect, ...)
	. = null
	if(QDELETED(src))
		return

	var/list/arguments = args.Copy()
	arguments[1] = src

	var/datum/status_effect/existing = find_exclusive_effect(effect)
	if(existing)
		switch(existing.status_type)
			if(STATUS_EFFECT_UNIQUE)
				return null
			if(STATUS_EFFECT_REFRESH)
				existing.refresh(arglist(arguments))
				return existing
			if(STATUS_EFFECT_REPLACE)
				qdel(existing)
			//STATUS_EFFECT_MULTIPLE stacks freely

	var/datum/status_effect/new_effect = new effect(arguments)
	if(QDELETED(new_effect))
		return null
	return new_effect

// removes status effects from this mob, returning TRUE if at least one was removed
// accepts a typepath (removes every effect matching it, subtypes included) or a live effect instance
/mob/living/proc/remove_status_effect(effect)
	. = FALSE
	if(!length(status_effects))
		return
	if(!ispath(effect))
		var/datum/status_effect/instance = effect
		if(istype(instance) && (instance in status_effects))
			qdel(instance)
			return TRUE
		return FALSE
	for(var/datum/status_effect/S as anything in status_effects.Copy())
		if(istype(S, effect))
			qdel(S)
			. = TRUE

///Returns a live effect matching the given typepath (subtypes included) or instance, or null.
/mob/living/proc/has_status_effect(datum/status_effect/checked_effect)
	RETURN_TYPE(/datum/status_effect)
	if(!length(status_effects))
		return null
	if(!ispath(checked_effect))
		return (checked_effect in status_effects) ? checked_effect : null
	return locate(checked_effect) in status_effects

//////////////////////
// STACKING EFFECTS //
//////////////////////

/datum/status_effect/stacking
	id = "stacking_base"
	duration = -1 //removed under specific conditions
	alert_type = null
	var/stacks = 0 //how many stacks are accumulated, also is # of stacks that target will have when first applied
	var/delay_before_decay //deciseconds until ticks start occuring, which removes stacks (first stack will be removed at this time plus tick_interval)
	tick_interval = 10 //deciseconds between decays once decay starts
	var/stack_decay = 1 //how many stacks are lost per tick (decay trigger)
	var/stack_threshold //special effects trigger when stacks reach this amount
	var/max_stacks //stacks cannot exceed this amount
	var/consumed_on_threshold = TRUE //if status should be removed once threshold is crossed
	var/threshold_crossed = FALSE //set to true once the threshold is crossed, false once it falls back below
	var/overlay_file
	var/underlay_file
	var/overlay_state // states in .dmi must be given a name followed by a number which corresponds to a number of stacks. put the state name without the number in these state vars
	var/underlay_state // the number is concatonated onto the string based on the number of stacks to get the correct state name
	var/mutable_appearance/status_overlay
	var/mutable_appearance/status_underlay

/datum/status_effect/stacking/proc/threshold_cross_effect() //what happens when threshold is crossed

/datum/status_effect/stacking/proc/stacks_consumed_effect() //runs if status is deleted due to threshold being crossed

/datum/status_effect/stacking/proc/fadeout_effect() //runs if status is deleted due to being under one stack

/datum/status_effect/stacking/proc/stack_decay_effect() //runs every time tick() causes stacks to decay

/datum/status_effect/stacking/proc/on_threshold_cross()
	threshold_cross_effect()
	if(consumed_on_threshold)
		stacks_consumed_effect()
		qdel(src)

/datum/status_effect/stacking/proc/on_threshold_drop()

/datum/status_effect/stacking/proc/can_have_status()
	return owner.stat != DEAD

/datum/status_effect/stacking/proc/can_gain_stacks()
	return owner.stat != DEAD

/datum/status_effect/stacking/tick()
	if(!can_have_status())
		qdel(src)
	else
		add_stacks(-stack_decay)
		stack_decay_effect()

/datum/status_effect/stacking/proc/add_stacks(stacks_added)
	if(stacks_added > 0 && !can_gain_stacks())
		return FALSE
	owner.cut_overlay(status_overlay)
	owner.underlays -= status_underlay
	stacks += stacks_added
	if(stacks > 0)
		if(stacks >= stack_threshold && !threshold_crossed) //threshold_crossed check prevents threshold effect from occuring if changing from above threshold to still above threshold
			threshold_crossed = TRUE
			on_threshold_cross()
		else if(stacks < stack_threshold && threshold_crossed)
			threshold_crossed = FALSE //resets threshold effect if we fall below threshold so threshold effect can trigger again
			on_threshold_drop()
		if(stacks_added > 0)
			next_tick += delay_before_decay //refreshes time until decay
		stacks = min(stacks, max_stacks)
		status_overlay.icon_state = "[overlay_state][stacks]"
		status_underlay.icon_state = "[underlay_state][stacks]"
		owner.add_overlay(status_overlay)
		owner.underlays += status_underlay
	else
		fadeout_effect()
		qdel(src) //deletes status if stacks fall under one

/datum/status_effect/stacking/on_creation(mob/living/new_owner, stacks_to_apply)
	..()
	src.add_stacks(stacks_to_apply)

/datum/status_effect/stacking/on_apply()
	if(!can_have_status())
		return FALSE
	status_overlay = mutable_appearance(overlay_file, "[overlay_state][stacks]")
	status_underlay = mutable_appearance(underlay_file, "[underlay_state][stacks]")
	var/icon/I = icon(owner.icon, owner.icon_state, owner.dir)
	var/icon_height = I.Height()
	status_overlay.pixel_x = -owner.pixel_x
	status_overlay.pixel_y = FLOOR(icon_height * 0.25, 1)
	status_overlay.transform = matrix() * (icon_height/world.icon_size) //scale the status's overlay size based on the target's icon size
	status_underlay.pixel_x = -owner.pixel_x
	status_underlay.transform = matrix() * (icon_height/world.icon_size) * 3
	status_underlay.alpha = 40
	owner.add_overlay(status_overlay)
	owner.underlays += status_underlay
	return ..()

/datum/status_effect/stacking/Destroy()
	if(owner)
		owner.cut_overlay(status_overlay)
		owner.underlays -= status_underlay
	QDEL_NULL(status_overlay)
	return ..()
