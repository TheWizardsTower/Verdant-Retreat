/datum/rmb_intent
	var/name = "intent"
	var/desc = ""
	var/icon_state = ""
	var/adjacency = TRUE
	/// Whether the rclick will try to get turfs as target.
	var/prioritize_turfs = FALSE

/mob/living/carbon/human/on_cmode()
	if(!HAS_TRAIT(src, TRAIT_DECEIVING_MEEKNESS))
		filtered_balloon_alert(TRAIT_COMBAT_AWARE, (cmode ? ("<i><font color = '#831414'>Tense</font></i>") : ("<i><font color = '#c7c6c6'>Relaxed</font></i>")), y_offset = 32)
	SEND_SIGNAL(src, COMSIG_COMBAT_MODE)
/mob/living/carbon/human/RightClickOn(atom/A, params)
	if(rmb_intent && !rmb_intent.adjacency && !istype(A, /obj/item/clothing) && cmode && !istype(src, /mob/living/carbon/human/species/skeleton) && !istype(A, /obj/item/quiver) && !istype(A, /obj/item/storage))
		var/held = get_active_held_item()
		if(held && istype(held, /obj/item))
			var/obj/item/I = held
			if(I.associated_skill)
				rmb_intent.special_attack(src, ismob(A) ? A : rmb_intent.prioritize_turfs ? get_turf(A) : get_foe_from_turf(get_turf(A)))
	else
		. = ..()

/// Used for "directional" style rmb attacks on a turf, prioritizing standing targets
/mob/living/proc/get_foe_from_turf(turf/T)
	if(!istype(T))
		return

	var/list/mob/living/foes = list()
	for(var/mob/living/foe_in_turf in T)
		if(foe_in_turf == src)
			continue

		var/foe_prio = rand(4, 8)
		if(foe_in_turf.mobility_flags & MOBILITY_STAND)
			foe_prio += 10
		else if(foe_in_turf.stat != CONSCIOUS)
			foe_prio = 2
		else if(foe_in_turf.surrendering)
			foe_prio = -5

		foes[foe_in_turf] = foe_prio

	if(!foes.len)
		return null

	if(foes.len > 1)
		sortTim(foes, cmp = /proc/cmp_numeric_dsc, associative = TRUE)
	return foes[1]

/datum/rmb_intent/proc/special_attack(mob/living/user, atom/target)
	return

/datum/rmb_intent/aimed
	name = "aimed"
	desc = "Your attacks are more precise but have a longer recovery time. Your precise attacks will critically hit more often, and your recovery is slightly faster depending on your perception. \n(SPECIAL) You can STAB through the gaps in heavy armor by aiming for a LIMB, the NECK, the GROIN or an EYE."
	icon_state = "rmbaimed"

/datum/rmb_intent/strong
	name = "strong"
	desc = "Your attacks always deal maximum damage, but use more stamina. Higher critrate with brutal attacks. Intentionally fails surgery steps. Costs slightly less stamina depending on your strength."
	icon_state = "rmbstrong"
	adjacency = FALSE
	prioritize_turfs = TRUE

/datum/rmb_intent/strong/special_attack(mob/living/user, atom/target)
	if(!user)
		return
	if(user.incapacitated())
		return
	if(!user.mind)
		return
	if(user.combat_cooldown_active("specialcd"))
		return

	user.face_atom(target)

	var/obj/item/rogueweapon/W = user.get_active_held_item()
	if(istype(W, /obj/item/rogueweapon) && W.special)
		var/skillreq = W.associated_skill
		if(W.special.custom_skill)
			skillreq = W.special.custom_skill
		if(user.get_skill_level(skillreq) < SKILL_LEVEL_JOURNEYMAN)
			to_chat(user, span_info("I'm not knowledgeable enough in the arts of this weapon to use this."))
			return
		if(W.special.check_range(user, target))
			if(W.special.apply_cost(user))
				W.special.deploy(user, W, target)

/datum/rmb_intent/swift
	name = "swift"
	desc = "Your attacks have less recovery time but are less accurate. Costs slightly less stamina depending on your speed."
	icon_state = "rmbswift"

/datum/rmb_intent/special
	name = "special"
	desc = "(RMB WHILE DEFENSE IS ACTIVE) A special attack that depends on the type of weapon you are using."
	icon_state = "rmbspecial"

/datum/rmb_intent/feint
	name = "feint"
	desc = "(RMB WHILE IN COMBAT MODE) A deceptive half-attack with no follow-through, meant to force your opponent to open their guard. Will fail on targets that are relaxed and less alert."
	icon_state = "rmbfeint"
	var/feintdur = 2 SECONDS

