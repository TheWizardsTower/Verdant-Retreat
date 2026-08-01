// Burn Damage System Unit Tests
// Custom unit testing framework for burn damage mechanics

GLOBAL_LIST_INIT(admin_verbs_burn_tests, list(
	/client/proc/test_burn_wound_application,
	/client/proc/test_burn_wound_sewing,
	/client/proc/test_acid_wound_clotting,
	/client/proc/test_burn_limb_destruction,
	/client/proc/test_blunt_limb_explosion,
	/client/proc/test_burn_fluid_loss,
	/client/proc/test_fire_stacks,
	/client/proc/test_fire_extinguishing,
	/client/proc/test_burn_severity_names,
	/client/proc/test_critical_burn_replacement,
	/client/proc/test_all_burn_systems
))
GLOBAL_PROTECT(admin_verbs_burn_tests)

/// Helper proc to create a test human
/proc/create_test_human(turf/location)
	var/mob/living/carbon/human/species/human/northern/H = new(location)
	return H

/// Helper proc to get test results string
/proc/format_test_result(test_name, passed, details = "")
	var/result = passed ? "<span class='green'>PASS</span>" : "<span class='red'>FAIL</span>"
	var/msg = "[result] - [test_name]"
	if(details)
		msg += " ([details])"
	return msg

/client/proc/test_burn_wound_application()
	set category = "Debug"
	set name = "Test: Burn Wound Application"

	if(!check_rights(R_DEBUG))
		return

	to_chat(src, "<span class='boldnotice'>===== BURN WOUND APPLICATION TEST =====</span>")

	var/turf/test_loc = get_turf(mob)
	var/mob/living/carbon/human/H = create_test_human(test_loc)
	var/obj/item/bodypart/r_arm = H.get_bodypart(BODY_ZONE_R_ARM)

	var/tests_passed = 0
	var/tests_total = 0

	// Test 1: Thermal burn wound application
	tests_total++
	r_arm.receive_damage(0, 20)
	var/datum/wound/thermal_wound = r_arm.has_wound(/datum/wound/dynamic/burn)
	if(thermal_wound)
		to_chat(src, format_test_result("Thermal burn wound created", TRUE, "whp=[thermal_wound.whp]"))
		tests_passed++
	else
		to_chat(src, format_test_result("Thermal burn wound created", FALSE, "No wound found"))

	// Test 2: Frostbite wound application
	tests_total++
	var/obj/item/bodypart/l_arm = H.get_bodypart(BODY_ZONE_L_ARM)
	l_arm.receive_damage(0, 15, bclass = BCLASS_FROST)
	var/datum/wound/frost_wound = l_arm.has_wound(/datum/wound/dynamic/burn)
	if(frost_wound)
		to_chat(src, format_test_result("Frost burn wound created", TRUE, "whp=[frost_wound.whp]"))
		tests_passed++
	else
		to_chat(src, format_test_result("Frost burn wound created", FALSE, "No wound found"))

	// Test 3: Electrical burn wound application
	tests_total++
	var/obj/item/bodypart/r_leg = H.get_bodypart(BODY_ZONE_R_LEG)
	r_leg.receive_damage(0, 18, bclass = BCLASS_ELECTRICAL)
	var/datum/wound/electrical_wound = r_leg.has_wound(/datum/wound/dynamic/burn)
	if(electrical_wound)
		to_chat(src, format_test_result("Electrical burn wound created", TRUE, "whp=[electrical_wound.whp]"))
		tests_passed++
	else
		to_chat(src, format_test_result("Electrical burn wound created", FALSE, "No wound found"))

	// Test 4: Acid burn wound application
	tests_total++
	var/obj/item/bodypart/l_leg = H.get_bodypart(BODY_ZONE_L_LEG)
	l_leg.receive_damage(0, 22, bclass = BCLASS_ACID)
	var/datum/wound/acid_wound = l_leg.has_wound(/datum/wound/dynamic/burn)
	if(acid_wound)
		to_chat(src, format_test_result("Acid burn wound created", TRUE, "whp=[acid_wound.whp], bleed=[acid_wound.bleed_rate]"))
		tests_passed++
	else
		to_chat(src, format_test_result("Acid burn wound created", FALSE, "No wound found"))

	// Test 5: Burn wound upgrade
	tests_total++
	var/initial_whp = thermal_wound.whp
	r_arm.receive_damage(0, 15)
	if(thermal_wound.whp > initial_whp)
		to_chat(src, format_test_result("Burn wound upgrades", TRUE, "whp: [initial_whp] -> [thermal_wound.whp]"))
		tests_passed++
	else
		to_chat(src, format_test_result("Burn wound upgrades", FALSE, "whp stayed at [thermal_wound.whp]"))

	to_chat(src, "<span class='boldnotice'>===== RESULTS: [tests_passed]/[tests_total] PASSED =====</span>")
	qdel(H)

