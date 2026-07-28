//Largely negative status effects go here, even if they have small benificial effects
//STUN EFFECTS
/datum/status_effect/incapacitating
	tick_interval = 0
	status_type = STATUS_EFFECT_REPLACE
	alert_type = null
	var/needs_update_stat = FALSE

/datum/status_effect/incapacitating/on_creation(mob/living/new_owner, set_duration, updating_canmove)
	if(isnum(set_duration))
		duration = set_duration
	. = ..()
	if(.)
		if(updating_canmove)
			owner.update_mobility()
			if(needs_update_stat)
				owner.update_stat()

/datum/status_effect/incapacitating/on_remove()
	if(owner)
		owner.update_mobility()
		if(needs_update_stat) //silicons need stat updates in addition to normal canmove updates
			owner.update_stat()

//STUN
/datum/status_effect/incapacitating/stun
	id = "stun"
	alert_type = /atom/movable/screen/alert/status_effect/stun

/atom/movable/screen/alert/status_effect/stun
	name = "Stunned"
	desc = ""
	icon_state = "stun"

//KNOCKDOWN
/datum/status_effect/incapacitating/knockdown
	id = "knockdown"
	alert_type = /atom/movable/screen/alert/status_effect/knocked_down

/atom/movable/screen/alert/status_effect/knocked_down
	name = "Knocked Down"
	desc = ""
	icon_state = "knockdown"

//IMMOBILIZED
/datum/status_effect/incapacitating/immobilized
	id = "immobilized"
	alert_type = /atom/movable/screen/alert/status_effect/immobilized
	mob_effect_icon = 'icons/mob/mob_effects.dmi'
	mob_effect_icon_state = "eff_immobilized"
	mob_effect_offset_x = 3

/atom/movable/screen/alert/status_effect/immobilized
	name = "Immobilized"
	desc = ""
	icon_state = "immob"

/datum/status_effect/incapacitating/paralyzed
	id = "paralyzed"
	alert_type = /atom/movable/screen/alert/status_effect/paralyzed

/atom/movable/screen/alert/status_effect/paralyzed
	name = "Paralyzed"
	desc = ""
	icon_state = "paralyze"

//UNCONSCIOUS
/datum/status_effect/incapacitating/unconscious
	id = "unconscious"
	needs_update_stat = TRUE

/datum/status_effect/incapacitating/unconscious/tick()
	if(owner.getStaminaLoss())
		owner.adjustStaminaLoss(-0.3) //reduce stamina loss by 0.3 per tick, 6 per 2 seconds

//SLEEPING
/datum/status_effect/incapacitating/sleeping
	id = "sleeping"
	alert_type = /atom/movable/screen/alert/status_effect/asleep
	needs_update_stat = TRUE
	var/mob/living/carbon/carbon_owner
	var/mob/living/carbon/human/human_owner
	var/sleptonground = FALSE

/datum/status_effect/incapacitating/sleeping/on_creation(mob/living/new_owner, updating_canmove)
	. = ..()
	if(.)
		if(owner.cmode)
			owner.cmode = 0
		SSdroning.kill_droning(owner.client)
		SSdroning.kill_loop(owner.client)
		SSdroning.kill_rain(owner.client)
		owner.clear_typing_indicator()
		if(iscarbon(owner)) //to avoid repeated istypes
			carbon_owner = owner
		if(ishuman(owner))
			human_owner = owner

/datum/status_effect/incapacitating/sleeping/on_remove()
	if(human_owner && human_owner.client)
		SSdroning.play_area_sound(get_area(src), human_owner.client)
		SSdroning.play_loop(get_area(src), human_owner.client)
	. = ..()

/datum/status_effect/incapacitating/sleeping/Destroy()
	carbon_owner = null
	human_owner = null
	return ..()

