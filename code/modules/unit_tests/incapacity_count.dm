/mob/living/simple_animal/incap_test_dummy
	name = "incapacity test dummy"
	icon_state = "chicken"
	density = FALSE
	wander = 0
	stop_automated_movement = 1

/datum/unit_test/incapacity_count

/// The invariant that matters: the maintained count always equals a live scan,
/// and incapacitated() agrees with it. Effects are applied directly because
/// Stun()/Paralyze() gate on CANSTUN and no-op on many mob types.
/datum/unit_test/incapacity_count/proc/expect(mob/living/M, expected, context)
	var/actual = 0
	for(var/datum/status_effect/E as anything in M.status_effects)
		if(istype(E, STATUS_EFFECT_UNCONSCIOUS) || istype(E, STATUS_EFFECT_STUN) || istype(E, STATUS_EFFECT_PARALYZED))
			actual++
	if(M.incapacity_count != actual)
		TEST_FAIL("[context]: incapacity_count is [M.incapacity_count] but a live scan says [actual]")
	if(actual != expected)
		TEST_FAIL("[context]: live scan says [actual] incapacitating effects, expected [expected]")
	var/incap = M.incapacitated(ignore_restraints = 1) ? TRUE : FALSE
	var/expected_incap = (M.stat || actual) ? TRUE : FALSE
	if(incap != expected_incap)
		TEST_FAIL("[context]: incapacitated() returned [incap], expected [expected_incap]")

/datum/unit_test/incapacity_count/Run()
	var/mob/living/simple_animal/incap_test_dummy/D = allocate(/mob/living/simple_animal/incap_test_dummy)
	if(!D)
		TEST_FAIL("could not allocate the test dummy")
		return

	expect(D, 0, "fresh mob")

	D.apply_status_effect(STATUS_EFFECT_STUN, 10 SECONDS)
	expect(D, 1, "after applying stun")

	D.apply_status_effect(STATUS_EFFECT_PARALYZED, 10 SECONDS)
	expect(D, 2, "after applying stun + paralyze")

	D.remove_status_effect(STATUS_EFFECT_STUN)
	expect(D, 1, "after removing stun")

	D.remove_status_effect(STATUS_EFFECT_PARALYZED)
	expect(D, 0, "after removing paralyze")

	// knockdown shares the /incapacitating parent but must NOT count
	D.apply_status_effect(STATUS_EFFECT_KNOCKDOWN, 10 SECONDS)
	expect(D, 0, "knockdown is not incapacitating")
	D.remove_status_effect(STATUS_EFFECT_KNOCKDOWN)
	expect(D, 0, "after removing knockdown")

	D.apply_status_effect(STATUS_EFFECT_UNCONSCIOUS, 10 SECONDS)
	expect(D, 1, "after applying unconscious")
	D.remove_status_effect(STATUS_EFFECT_UNCONSCIOUS)
	expect(D, 0, "after removing unconscious")

	// re-application must not leave the count inflated
	D.apply_status_effect(STATUS_EFFECT_STUN, 10 SECONDS)
	D.apply_status_effect(STATUS_EFFECT_STUN, 10 SECONDS)
	var/after_double = D.incapacity_count
	D.remove_status_effect(STATUS_EFFECT_STUN)
	expect(D, 0, "after clearing a re-applied stun (count was [after_double])")