/client/proc/test_burn_wound_sewing()
	set category = "Debug"
	set name = "Test: Burn Wound Sewing"

	if(!check_rights(R_DEBUG))
		return

	to_chat(src, "<span class='boldnotice'>===== BURN WOUND SEWING TEST =====</span>")

	var/turf/test_loc = get_turf(mob)
	var/mob/living/carbon/human/H = create_test_human(test_loc)
	var/obj/item/bodypart/r_arm = H.get_bodypart(BODY_ZONE_R_ARM)

	var/tests_passed = 0
	var/tests_total = 0

	// Test 1: Thermal burns can be sewn
	tests_total++
	r_arm.receive_damage(0, 25)
	var/datum/wound/thermal_wound = r_arm.has_wound(/datum/wound/dynamic/burn)
	if(thermal_wound && thermal_wound.can_sew)
		to_chat(src, format_test_result("Thermal burns are sewable", TRUE, "can_sew=[thermal_wound.can_sew]"))
		tests_passed++
	else
		to_chat(src, format_test_result("Thermal burns are sewable", FALSE))

	// Test 2: Sewing stops bleeding
	tests_total++
	var/initial_bleed = thermal_wound.bleed_rate
	thermal_wound.sew_wound()
	if(thermal_wound.bleed_rate <= 0.01)
		to_chat(src, format_test_result("Sewing stops bleeding", TRUE, "bleed: [initial_bleed] -> [thermal_wound.bleed_rate]"))
		tests_passed++
	else
		to_chat(src, format_test_result("Sewing stops bleeding", FALSE, "bleed: [initial_bleed] -> [thermal_wound.bleed_rate]"))

	// Test 3: Sewing doesn't heal the wound
	tests_total++
	var/whp_after_sew = thermal_wound ? thermal_wound.whp : 0
	if(whp_after_sew > 0)
		to_chat(src, format_test_result("Sewing doesn't heal wound", TRUE, "whp still [whp_after_sew]"))
		tests_passed++
	else
		to_chat(src, format_test_result("Sewing doesn't heal wound", FALSE, "whp is 0"))

	// Test 4: All burn types create same dynamic burn wound
	tests_total++
	var/obj/item/bodypart/head = H.get_bodypart(BODY_ZONE_HEAD)
	var/obj/item/bodypart/chest = H.get_bodypart(BODY_ZONE_CHEST)
	var/obj/item/bodypart/r_leg = H.get_bodypart(BODY_ZONE_R_LEG)
	var/obj/item/bodypart/l_arm = H.get_bodypart(BODY_ZONE_L_ARM)
	head.receive_damage(0, 10, bclass = BCLASS_BURN)
	var/datum/wound/regular_burn = head.has_wound(/datum/wound/dynamic/burn)
	chest.receive_damage(0, 10, bclass = BCLASS_FROST)
	var/datum/wound/frost_wound = chest.has_wound(/datum/wound/dynamic/burn)
	r_leg.receive_damage(0, 10, bclass = BCLASS_ACID)
	var/datum/wound/acid_wound = r_leg.has_wound(/datum/wound/dynamic/burn/)
	l_arm.receive_damage(0, 10, bclass = BCLASS_ELECTRICAL)
	var/datum/wound/electrical_wound = l_arm.has_wound(/datum/wound/dynamic/burn)

	if(regular_burn && frost_wound && electrical_wound && acid_wound)
		to_chat(src, format_test_result("All burn types create dynamic/burn", TRUE, "All wounds are dynamic/burn type"))
		tests_passed++
	else
		to_chat(src, format_test_result("All burn types create dynamic/burn", FALSE))

	to_chat(src, "<span class='boldnotice'>===== RESULTS: [tests_passed]/[tests_total] PASSED =====</span>")
	qdel(H)