/mob/living/proc/attempt_feint(mob/living/user, atom/target)
	if(istype(src, /mob/living/carbon/human/species/skeleton))
		return
	if(!isliving(target))
		return
	if(!user)
		return
	if(user.incapacitated())
		return
	if(!user.mind)
		return
	if(user.combat_cooldown_active("feintcd"))
		return
	var/mob/living/L = target
	if (L.client && !L.cmode)
		playsound(user, 'sound/combat/feint.ogg', 100, TRUE)
		user.visible_message(span_danger("[user] attempts to feint an attack at [L], but only makes a fool of themselves!"))
		user.OffBalance(3 SECONDS)
		user.set_combat_cooldown("feintcd", 30 SECONDS, /atom/movable/screen/alert/status_effect/debuff/feintcd)
		for(var/mob/living/carbon/human/H in view(7, user))
			if(H == user || !H.client)
				continue
			if(HAS_TRAIT(H, TRAIT_XYLIX) && !H.has_status_effect(/datum/status_effect/buff/xylix_joy))
				H.apply_status_effect(/datum/status_effect/buff/xylix_joy)
				to_chat(H, span_info("Such a curt display of hubris amuses the Laughing God!"))
		return
	else
		user.visible_message(span_danger("[user] feints an attack at [target]!"))
	var/obj/item/I = user.get_active_held_item()
	var/user_feintmod = I?.associated_skill ? get_stat_roll(user.STAINT, user.get_skill_level(I.associated_skill), return_mod = TRUE) : get_stat_roll(user.STAINT, user.get_skill_level(/datum/skill/combat/unarmed), return_mod = TRUE)
	
	var/feintdur = 2 SECONDS + user_feintmod
	var/user_roll = get_stat_roll(user_feintmod)
	I = L.get_active_held_item()
	var/target_feintmod = I?.associated_skill ? get_stat_roll(L.STAINT, L.get_skill_level(I.associated_skill), return_mod = TRUE) : get_stat_roll(L.STAINT, L.get_skill_level(/datum/skill/combat/unarmed), return_mod = TRUE)
	var/target_roll = get_stat_roll(target_feintmod)
	var/autofail = FALSE

	var/special_msg
	var/newcd = 15 SECONDS + feintdur
	if(L.has_status_effect(/datum/status_effect/debuff/exposed))
		autofail = TRUE

	if(L.has_status_effect(/datum/status_effect/debuff/feinted))
		autofail = TRUE
		special_msg = span_warning("Too soon! They were expecting it!")

	if(!L.can_see_cone(user) && L.mind)
		autofail = TRUE
		special_msg = span_warning("They need to see me for me to feint them!")

	user.set_combat_cooldown("feintcd", newcd, /atom/movable/screen/alert/status_effect/debuff/feintcd)

	if(autofail)
		newcd = 10 SECONDS
		playsound(user, 'sound/combat/feint.ogg', 100, TRUE)
		user.set_combat_cooldown("feintcd", newcd, /atom/movable/screen/alert/status_effect/debuff/feintcd)
		if(special_msg)
			to_chat(user, special_msg)
		return

	if(L.has_status_effect(/datum/status_effect/buff/clash))
		L.remove_status_effect(/datum/status_effect/buff/clash)
		to_chat(user, span_notice("[L.p_they(TRUE)] drops [L.p_their()] guard!"))

	var/mob/living/loser = user_roll < target_roll ? user : L

	if(loser == user)
		if(user.client?.prefs.showrolls)
			var/modifier_diff = user_feintmod - target_feintmod
			var/perc = 47.5 + (modifier_diff * 2.5)  // Linear approximation
			perc = clamp(perc, 2.5, 97.5)
			to_chat(user, span_warning("[L.p_they(TRUE)] did not fall for my feint! [perc]%"))
	loser.apply_status_effect(/datum/status_effect/debuff/exposed, feintdur)
	loser.apply_click_cooldown(max(1.5 SECONDS + user_feintmod, 2.5 SECONDS))
	loser.Immobilize(feintdur)
	loser.stamina_add(L.stamina * 0.1)
	loser.Slowdown(2)
	user.set_combat_cooldown("feintcd", newcd, /atom/movable/screen/alert/status_effect/debuff/feintcd)
	if(loser == L)
		to_chat(user, span_notice("[L.p_they(TRUE)] fell for my feint attack!"))
		to_chat(L, span_danger("I fall for [user.p_their()] feint attack!"))
	else
		to_chat(user, span_notice("I failed my feint attacked and was thrown off guard!"))
		to_chat(L, span_danger("[user.p_they(TRUE)] failed to trick me with their feint and exposed their guard!"))
	playsound(user, 'sound/combat/riposte.ogg', 100, TRUE)

/datum/rmb_intent/feint/special_attack(mob/living/user, atom/target)
	user.attempt_feint(user, target)

/datum/rmb_intent/riposte
	name = "defend"
	desc = "Reduces the stamina cost of defensive maneuvers.\n(RMB WHILE NOT GRABBING ANYTHING AND HOLDING A WEAPON)\nEnter a defensive stance, guaranteeing the next hit is defended against.\nTwo people who hit each other with the Guard up will have their weapons Clash, potentially disarming them.\nLetting it expire or hitting someone with it who has no Guard up is tiresome."
	icon_state = "rmbdef"
	adjacency = FALSE

