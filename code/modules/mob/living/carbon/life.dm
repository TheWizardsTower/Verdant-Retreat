/mob/living/carbon
	var/breath_remaining = -1
	var/holding_breath = FALSE
	var/drowning_active = FALSE

/mob/living/carbon/proc/get_breath_max()
	return max(BREATH_FLOOR, BREATH_BASE_TIME + get_skill_level(/datum/skill/misc/swimming) * BREATH_PER_SWIM_LEVEL + (STAEND - 10) * BREATH_PER_ENDURANCE)

/mob/living/carbon/proc/get_drown_damage()
	. = clamp(DROWN_DAMAGE_BASE - STACON, DROWN_DAMAGE_MIN, DROWN_DAMAGE_BASE)
	if(has_world_trait(/datum/world_trait/abyssor_rage))
		. += DROWN_DAMAGE_ABYSSOR_BONUS

/mob/living/carbon/proc/is_holding_breath()
	return holding_breath && breath_remaining > 0

/mob/living/carbon/Life(seconds, times_fired)
	set invisibility = 0

	if(notransform)
		return

	if(stasis)//if we're in stasis via wildshape then we don't want to be messing with anything related to bleeding or whatever
		return

	if(damageoverlaytemp)
		damageoverlaytemp = 0
		update_damage_hud()

	//Reagent processing needs to come before breathing, to prevent edge cases.
	if(life_work & (LIFEWORK_REAGENTS|LIFEWORK_ORGANS))
		handle_organs()
		if(!reagents || !reagents.total_volume)
			life_work &= ~LIFEWORK_REAGENTS
		if(life_organs_settled())
			life_work &= ~LIFEWORK_ORGANS

	. = ..(seconds, times_fired)

	if (QDELETED(src))
		return

	if(life_work & LIFEWORK_WOUNDS)
		handle_wounds()
		handle_embedded_objects()
		handle_blood()
		if(life_wounds_settled())
			life_work &= ~LIFEWORK_WOUNDS
	handle_roguebreath()
	handle_choke_recovery()
	var/bprv = handle_bodyparts()
	if(bprv & BODYPART_LIFE_UPDATE_HEALTH)
		update_stamina() //needs to go before updatehealth to remove stamcrit
		updatehealth()
	if (times_fired % 3 == 0) // every 3rd tick, fire stress handler. it isn't time-critical, so we don't particularly need it to go EVERY tick
		update_stress()
	handle_nausea()

	handle_sleep()

	handle_brain_damage()

	if(stat != DEAD)
		return 1

/mob/living/carbon/DeadLife()
	set invisibility = 0

	if(notransform)
		return

	. = ..()
	if (QDELETED(src))
		return
	handle_wounds()
	handle_embedded_objects()
	handle_blood()

	check_cremation()

	if(HAS_TRAIT(src, TRAIT_IN_FRENZY))
		handle_automated_frenzy()