/client/proc/test_acid_wound_clotting()
	set category = "Debug"
	set name = "Test: Acid Wound Clotting"

	if(!check_rights(R_DEBUG))
		return

	to_chat(src, "<span class='boldnotice'>===== ACID WOUND CLOTTING TEST =====</span>")

	var/turf/test_loc = get_turf(mob)
	var/mob/living/carbon/human/H = create_test_human(test_loc)
	var/obj/item/bodypart/r_arm = H.get_bodypart(BODY_ZONE_R_ARM)

	var/tests_passed = 0
	var/tests_total = 0

	// Test 1: Critical burn wounds stop bleeding when sewn
	tests_total++
	r_arm.receive_damage(0, 80)
	var/datum/wound/burn_wound = r_arm.has_wound(/datum/wound/dynamic/burn)
	var/bleed_before_sew = burn_wound.bleed_rate
	burn_wound.sew_wound()
	if(burn_wound && burn_wound.is_sewn() && burn_wound.bleed_rate <= 0.01 && bleed_before_sew > 0)
		to_chat(src, format_test_result("Sewn critical burns stop bleeding", TRUE, "bleed: [bleed_before_sew] -> [burn_wound.bleed_rate]"))
		tests_passed++
	else
		to_chat(src, format_test_result("Sewn critical burns stop bleeding", FALSE, "before=[bleed_before_sew], after=[burn_wound?.bleed_rate]"))

	// Test 2: Only critical burns bleed (whp >= 70)
	tests_total++
	var/obj/item/bodypart/l_leg = H.get_bodypart(BODY_ZONE_L_LEG)
	l_leg.receive_damage(0, 50)
	var/datum/wound/moderate_burn = l_leg.has_wound(/datum/wound/dynamic/burn)
	if(moderate_burn && moderate_burn.whp < 70 && moderate_burn.bleed_rate == 0)
		to_chat(src, format_test_result("Non-critical burns don't bleed", TRUE, "whp=[moderate_burn.whp], bleed=[moderate_burn.bleed_rate]"))
		tests_passed++
	else
		to_chat(src, format_test_result("Non-critical burns don't bleed", FALSE, "whp=[moderate_burn?.whp], bleed=[moderate_burn?.bleed_rate]"))

	// Test 3: Critical acid wounds cannot be sewn
	tests_total++
	var/datum/wound/acid_crit = new /datum/wound/burn/acid()
	if(acid_crit && !acid_crit.can_sew)
		to_chat(src, format_test_result("Severe acid wounds cannot be sewn", TRUE, "can_sew=[acid_crit.can_sew]"))
		tests_passed++
	else
		to_chat(src, format_test_result("Severe acid wounds cannot be sewn", FALSE))
	qdel(acid_crit)

	// Test 4: Thermal burns don't clot naturally (or very slowly) (or very slowly)
	tests_total++
	var/obj/item/bodypart/r_leg = H.get_bodypart(BODY_ZONE_R_LEG)
	r_leg.receive_damage(0, 25)
	var/datum/wound/thermal_wound = r_leg.has_wound(/datum/wound/dynamic/burn)
	if(thermal_wound && thermal_wound.clotting_rate <= 0.01)
		to_chat(src, format_test_result("Thermal burns have minimal clotting", TRUE, "rate=[thermal_wound.clotting_rate]"))
		tests_passed++
	else
		to_chat(src, format_test_result("Thermal burns have minimal clotting", FALSE, "rate=[thermal_wound?.clotting_rate]"))

	to_chat(src, "<span class='boldnotice'>===== RESULTS: [tests_passed]/[tests_total] PASSED =====</span>")
	qdel(H)

