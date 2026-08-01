//Engine-managed replacements for the legacy Life() counters.
//One counter unit equals one 2-second Life tick: durations are units * STATUS_COUNTER_UNIT deciseconds.

/datum/status_effect/life_counter
	id = "life_counter"
	alert_type = null
	tick_interval = STATUS_EFFECT_NO_TICK
	///Extra remaining-time drain per tick while the owner rests, in deciseconds. 80 matches the legacy restingpwr of 5.
	var/resting_drain = 0

/datum/status_effect/life_counter/on_creation(mob/living/new_owner, set_duration)
	if(isnum(set_duration))
		duration = set_duration
	return ..()

///Remaining time expressed in legacy counter units.
/datum/status_effect/life_counter/proc/units()
	return remaining() / STATUS_COUNTER_UNIT

/datum/status_effect/life_counter/tick()
	if(resting_drain && owner.resting)
		adjust_remaining(-resting_drain)

/datum/status_effect/life_counter/dizziness
	id = "dizzy"
	tick_interval = STATUS_COUNTER_UNIT
	resting_drain = 80

/datum/status_effect/life_counter/dizziness/tick()
	..()
	if(QDELETED(src))
		return
	var/client/C = owner.client
	if(!C)
		return
	var/strength = units()
	var/amplitude = strength * (sin(strength * world.time) + 1)
	var/base_x = C.pixel_x
	var/base_y = C.pixel_y
	animate(C, pixel_x = base_x + amplitude * sin(strength * world.time), pixel_y = base_y + amplitude * cos(strength * world.time), time = 3)
	animate(pixel_x = base_x + amplitude * sin(strength * (world.time + 3)), pixel_y = base_y + amplitude * cos(strength * (world.time + 3)), time = 3)
	animate(pixel_x = base_x, pixel_y = base_y, time = 0)

/datum/status_effect/life_counter/jitter
	id = "jittery"
	tick_interval = STATUS_COUNTER_UNIT
	resting_drain = 80

/datum/status_effect/life_counter/jitter/tick()
	..()
	if(QDELETED(src))
		return
	owner.do_jitter_animation(units())

/datum/status_effect/life_counter/drowsiness
	id = "drowsy"
	tick_interval = STATUS_COUNTER_UNIT
	resting_drain = 80

/datum/status_effect/life_counter/drowsiness/tick()
	..()
	if(QDELETED(src))
		return
	owner.blur_eyes(2)
	if(units() >= 100)
		owner.Sleeping(300)

/datum/status_effect/life_counter/stutter
	id = "stutter"

/datum/status_effect/life_counter/stutter/on_apply()
	if(isanimal(owner))
		return FALSE
	return ..()

/datum/status_effect/life_counter/slur
	id = "slur"

/datum/status_effect/life_counter/confusion
	id = "confusion"

/datum/status_effect/life_counter/drugged
	id = "drugged"

/datum/status_effect/life_counter/drugged/on_apply()
	. = ..()
	if(.)
		owner.overlay_fullscreen("high", /atom/movable/screen/fullscreen/high)

/datum/status_effect/life_counter/drugged/on_remove()
	owner.clear_fullscreen("high")
	..()

/datum/status_effect/life_counter/slowed
	id = "slowed"

/datum/status_effect/life_counter/slowed/on_apply()
	. = ..()
	if(.)
		owner.add_movespeed_modifier(MOVESPEED_ID_LIVING_SLOWDOWN_STATUS, update=TRUE, priority=100, multiplicative_slowdown=2, movetypes=GROUND)

/datum/status_effect/life_counter/slowed/on_remove()
	owner.remove_movespeed_modifier(MOVESPEED_ID_LIVING_SLOWDOWN_STATUS)
	..()

/datum/status_effect/life_counter/hallucinating
	id = "hallucinating"
	tick_interval = STATUS_COUNTER_UNIT
	///Absolute world.time gate for the next hallucination spawn.
	var/next_hallucination = 0

/datum/status_effect/life_counter/hallucinating/tick()
	if(!iscarbon(owner))
		return
	if(world.time < next_hallucination)
		return
	var/halpick = pickweight(GLOB.hallucination_list)
	new halpick(owner, FALSE)
	next_hallucination = world.time + rand(100, 600)

/datum/status_effect/life_counter/blindness
	id = "blinded"
	tick_interval = STATUS_COUNTER_UNIT