/mob/living/carbon/handle_random_events()//BP/WOUND BASED PAIN
	if(HAS_TRAIT(src, TRAIT_NOPAIN) && !HAS_TRAIT(src, TRAIT_CRIMSON_CURSE))
		return
	if(!stat)
		var/pain_threshold = HAS_TRAIT(src, TRAIT_ADRENALINE_RUSH) ? ((STACON + 5) * 10) : (STACON * 10)
		if(has_flaw(/datum/charflaw/masochist)) // Masochists handle pain better by about 1 endurance point
			pain_threshold += 10
		var/painpercent = get_complex_pain() / pain_threshold
		painpercent = painpercent * 100

		if(world.time > mob_timers["painstun"])
			mob_timers["painstun"] = world.time + 100
			var/probby = 40 - (STACON * 2)
			probby = max(probby, 10)
			if(lying || IsKnockdown())
				if(prob(3) && (painpercent >= 80) )
					emote("painmoan")
			else
				if(painpercent >= 100)
					if(HAS_TRAIT(src, TRAIT_NOPAIN) && HAS_TRAIT(src, TRAIT_CRIMSON_CURSE))
						adjust_bloodpool(-250)
						if(bloodpool < 500)
							to_chat(src, span_danger("The Curse no longer shields me from my pain!"))
							emote("painmoan")
							REMOVE_TRAIT(src, TRAIT_NOPAIN, "clan")
						else
							to_chat(src, span_warning("The Curse lets me ignore my pain, but at a cost..."))
						return
					if(HAS_TRAIT(src, TRAIT_PSYDONIAN_GRIT) || STACON >= 15)
						if(prob(25)) // PSYDONIC WEIGHTED COINFLIP. TWEAK THIS AS THOU WILT. DON'T LET THEM BE BROKEN, PSYDON WILLING. THROW CON-MAXXERS A BONE, TOO.
							Immobilize(15) // EAT A MICROSTUN. YOU'RE AVOIDING A PAINCRIT.
							if(HAS_TRAIT(src, TRAIT_PSYDONIAN_GRIT))
								visible_message(span_info("[src] audibly grits their teeth. ENDURING through their pain."), span_info("Through my faith in HIM, I ENDURE."))
							else
								visible_message(span_info("[src] trembled for a moment, but they remain stood."), span_info("My strong constitution keeps me upright."))
							adjust_timed_status_effect(5 * STATUS_COUNTER_UNIT, /datum/status_effect/life_counter/stutter)
							emote("painmoan")
							return
					if(prob(probby) && !HAS_TRAIT(src, TRAIT_NOPAINSTUN) && !has_status_effect(/datum/status_effect/buff/psyhealing))
						Immobilize(10)
						emote("painscream")
						adjust_timed_status_effect(5 * STATUS_COUNTER_UNIT, /datum/status_effect/life_counter/stutter)
						addtimer(CALLBACK(src, PROC_REF(Stun), 110), 10)
						addtimer(CALLBACK(src, PROC_REF(Knockdown), 110), 10)
						mob_timers["painstun"] = world.time + 160
					else
						emote("painmoan")
						adjust_timed_status_effect(5 * STATUS_COUNTER_UNIT, /datum/status_effect/life_counter/stutter)
				else
					if(painpercent >= 80)
						if(probby)
							emote("painmoan")

		if(painpercent >= 100)
			add_stress(/datum/stressevent/painmax)

/mob/living/carbon/proc/handle_roguebreath()
	return

/mob/living/carbon/proc/life_organs_settled()
	for(var/obj/item/organ/O as anything in internal_organs)
		if(O.damage > 0)
			return FALSE
		if(istype(O, /obj/item/organ/heart) || istype(O, /obj/item/organ/stomach) || istype(O, /obj/item/organ/eyes/night_vision))
			return FALSE
	return TRUE

/mob/living/carbon/human/handle_roguebreath()
	..()
	handle_breath()
	if(HAS_TRAIT(src, TRAIT_NOBREATH))
		return TRUE
	if(istype(loc, /obj/structure/closet/dirthole))
		adjustChokeOxyLoss(5)
	if(istype(loc, /obj/structure/closet/burial_shroud))
		var/obj/O = loc
		if(istype(O.loc, /obj/structure/closet/dirthole))
			adjustChokeOxyLoss(10)
	if(isopenturf(loc))
		var/turf/open/T = loc
		if(reagents && T.pollution)
			T.pollution.breathe_act(src)
			if(next_smell <= world.time)
				next_smell = world.time + 30 SECONDS
				T.pollution.smell_act(src)