/client/proc/test_burn_limb_destruction()
	set category = "Debug"
	set name = "Test: Burn Limb Destruction"

	if(!check_rights(R_DEBUG))
		return

	to_chat(src, "<span class='boldnotice'>===== BURN LIMB DESTRUCTION TEST =====</span>")

	var/turf/test_loc = get_turf(mob)
	var/mob/living/carbon/human/H = create_test_human(test_loc)
	var/obj/item/bodypart/r_arm = H.get_bodypart(BODY_ZONE_R_ARM)

	var/tests_passed = 0
	var/tests_total = 0

	// Test 1: Limb survives below max damage
	tests_total++
	r_arm.receive_damage(0, r_arm.max_damage - 5)
	var/obj/item/bodypart/check_arm = H.get_bodypart(BODY_ZONE_R_ARM)
	if(check_arm)
		to_chat(src, format_test_result("Limb survives below max damage", TRUE, "burn=[r_arm.burn_dam]/[r_arm.max_damage]"))
		tests_passed++
	else
		to_chat(src, format_test_result("Limb survives below max damage", FALSE, "Limb destroyed prematurely"))

	// Test 2: Limb destroyed at max burn damage
	tests_total++
	r_arm.receive_damage(0, 10) // Push over max_damage
	check_arm = H.get_bodypart(BODY_ZONE_R_ARM)
	if(!check_arm)
		to_chat(src, format_test_result("Limb destroyed at max burn damage", TRUE))
		tests_passed++
	else
		to_chat(src, format_test_result("Limb destroyed at max burn damage", FALSE, "Limb still attached"))

	// Test 3: Different burn types destroy limbs
	tests_total++
	var/obj/item/bodypart/l_arm = H.get_bodypart(BODY_ZONE_L_ARM)
	if(l_arm)
		l_arm.receive_damage(0, l_arm.max_damage + 5, bclass = BCLASS_FROST)
		var/obj/item/bodypart/check_l_arm = H.get_bodypart(BODY_ZONE_L_ARM)
		if(!check_l_arm)
			to_chat(src, format_test_result("Frostbite destroys limbs", TRUE))
			tests_passed++
		else
			to_chat(src, format_test_result("Frostbite destroys limbs", FALSE, "burn_dam=[l_arm.burn_dam]/[l_arm.max_damage]"))
	else
		tests_total--

	to_chat(src, "<span class='boldnotice'>===== RESULTS: [tests_passed]/[tests_total] PASSED =====</span>")
	qdel(H)

/client/proc/test_blunt_limb_explosion()
	set category = "Debug"
	set name = "Test: Blunt Limb Explosion"

	if(!check_rights(R_DEBUG))
		return

	to_chat(src, "<span class='boldnotice'>===== BLUNT LIMB EXPLOSION TEST =====</span>")

	var/turf/test_loc = get_turf(mob)
	var/mob/living/carbon/human/H = create_test_human(test_loc)
	var/obj/item/bodypart/r_arm = H.get_bodypart(BODY_ZONE_R_ARM)

	var/tests_passed = 0
	var/tests_total = 0

	// Test 1: Limb survives blunt damage below max
	tests_total++
	r_arm.receive_damage(r_arm.max_damage - 5, 0)
	r_arm.bodypart_attacked_by(BCLASS_BLUNT, 3, null, BODY_ZONE_R_ARM, FALSE, FALSE, 0, FALSE, 3, 0)
	var/obj/item/bodypart/check_arm = H.get_bodypart(BODY_ZONE_R_ARM)
	if(check_arm)
		to_chat(src, format_test_result("Limb survives below max brute", TRUE, "brute=[r_arm.brute_dam]/[r_arm.max_damage]"))
		tests_passed++
	else
		to_chat(src, format_test_result("Limb survives below max brute", FALSE))

	// Test 2: Blunt weapon explodes limb at max damage
	tests_total++
	r_arm.receive_damage(10, 0) // Push to max
	r_arm.bodypart_attacked_by(BCLASS_BLUNT, 5, null, BODY_ZONE_R_ARM, FALSE, FALSE, 0, FALSE, 5, 0)
	check_arm = H.get_bodypart(BODY_ZONE_R_ARM)
	if(!check_arm)
		to_chat(src, format_test_result("Blunt weapon explodes limb at max", TRUE))
		tests_passed++
	else
		to_chat(src, format_test_result("Blunt weapon explodes limb at max", FALSE, "Limb still attached"))

	// Test 3: BCLASS_SMASH also explodes limbs
	tests_total++
	var/obj/item/bodypart/l_arm = H.get_bodypart(BODY_ZONE_L_ARM)
	l_arm.receive_damage(l_arm.max_damage, 0)
	l_arm.bodypart_attacked_by(BCLASS_SMASH, 5, null, BODY_ZONE_L_ARM, FALSE, FALSE, 0, FALSE, 5, 0)
	var/obj/item/bodypart/check_l_arm = H.get_bodypart(BODY_ZONE_L_ARM)
	if(!check_l_arm)
		to_chat(src, format_test_result("BCLASS_SMASH explodes limbs", TRUE))
		tests_passed++
	else
		to_chat(src, format_test_result("BCLASS_SMASH explodes limbs", FALSE))

	// Test 4: Cut weapons don't explode limbs
	tests_total++
	var/obj/item/bodypart/r_leg = H.get_bodypart(BODY_ZONE_R_LEG)
	r_leg.receive_damage(r_leg.max_damage, 0)
	r_leg.bodypart_attacked_by(BCLASS_CUT, 5, null, BODY_ZONE_R_LEG, FALSE, FALSE, 0, FALSE, 5, 0)
	var/obj/item/bodypart/check_r_leg = H.get_bodypart(BODY_ZONE_R_LEG)
	if(check_r_leg)
		to_chat(src, format_test_result("Cut weapons don't explode limbs", TRUE))
		tests_passed++
	else
		to_chat(src, format_test_result("Cut weapons don't explode limbs", FALSE, "Limb exploded incorrectly"))

	to_chat(src, "<span class='boldnotice'>===== RESULTS: [tests_passed]/[tests_total] PASSED =====</span>")
	qdel(H)

