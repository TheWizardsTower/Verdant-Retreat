/datum/unit_test/life_cadence
	var/list/life_times
	var/list/life_fired

/datum/unit_test/life_cadence/proc/on_life(mob/living/source, seconds, times_fired)
	SIGNAL_HANDLER
	life_times += world.time
	life_fired += times_fired

/datum/unit_test/life_cadence/Run()
	var/mob/living/carbon/human/H = allocate(/mob/living/carbon/human)
	life_times = list()
	life_fired = list()
	RegisterSignal(H, COMSIG_LIVING_LIFE, PROC_REF(on_life))

	var/timeout = world.time + 1 MINUTES
	while(length(life_times) < 5 && world.time < timeout)
		sleep(5)
	UnregisterSignal(H, COMSIG_LIVING_LIFE)
	var/fires = length(life_times)
	TEST_ASSERT(fires >= 5, "Life() fired only [fires] times in 60s; SSmobs not running in test env")

	var/list/gaps = list()
	for(var/i in 2 to fires)
		gaps += (life_times[i] - life_times[i - 1])
		TEST_ASSERT_EQUAL(life_fired[i] - life_fired[i - 1], 1, "SSmobs skipped a fire between Life() calls")

	world.log << "LIFE_CADENCE_MEASURE: gaps(ds)=[gaps.Join(",")]"
	for(var/gap in gaps)
		TEST_ASSERT(gap >= 15 && gap <= 25, "Life() cadence [gap]ds is outside the expected ~20ds window")