/mob/living/carbon/human/proc/handle_breath()
	if(HAS_TRAIT(src, TRAIT_NOBREATH) || HAS_TRAIT(src, TRAIT_WATERBREATHING))
		breath_remaining = get_breath_max()
		drowning_active = FALSE
		hud_used?.shutdown_breath_meter()
		return
	if(breath_remaining < 0)
		breath_remaining = get_breath_max()

	var/underwater = (submersion_level == SUBMERSION_FULL)

	if(holding_breath)
		var/had = breath_remaining
		breath_remaining = max(0, breath_remaining - BREATH_DRAIN_PER_TICK)
		if(had > 0 && breath_remaining <= 0)
			holding_breath = FALSE
			if(!underwater)
				INVOKE_ASYNC(src, PROC_REF(emote), "gasp")
				to_chat(src, span_userdanger("I can't hold my breath any longer!"))

	if(underwater && !is_holding_breath())
		if(!drowning_active)
			drowning_active = TRUE
			playsound(src, 'sound/foley/waterenter.ogg', 100, TRUE)
			INVOKE_ASYNC(src, PROC_REF(emote), "gasp")
			to_chat(src, span_userdanger("Water floods my lungs!"))
		adjustChokeOxyLoss(get_drown_damage())
		if(stat == DEAD && client)
			record_round_statistic(STATS_PEOPLE_DROWNED)
		INVOKE_ASYNC(src, PROC_REF(emote), "drown")
	else
		drowning_active = FALSE

	if(!holding_breath && !underwater)
		breath_remaining = min(get_breath_max(), breath_remaining + BREATH_REGEN_PER_TICK)

	if(!hud_used)
		return
	var/max_breath = get_breath_max()
	if(!(submersion_level != SUBMERSION_NONE || holding_breath || breath_remaining < max_breath))
		hud_used.shutdown_breath_meter()
		return
	hud_used.initialize_breath_meter()
	var/atom/movable/screen/bloodpool/breath/meter = hud_used.breath_meter
	meter.set_value(breath_remaining / max_breath, 5)
	var/target_state = drowning_active ? BREATH_METER_DROWNING : (holding_breath ? BREATH_METER_HOLDING : BREATH_METER_IDLE)
	if(meter.color_state != target_state)
		meter.color_state = target_state
		switch(target_state)
			if(BREATH_METER_DROWNING)
				meter.set_fill_color("#E04A3C")
			if(BREATH_METER_HOLDING)
				meter.set_fill_color("#3CC7E0")
			if(BREATH_METER_IDLE)
				meter.set_fill_color("#2A7A8C")

/mob/living/proc/handle_inwater(turf/W, extinguish = TRUE, force_drown = FALSE)
	if(!extinguish)
		return
	if(is_floor_hazard_immune())
		return
	var/wl = 3
	if(istype(W, /turf/open/water))
		var/turf/open/water/WT = W
		wl = WT.water_level
	if(!(mobility_flags & MOBILITY_STAND) || wl == 3)
		SoakMob(FULL_BODY)
	else if(wl == 2)
		SoakMob(BELOW_CHEST)

/mob/living/carbon/handle_inwater(turf/onturf, extinguish = TRUE, force_drown = FALSE)
	..()
	if(!force_drown)
		return
	if(HAS_TRAIT(src, TRAIT_NOBREATH) || HAS_TRAIT(src, TRAIT_WATERBREATHING) || is_holding_breath())
		return TRUE
	if(stat == DEAD && client)
		record_round_statistic(STATS_PEOPLE_DROWNED)
	breath_remaining = 0
	adjustChokeOxyLoss(get_drown_damage())
	emote("drown")

/mob/living/carbon/human/handle_inwater(turf/onturf, extinguish = TRUE, force_drown = FALSE)
	. = ..()
	if(istype(onturf, /turf/open/water/bath))
		if(!wear_armor && !wear_shirt && !wear_pants)
			add_stress(/datum/stressevent/bathwater)

/mob/living/carbon/human/handle_inwater(turf/onturf, extinguish = TRUE, force_drown = FALSE)
	. = ..()
	if(istype(onturf, /turf/open/water/sewer) && !HAS_TRAIT(src, TRAIT_NOSTINK))
		if(!is_holding_breath())
			add_stress(/datum/stressevent/sewertouched)