/client/proc/test_burn_fluid_loss()
	set category = "Debug"
	set name = "Test: Burn Fluid Loss"

	if(!check_rights(R_DEBUG))
		return

	to_chat(src, "<span class='boldnotice'>===== BURN FLUID LOSS TEST =====</span>")

	var/turf/test_loc = get_turf(mob)
	var/mob/living/carbon/human/H = create_test_human(test_loc)
	var/obj/item/bodypart/r_arm = H.get_bodypart(BODY_ZONE_R_ARM)

	var/tests_passed = 0
	var/tests_total = 0

	// Test 1: Minor burn wounds DON'T bleed
	tests_total++
	r_arm.receive_damage(0, 15)
	var/datum/wound/burn_wound = r_arm.has_wound(/datum/wound/dynamic/burn)
	if(burn_wound && burn_wound.bleed_rate == 0)
		to_chat(src, format_test_result("Minor burns don't bleed", TRUE, "bleed_rate=[burn_wound.bleed_rate], whp=[burn_wound.whp]"))
		tests_passed++
	else
		to_chat(src, format_test_result("Minor burns don't bleed", FALSE, "bleed_rate=[burn_wound?.bleed_rate]"))

	// Test 2: Critical burns (whp >= 70) DO bleed
	tests_total++
	r_arm.receive_damage(0, 60)
	if(burn_wound.whp >= 70 && burn_wound.bleed_rate > 0)
		to_chat(src, format_test_result("Critical burns bleed", TRUE, "whp=[burn_wound.whp], bleed_rate=[burn_wound.bleed_rate]"))
		tests_passed++
	else
		to_chat(src, format_test_result("Critical burns bleed", FALSE, "whp=[burn_wound.whp], bleed=[burn_wound.bleed_rate]"))

	// Test 3: Charred wounds have high fluid loss
	tests_total++
	var/obj/item/bodypart/chest = H.get_bodypart(BODY_ZONE_CHEST)
	chest.add_wound(/datum/wound/burn/charred)
	var/datum/wound/charred = chest.has_wound(/datum/wound/burn/charred)
	if(charred && charred.bleed_rate >= 0.6)
		to_chat(src, format_test_result("Charred wounds have severe fluid loss", TRUE, "bleed_rate=[charred.bleed_rate]"))
		tests_passed++
	else
		to_chat(src, format_test_result("Charred wounds have severe fluid loss", FALSE, "bleed_rate=[charred?.bleed_rate]"))

	// Test 4: Fluid loss uses existing bleed cache
	tests_total++
	H.recalculate_bleed_cache()
	var/cached_rate = H.cached_normal_bleed + H.cached_critical_bleed
	if(cached_rate > 0)
		to_chat(src, format_test_result("Fluid loss uses bleed cache", TRUE, "cached_bleed_rate=[cached_rate]"))
		tests_passed++
	else
		to_chat(src, format_test_result("Fluid loss uses bleed cache", FALSE))

	to_chat(src, "<span class='boldnotice'>===== RESULTS: [tests_passed]/[tests_total] PASSED =====</span>")
	qdel(H)

