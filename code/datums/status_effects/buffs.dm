/datum/status_effect/good_music
	id = "Good Music"
	alert_type = null
	duration = 6 SECONDS
	tick_interval = 1 SECONDS
	status_type = STATUS_EFFECT_REFRESH

/datum/status_effect/good_music/tick()
	if(owner.can_hear())
		owner.adjust_timed_status_effect(-2 * STATUS_COUNTER_UNIT, /datum/status_effect/life_counter/dizziness)
		owner.adjust_timed_status_effect(-2 * STATUS_COUNTER_UNIT, /datum/status_effect/life_counter/jitter)
		owner.adjust_timed_status_effect(-1 * STATUS_COUNTER_UNIT, /datum/status_effect/life_counter/confusion)

/datum/status_effect/antimagic
	id = "antimagic"
	duration = 10 SECONDS
	examine_text = "<span class='notice'>They seem to be covered in a dull, grey aura.</span>"

/datum/status_effect/antimagic/on_apply()
	owner.visible_message("<span class='notice'>[owner] is coated with a dull aura!</span>")
	ADD_TRAIT(owner, TRAIT_ANTIMAGIC, MAGIC_TRAIT)
	playsound(owner, 'sound/blank.ogg', 75, FALSE)
	return ..()

/datum/status_effect/antimagic/on_remove()
	REMOVE_TRAIT(owner, TRAIT_ANTIMAGIC, MAGIC_TRAIT)
	owner.visible_message("<span class='warning'>[owner]'s dull aura fades away...</span>")

/datum/status_effect/buff/parish_boon
	id = "parish_boon"
	alert_type = /atom/movable/screen/alert/status_effect/buff/parish_boon
	effectedstats = list("perception" = 1, "intelligence" = 1)
	duration = 20 MINUTES

/atom/movable/screen/alert/status_effect/buff/parish_boon
	name = "Boon of the Parish"
	desc = "You lent partial aid to the local church and bear a modest share of its blessing."
	icon_state = "buff"