/mob/living/carbon/proc/get_complex_pain()
	. = 0
	var/has_adrenaline = HAS_TRAIT(src, TRAIT_ADRENALINE_RUSH)
	for(var/obj/item/bodypart/limb as anything in bodyparts)
		if(limb.status == BODYPART_ROBOTIC || limb.skeletonized)
			continue
		var/bodypart_pain = ((limb.brute_dam + limb.burn_dam) / limb.max_damage) * limb.max_pain_damage
		for(var/datum/wound/wound as anything in limb.wounds)
			bodypart_pain += wound.woundpain
		bodypart_pain = min(bodypart_pain, limb.max_pain_damage)
		if(has_adrenaline)
			bodypart_pain *= 0.5
		. += bodypart_pain
	// Round to prevent floating point precision errors from causing persistent phantom pain
	. = round(., 0.1)

/mob/living/carbon/human/get_complex_pain()
	. = ..()
	if(physiology)
		. *= physiology.pain_mod
	. = round(., 0.1)

///////////////
// BREATHING //
///////////////

//Start of a breath chain, calls breathe()
/mob/living/carbon/handle_breathing(times_fired)
	return

/mob/living/carbon/proc/has_smoke_protection()
	if(HAS_TRAIT(src, TRAIT_NOBREATH))
		return TRUE
	return FALSE

/mob/living/carbon/proc/handle_bodyparts()
	var/stam_regen = stam_regen_start_time <= world.time
	if(stam_regen && stam_paralyzed)
		. |= BODYPART_LIFE_UPDATE_HEALTH
	for(var/obj/item/bodypart/BP as anything in bodyparts)
		if(BP.needs_processing)
			. |= BP.on_life(stam_regen)

/mob/living/carbon/proc/handle_organs()
	if(stat != DEAD)
		for(var/obj/item/organ/O as anything in internal_organs)
			O.on_life()
	else
		for(var/obj/item/organ/O as anything in internal_organs)
			O.on_death()

/mob/living/carbon/handle_embedded_objects()
	for(var/obj/item/bodypart/bodypart as anything in bodyparts)
		for(var/obj/item/embedded as anything in bodypart.embedded_objects)
			if(embedded.on_embed_life(src, bodypart))
				continue

			if(prob(embedded.embedding.embedded_pain_chance))
				// Jiggling increases wound pain temporarily
				var/datum/wound/dynamic/puncture/stab_wound = bodypart.has_wound(/datum/wound/dynamic/puncture)
				if(!stab_wound)
					// Object healed around - create wound through normal damage, then edit bleed rate to 0
					bodypart.receive_damage(embedded.w_class * embedded.embedding.embedded_pain_multiplier)
					stab_wound = bodypart.has_wound(/datum/wound/dynamic/puncture)
					if(stab_wound)
						stab_wound.set_bleed_rate(0)
				else
					var/jiggle_pain_add = embedded.w_class * 8
					stab_wound.jiggle_pain += jiggle_pain_add
					stab_wound.woundpain = stab_wound.base_woundpain + stab_wound.jiggle_pain
				to_chat(src, span_danger("[embedded] in my [bodypart.name] hurts!"))

			// Objects no longer fall out on their own - must be surgically removed or ripped out
			//if(prob(embedded.embedding.embedded_fall_chance))
			//	bodypart.receive_damage(embedded.w_class*embedded.embedding.embedded_fall_pain_multiplier)
			//	bodypart.remove_embedded_object(embedded)
			//	to_chat(src,span_danger("[embedded] falls out of my [bodypart.name]!"))

