/datum/unit_test/liquid_evaporation/Run()
	var/turf/open/floor/rogue/cobble/C = run_loc_bottom_left.ChangeTurf(/turf/open/floor/rogue/cobble, null, CHANGETURF_IGNORE_AIR)
	new /atom/movable/outdoor_effect(C)
	if(!C.cell)
		C.cell = new /cell(C)
		C.cell.InitLiquids()
	var/datum/liquid/water_fluid = C.cell.get_fluid_datum(WATER)
	TEST_ASSERT_NOTNULL(water_fluid, "evaporation test turf must have a water fluid datum")

	var/old_tod = GLOB.tod

	C.cell.fluid_volume[water_fluid] = LIQUID_EVAP_THRESHOLD - 1
	SSliquid.update_fluidsum(C)
	SSliquid.sync_cell_to_native(C)
	SSliquid.pool_manager.liquid_turfs[C] = TRUE

	GLOB.tod = "night"
	SSliquid.pool_manager.evap_timer = 0
	SSliquid.pool_manager.process_evaporation()
	TEST_ASSERT_EQUAL(C.cell.fluidsum, LIQUID_EVAP_THRESHOLD - 1, "an outdoor puddle must not evaporate at night without a fire")

	GLOB.tod = "day"
	var/pre_wet = C.water_level
	SSliquid.pool_manager.evap_timer = 0
	SSliquid.pool_manager.process_evaporation()
	TEST_ASSERT_EQUAL(C.cell.fluidsum, LIQUID_EVAP_THRESHOLD - 1 - LIQUID_EVAP_AMOUNT, "a sun-exposed puddle must lose LIQUID_EVAP_AMOUNT per pass")
	TEST_ASSERT_EQUAL(C.water_level, pre_wet, "evaporated fluid must not convert to wetness")

	C.outdoor_effect.weatherproof = TRUE
	var/pre_roofed = C.cell.fluidsum
	SSliquid.pool_manager.evap_timer = 0
	SSliquid.pool_manager.process_evaporation()
	TEST_ASSERT_EQUAL(C.cell.fluidsum, pre_roofed, "a roofed puddle must not evaporate in daylight")

	C.outdoor_effect.weatherproof = FALSE
	C.cell.fluid_volume[water_fluid] = LIQUID_EVAP_THRESHOLD
	SSliquid.update_fluidsum(C)
	SSliquid.sync_cell_to_native(C)
	SSliquid.pool_manager.evap_timer = 0
	SSliquid.pool_manager.process_evaporation()
	TEST_ASSERT_EQUAL(C.cell.fluidsum, LIQUID_EVAP_THRESHOLD, "fluid at or above the evaporation threshold must not evaporate")

	GLOB.tod = "night"
	C.cell.fluid_volume[water_fluid] = LIQUID_EVAP_THRESHOLD - 2
	SSliquid.update_fluidsum(C)
	SSliquid.sync_cell_to_native(C)
	var/obj/machinery/light/rogue/campfire/fire = allocate(/obj/machinery/light/rogue/campfire)
	if(!fire.on)
		fire.fire_act()
	TEST_ASSERT(fire.on, "campfire must light for the evaporation test")
	SSliquid.pool_manager.evap_timer = 0
	SSliquid.pool_manager.process_evaporation()
	TEST_ASSERT_EQUAL(C.cell.fluidsum, LIQUID_EVAP_THRESHOLD - 2 - LIQUID_EVAP_AMOUNT, "a puddle near a lit fire must evaporate regardless of time of day")

	fire.extinguish()
	var/pre_dark = C.cell.fluidsum
	SSliquid.pool_manager.evap_timer = 0
	SSliquid.pool_manager.process_evaporation()
	TEST_ASSERT_EQUAL(C.cell.fluidsum, pre_dark, "an extinguished fire must not drive evaporation")

	GLOB.tod = old_tod
	SSliquid.clear_cell_fluid(C)
