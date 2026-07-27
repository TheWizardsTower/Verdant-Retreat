/*

Usage:
Override /Run() to run your test code

Call Fail() to fail the test (You should specify a reason)

You may use /New() and /Destroy() for setup/teardown respectively

You can use the run_loc_bottom_left and run_loc_top_right to get turfs for testing

*/

GLOBAL_DATUM(current_test, /datum/unit_test)
GLOBAL_VAR_INIT(failed_any_test, FALSE)
GLOBAL_VAR(test_log)


/// The name of the test that is currently focused.
/// Use the PERFORM_ALL_TESTS macro instead.
GLOBAL_VAR_INIT(focused_test, focused_test())

/proc/focused_test()
	for(var/datum/unit_test/unit_test as anything in subtypesof(/datum/unit_test))
		if(initial(unit_test.focus))
			return unit_test
	return null

/datum/unit_test
	//Bit of metadata for the future maybe
	var/list/procs_tested

	//usable vars
	var/turf/run_loc_bottom_left
	var/turf/run_loc_top_right

	///The priority of the test, the larger it is the later it fires
	var/priority = TEST_DEFAULT

	//internal shit
	var/list/allocated
	var/focus = FALSE
	var/succeeded = TRUE
	var/list/fail_reasons

/proc/cmp_unit_test_priority(datum/unit_test/a, datum/unit_test/b)
	return initial(a.priority) - initial(b.priority)

/datum/unit_test/New()
	run_loc_bottom_left = locate(1, 1, 1)
	run_loc_top_right = locate(5, 5, 1)
	allocated = list()

/datum/unit_test/Destroy()
	//clear the test area
	for(var/atom/movable/AM in block(run_loc_bottom_left, run_loc_top_right))
		qdel(AM)
	QDEL_LIST(allocated)
	return ..()

/datum/unit_test/proc/Run()
	Fail("Run() called parent or not implemented")

/datum/unit_test/proc/Fail(reason = "No reason")
	succeeded = FALSE

	if(!istext(reason))
		reason = "FORMATTED: [reason != null ? reason : "NULL"]"

	LAZYADD(fail_reasons, reason)

/proc/RunUnitTests()
	CHECK_TICK

	var/list/tests_to_run = sortTim(subtypesof(/datum/unit_test), /proc/cmp_unit_test_priority)
	for(var/_test_to_run in tests_to_run)
		var/datum/unit_test/test_to_run = _test_to_run
		if(initial(test_to_run.focus))
			tests_to_run = list(test_to_run)
			break

	for(var/I in tests_to_run)
		if(ispath(I, /datum/unit_test/focus_only))
			continue
		var/datum/unit_test/test = new I

		GLOB.current_test = test
		var/duration = REALTIMEOFDAY

		test.Run()

		duration = REALTIMEOFDAY - duration
		GLOB.current_test = null
		GLOB.failed_any_test |= !test.succeeded

		var/list/log_entry = list("[test.succeeded ? "PASS" : "FAIL"]: [I] [duration / 10]s")
		var/list/fail_reasons = test.fail_reasons

		qdel(test)

		for(var/J in 1 to LAZYLEN(fail_reasons))
			log_entry += "\tREASON #[J]: [fail_reasons[J]]"
		log_test(log_entry.Join("\n"))

		CHECK_TICK

	SSticker.force_ending = TRUE

/// Allocates an instance of the provided type, and places it somewhere in an available loc
/// Instances allocated through this proc will be destroyed when the test is over
/datum/unit_test/proc/allocate(type, ...)
	var/list/arguments = args.Copy(2)
	if (!arguments.len)
		arguments = list(run_loc_bottom_left)
	else if (arguments[1] == null)
		arguments[1] = run_loc_bottom_left
	var/instance = new type(arglist(arguments))
	allocated += instance
	return instance