/*
Alcohol Poisoning Chart
Note that all higher effects of alcohol poisoning will inherit effects for smaller amounts (i.e. light poisoning inherts from slight poisoning)
In addition, severe effects won't always trigger unless the drink is poisonously strong
All effects don't start immediately, but rather get worse over time; the rate is affected by the imbiber's alcohol tolerance

0: Non-alcoholic
1-10: Barely classifiable as alcohol - occassional slurring
11-20: Slight alcohol content - slurring
21-30: Below average - imbiber begins to look slightly drunk
31-40: Just below average - no unique effects
41-50: Average - mild disorientation, imbiber begins to look drunk
51-60: Just above average - disorientation, vomiting, imbiber begins to look heavily drunk
61-70: Above average - small chance of blurry vision, imbiber begins to look smashed
71-80: High alcohol content - blurry vision, imbiber completely shitfaced
81-90: Extremely high alcohol content - light brain damage, passing out
91-100: Dangerously toxic - swift death
*/
#define BALLMER_POINTS 5
GLOBAL_LIST_INIT(ballmer_good_msg, list("Hey guys, what if we rolled out a bluespace wiring system so mice can't destroy the powergrid anymore?",
										"Hear me out here. What if, and this is just a theory, we made R&D controllable from our PDAs?",
										"I'm thinking we should roll out a git repository for our research under the AGPLv3 license so that we can share it among the other stations freely.",
										"I dunno about you guys, but IDs and PDAs being separate is clunky as fuck. Maybe we should merge them into a chip in our arms? That way they can't be stolen easily.",
										"Why the fuck aren't we just making every pair of shoes into galoshes? We have the technology."))
GLOBAL_LIST_INIT(ballmer_windows_me_msg, list("Yo man, what if, we like, uh, put a webserver that's automatically turned on with default admin passwords into every PDA?",
												"So like, you know how we separate our codebase from the master copy that runs on our consumer boxes? What if we merged the two and undid the separation between codebase and server?",
												"Dude, radical idea: H.O.N.K mechs but with no bananium required.",
												"Best idea ever: Disposal pipes instead of hallways.",
												"We should store bank records in a webscale datastore, like /dev/null.",
												"You ever wonder if /dev/null supports sharding?",
												"Do you know who ate all the donuts?",
												"What if we use a language that was written on a napkin and created over 1 weekend for all of our servers?"))

//used in human and monkey handle_environment()
/mob/living/carbon/proc/natural_bodytemperature_stabilization()
	var/body_temperature_difference = BODYTEMP_NORMAL - bodytemperature
	switch(bodytemperature)
		if(-INFINITY to BODYTEMP_COLD_DAMAGE_LIMIT) //Cold damage limit is 50 below the default, the temperature where you start to feel effects.
			return max((body_temperature_difference * metabolism_efficiency / BODYTEMP_AUTORECOVERY_DIVISOR), BODYTEMP_AUTORECOVERY_MINIMUM)
		if(BODYTEMP_COLD_DAMAGE_LIMIT to BODYTEMP_NORMAL)
			return max(body_temperature_difference * metabolism_efficiency / BODYTEMP_AUTORECOVERY_DIVISOR, min(body_temperature_difference, BODYTEMP_AUTORECOVERY_MINIMUM/4))
		if(BODYTEMP_NORMAL to BODYTEMP_HEAT_DAMAGE_LIMIT) // Heat damage limit is 50 above the default, the temperature where you start to feel effects.
			return min(body_temperature_difference * metabolism_efficiency / BODYTEMP_AUTORECOVERY_DIVISOR, max(body_temperature_difference, -BODYTEMP_AUTORECOVERY_MINIMUM/4))
		if(BODYTEMP_HEAT_DAMAGE_LIMIT to INFINITY)
			return min((body_temperature_difference / BODYTEMP_AUTORECOVERY_DIVISOR), -BODYTEMP_AUTORECOVERY_MINIMUM)	//We're dealing with negative numbers

/////////
//LIVER//
/////////

///Decides if the liver is failing or not.
/mob/living/carbon/proc/handle_liver()
	if(!dna)
		return
	var/obj/item/organ/liver/liver = getorganslot(ORGAN_SLOT_LIVER)
	if(!liver)
		liver_failure()