/client/proc/test_fire_stacks()
	set category = "Debug"
	set name = "Test: Fire Stacks"

	if(!check_rights(R_DEBUG))
		return

	to_chat(src, "<span class='boldnotice'>===== FIRE STACKS TEST =====</span>")

	var/turf/test_loc = get_turf(mob)
	var/mob/living/carbon/human/H = create_test_human(test_loc)

	var/tests_passed = 0
	var/tests_total = 0

	// Test 1: Fire stacks create burn wounds
	tests_total++
	H.adjust_fire_stacks(5)
	var/datum/status_effect/fire_handler/fire_stacks/fire_effect = H.get_status_effect_exact(/datum/status_effect/fire_handler/fire_stacks)
	if(fire_effect)
		fire_effect.ignite()
		sleep(30)
		var/has_burn = FALSE
		for(var/obj/item/bodypart/BP in H.bodyparts)
			if(BP.has_wound(/datum/wound/dynamic/burn))
				has_burn = TRUE
				break
		if(has_burn)
			to_chat(src, format_test_result("Fire stacks create burn wounds", TRUE))
			tests_passed++
		else
			to_chat(src, format_test_result("Fire stacks create burn wounds", FALSE, "No burns found"))
	else
		to_chat(src, format_test_result("Fire stacks create burn wounds", FALSE, "Fire effect not applied"))

	// Test 2: Fire stacks upgrade existing burns
	tests_total++
	var/obj/item/bodypart/r_arm = H.get_bodypart(BODY_ZONE_R_ARM)
	if(r_arm)
		var/datum/wound/burn_wound = r_arm.has_wound(/datum/wound/dynamic/burn)
		if(burn_wound)
			var/initial_whp = burn_wound.whp
			sleep(30)
			if(burn_wound.whp > initial_whp)
				to_chat(src, format_test_result("Fire upgrades existing burns", TRUE, "whp: [initial_whp] -> [burn_wound.whp]"))
				tests_passed++
			else
				to_chat(src, format_test_result("Fire upgrades existing burns", FALSE, "whp stayed at [burn_wound.whp]"))
		else
			to_chat(src, format_test_result("Fire upgrades existing burns", FALSE, "No burn found"))
	else
		tests_total--

	// Test 3: Fire damage is balanced (reduced from old values)
	tests_total++
	H.adjust_fire_stacks(5)
	var/initial_burn = H.getFireLoss()
	sleep(30)
	var/burn_increase = H.getFireLoss() - initial_burn
	if(burn_increase < 15)
		to_chat(src, format_test_result("Fire damage is balanced", TRUE, "damage over 3s: [burn_increase]"))
		tests_passed++
	else
		to_chat(src, format_test_result("Fire damage is balanced", FALSE, "Too much damage: [burn_increase]"))

	to_chat(src, "<span class='boldnotice'>===== RESULTS: [tests_passed]/[tests_total] PASSED =====</span>")
	qdel(H)

