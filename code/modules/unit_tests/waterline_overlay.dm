/datum/unit_test/waterline_overlay/proc/is_upright(matrix/M)
	return !M || (M.a == 1 && M.b == 0 && M.d == 0 && M.e == 1)

/datum/unit_test/waterline_overlay/proc/child_mask_y(atom/movable/AM)
	if(!AM || !length(AM.filters))
		return null
	var/mask = AM.filters[1]
	return mask:y

/datum/unit_test/waterline_overlay/Run()
	fdel("data/waterline_overlay_results.txt")
	var/F = file("data/waterline_overlay_results.txt")

	var/turf/open/T = run_loc_bottom_left
	if(!T.cell)
		T.cell = new /cell(T)
		T.cell.InitLiquids()
	var/datum/liquid/water_fluid = T.cell.get_fluid_datum(WATER)
	TEST_ASSERT_NOTNULL(water_fluid, "waterline test turf must have a water fluid datum")
	T.cell.fluid_volume[water_fluid] = MAX_FLUID_VOLUME
	SSliquid.update_fluidsum(T)
	TEST_ASSERT(T.fluid_depth() >= MAX_FLUID_VOLUME, "waterline test turf must be fully flooded")

	var/obj/probe = allocate(/obj, T)
	probe.update_submersion_cut()
	var/list/params = probe.filter_data?[SUBMERSION_FILTER_ID]
	TEST_ASSERT_NOTNULL(params, "an upright submerged obj must be cut by a filter on itself")
	TEST_ASSERT_EQUAL(params["y"], SUBMERSION_MASK_OFFSET_FULL, "an upright obj at full depth must be cut at the full waterline")
	TEST_ASSERT_EQUAL(params["flags"], MASK_INVERSE, "the waterline mask must cut the obj, not paint over it")
	TEST_ASSERT_NULL(probe.waterline_overlay, "an upright obj must not need a waterline child")
	TEST_ASSERT_NULL(probe.render_target, "an upright obj must not be diverted to a render target")
	F << "upright: mask y=[params["y"]] child=[probe.waterline_overlay ? "yes" : "no"] render_target=[probe.render_target || "none"]"

	var/matrix/shrunk = matrix()
	shrunk.Scale(0.75, 0.75)
	probe.transform = shrunk
	probe.update_submersion_cut()
	TEST_ASSERT_NOTNULL(probe.filter_data?[SUBMERSION_FILTER_ID], "a scaled but unturned obj must keep the plain cut")
	TEST_ASSERT_NULL(probe.waterline_overlay, "a scaled but unturned obj must not need a waterline child")
	F << "scaled 0.75: mask y=[probe.filter_data[SUBMERSION_FILTER_ID]["y"]] child=[probe.waterline_overlay ? "yes" : "no"]"

	for(var/angle in list(90, -90, 180, 30))
		probe.transform = turn(matrix(), angle)
		probe.update_submersion_cut()
		var/obj/effect/waterline/W = probe.waterline_overlay
		TEST_ASSERT_NOTNULL(W, "an obj turned [angle] degrees must cut through a waterline child")
		TEST_ASSERT(W in probe.vis_contents, "the waterline child must live in the obj's vis_contents")
		TEST_ASSERT(W.appearance_flags & RESET_TRANSFORM, "the waterline child must not inherit the obj's transform")
		TEST_ASSERT(is_upright(W.transform), "the waterline child must stay upright")
		TEST_ASSERT_NOTNULL(probe.render_target, "a turned obj must render to a target for its child to cut")
		TEST_ASSERT_EQUAL(W.render_source, probe.render_target, "the waterline child must draw the obj's rendered image")
		TEST_ASSERT_NULL(probe.filter_data?[SUBMERSION_FILTER_ID], "a turned obj must not also carry the skewed filter")
		TEST_ASSERT_EQUAL(child_mask_y(W), SUBMERSION_MASK_OFFSET_FULL, "a turned obj must be cut at the same waterline as an upright one")
		F << "turn [angle]: child mask y=[child_mask_y(W)] upright=[is_upright(W.transform)] source=[W.render_source]"

	probe.transform = null
	probe.update_submersion_cut()
	TEST_ASSERT_NULL(probe.waterline_overlay, "straightening an obj must drop the waterline child")
	TEST_ASSERT_NULL(probe.render_target, "straightening an obj must release its render target")
	TEST_ASSERT_NOTNULL(probe.filter_data?[SUBMERSION_FILTER_ID], "straightening an obj must restore the plain cut")
	TEST_ASSERT(!length(probe.vis_contents), "straightening an obj must empty its vis_contents")

	probe.transform = turn(matrix(), 90)
	probe.update_submersion_cut()
	TEST_ASSERT_NOTNULL(probe.waterline_overlay, "a turned obj must take the child path again")
	SSliquid.clear_cell_fluid(T)
	probe.update_submersion_cut()
	TEST_ASSERT_NULL(probe.waterline_overlay, "a dried obj must drop its waterline child")
	TEST_ASSERT_NULL(probe.render_target, "a dried obj must release its render target")
	TEST_ASSERT_NULL(probe.filter_data?[SUBMERSION_FILTER_ID], "a dried obj must drop its cut")
	probe.transform = null
	T.cell.fluid_volume[water_fluid] = MAX_FLUID_VOLUME
	SSliquid.update_fluidsum(T)

	var/mob/living/carbon/human/H = allocate(/mob/living/carbon/human, T)
	H.update_submersion()
	var/list/standing = H.filter_data?[SUBMERSION_FILTER_ID]
	TEST_ASSERT_NOTNULL(standing, "a standing submerged mob must be cut by a filter on itself")
	TEST_ASSERT_EQUAL(standing["y"], SUBMERSION_MASK_OFFSET_FULL, "a standing mob at full depth must be cut at the full waterline")
	TEST_ASSERT_NULL(H.waterline_overlay, "a standing mob must not need a waterline child")
	F << "standing mob: mask y=[standing["y"]] child=no"

	H.set_resting(TRUE)
	var/matrix/lying = H.transform
	F << "lying mob: transform b=[lying?.b] d=[lying?.d] e=[lying?.e] pixel_y=[H.pixel_y] render_target=[H.render_target || "none"] depth=[H.submersion_depth] filter=[H.filter_data?[SUBMERSION_FILTER_ID] ? "yes" : "no"] child=[H.waterline_overlay ? "yes" : "no"]"
	if(lying && (lying.b || lying.d || lying.e <= 0))
		var/obj/effect/waterline/LW = H.waterline_overlay
		TEST_ASSERT_NOTNULL(LW, "a lying mob must cut through a waterline child")
		TEST_ASSERT(LW in H.vis_contents, "the lying mob's waterline child must be in its vis_contents")
		TEST_ASSERT(is_upright(LW.transform), "the lying mob's waterline child must stay upright")
		TEST_ASSERT_EQUAL(LW.render_source, H.render_target, "the lying mob's child must draw its rendered image")
		TEST_ASSERT_NULL(H.filter_data?[SUBMERSION_FILTER_ID], "a lying mob must not also carry the skewed filter")
		TEST_ASSERT_EQUAL(H.em_block?.render_source, H.render_target, "taking over the render target must keep the emissive blocker pointed at it")
		F << "lying mob: child mask y=[child_mask_y(LW)] upright=[is_upright(LW.transform)]"
	else
		TEST_FAIL("a resting mob was expected to be turned by update_transform")
	H.set_resting(FALSE)
	TEST_ASSERT_NULL(H.waterline_overlay, "standing back up must drop the waterline child")
	TEST_ASSERT_NOTNULL(H.filter_data?[SUBMERSION_FILTER_ID], "standing back up must restore the plain cut")
	TEST_ASSERT_EQUAL(H.render_target, ref(H), "standing back up must hand the render target back to the emissive blocker")
	TEST_ASSERT_EQUAL(H.em_block?.render_source, H.render_target, "the emissive blocker must follow the restored render target")

	SSliquid.clear_cell_fluid(T)

	F << "COMPLETE"