/mob/living/carbon/proc/undergoing_liver_failure()
	var/obj/item/organ/liver/liver = getorganslot(ORGAN_SLOT_LIVER)
	if(liver && (liver.organ_flags & ORGAN_FAILING))
		return TRUE

/mob/living/carbon/proc/liver_failure()
	reagents.end_metabolization(src, keep_liverless = TRUE) //Stops trait-based effects on reagents, to prevent permanent buffs
	reagents.metabolize(src, can_overdose=FALSE, liverless = TRUE)
	if(mind && (HAS_TRAIT(src, TRAIT_STABLELIVER) || HAS_TRAIT(src, TRAIT_NOMETABOLISM)))
		return
	adjustToxLoss(4, TRUE,  TRUE)
//	if(prob(30))
//		to_chat(src, span_warning("I feel a stabbing pain in your abdomen!"))


/////////////
//CREMATION//
/////////////
/mob/living/carbon/proc/check_cremation()
	//Only cremate while actively on fire
	if(!on_fire)
		return

	if(stat != DEAD)
		return

	//Only starts when the chest has taken full damage
	var/obj/item/bodypart/chest = get_bodypart(BODY_ZONE_CHEST)
	if(!(chest.get_damage() >= chest.max_damage))
		return

	//Burn off limbs one by one
	var/obj/item/bodypart/limb
	var/list/limb_list = list(BODY_ZONE_L_ARM, BODY_ZONE_R_ARM, BODY_ZONE_L_LEG, BODY_ZONE_R_LEG)
	var/still_has_limbs = FALSE
	var/should_update_body = FALSE
	for(var/zone in limb_list)
		limb = get_bodypart(zone)
		if(limb && !limb.skeletonized)
			still_has_limbs = TRUE
			if(limb.get_damage() >= limb.max_damage)
				limb.cremation_progress += rand(2,5)
				if(dna && dna.species && !(NOBLOOD in dna.species.species_traits))
					blood_volume = max(blood_volume - 10, 0)
				if(limb.cremation_progress >= 50)
					if(limb.status == BODYPART_ORGANIC) //Non-organic limbs don't burn
						limb.skeletonize()
						should_update_body = TRUE
//						limb.drop_limb()
//						limb.visible_message(span_warning("[src]'s [limb.name] crumbles into ash!"))
//						qdel(limb)
//					else
//						limb.drop_limb()
//						limb.visible_message(span_warning("[src]'s [limb.name] detaches from [p_their()] body!"))
	if(still_has_limbs)
		return

	//Burn the head last
	var/obj/item/bodypart/head = get_bodypart(BODY_ZONE_HEAD)
	if(head && !head.skeletonized)
		if(head.get_damage() >= head.max_damage)
			head.cremation_progress += 999
			if(head.cremation_progress >= 20)
				if(head.status == BODYPART_ORGANIC) //Non-organic limbs don't burn
					head.skeletonize()
					should_update_body = TRUE
//					head.drop_limb()
//					head.visible_message(span_warning("[src]'s head crumbles into ash!"))
//					qdel(head)
//				else
//					head.drop_limb()
//					head.visible_message(span_warning("[src]'s head detaches from [p_their()] body!"))
		return

	//Nothing left: dust the body, drop the items (if they're flammable they'll burn on their own)
	if(chest && !chest.skeletonized)
		if(chest.get_damage() >= chest.max_damage)
			chest.cremation_progress += 999
			if(chest.cremation_progress >= 19)
		//		visible_message(span_warning("[src]'s body crumbles into a pile of ash!"))
		//		dust(TRUE, TRUE)
				chest.skeletonized = TRUE
				if(ishuman(src))
					var/mob/living/carbon/human/H = src
					qdel(H.underwear)
				should_update_body = TRUE
				if(dna && dna.species)
					if(dna && dna.species && !(NOBLOOD in dna.species.species_traits))
						blood_volume = 0
					dna.species.species_traits |= NOBLOOD

	if(should_update_body)
		update_body()

