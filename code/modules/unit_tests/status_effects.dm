/datum/status_effect/test_unique
	id = "test_unique"
	duration = 1 MINUTES
	alert_type = null
	status_type = STATUS_EFFECT_UNIQUE

/datum/status_effect/test_expiry
	id = "test_expiry"
	duration = 10
	alert_type = null

/datum/status_effect/test_refresh
	id = "test_refresh"
	duration = 30 SECONDS
	alert_type = null
	status_type = STATUS_EFFECT_REFRESH

/datum/status_effect/test_refresh/on_creation(mob/living/new_owner, new_dur)
	if(isnum(new_dur))
		duration = new_dur
	return ..()

/datum/status_effect/test_replace
	id = "test_replace"
	duration = 1 MINUTES
	alert_type = null
	status_type = STATUS_EFFECT_REPLACE
	var/static/replace_apply_count = 0
	var/static/replace_remove_count = 0

/datum/status_effect/test_replace/on_apply()
	replace_apply_count++
	return ..()

/datum/status_effect/test_replace/on_remove()
	replace_remove_count++
	return ..()

/datum/status_effect/test_multiple
	id = "test_multiple"
	duration = 1 MINUTES
	alert_type = null
	status_type = STATUS_EFFECT_MULTIPLE

/datum/status_effect/test_multiple/on_creation(mob/living/new_owner, new_dur)
	if(isnum(new_dur))
		duration = new_dur
	return ..()

/datum/status_effect/test_ticker
	id = "test_ticker"
	duration = 1 MINUTES
	tick_interval = 2
	alert_type = null
	var/static/ticks_seen = 0

/datum/status_effect/test_ticker/tick()
	ticks_seen++

/datum/status_effect/test_stats
	id = "test_stats"
	duration = 1 MINUTES
	alert_type = null
	effectedstats = list("strength" = 5)

/datum/status_effect/test_alerted
	id = "test_alerted"
	duration = 1 MINUTES
	alert_type = /atom/movable/screen/alert/status_effect

/datum/status_effect/test_parented
	duration = 1 MINUTES
	alert_type = null

/datum/status_effect/test_parented/alpha
	id = "test_parented_alpha"

/datum/status_effect/test_parented/beta
	id = "test_parented_beta"

/datum/status_effect/test_mobdel
	id = "test_mobdel"
	duration = 1 MINUTES
	alert_type = null
	on_remove_on_mob_delete = FALSE
	var/static/mobdel_remove_count = 0

/datum/status_effect/test_mobdel/on_remove()
	mobdel_remove_count++
	return ..()

/datum/status_effect/test_mobdel_notify
	id = "test_mobdel_notify"
	duration = 1 MINUTES
	alert_type = null
	on_remove_on_mob_delete = TRUE
	var/static/mobdel_notify_remove_count = 0

/datum/status_effect/test_mobdel_notify/on_remove()
	mobdel_notify_remove_count++
	return ..()

/datum/unit_test/status_effect_identity/Run()
	var/mob/living/carbon/human/H = allocate(/mob/living/carbon/human)

	var/datum/status_effect/first = H.apply_status_effect(/datum/status_effect/test_unique)
	TEST_ASSERT_NOTNULL(first, "applying a fresh effect must return the instance")
	TEST_ASSERT(first in H.status_effects, "applied effect must be in the owner's status_effects list")
	TEST_ASSERT_EQUAL(H.has_status_effect(/datum/status_effect/test_unique), first, "has_status_effect must find the effect by exact type")

	var/datum/status_effect/second = H.apply_status_effect(/datum/status_effect/test_unique)
	TEST_ASSERT(!second, "applying a UNIQUE effect twice must not create a second instance")
	var/count = 0
	for(var/datum/status_effect/test_unique/S in H.status_effects)
		count++
	TEST_ASSERT_EQUAL(count, 1, "exactly one UNIQUE instance must exist after double apply")

	TEST_ASSERT(H.remove_status_effect(/datum/status_effect/test_unique), "remove_status_effect must report removal")
	TEST_ASSERT_NULL(H.has_status_effect(/datum/status_effect/test_unique), "effect must be gone after remove_status_effect")

	var/datum/status_effect/inst = H.apply_status_effect(/datum/status_effect/test_unique)
	TEST_ASSERT(H.remove_status_effect(inst), "remove_status_effect must accept a live instance argument")
	TEST_ASSERT_NULL(H.has_status_effect(/datum/status_effect/test_unique), "effect must be gone after instance-argument removal")