/datum/status_effect/incapacitating/sleeping/tick()
	if(owner.health < owner.crit_threshold) // no sleep-healing while we're dying.
		return

	if(owner.maxHealth)
		var/health_ratio = owner.health / owner.maxHealth
		var/healing = -0.2
		if((locate(/obj/structure/bed) in owner.loc))
			healing -= 0.3
		else if((locate(/obj/structure/table) in owner.loc))
			healing -= 0.1
		for(var/obj/item/bedsheet/bedsheet in range(owner.loc,0))
			if(bedsheet.loc != owner.loc) //bedsheets in my backpack/neck don't give you comfort
				continue
			healing -= 0.1
			break //Only count the first bedsheet
		if(health_ratio > 0.8)
			owner.adjustToxLoss(healing * 0.5, FALSE, TRUE)
		owner.adjustStaminaLoss(healing)
	if(human_owner)
		var/datum/status_effect/inebriated/booze = human_owner.has_status_effect(/datum/status_effect/inebriated)
		booze?.set_strength(booze.strength * 0.997) //reduce drunkenness by 0.3% per tick, 6% per 2 seconds
	if(prob(20))
		if(carbon_owner)
			carbon_owner.handle_dreams()
			if((prob(10) && owner.health > owner.crit_threshold) && !HAS_TRAIT(owner, TRAIT_NOBREATH))
				owner.emote("snore")
	if(isharpy(owner))
		var/obj/item/clothing/suit/roguetown/armor/skin_armor/harpy_skin = human_owner.skin_armor
		if(harpy_skin.obj_integrity < harpy_skin.max_integrity)
			harpy_skin.obj_integrity += 10
			to_chat(human_owner, "I can feel the skin on my feet mend...")
		else if((harpy_skin.obj_integrity >= harpy_skin.max_integrity) && harpy_skin.obj_broken)
			harpy_skin.obj_broken = FALSE

/atom/movable/screen/alert/status_effect/asleep
	name = "Asleep"
	desc = ""
	icon_state = "sleeping"

//STASIS
/datum/status_effect/incapacitating/stasis
		id = "stasis"
		duration = -1
		tick_interval = 10
		alert_type = /atom/movable/screen/alert/status_effect/stasis
		var/last_dead_time

/datum/status_effect/incapacitating/stasis/proc/update_time_of_death()
		if(last_dead_time)
				var/delta = world.time - last_dead_time
				var/new_timeofdeath = owner.timeofdeath + delta
				owner.timeofdeath = new_timeofdeath
				owner.tod = station_time_timestamp(wtime=new_timeofdeath)
				last_dead_time = null
		if(owner.stat == DEAD)
				last_dead_time = world.time

/datum/status_effect/incapacitating/stasis/on_creation(mob/living/new_owner, set_duration, updating_canmove)
		. = ..()
		update_time_of_death()
		owner.reagents?.end_metabolization(owner, FALSE)

/datum/status_effect/incapacitating/stasis/tick()
		update_time_of_death()

/datum/status_effect/incapacitating/stasis/on_remove()
		update_time_of_death()
		return ..()

/datum/status_effect/incapacitating/stasis/be_replaced()
		update_time_of_death()
		return ..()

/atom/movable/screen/alert/status_effect/stasis
		name = "Stasis"
		desc = ""
		icon_state = "stasis"

//GOLEM GANG

//OTHER DEBUFFS
/datum/status_effect/strandling //get it, strand as in durathread strand + strangling = strandling hahahahahahahahahahhahahaha i want to die
	id = "strandling"
	status_type = STATUS_EFFECT_UNIQUE
	alert_type = /atom/movable/screen/alert/status_effect/strandling

/datum/status_effect/strandling/on_apply()
	ADD_TRAIT(owner, TRAIT_MAGIC_CHOKE, "dumbmoron")
	return ..()

/datum/status_effect/strandling/on_remove()
	REMOVE_TRAIT(owner, TRAIT_MAGIC_CHOKE, "dumbmoron")
	return ..()

/atom/movable/screen/alert/status_effect/strandling
	name = "Choking strand"
	desc = ""
	icon_state = "his_grace"
	alerttooltipstyle = "hisgrace"

/atom/movable/screen/alert/status_effect/strandling/Click(location, control, params)
	. = ..()
	to_chat(mob_viewer, "<span class='notice'>I attempt to remove the durathread strand from around my neck.</span>")
	if(do_after(mob_viewer, 35, null, mob_viewer))
		if(isliving(mob_viewer))
			var/mob/living/L = mob_viewer
			to_chat(mob_viewer, "<span class='notice'>I succesfuly remove the durathread strand.</span>")
			L.remove_status_effect(STATUS_EFFECT_CHOKINGSTRAND)