////////////////
//BRAIN DAMAGE//
////////////////

/mob/living/carbon/proc/handle_brain_damage()
	for(var/T in get_traumas())
		var/datum/brain_trauma/BT = T
		BT.on_life()

/////////////////////////////////////
//MONKEYS WITH TOO MUCH CHOLOESTROL//
/////////////////////////////////////

/mob/living/carbon/proc/can_heartattack()
	if(!needs_heart())
		return FALSE
	var/obj/item/organ/heart/heart = getorganslot(ORGAN_SLOT_HEART)
	if(!heart || (heart.organ_flags & ORGAN_SYNTHETIC))
		return FALSE
	return TRUE

/mob/living/carbon/proc/needs_heart()
	if(HAS_TRAIT(src, TRAIT_STABLEHEART))
		return FALSE
	if(dna && dna.species && (NOBLOOD in dna.species.species_traits)) //not all carbons have species!
		return FALSE
	return TRUE

/*
 * The mob is having a heart attack
 *
 * NOTE: this is true if the mob has no heart and needs one, which can be suprising,
 * you are meant to use it in combination with can_heartattack for heart attack
 * related situations (i.e not just cardiac arrest)
 */
/mob/living/carbon/proc/undergoing_cardiac_arrest()
	var/obj/item/organ/heart/heart = getorganslot(ORGAN_SLOT_HEART)
	if(istype(heart) && heart.beating)
		return FALSE
	else if(!needs_heart())
		return FALSE
	return TRUE

/mob/living/carbon/proc/set_heartattack(status)
	if(!can_heartattack())
		return FALSE

	var/obj/item/organ/heart/heart = getorganslot(ORGAN_SLOT_HEART)
	if(!istype(heart))
		return

	heart.beating = !status

/// Handles sleep. Mobs with no_sleep trait cannot sleep.
/*
*	The mob tries to go to sleep or IS sleeping
*
*	Accounts for...
*	TRAIT_NOSLEEP
*	CANT_SLEEP_IN
*	Hunger and Hydration.
*/