/datum/unit_test/status_effect_parent_type/Run()
	var/mob/living/carbon/human/H = allocate(/mob/living/carbon/human)

	var/datum/status_effect/A = H.apply_status_effect(/datum/status_effect/test_parented/alpha)
	TEST_ASSERT_NOTNULL(A, "parented subtype must apply")
	TEST_ASSERT_EQUAL(H.has_status_effect(/datum/status_effect/test_parented), A, "has_status_effect with a parent type must find a live subtype instance")

	H.remove_status_effect(/datum/status_effect/test_parented)
	TEST_ASSERT_NULL(H.has_status_effect(/datum/status_effect/test_parented/alpha), "remove_status_effect with a parent type must remove the subtype instance")

	H.apply_status_effect(/datum/status_effect/test_parented/alpha)
	H.apply_status_effect(/datum/status_effect/test_parented/beta)
	H.remove_status_effect(/datum/status_effect/test_parented)
	TEST_ASSERT_NULL(H.has_status_effect(/datum/status_effect/test_parented), "remove_status_effect with a parent type must remove every matching instance")

/datum/unit_test/status_effect_refresh_duration/Run()
	var/mob/living/carbon/human/H = allocate(/mob/living/carbon/human)

	var/datum/status_effect/first = H.apply_status_effect(/datum/status_effect/test_refresh, 50)
	TEST_ASSERT_NOTNULL(first, "refresh-type effect must apply")
	var/remaining = H.get_timed_status_effect_duration(/datum/status_effect/test_refresh)
	TEST_ASSERT(remaining > 40 && remaining <= 50, "constructed duration must be the runtime-passed one, got [remaining]")

	var/datum/status_effect/again = H.apply_status_effect(/datum/status_effect/test_refresh, 100)
	TEST_ASSERT_EQUAL(again, first, "re-applying a REFRESH effect must return the refreshed existing instance")
	remaining = H.get_timed_status_effect_duration(/datum/status_effect/test_refresh)
	TEST_ASSERT(remaining > 90 && remaining <= 100, "refresh must honor the newly passed duration, not initial(), got [remaining]")

	H.remove_status_effect(/datum/status_effect/test_refresh)

/datum/unit_test/status_effect_replace/Run()
	var/mob/living/carbon/human/H = allocate(/mob/living/carbon/human)

	var/datum/status_effect/test_replace/first = H.apply_status_effect(/datum/status_effect/test_replace)
	var/base_applies = first.replace_apply_count
	var/base_removes = first.replace_remove_count

	var/datum/status_effect/test_replace/second = H.apply_status_effect(/datum/status_effect/test_replace)
	TEST_ASSERT_NOTNULL(second, "REPLACE re-apply must create a fresh instance")
	TEST_ASSERT_NOTEQUAL(second, first, "REPLACE re-apply must not return the old instance")
	TEST_ASSERT(QDELETED(first), "REPLACE must destroy the old instance")
	TEST_ASSERT_EQUAL(second.replace_apply_count, base_applies + 1, "replacement must run on_apply")
	TEST_ASSERT_EQUAL(second.replace_remove_count, base_removes + 1, "replacement must run the old instance's on_remove")

	var/count = 0
	for(var/datum/status_effect/test_replace/S in H.status_effects)
		count++
	TEST_ASSERT_EQUAL(count, 1, "exactly one instance must remain after REPLACE")
	H.remove_status_effect(/datum/status_effect/test_replace)

/datum/unit_test/status_effect_multiple/Run()
	var/mob/living/carbon/human/H = allocate(/mob/living/carbon/human)

	var/datum/status_effect/long_lived = H.apply_status_effect(/datum/status_effect/test_multiple, 10 MINUTES)
	var/datum/status_effect/short_lived = H.apply_status_effect(/datum/status_effect/test_multiple, 10)
	TEST_ASSERT_NOTNULL(long_lived, "first MULTIPLE instance must apply")
	TEST_ASSERT_NOTNULL(short_lived, "second MULTIPLE instance must apply")
	TEST_ASSERT_NOTEQUAL(long_lived, short_lived, "MULTIPLE applies must create distinct instances")

	sleep(30)
	TEST_ASSERT(QDELETED(short_lived), "short-lived MULTIPLE instance must expire")
	TEST_ASSERT(!QDELETED(long_lived), "long-lived MULTIPLE instance must survive its sibling's expiry")
	TEST_ASSERT_NOTNULL(H.has_status_effect(/datum/status_effect/test_multiple), "has_status_effect must still find the surviving MULTIPLE instance after a sibling expires")

	H.remove_status_effect(/datum/status_effect/test_multiple)
	TEST_ASSERT(QDELETED(long_lived), "remove_status_effect must remove every MULTIPLE instance")
	TEST_ASSERT_NULL(H.has_status_effect(/datum/status_effect/test_multiple), "no MULTIPLE instance may survive removal")

/datum/unit_test/status_effect_expiry_and_tick/Run()
	var/mob/living/carbon/human/H = allocate(/mob/living/carbon/human)

	var/datum/status_effect/short_lived = H.apply_status_effect(/datum/status_effect/test_expiry)
	TEST_ASSERT_NOTNULL(short_lived, "expiry test effect must apply")
	sleep(30)
	TEST_ASSERT(QDELETED(short_lived), "a 1-second effect must be destroyed after 3 seconds")
	TEST_ASSERT_NULL(H.has_status_effect(/datum/status_effect/test_expiry), "expired effect must be gone from the owner")

	var/datum/status_effect/test_ticker/T = H.apply_status_effect(/datum/status_effect/test_ticker)
	var/base_ticks = T.ticks_seen
	sleep(20)
	TEST_ASSERT(T.ticks_seen >= base_ticks + 5, "a 0.2s-interval ticker must tick at least 5 times in 2 seconds, saw [T.ticks_seen - base_ticks]")
	H.remove_status_effect(/datum/status_effect/test_ticker)

