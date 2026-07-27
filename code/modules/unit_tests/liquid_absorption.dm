/datum/unit_test/liquid_absorption/Run()
	var/turf/open/floor/rogue/sand/S = run_loc_bottom_left.ChangeTurf(/turf/open/floor/rogue/sand, null, CHANGETURF_IGNORE_AIR)
	if(!S.cell)
		S.cell = new /cell(S)
		S.cell.InitLiquids()
	var/datum/liquid/sand_water = S.cell.get_fluid_datum(WATER)
	TEST_ASSERT_NOTNULL(sand_water, "sand turf must have a water fluid datum")
	S.cell.fluid_volume[sand_water] = MIN_FLUID_VOLUME + 50
	SSliquid.update_fluidsum(S)
	GLOB.pool_manager.liquid_turfs[S] = TRUE

	var/pre_fluidsum = S.cell.fluidsum
	var/pre_water_level = S.water_level

	GLOB.pool_manager.absorption_timer = 0
	GLOB.pool_manager.process_absorption()

	TEST_ASSERT_EQUAL(S.cell.fluidsum, pre_fluidsum - S.liquid_absorption, "sand absorption must remove liquid_absorption units of fluid from the cell")
	TEST_ASSERT_EQUAL(S.water_level, pre_water_level + (S.liquid_absorption * LIQUID_ABSORPTION_WETNESS_MULT), "sand absorption must raise wetness by liquid_absorption * 3")

	TEST_ASSERT(GLOB.pool_manager.wet_update_queue[S], "wetting a turf must queue it for a deferred update_water pass")
	GLOB.pool_manager.wet_update_timer = 0
	GLOB.pool_manager.process_wet_updates()
	TEST_ASSERT(!GLOB.pool_manager.wet_update_queue[S], "a turf whose update_water returns TRUE must be dequeued")

	var/turf/open/water/W = run_loc_top_right.ChangeTurf(/turf/open/water, null, CHANGETURF_IGNORE_AIR)
	if(!W.cell)
		W.cell = new /cell(W)
		W.cell.InitLiquids()
	var/datum/liquid/deep_water = W.cell.get_fluid_datum(WATER)
	if(deep_water)
		W.cell.fluid_volume[deep_water] = MIN_FLUID_VOLUME + 50
	SSliquid.update_fluidsum(W)
	GLOB.pool_manager.liquid_turfs[W] = TRUE

	var/pre_depth = W.water_level

	GLOB.pool_manager.absorption_timer = 0
	GLOB.pool_manager.process_absorption()

	TEST_ASSERT_EQUAL(W.water_level, pre_depth, "/turf/open/water depth tier must be untouched by the absorption pass")