/datum/status_effect/pacify
	id = "pacify"
	status_type = STATUS_EFFECT_REPLACE
	tick_interval = 1
	duration = 100
	alert_type = null

/datum/status_effect/pacify/on_creation(mob/living/new_owner, set_duration)
	if(isnum(set_duration))
		duration = set_duration
	. = ..()

/datum/status_effect/pacify/on_apply()
	ADD_TRAIT(owner, TRAIT_PACIFISM, "status_effect")
	return ..()

/datum/status_effect/pacify/on_remove()
	REMOVE_TRAIT(owner, TRAIT_PACIFISM, "status_effect")

/datum/status_effect/neck_slice
	id = "neck_slice"
	status_type = STATUS_EFFECT_UNIQUE
	alert_type = null
	duration = -1

/datum/status_effect/neck_slice/tick()
	var/mob/living/carbon/human/H = owner
	if(H.stat == DEAD || H.bleed_rate <= 8)
		H.remove_status_effect(/datum/status_effect/neck_slice)
	if(prob(10) && !HAS_TRAIT(H, TRAIT_NOBREATH))
		H.emote(pick("gasp", "gag", "choke"))

/obj/effect/temp_visual/curse
	icon_state = "curse"

/datum/status_effect/trance
	id = "trance"
	status_type = STATUS_EFFECT_UNIQUE
	duration = 300
	tick_interval = 10
	examine_text = "<span class='warning'>SUBJECTPRONOUN seems slow and unfocused.</span>"
	var/stun = TRUE
	alert_type = /atom/movable/screen/alert/status_effect/trance

/atom/movable/screen/alert/status_effect/trance
	name = "Trance"
	desc = ""
	icon_state = "high"

/datum/status_effect/trance/tick()
	if(stun)
		owner.Stun(60, TRUE, TRUE)
	owner.set_dizziness(20)

