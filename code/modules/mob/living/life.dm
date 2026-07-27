/mob/living/proc/Life(seconds, times_fired)
	set waitfor = FALSE

	SEND_SIGNAL(src, COMSIG_LIVING_LIFE, seconds, times_fired)

	if (client)
		var/turf/T = get_turf(src)
		if(!T)
			var/msg = "[ADMIN_LOOKUPFLW(src)] was found to have no .loc with an attached client, if the cause is unknown it would be wise to ask how this was accomplished."
			message_admins(msg)
			send2irc_adminless_only("Mob", msg, R_ADMIN)
			log_game("[key_name(src)] was found to have no .loc with an attached client.")

	if (notransform)
		return
	if(!loc)
		return

	life_work_upkeep(times_fired)

	//Breathing, if applicable - CURRENTLY NOT IMPLEMENTED
	//handle_breathing(times_fired)

	if(life_work & LIFEWORK_WOUNDS)
		if(HAS_TRAIT(src, TRAIT_SIMPLE_WOUNDS))
			handle_wounds()
			handle_embedded_objects()
			handle_blood()
			//passively heal even wounds with no passive healing

			var/heal_amount = 1 + (blood_volume > BLOOD_VOLUME_SURVIVE ? 0.6 : 0)
			// apparently this means NPCs should heal their wounds slowly over time,
			// with a 60% bonus if they're not completely bled out.
			// this is a strict replacement for two whole-ass block iteration things that did the same thing (or nothing at all)
			heal_wounds(heal_amount)
		if(life_wounds_settled())
			life_work &= ~LIFEWORK_WOUNDS

	if (QDELETED(src)) // diseases can qdel the mob via transformations
		return

	if(life_work & (LIFEWORK_TEMP|LIFEWORK_FIRE_WATER))
		handle_environment()
		if(life_temp_settled())
			life_work &= ~LIFEWORK_TEMP
		if(life_fire_water_settled())
			life_work &= ~LIFEWORK_FIRE_WATER

	//Random events (vomiting etc)
	handle_random_events()

	handle_gravity()

	handle_traits() // eye, ear, brain damages
	if(life_work & LIFEWORK_STATUS)
		handle_status_effects() //all special effects, stun, knockdown, jitteryness, hallucination, sleeping, etc
		if(life_status_settled())
			life_work &= ~LIFEWORK_STATUS

	if(rogue_sneaking || m_intent == MOVE_INTENT_SNEAK || world.time < mob_timers[MT_INVISIBILITY])
		update_sneak_invis()

	if(machine)
		machine.check_eye(src)

	check_drowning()

	if(stat != DEAD)
		return 1

/mob/living/proc/check_drowning()
	if(istype(loc, /turf/open/water))
		handle_inwater(loc)
		return
	if(is_submerged())
		handle_inwater(loc)

/mob/living/carbon/human/check_drowning()
	if(isdullahan(src))
		var/mob/living/carbon/human = src
		var/datum/species/dullahan/dullahan = human.dna.species
		if(dullahan.headless)
			var/obj/item/bodypart/head/dullahan/drownrelay = dullahan.my_head
			if(!drownrelay)
				return
			if(istype(drownrelay.loc, /turf/open/water))
				handle_inwater(drownrelay.loc, extinguish = FALSE, force_drown = TRUE)
			if(istype(loc, /turf/open/water)) // Extinguish ourselves if our body is in water.	
				extinguish_mob()
			return
	. =..()


/mob/living/proc/DeadLife()
	set invisibility = 0
	if (notransform)
		return
	if(!loc)
		return
	if(HAS_TRAIT(src, TRAIT_SIMPLE_WOUNDS))
		handle_wounds()
		handle_embedded_objects()
		handle_blood()
	update_sneak_invis()
	check_drowning()

/mob/living/proc/handle_breathing(times_fired)
	return

/mob/living/proc/handle_random_events()
	//random painstun
	if(!stat && !HAS_TRAIT(src, TRAIT_NOPAINSTUN))
		if(world.time > mob_timers["painstun"] + 600)
			if(getBruteLoss() + getFireLoss() >= (STACON * 10))
				var/probby = 53 - (STACON * 2)
				if(!(mobility_flags & MOBILITY_STAND))
					probby = probby - 20
				if(prob(probby))
					mob_timers["painstun"] = world.time
					Immobilize(10)
					emote("painscream")
					visible_message(span_warning("[src] freezes in pain!"),
								span_warning("I'm frozen in pain!"))
					sleep(10)
					Stun(110)
					Knockdown(110)

/mob/living/proc/handle_environment()
	return