/datum/unit_test/status_effect_stats/Run()
	var/mob/living/carbon/human/H = allocate(/mob/living/carbon/human)

	var/base_str = H.STASTR
	H.apply_status_effect(/datum/status_effect/test_stats)
	TEST_ASSERT_EQUAL(H.STASTR, min(20, base_str + 5), "strength buff must raise displayed strength with a cap of 20")
	H.remove_status_effect(/datum/status_effect/test_stats)
	TEST_ASSERT_EQUAL(H.STASTR, base_str, "removing the buff must restore the exact base strength")

	H.change_stat("strength", 18 - H.STASTR)
	var/high_base = H.STASTR
	TEST_ASSERT_EQUAL(high_base, 18, "setup must land base strength on 18")
	H.apply_status_effect(/datum/status_effect/test_stats)
	TEST_ASSERT_EQUAL(H.STASTR, 20, "a +5 buff at 18 must clamp displayed strength to 20")
	H.remove_status_effect(/datum/status_effect/test_stats)
	TEST_ASSERT_EQUAL(H.STASTR, 18, "removing the clamped buff must restore base strength exactly")
	H.change_stat("strength", base_str - H.STASTR)

/datum/unit_test/status_effect_alerts/Run()
	var/mob/living/carbon/human/H = allocate(/mob/living/carbon/human)

	var/datum/status_effect/test_alerted/E = H.apply_status_effect(/datum/status_effect/test_alerted)
	TEST_ASSERT_NOTNULL(E, "alerted effect must apply")
	TEST_ASSERT_NOTNULL(H.alerts[E.id], "applying an effect with an alert_type must throw its alert")
	H.remove_status_effect(/datum/status_effect/test_alerted)
	TEST_ASSERT_NULL(H.alerts["test_alerted"], "removing the effect must clear its alert")

/datum/unit_test/combat_cooldowns/Run()
	var/mob/living/carbon/human/H = allocate(/mob/living/carbon/human)

	H.set_combat_cooldown("testcd", 10, /atom/movable/screen/alert/status_effect/debuff/clickcd)
	TEST_ASSERT(H.combat_cooldown_active("testcd"), "a fresh cooldown must read as active")
	TEST_ASSERT_NOTNULL(H.alerts["testcd"], "starting a cooldown with an alert type must throw the alert")
	sleep(20)
	TEST_ASSERT(!H.combat_cooldown_active("testcd"), "an expired cooldown must read as inactive")
	TEST_ASSERT_NULL(H.alerts["testcd"], "an expired cooldown must clear its alert")

	H.set_combat_cooldown("testcd", 10, /atom/movable/screen/alert/status_effect/debuff/clickcd)
	H.set_combat_cooldown("testcd", 40, /atom/movable/screen/alert/status_effect/debuff/clickcd)
	sleep(20)
	TEST_ASSERT(H.combat_cooldown_active("testcd"), "restarting a cooldown must survive the first application's expiry")
	TEST_ASSERT_NOTNULL(H.alerts["testcd"], "a restarted cooldown must keep its alert past the first expiry time")
	H.clear_combat_cooldown("testcd")
	TEST_ASSERT(!H.combat_cooldown_active("testcd"), "clear_combat_cooldown must end the cooldown early")
	TEST_ASSERT_NULL(H.alerts["testcd"], "clear_combat_cooldown must clear the alert")

/datum/unit_test/status_effect_mob_deletion/Run()
	var/mob/living/carbon/human/quiet = new(run_loc_bottom_left)
	var/datum/status_effect/test_mobdel/quiet_effect = quiet.apply_status_effect(/datum/status_effect/test_mobdel)
	var/base_quiet = quiet_effect.mobdel_remove_count
	qdel(quiet)
	sleep(1)
	TEST_ASSERT_EQUAL(quiet_effect.mobdel_remove_count, base_quiet, "on_remove must NOT run on mob deletion when on_remove_on_mob_delete is FALSE")

	var/mob/living/carbon/human/loud = new(run_loc_bottom_left)
	var/datum/status_effect/test_mobdel_notify/loud_effect = loud.apply_status_effect(/datum/status_effect/test_mobdel_notify)
	var/base_loud = loud_effect.mobdel_notify_remove_count
	qdel(loud)
	sleep(1)
	TEST_ASSERT_EQUAL(loud_effect.mobdel_notify_remove_count, base_loud + 1, "on_remove MUST run on mob deletion when on_remove_on_mob_delete is TRUE")
