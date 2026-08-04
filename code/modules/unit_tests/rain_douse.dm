/datum/unit_test/rain_injection/Run()
	var/turf/open/floor/rogue/sand/S = run_loc_bottom_left.ChangeTurf(/turf/open/floor/rogue/sand, null, CHANGETURF_IGNORE_AIR)
	new /atom/movable/outdoor_effect(S)
	var/pre_wet = S.water_level
	SSliquid.pool_manager.rain_hit(S)
	TEST_ASSERT_EQUAL(S.water_level, pre_wet + (RAIN_INJECT_AMOUNT * LIQUID_ABSORPTION_WETNESS_MULT), "rain on absorbent ground must convert directly to wetness")
	TEST_ASSERT(!S.cell?.fluidsum, "rain on absorbent ground must not inject standing fluid")

	var/turf/open/floor/rogue/cobble/C = run_loc_top_right.ChangeTurf(/turf/open/floor/rogue/cobble, null, CHANGETURF_IGNORE_AIR)
	new /atom/movable/outdoor_effect(C)
	var/pre_cobble_wet = C.water_level
	SSliquid.pool_manager.rain_hit(C)
	TEST_ASSERT_NOTNULL(C.cell, "rain on non-absorbent ground must create a liquid cell")
	TEST_ASSERT_EQUAL(C.cell.fluidsum, RAIN_INJECT_AMOUNT, "rain on non-absorbent ground must inject fluid")
	TEST_ASSERT_EQUAL(C.water_level, pre_cobble_wet + RAIN_INJECT_AMOUNT, "rain on non-absorbent ground must also wet the surface")

	C.outdoor_effect.weatherproof = TRUE
	SSliquid.pool_manager.rain_hit(C)
	TEST_ASSERT_EQUAL(C.cell.fluidsum, RAIN_INJECT_AMOUNT, "weatherproof turfs must not receive rain")

/datum/unit_test/liquid_douse/Run()
	var/turf/open/T = run_loc_bottom_left
	var/obj/machinery/light/rogue/campfire/fire = allocate(/obj/machinery/light/rogue/campfire)
	if(!fire.on)
		fire.fire_act()
	TEST_ASSERT(fire.on, "campfire must light for the douse test")

	if(!T.cell)
		T.cell = new /cell(T)
		T.cell.InitLiquids()
	var/datum/liquid/water_fluid = T.cell.get_fluid_datum(WATER)
	TEST_ASSERT_NOTNULL(water_fluid, "douse test turf must have a water fluid datum")

	T.cell.fluid_volume[water_fluid] = LIQUID_DOUSE_THRESHOLD - 1
	SSliquid.update_fluidsum(T)
	T.douse_contents()
	TEST_ASSERT(fire.on, "fluid below the douse threshold must not snuff a campfire")

	T.cell.fluid_volume[water_fluid] = LIQUID_DOUSE_THRESHOLD
	SSliquid.update_fluidsum(T)
	T.douse_contents()
	TEST_ASSERT(!fire.on, "standing fluid at the douse threshold must snuff a campfire")

	var/obj/machinery/light/rogue/wallfire/wf = allocate(/obj/machinery/light/rogue/wallfire)
	if(!wf.on)
		wf.fire_act()
	TEST_ASSERT(wf.on, "wallfire must light for the douse test")
	T.douse_contents()
	TEST_ASSERT(wf.on, "shallow fluid must not snuff a wall-mounted fire")

	T.cell.fluid_volume[water_fluid] = FLUID_THRESHOLD
	SSliquid.update_fluidsum(T)
	T.douse_contents()
	TEST_ASSERT(!wf.on, "full submersion must snuff a wall-mounted fire")