/mob/living/proc/handle_wounds()
	for(var/datum/wound/wound as anything in get_wounds())
		if(!wound)
			continue
		if(stat != DEAD)
			wound.on_life()
		else
			wound.on_death()

/mob/living/carbon/handle_wounds() // Carbons now directly access these lists for performance reasons
	for(var/obj/item/bodypart/BP as anything in bodyparts)
		for(var/datum/wound/W as anything in BP.wounds)
			if (stat != DEAD)
				W.on_life()
			else
				W.on_death()


/obj/item/proc/on_embed_life(mob/living/user, obj/item/bodypart/bodypart)
	return

/mob/living/proc/handle_embedded_objects()
	for(var/obj/item/embedded as anything in simple_embedded_objects)
		if(embedded.on_embed_life(src))
			continue

		if(prob(embedded.embedding.embedded_pain_chance))
			if(embedded.is_silver && HAS_TRAIT(src, TRAIT_SILVER_WEAK) && !has_status_effect(STATUS_EFFECT_ANTIMAGIC))
				var/datum/component/silverbless/psyblessed = embedded.GetComponent(/datum/component/silverbless)
				adjust_fire_stacks(1, psyblessed?.is_blessed ? /datum/status_effect/fire_handler/fire_stacks/sunder/blessed : /datum/status_effect/fire_handler/fire_stacks/sunder)
			to_chat(src, span_danger("[embedded] in me hurts!"))

		//if(prob(embedded.embedding.embedded_fall_chance))
		//	simple_remove_embedded_object(embedded)
		//	to_chat(src,span_danger("[embedded] falls out of me!"))

//this updates all special effects: knockdown, druggy, stuttering, etc..
/mob/living/proc/handle_status_effects()
	if(confused)
		confused = max(confused - 1, 0)
	if(slowdown)
		slowdown = max(slowdown - 1, 0)
	if(slowdown <= 0)
		remove_movespeed_modifier(MOVESPEED_ID_LIVING_SLOWDOWN_STATUS)

/mob/living/proc/handle_traits()
	//Eyes
	if(eye_blind)	//blindness, heals slowly over time
		if(HAS_TRAIT_FROM(src, TRAIT_BLIND, EYES_COVERED)) //covering your eyes heals blurry eyes faster
			adjust_blindness(-3)
		else if(!stat && !(HAS_TRAIT(src, TRAIT_BLIND)))
			adjust_blindness(-1)
	else if(eye_blurry)			//blurry eyes heal slowly
		adjust_blurriness(-1)

/mob/living/proc/update_damage_hud()
	return

/mob/living/proc/handle_gravity()
	var/gravity = mob_has_gravity()
	update_gravity(gravity)

	if(gravity > STANDARD_GRAVITY)
		gravity_animate()
		handle_high_gravity(gravity)

/mob/living/proc/gravity_animate()
	if(!get_filter("gravity"))
		add_filter("gravity",1,list("type"="motion_blur", "x"=0, "y"=0))
	INVOKE_ASYNC(src, PROC_REF(gravity_pulse_animation))

/mob/living/proc/gravity_pulse_animation()
	animate(get_filter("gravity"), y = 1, time = 10)
	sleep(10)
	animate(get_filter("gravity"), y = 0, time = 10)

/mob/living/proc/handle_high_gravity(gravity)
	if(gravity >= GRAVITY_DAMAGE_TRESHOLD) //Aka gravity values of 3 or more
		var/grav_stregth = gravity - GRAVITY_DAMAGE_TRESHOLD
		adjustBruteLoss(min(grav_stregth,3))

// ==============================================================================
// CHANGE-DRIVEN LIFE() WORK SKIPPING
// ==============================================================================

/mob/living/proc/life_extras(alive = TRUE)
	return

/mob/living/var/life_work = LIFEWORK_ALL
/mob/living/var/life_work_id = 0

/mob/living/proc/life_work_upkeep(times_fired)
	if(!life_work_id)
		life_work_id = SSmobs.LifeWorkRegister(src)
	if((times_fired + life_work_id) % 15 == 0)
		life_work |= LIFEWORK_STATUS
	if((times_fired + life_work_id) % 30 == 0)
		life_work |= LIFEWORK_ALL

/mob/living/proc/life_wounds_settled()
	return !length(get_wounds()) && !length(get_embedded_objects()) && bleed_rate <= 0

/mob/living/proc/life_temp_settled()
	return TRUE

/mob/living/proc/life_fire_water_settled()
	return !on_fire && fire_stacks <= 0 && !istype(loc, /turf/open/water)

/mob/living/proc/life_status_settled()
	return !confused && !slowdown