/mob/living/proc/attempt_riposte(mob/living/user, atom/target)
	// if our mage armor is active, using RMB defend on ourself causes us instead to feed energy & stamina based on the time left before it comes back up to instantly recharge it
	if (user == target && user.can_speak_vocal() && user.magearmor && HAS_TRAIT(user, TRAIT_MAGEARMOR))
		var/datum/status_effect/buff/magearmor/MA = user.has_status_effect(/datum/status_effect/buff/magearmor)
		if (!MA)
			return
		var/stamina_to_deduct = MA.remaining() / 100 // they're in deciseconds, remember. so 30 seconds = 30 stamina. also, athletics applies to this as well because stamina_add
		if ((user.stamina + stamina_to_deduct) < user.max_stamina)
			user.stamina_add(stamina_to_deduct)
			user.changeNext_move(CLICK_CD_MELEE)
			user.remove_status_effect(MA)
			var/recharge_state = user.get_mage_armor_descriptor()
			user.visible_message(span_warning("[user] [recharge_state] feeds power into their defensive wards, swiftly raising them!"), span_notice("I [recharge_state] feed a burst of mana into my defensive wards, recharging them instantly!"))
			playsound(user, 'sound/magic/ma-forcerecover.ogg', 75, FALSE)
			// this path renders us unable to clash, which is the tradeoff for magearmor anyway, so wig out from here.
			return

	if(!user.has_status_effect(/datum/status_effect/buff/clash) && !user.combat_cooldown_active("clashcd"))
		if(!user.get_active_held_item()) //Nothing in our hand to Guard with.
			return 
		if(user.r_grab || user.l_grab || length(user.grabbedby)) //Not usable while grabs are in play.
			return
		if(user.IsImmobilized() || user.IsOffBalanced()) //Not usable while we're offbalanced or immobilized
			return
		if(user.m_intent == MOVE_INTENT_RUN)
			to_chat(user, span_warning("I can't focus on this while running."))
			return
		if(user.magearmor == FALSE && HAS_TRAIT(user, TRAIT_MAGEARMOR))	//The magearmor is ACTIVE, so we can't Guard. (Yes, it's active while FALSE / 0.)
			to_chat(user, span_warning("I'm already focusing on my mage armor!"))
			return
		user.apply_status_effect(/datum/status_effect/buff/clash)

// returns a verb that describes our fatigue level in the mage armor force recharge
/mob/living/proc/get_mage_armor_descriptor()
	switch (stamina)
		if (0 to 10)
			return "effortlessly"
		if (11 to 30)
			return "easily"
		if (31 to 60)
			return "carefully"
		if (61 to 90)
			return "unsteadily"
		if (90 to INFINITY)
			return span_crit("<B>BARELY</B>")
	
	return "neutrally" // shouldn't see this

/datum/rmb_intent/riposte/special_attack(mob/living/user, atom/target)	//Wish we could breakline these somehow.
	user.attempt_riposte(user, target)

/datum/rmb_intent/guard
	name = "guarde"
	desc = "(RMB WHILE DEFENSE IS ACTIVE) Raise your weapon, ready to attack any creature who moves onto the space you are guarding."
	icon_state = "rmbguard"

/datum/rmb_intent/weak
	name = "weak"
	desc = "Your attacks always deal minimum damage and will never critically-hit. Useful for longer punishments, play-fighting, and bloodletting."
	icon_state = "rmbweak"

/datum/rmb_intent/omni
	name = "omni"
	desc = "Intelligently attempts to apply other RMB & MMB intent actives based on the situation. (RMB on yourself or the ground triggers DEFEND, RMB on an opponent attempts to bait (if possible), kick them if they're grappling you, kick them if they're off balance and feint (in this order) otherwise.)"
	icon_state = "rmbguard" // needs a new icon_state or something

/datum/rmb_intent/omni/special_attack(mob/living/user, atom/target)
	var/mob/living/carbon/human/HU = user
	if (isturf(target) || user == target)
		// RMB on turf or self: DEFEND.
		if (!HU.combat_cooldown_active("clashcd"))
			HU.attempt_riposte(user, target)
			HU.changeNext_move(0.5 SECONDS)
			return
	
	var/mob/living/carbon/human/HT
	if (ismob(target) && user != target)
		if (ishuman(target))
			HT = target

		// RMB on mob (priority 1): has something grappled us (passively), and can we kick? if so, attempt a kick.
		if (!HU.IsOffBalanced())
			var/mob/kick_target
			for(var/obj/item/grabbing/G in HU.grabbedby)
				if(G.grabbee && G.grab_state == GRAB_PASSIVE)
					kick_target = G.grabbee
					break
			if (kick_target)
				HU.try_kick(kick_target)
				HU.changeNext_move(0.5 SECONDS)
				return

		// RMB on mob (priority 2): is the target off-balance and not knocked over? if so, kick them over.
		if (HT && HT.IsOffBalanced() && (HT.mobility_flags & MOBILITY_STAND))
			HU.try_kick(target)
			HU.changeNext_move(0.5 SECONDS)
			return

		// RMB on mob (priority 3): attempt a feint if possible and off cooldown.
		if (!HU.combat_cooldown_active("feintcd"))
			HU.attempt_feint(user, target)
			HU.changeNext_move(0.5 SECONDS)
			return
