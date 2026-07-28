/datum/unit_test/drowning_native_fluid/Run()
	var/mob/living/carbon/human/H = allocate(/mob/living/carbon/human)

	var/turf/rb = run_loc_top_right.ChangeTurf(/turf/open/floor/rogue/riverbot, null, CHANGETURF_IGNORE_AIR)
	TEST_ASSERT_NOTNULL(rb.cell, "riverbot must have a liquid cell")
	TEST_ASSERT(rb.cell.fluidsum >= 80, "riverbot cell must be full")

	H.forceMove(rb)
	H.update_submersion()
	TEST_ASSERT_EQUAL(H.submersion_level, SUBMERSION_PARTIAL, "standing human on a full riverbot must read as partially submerged")

	H.setOxyLoss(0)
	H.holding_breath = FALSE
	H.breath_remaining = H.get_breath_max()
	var/pre_breath = H.breath_remaining
	H.check_drowning()
	H.handle_roguebreath()
	H.handle_choke_recovery()
	TEST_ASSERT_EQUAL(H.getOxyLoss(), 0, "standing (partial) submersion while not holding must not deal drowning damage")
	TEST_ASSERT_EQUAL(H.breath_remaining, pre_breath, "standing (partial) submersion while not holding must not drain breath")

	H.set_resting(TRUE)
	H.update_submersion()
	TEST_ASSERT_EQUAL(H.submersion_level, SUBMERSION_FULL, "prone human on a full riverbot must read as fully submerged")

	H.setOxyLoss(0)
	H.holding_breath = FALSE
	H.breath_remaining = H.get_breath_max()
	H.check_drowning()
	H.handle_roguebreath()
	H.handle_choke_recovery()
	TEST_ASSERT(H.getOxyLoss() > 0, "full submersion while not holding breath must drown immediately, even with fresh breath")

	H.setOxyLoss(0)
	H.holding_breath = TRUE
	H.breath_remaining = H.get_breath_max()
	pre_breath = H.breath_remaining
	H.check_drowning()
	H.handle_roguebreath()
	H.handle_choke_recovery()
	TEST_ASSERT(H.breath_remaining < pre_breath, "full submersion while holding breath with fresh breath must drain the breath pool")
	TEST_ASSERT_EQUAL(H.getOxyLoss(), 0, "full submersion while holding breath with breath remaining must not deal drowning damage")

	H.setOxyLoss(0)
	H.holding_breath = TRUE
	H.breath_remaining = BREATH_DRAIN_PER_TICK
	H.check_drowning()
	H.handle_roguebreath()
	H.handle_choke_recovery()
	TEST_ASSERT_EQUAL(H.holding_breath, FALSE, "breath hitting zero while holding must auto-release the hold")
	H.check_drowning()
	H.handle_roguebreath()
	H.handle_choke_recovery()
	TEST_ASSERT(H.getOxyLoss() > 0, "running out of held breath while still fully submerged must begin drowning damage within the following tick")

/datum/unit_test/drowning_lethality/Run()
	var/mob/living/carbon/human/H = allocate(/mob/living/carbon/human)

	var/turf/rb = run_loc_top_right.ChangeTurf(/turf/open/floor/rogue/riverbot, null, CHANGETURF_IGNORE_AIR)
	TEST_ASSERT(rb.cell?.fluidsum >= 80, "riverbot cell must be full")

	H.forceMove(rb)
	H.set_resting(TRUE)
	H.update_submersion()
	TEST_ASSERT_EQUAL(H.submersion_level, SUBMERSION_FULL, "prone human on a full riverbot must read as fully submerged")

	H.STACON = 10
	H.setOxyLoss(0)
	H.holding_breath = FALSE
	TEST_ASSERT_EQUAL(H.stat, CONSCIOUS, "drowning victim must start conscious")

	var/unconscious_at = 0
	var/dead_at = 0
	var/oxy_at_unconscious = 0
	var/oxy_after_unconscious = 0
	for(var/i in 1 to 100)
		H.check_drowning()
		H.handle_roguebreath()
		H.handle_choke_recovery()
		if(!unconscious_at && H.stat == UNCONSCIOUS)
			unconscious_at = i
			oxy_at_unconscious = H.getOxyLoss()
		if(unconscious_at && !oxy_after_unconscious && i == unconscious_at + 3)
			oxy_after_unconscious = H.getOxyLoss()
		if(H.stat == DEAD)
			dead_at = i
			break

	TEST_ASSERT(unconscious_at, "sustained drowning must render the victim unconscious (oxy=[H.getOxyLoss()] stat=[H.stat] after 100 ticks)")
	TEST_ASSERT(oxy_after_unconscious > oxy_at_unconscious, "an unconscious victim must keep drowning ([oxy_at_unconscious] -> [oxy_after_unconscious])")
	TEST_ASSERT(dead_at, "sustained drowning must eventually kill (oxy=[H.getOxyLoss()] health=[H.health] stat=[H.stat] after 100 ticks)")
	TEST_ASSERT(dead_at > unconscious_at, "death must come after unconsciousness (unconscious@[unconscious_at] dead@[dead_at])")

	var/ticks_con0 = ticks_to_unconscious(0)
	var/ticks_con10 = ticks_to_unconscious(10)
	var/ticks_con20 = ticks_to_unconscious(20)
	TEST_ASSERT(ticks_con0 && ticks_con10 && ticks_con20, "monotonicity check requires all three constitution levels to reach unconsciousness (con0=[ticks_con0] con10=[ticks_con10] con20=[ticks_con20])")
	TEST_ASSERT(ticks_con0 < ticks_con10, "lower constitution must drown to unconsciousness faster (con0=[ticks_con0] con10=[ticks_con10])")
	TEST_ASSERT(ticks_con10 < ticks_con20, "higher constitution must resist drowning longer (con10=[ticks_con10] con20=[ticks_con20])")