/datum/status_effect/life_counter/blindness/on_apply()
	. = ..()
	if(.)
		owner.update_blindness()

/datum/status_effect/life_counter/blindness/on_remove()
	..()
	owner.update_blindness()

/datum/status_effect/life_counter/blindness/tick()
	if(HAS_TRAIT_FROM(owner, TRAIT_BLIND, EYES_COVERED))
		adjust_remaining(-2 * STATUS_COUNTER_UNIT)
	else if(owner.stat || HAS_TRAIT(owner, TRAIT_BLIND))
		adjust_remaining(STATUS_COUNTER_UNIT)

/datum/status_effect/life_counter/eye_blur
	id = "eye_blur"
	tick_interval = STATUS_COUNTER_UNIT

/datum/status_effect/life_counter/eye_blur/on_apply()
	. = ..()
	if(.)
		owner.update_eye_blur()

/datum/status_effect/life_counter/eye_blur/on_remove()
	..()
	owner.update_eye_blur()

/datum/status_effect/life_counter/eye_blur/tick()
	if(owner.has_status_effect(/datum/status_effect/life_counter/blindness))
		adjust_remaining(STATUS_COUNTER_UNIT)
		return
	owner.update_eye_blur()

//Strength-based, not duration-based: drunkenness decays exponentially and drives the threshold ladder.
/datum/status_effect/inebriated
	id = "inebriated"
	alert_type = null
	duration = -1
	tick_interval = STATUS_COUNTER_UNIT
	var/strength = 0

/datum/status_effect/inebriated/on_creation(mob/living/new_owner, initial_strength)
	if(isnum(initial_strength))
		strength = initial_strength
	return ..()

/datum/status_effect/inebriated/proc/set_strength(value)
	strength = max(value, 0)
	if(!strength)
		qdel(src)

/datum/status_effect/inebriated/on_remove()
	if(iscarbon(owner))
		owner.remove_stress(/datum/stressevent/drunk)
	..()

/datum/status_effect/inebriated/tick()
	var/mob/living/carbon/C = owner
	if(!istype(C))
		qdel(src)
		return
	strength = max(strength - (strength * 0.04) - 0.01, 0)
	if(!strength)
		qdel(src)
		return
	if(strength >= 3)
		if(prob(3))
			C.adjust_timed_status_effect(2 * STATUS_COUNTER_UNIT, /datum/status_effect/life_counter/slur)
		C.adjust_timed_status_effect(-3 * STATUS_COUNTER_UNIT, /datum/status_effect/life_counter/jitter)
		C.apply_status_effect(/datum/status_effect/buff/drunk)
		C.add_stress(/datum/stressevent/drunk)
	else
		C.remove_stress(/datum/stressevent/drunk)
	if(strength >= 8.5)
		if(C.has_flaw(/datum/charflaw/addiction/alcoholic))
			C.sate_addiction()
	if(strength >= 11 && C.get_counter_units(/datum/status_effect/life_counter/slur) < 5)
		C.adjust_timed_status_effect(1.2 * STATUS_COUNTER_UNIT, /datum/status_effect/life_counter/slur)
	if(strength >= 41)
		if(prob(25))
			C.adjust_timed_status_effect(2 * STATUS_COUNTER_UNIT, /datum/status_effect/life_counter/confusion)
		C.Dizzy(10)
	if(strength >= 51)
		C.adjustToxLoss(1)
		if(prob(3))
			C.adjust_timed_status_effect(15 * STATUS_COUNTER_UNIT, /datum/status_effect/life_counter/confusion)
			INVOKE_ASYNC(C, TYPE_PROC_REF(/mob/living/carbon, vomit))
		C.Dizzy(25)
	if(strength >= 61)
		C.adjustToxLoss(1)
		if(prob(50))
			C.blur_eyes(5)
	if(strength >= 71)
		C.adjustToxLoss(1)
		if(prob(10))
			C.blur_eyes(5)
	if(strength >= 81)
		C.adjustToxLoss(3)
		if(prob(5) && !C.stat)
			to_chat(C, span_warning("Maybe I should lie down for a bit..."))
	if(strength >= 91)
		C.adjustToxLoss(5)
		if(prob(20) && !C.stat)
			to_chat(C, span_warning("Just a quick nap..."))
			C.Sleeping(900)
	if(strength >= 101)
		C.adjustToxLoss(5)