/mob/living/carbon/proc/handle_sleep()
	if (!client) // not really relevant to NPCs at the moment
		return
	if(HAS_TRAIT(src, TRAIT_NOSLEEP))
		if(!(mobility_flags & MOBILITY_STAND))
			energy_add(5)
		if(mind?.has_antag_datum(/datum/antagonist/vampire))
			if(!(mobility_flags & MOBILITY_STAND))
				energy_add(10)
			energy_add(4)
		return
	//Healing while sleeping in a bed
	if(IsSleeping())
		var/sleepy_mod = 0.5
		var/doesnt_hunger = HAS_TRAIT(src, TRAIT_NOHUNGER)
		if(HAS_TRAIT(src, TRAIT_BETTER_SLEEP))
			energy_add(sleepy_mod * 4)
		if(buckled?.sleepy)
			sleepy_mod = buckled.sleepy
		else if(isturf(loc)) //No illegal tech.
			var/obj/structure/bed/rogue/bed = locate() in loc
			if(bed)
				sleepy_mod = bed.sleepy
			else
				if(HAS_TRAIT(src, TRAIT_OUTDOORSMAN))
					var/obj/structure/flora/newbranch/branch = locate() in loc
					if(branch)
						sleepy_mod = 2 // just equivalent to a bedroll
		if(nutrition > 0 || doesnt_hunger)
			energy_add(sleepy_mod * 15)
		if(hydration > 0 || doesnt_hunger)
			if(!bleed_rate)
				blood_volume = min(blood_volume + (4 * sleepy_mod), BLOOD_VOLUME_NORMAL)
			for (var/obj/item/bodypart/affecting in bodyparts)
				if (!affecting)
					continue

				if (affecting.get_bleed_rate() >= 1)
					continue

				if (affecting.heal_damage(sleepy_mod, sleepy_mod, required_status = BODYPART_ORGANIC))
					src.update_damage_overlays()

				var/list/wlist = affecting.wounds
				if (islist(wlist))
					for (var/datum/wound/W in wlist)
						var/sh = W?.sleep_healing
						if (sh)
							W.heal_wound(sh * sleepy_mod)
			adjustToxLoss(-sleepy_mod)
			if(eyesclosed && !HAS_TRAIT(src, TRAIT_NOSLEEP))
				Sleeping(300)
	else if(!IsSleeping() && !HAS_TRAIT(src, TRAIT_NOSLEEP))
		// Resting on a bed or something
		var/sleepy_mod = 0
		if(buckled?.sleepy)
			sleepy_mod = buckled.sleepy
		else if(isturf(loc) && !(mobility_flags & MOBILITY_STAND))
			var/obj/structure/bed/rogue/bed = locate() in loc
			if(bed)
				sleepy_mod = bed.sleepy
			else
				if(HAS_TRAIT(src, TRAIT_OUTDOORSMAN))
					var/obj/structure/flora/newbranch/branch = locate() in loc
					if(branch)
						sleepy_mod = 0.5 // equivalent to leaning against a wall, since you get this while NOT asleep
		if(sleepy_mod > 0)
			if(eyesclosed)
				var/armor_blocked = FALSE
				if(ishuman(src) && stat == CONSCIOUS)
					var/mob/living/carbon/human/H = src
					if(H.head && H.head.armor?.blunt > 70 && !(HAS_TRAIT(H.head.armor, TRAIT_NODROP)))
						armor_blocked = TRUE
					if(H.wear_armor && (H.wear_armor.armor_class in list(ARMOR_CLASS_HEAVY, ARMOR_CLASS_MEDIUM)) && !(HAS_TRAIT(H.wear_armor, TRAIT_NODROP)))
						armor_blocked = TRUE
					if(armor_blocked && !fallingas)
						to_chat(src, span_warning("I can't sleep like this. My armor is burdening me."))
						fallingas = TRUE
				if(!armor_blocked)
					if(!fallingas)
						to_chat(src, span_warning("I'll fall asleep soon..."))
					fallingas++
					if(HAS_TRAIT(src, TRAIT_FASTSLEEP))
						fallingas++
					if(fallingas > 15)
						Sleeping(300)
			else
				energy_add(sleepy_mod * 10)
		// Resting on the ground (not sleeping or with eyes closed and about to fall asleep)
		else if(!(mobility_flags & MOBILITY_STAND))
			if(eyesclosed)
				var/armor_blocked = FALSE
				if(ishuman(src) && stat == CONSCIOUS)
					var/mob/living/carbon/human/H = src
					if(H.head && H.head.armor?.blunt > 70)
						armor_blocked = TRUE
					if(H.wear_armor && (H.wear_armor.armor_class in list(ARMOR_CLASS_HEAVY, ARMOR_CLASS_MEDIUM)))
						armor_blocked = TRUE
					if(armor_blocked && !fallingas)
						to_chat(src, span_warning("I can't sleep like this. My armor is burdening me."))
						fallingas = TRUE
				if(!armor_blocked)
					if(!fallingas)
						to_chat(src, span_warning("I'll fall asleep soon, although a bed would be more comfortable..."))
					fallingas++
					if(HAS_TRAIT(src, TRAIT_FASTSLEEP))
						fallingas++
					if(fallingas > 25)
						Sleeping(300)
			else
				energy_add(10)
		else if(fallingas)
			fallingas = 0

	// Leaning against a wall: slowly regain stamina
	if(mobility_flags & MOBILITY_STAND && wallpressed && !IsSleeping() && !buckled && !lying && !climbing)
		energy_add(5)