/datum/unit_test/drowning_lethality/proc/ticks_to_unconscious(con)
	var/mob/living/carbon/human/H = allocate(/mob/living/carbon/human)
	H.forceMove(run_loc_top_right)
	H.set_resting(TRUE)
	H.update_submersion()
	H.STACON = con
	H.setOxyLoss(0)
	H.holding_breath = FALSE
	for(var/i in 1 to 100)
		H.check_drowning()
		H.handle_roguebreath()
		H.handle_choke_recovery()
		if(H.stat == UNCONSCIOUS)
			return i
	return 0

/datum/unit_test/breath_scaling/Run()
	var/mob/living/carbon/human/H = allocate(/mob/living/carbon/human)
	H.STAEND = 10
	var/base_max = H.get_breath_max()

	H.adjust_skillrank(/datum/skill/misc/swimming, 6, TRUE)
	TEST_ASSERT(H.get_breath_max() > base_max, "training swimming must raise the breath ceiling (base=[base_max] trained=[H.get_breath_max()])")

	var/mob/living/carbon/human/H2 = allocate(/mob/living/carbon/human)
	H2.STAEND = 10
	var/base_max2 = H2.get_breath_max()
	H2.STAEND = 18
	TEST_ASSERT(H2.get_breath_max() > base_max2, "higher endurance must raise the breath ceiling (base=[base_max2] endurance18=[H2.get_breath_max()])")

	var/mob/living/carbon/human/H3 = allocate(/mob/living/carbon/human)
	H3.STAEND = -5
	TEST_ASSERT_EQUAL(H3.get_breath_max(), BREATH_FLOOR, "starved endurance and no swim skill must clamp to the breath floor")

/datum/unit_test/breath_regen/Run()
	var/mob/living/carbon/human/H = allocate(/mob/living/carbon/human)
	TEST_ASSERT_EQUAL(H.submersion_level, SUBMERSION_NONE, "a freshly allocated human must not start submerged")

	var/max_breath = H.get_breath_max()
	H.breath_remaining = max(0, max_breath - (BREATH_REGEN_PER_TICK * 2))
	var/pre = H.breath_remaining
	H.handle_roguebreath()
	TEST_ASSERT_EQUAL(H.breath_remaining, pre + BREATH_REGEN_PER_TICK, "breath must regenerate by BREATH_REGEN_PER_TICK per tick while not submerged or holding breath")

	H.breath_remaining = max_breath
	H.handle_roguebreath()
	TEST_ASSERT_EQUAL(H.breath_remaining, max_breath, "breath regeneration must not exceed the max")

	H.holding_breath = TRUE
	H.breath_remaining = max_breath
	H.setOxyLoss(0)
	pre = H.breath_remaining
	H.handle_roguebreath()
	TEST_ASSERT_EQUAL(H.breath_remaining, pre - BREATH_DRAIN_PER_TICK, "holding breath on dry land must drain by BREATH_DRAIN_PER_TICK per tick")
	TEST_ASSERT_EQUAL(H.getOxyLoss(), 0, "holding breath on dry land must never deal drowning damage")
	TEST_ASSERT_EQUAL(H.holding_breath, TRUE, "holding breath on dry land must remain held while breath remains")

	H.breath_remaining = BREATH_DRAIN_PER_TICK
	H.handle_roguebreath()
	TEST_ASSERT_EQUAL(H.holding_breath, FALSE, "breath hitting zero on dry land must auto-release the hold")
	TEST_ASSERT_EQUAL(H.getOxyLoss(), 0, "auto-releasing a held breath on dry land must never deal drowning damage")