/datum/status_effect/trance/on_apply()
	if(!iscarbon(owner))
		return FALSE
	RegisterSignal(owner, COMSIG_MOVABLE_HEAR, PROC_REF(hypnotize))
	ADD_TRAIT(owner, TRAIT_MUTE, "trance")
	owner.add_client_colour(/datum/client_colour/monochrome/trance)
	owner.visible_message("[stun ? "<span class='warning'>[owner] stands still as [owner.p_their()] eyes seem to focus on a distant point.</span>" : ""]", \
	"<span class='warning'>[pick("You feel my thoughts slow down...", "You suddenly feel extremely dizzy...", "You feel like you're in the middle of a dream...","You feel incredibly relaxed...")]</span>")
	return TRUE

/datum/status_effect/trance/on_creation(mob/living/new_owner, _duration, _stun = TRUE)
	duration = _duration
	stun = _stun
	return ..()

/datum/status_effect/trance/on_remove()
	UnregisterSignal(owner, COMSIG_MOVABLE_HEAR)
	REMOVE_TRAIT(owner, TRAIT_MUTE, "trance")
	owner.remove_status_effect(/datum/status_effect/life_counter/dizziness)
	owner.remove_client_colour(/datum/client_colour/monochrome/trance)
	to_chat(owner, "<span class='warning'>I snap out of my trance!</span>")

/datum/status_effect/trance/proc/hypnotize(datum/source, list/hearing_args)
	if(!owner.can_hear())
		return
	if(hearing_args[HEARING_SPEAKER] == owner)
		return
	var/mob/living/carbon/C = owner
	C.cure_trauma_type(/datum/brain_trauma/hypnosis, TRAUMA_RESILIENCE_SURGERY) //clear previous hypnosis
	addtimer(CALLBACK(C, TYPE_PROC_REF(/mob/living/carbon, gain_trauma), /datum/brain_trauma/hypnosis, TRAUMA_RESILIENCE_SURGERY, hearing_args[HEARING_RAW_MESSAGE]), 10)
	addtimer(CALLBACK(C, TYPE_PROC_REF(/mob/living, Stun), 60, TRUE, TRUE), 15) //Take some time to think about it
	qdel(src)

/datum/status_effect/spasms
	id = "spasms"
	status_type = STATUS_EFFECT_MULTIPLE
	alert_type = null

/datum/status_effect/spasms/tick()
	if(prob(15))
		switch(rand(1,5))
			if(1)
				if((owner.mobility_flags & MOBILITY_MOVE) && isturf(owner.loc))
					to_chat(owner, "<span class='warning'>My leg spasms!</span>")
					step(owner, pick(GLOB.cardinals))
			if(2)
				if(owner.incapacitated())
					return
				var/obj/item/I = owner.get_active_held_item()
				if(I)
					to_chat(owner, "<span class='warning'>My fingers spasm!</span>")
					owner.log_message("used [I] due to a Muscle Spasm", LOG_ATTACK)
					I.attack_self(owner)
			if(3)
				var/prev_intent = owner.a_intent
				owner.a_intent = INTENT_HARM

				var/range = 1
				if(istype(owner.get_active_held_item(), /obj/item/gun)) //get targets to shoot at
					range = 7

				var/list/mob/living/targets = list()
				for(var/mob/M in oview(owner, range))
					if(isliving(M))
						targets += M
				if(LAZYLEN(targets))
					to_chat(owner, "<span class='warning'>My arm spasms!</span>")
					owner.log_message(" attacked someone due to a Muscle Spasm", LOG_ATTACK) //the following attack will log itself
					owner.ClickOn(pick(targets))
				owner.a_intent = prev_intent
			if(4)
				var/prev_intent = owner.a_intent
				owner.a_intent = INTENT_HARM
				to_chat(owner, "<span class='warning'>My arm spasms!</span>")
				owner.log_message("attacked [owner.p_them()]self to a Muscle Spasm", LOG_ATTACK)
				owner.ClickOn(owner)
				owner.a_intent = prev_intent
			if(5)
				if(owner.incapacitated())
					return
				var/obj/item/I = owner.get_active_held_item()
				var/list/turf/targets = list()
				for(var/turf/T in oview(owner, 3))
					targets += T
				if(LAZYLEN(targets) && I)
					to_chat(owner, "<span class='warning'>My arm spasms!</span>")
					owner.log_message("threw [I] due to a Muscle Spasm", LOG_ATTACK)
					owner.throw_item(pick(targets))

/atom/movable/screen/alert/status_effect/debuff/feintcd
	name = "Feint Cool down"
	desc = "I used it. I must wait, or risk a lower chance of success."
	icon_state = "feintcd"


/atom/movable/screen/alert/status_effect/debuff/feinted
	name = "Feinted"
	desc = "I've been feinted. It won't happen again so soon."
	icon_state = "feinted"


/atom/movable/screen/alert/status_effect/debuff/clashcd
	name = "Riposte / Guard Cooldown"
	desc = "I used it. I must wait."
	icon_state = "guardcd"

/atom/movable/screen/alert/status_effect/debuff/exposed
	name = "Exposed"
	desc = "My defenses are exposed. I can be hit through my parry and dodge!"
	icon_state = "exposed"

/datum/status_effect/debuff/exposed
	id = "nofeint"
	alert_type = /atom/movable/screen/alert/status_effect/debuff/exposed
	duration = 10 SECONDS
	mob_effect_icon = 'icons/mob/mob_effects.dmi'
	mob_effect_icon_state = "eff_exposed"
	mob_effect_layer = MOB_EFFECT_LAYER_EXPOSED

/datum/status_effect/debuff/exposed/on_creation(mob/living/new_owner, new_dur)
	if(new_dur)
		duration = new_dur
	return ..()

/datum/status_effect/debuff/feinted
	id = "feinted"
	alert_type = /atom/movable/screen/alert/status_effect/debuff/feinted
	mob_effect_icon = 'icons/mob/mob_effects.dmi'
	mob_effect_icon_state = "eff_feinted"
	mob_effect_offset_y = 10
	mob_effect_layer = MOB_EFFECT_LAYER_FEINTED
	duration = 30 SECONDS

/datum/status_effect/debuff/feinted/on_creation(mob/living/new_owner, new_dur)
	if(new_dur)
		duration = new_dur
	return ..()

/atom/movable/screen/alert/status_effect/debuff/clickcd
	name = "Action Delayed"
	desc = "I cannot take another action."
	icon_state = "clickcd"