/client/proc/test_fire_extinguishing()
	set category = "Debug"
	set name = "Test: Fire Extinguishing"

	if(!check_rights(R_DEBUG))
		return

	to_chat(src, "<span class='boldnotice'>===== FIRE EXTINGUISHING TEST =====</span>")

	var/turf/test_loc = get_turf(mob)
	var/mob/living/carbon/human/H = create_test_human(test_loc)

	var/tests_passed = 0
	var/tests_total = 0

	// Test 1: Water turf extinguishes fire
	tests_total++
	H.adjust_fire_stacks(5)
	var/datum/status_effect/fire_handler/fire_stacks/fire_effect = H.get_status_effect_exact(/datum/status_effect/fire_handler/fire_stacks)
	if(fire_effect)
		fire_effect.ignite()
		var/turf/open/water/W = new(test_loc)
		W.Entered(H, test_loc)
		if(H.fire_stacks <= 0 && !fire_effect.on_fire)
			to_chat(src, format_test_result("Water turf extinguishes fire", TRUE))
			tests_passed++
		else
			to_chat(src, format_test_result("Water turf extinguishes fire", FALSE, "fire_stacks=[H.fire_stacks], on_fire=[fire_effect.on_fire]"))
		qdel(W)
	else
		to_chat(src, format_test_result("Water turf extinguishes fire", FALSE, "Fire effect not applied"))

	// Test 2: Water reagent (15u+) extinguishes fire
	tests_total++
	H.adjust_fire_stacks(5)
	fire_effect = H.get_status_effect_exact(/datum/status_effect/fire_handler/fire_stacks)
	if(fire_effect)
		fire_effect.ignite()
		var/datum/reagent/water/water_reagent = new()
		water_reagent.reaction_mob(H, TOUCH, 15)
		if(H.fire_stacks <= 0 && !fire_effect.on_fire)
			to_chat(src, format_test_result("Water reagent (15u) extinguishes fire", TRUE))
			tests_passed++
		else
			to_chat(src, format_test_result("Water reagent (15u) extinguishes fire", FALSE, "fire_stacks=[H.fire_stacks]"))
	else
		to_chat(src, format_test_result("Water reagent (15u) extinguishes fire", FALSE, "Fire effect not applied"))

	// Test 3: Less than 15u water doesn't extinguish
	tests_total++
	H.adjust_fire_stacks(5)
	fire_effect = H.get_status_effect_exact(/datum/status_effect/fire_handler/fire_stacks)
	if(fire_effect)
		fire_effect.ignite()
		var/datum/reagent/water/water_reagent = new()
		water_reagent.reaction_mob(H, TOUCH, 10)
		if(H.fire_stacks > 0 || fire_effect.on_fire)
			to_chat(src, format_test_result("Less than 15u doesn't extinguish", TRUE, "fire_stacks=[H.fire_stacks]"))
			tests_passed++
		else
			to_chat(src, format_test_result("Less than 15u doesn't extinguish", FALSE, "Fire was extinguished"))
	else
		to_chat(src, format_test_result("Less than 15u doesn't extinguish", FALSE, "Fire effect not applied"))

	to_chat(src, "<span class='boldnotice'>===== RESULTS: [tests_passed]/[tests_total] PASSED =====</span>")
	qdel(H)

/client/proc/test_burn_severity_names()
	set category = "Debug"
	set name = "Test: Burn Severity Names"

	if(!check_rights(R_DEBUG))
		return

	to_chat(src, "<span class='boldnotice'>===== BURN SEVERITY NAMES TEST =====</span>")

	var/turf/test_loc = get_turf(mob)
	var/mob/living/carbon/human/H = create_test_human(test_loc)
	var/obj/item/bodypart/r_arm = H.get_bodypart(BODY_ZONE_R_ARM)

	var/tests_passed = 0
	var/tests_total = 0

	// Test 1: Minor burn (whp 15-29)
	tests_total++
	r_arm.receive_damage(0, 15)
	var/datum/wound/burn_wound = r_arm.has_wound(/datum/wound/dynamic/burn)
	if(burn_wound && findtext(burn_wound.name, "minor"))
		to_chat(src, format_test_result("Minor burn naming", TRUE, "name='[burn_wound.name]', whp=[burn_wound.whp]"))
		tests_passed++
	else
		to_chat(src, format_test_result("Minor burn naming", FALSE, "name='[burn_wound?.name]'"))

	// Test 2: Moderate burn (whp 30-49)
	tests_total++
	r_arm.receive_damage(0, 20)
	if(burn_wound && findtext(burn_wound.name, "moderate"))
		to_chat(src, format_test_result("Moderate burn naming", TRUE, "name='[burn_wound.name]', whp=[burn_wound.whp]"))
		tests_passed++
	else
		to_chat(src, format_test_result("Moderate burn naming", FALSE, "name='[burn_wound?.name]', whp=[burn_wound?.whp]"))

	// Test 3: Severe burn (whp 50-69)
	tests_total++
	r_arm.receive_damage(0, 25)
	if(burn_wound && findtext(burn_wound.name, "severe"))
		to_chat(src, format_test_result("Severe burn naming", TRUE, "name='[burn_wound.name]', whp=[burn_wound.whp]"))
		tests_passed++
	else
		to_chat(src, format_test_result("Severe burn naming", FALSE, "name='[burn_wound?.name]', whp=[burn_wound?.whp]"))

	// Test 4: Critical burn (whp >= 70)
	tests_total++
	r_arm.receive_damage(0, 30)
	if(burn_wound && findtext(burn_wound.name, "critical"))
		to_chat(src, format_test_result("Critical burn naming", TRUE, "name='[burn_wound.name]', whp=[burn_wound.whp]"))
		tests_passed++
	else
		to_chat(src, format_test_result("Critical burn naming", FALSE, "name='[burn_wound?.name]', whp=[burn_wound?.whp]"))

	to_chat(src, "<span class='boldnotice'>===== RESULTS: [tests_passed]/[tests_total] PASSED =====</span>")
	qdel(H)

/client/proc/test_critical_burn_replacement()
	set category = "Debug"
	set name = "Test: Critical Burn Replacement"

	if(!check_rights(R_DEBUG))
		return

	to_chat(src, "<span class='boldnotice'>===== CRITICAL BURN REPLACEMENT TEST =====</span>")

	var/turf/test_loc = get_turf(mob)
	var/mob/living/carbon/human/H = create_test_human(test_loc)
	var/obj/item/bodypart/r_arm = H.get_bodypart(BODY_ZONE_R_ARM)

	var/tests_passed = 0
	var/tests_total = 0

	// Test 1: Less severe critical wound can be replaced by more severe
	tests_total++
	var/datum/wound/burn/frostbite/frost = new()
	frost.whp = 40
	r_arm.wounds += frost
	frost.on_mob_gain(H, 0)
	var/datum/wound/burn/electrical/elec = new()
	elec.whp = 50
	if(elec.can_stack_with(frost))
		to_chat(src, format_test_result("Less severe crit can be replaced", TRUE, "frost(40) < elec(50)"))
		tests_passed++
	else
		to_chat(src, format_test_result("Less severe crit can be replaced", FALSE))

	// Test 2: More severe wound replaces less severe via worsen_wound
	tests_total++
	var/initial_whp = frost.whp
	if(frost.can_stack_with(elec) == FALSE)
		if(frost.whp >= 50)
			to_chat(src, format_test_result("Wound replacement calls worsen", TRUE, "whp: [initial_whp] -> [frost.whp]"))
			tests_passed++
		else
			to_chat(src, format_test_result("Wound replacement calls worsen", FALSE, "whp only [frost.whp]"))
	else
		tests_total--

	// Test 3: Same severity doesn't replace
	tests_total++
	var/datum/wound/burn/frostbite/frost2 = new()
	frost2.whp = frost.whp
	if(!frost.can_stack_with(frost2))
		to_chat(src, format_test_result("Same severity prevents stacking", TRUE))
		tests_passed++
	else
		to_chat(src, format_test_result("Same severity prevents stacking", FALSE))

	to_chat(src, "<span class='boldnotice'>===== RESULTS: [tests_passed]/[tests_total] PASSED =====</span>")
	qdel(H)

/client/proc/test_all_burn_systems()
	set category = "Debug"
	set name = "Test: All Burn Systems"

	if(!check_rights(R_DEBUG))
		return

	to_chat(src, "<span class='boldnotice'>========== RUNNING ALL BURN TESTS ==========</span>")

	test_burn_wound_application()
	sleep(10)
	test_burn_wound_sewing()
	sleep(10)
	test_acid_wound_clotting()
	sleep(10)
	test_burn_limb_destruction()
	sleep(10)
	test_blunt_limb_explosion()
	sleep(10)
	test_burn_fluid_loss()
	sleep(10)
	test_fire_stacks()
	sleep(10)
	test_fire_extinguishing()
	sleep(10)
	test_burn_severity_names()
	sleep(10)
	test_critical_burn_replacement()

	to_chat(src, "<span class='boldnotice'>========== ALL BURN TESTS COMPLETE ==========</span>")
