/datum/unit_test/procgen_forest
	var/list/report = list()
	var/test_z = 0

/datum/unit_test/procgen_forest/proc/note(text)
	report += text

/datum/unit_test/procgen_forest/proc/find_test_z()
	for(var/candidate in 1 to length(SSmapping.multiz_levels))
		var/list/level = SSmapping.multiz_levels[candidate]
		if(level[Z_LEVEL_UP] && level[Z_LEVEL_DOWN])
			return candidate
	return 0

/datum/unit_test/procgen_forest/proc/claim_turfs(area/procedural_generation/target, list/coords)
	var/list/claimed = list()
	for(var/list/coord as anything in coords)
		var/turf/T = locate(coord[1], coord[2], test_z)
		if(!T)
			continue
		T = T.ChangeTurf(/turf/open/floor/rogue/dirt)
		var/area/old_area = T.loc
		target.contents += T
		T.change_area(old_area, target)
		claimed += T
	return claimed

/datum/unit_test/procgen_forest/proc/open_canopy(list/coords)
	var/area/sky = type2area(/area/rogue/outdoors)
	for(var/list/coord as anything in coords)
		var/turf/above = locate(coord[1], coord[2], test_z + 1)
		if(!above)
			continue
		if(!istype(above, /turf/open/transparent/openspace))
			above = above.ChangeTurf(/turf/open/transparent/openspace)
		var/area/above_area = get_area(above)
		if(sky && above_area && !above_area.outdoors)
			sky.contents += above
			above.change_area(above_area, sky)

/datum/unit_test/procgen_forest/proc/rect_coords(x1, y1, x2, y2)
	var/list/out = list()
	for(var/x = x1, x <= x2, x++)
		for(var/y = y1, y <= y2, y++)
			out += list(list(x, y))
	return out

/datum/unit_test/procgen_forest/proc/is_standing_tree(turf/T)
	if(locate(/obj/structure/flora/newtree) in T)
		return TRUE
	for(var/obj/structure/flora/roguetree/candidate in T)
		if(!istype(candidate, /obj/structure/flora/roguetree/stump))
			return TRUE
	return FALSE

/datum/unit_test/procgen_forest/proc/largest_tree_clump(list/tree_keys)
	var/list/pending = tree_keys.Copy()
	var/largest = 0
	while(length(pending))
		var/list/frontier = list(pending[1])
		pending -= pending[1]
		var/size = 0
		while(length(frontier))
			var/key = frontier[1]
			frontier -= key
			size++
			var/list/coords = splittext(key, "-")
			var/cx = text2num(coords[1])
			var/cy = text2num(coords[2])
			for(var/dx in -1 to 1)
				for(var/dy in -1 to 1)
					if(!dx && !dy)
						continue
					var/neighbor_key = "[cx + dx]-[cy + dy]"
					if(neighbor_key in pending)
						pending -= neighbor_key
						frontier += neighbor_key
		if(size > largest)
			largest = size
	return largest

/datum/unit_test/procgen_forest/proc/run_grove()
	var/area/procedural_generation/forest/test/grove = new
	TEST_ASSERT(grove in GLOB.mapgen_areas, "A new procedural_generation area did not register itself in GLOB.mapgen_areas")

	var/list/grove_coords = rect_coords(8, 7, 37, 24)
	open_canopy(grove_coords)
	var/list/grove_turfs = claim_turfs(grove, grove_coords)
	TEST_ASSERT_EQUAL(length(grove_turfs), length(grove_coords), "Claimed the wrong number of grove turfs")

	grove.setup_procgen()

	TEST_ASSERT_EQUAL(grove.low_x, 8, "grove.low_x")
	TEST_ASSERT_EQUAL(grove.high_x, 37, "grove.high_x")
	TEST_ASSERT_EQUAL(grove.low_y, 7, "grove.low_y")
	TEST_ASSERT_EQUAL(grove.high_y, 24, "grove.high_y")

	var/list/tree_keys = list()
	var/ground_newtrees = 0
	var/ground_roguetrees = 0
	var/stumps = 0
	var/canopy_trunks = 0
	var/leaves = 0
	var/branches = 0
	for(var/list/coord as anything in grove_coords)
		var/turf/T = locate(coord[1], coord[2], test_z)
		if(locate(/obj/structure/flora/newtree) in T)
			ground_newtrees++
		for(var/obj/structure/flora/roguetree/candidate in T)
			if(istype(candidate, /obj/structure/flora/roguetree/stump))
				stumps++
			else
				ground_roguetrees++
		if(is_standing_tree(T))
			tree_keys += "[T.x]-[T.y]"
		var/turf/above = locate(coord[1], coord[2], test_z + 1)
		if(!above)
			continue
		if(locate(/obj/structure/flora/newtree) in above)
			canopy_trunks++
		if(locate(/obj/structure/flora/newleaf) in above)
			leaves++
		if(locate(/obj/structure/flora/newbranch) in above)
			branches++

	var/trees = length(tree_keys)
	TEST_ASSERT(trees > 0, "The forest generator planted no trees at all, so nothing below is being tested")

	var/largest_clump = largest_tree_clump(tree_keys)
	note("grove: [length(grove_coords)] cells -> [trees] standing trees ([round(trees * 100 / length(grove_coords))]% coverage)")
	note("grove: [ground_newtrees] newtree, [ground_roguetrees] roguetree, [stumps] stumps (stumps are undergrowth, not counted as trees)")
	note("grove: largest contiguous tree clump [largest_clump] tiles")
	note("grove: [canopy_trunks] canopy trunks, [leaves] leaf tiles, [branches] branch tiles on z [test_z + 1]")

	for(var/y = 24, y >= 7, y--)
		var/line = ""
		for(var/x = 8, x <= 37, x++)
			var/turf/T = locate(x, y, test_z)
			if(istype(T, /turf/open/transparent/openspace))
				line += "~"
			else if(is_standing_tree(T))
				line += "T"
			else if(locate(/obj/structure/flora) in T)
				line += ","
			else
				line += "."
		note("  [line]")

	TEST_ASSERT(largest_clump <= 4, "Largest contiguous tree clump is [largest_clump] tiles; trees are still generating as walls")
	TEST_ASSERT_EQUAL(canopy_trunks, ground_newtrees, "[ground_newtrees] ground newtrees produced [canopy_trunks] canopy trunks; build_trees is not 1:1")
	TEST_ASSERT(leaves > 0, "No leaf tiles were built; SStreesetup never processed the generated trees")
	TEST_ASSERT(branches > 0, "No branch tiles were built; SStreesetup never processed the generated trees")

/datum/unit_test/procgen_forest/proc/run_spill()
	var/area/procedural_generation/forest/test/spill/patchwork = new
	var/list/l_shape = rect_coords(40, 7, 48, 15) - rect_coords(44, 7, 48, 11)
	var/list/island = rect_coords(40, 19, 44, 22)
	var/list/spill_coords = l_shape + island
	open_canopy(spill_coords)
	var/list/spill_turfs = claim_turfs(patchwork, spill_coords)
	TEST_ASSERT_EQUAL(length(spill_turfs), length(spill_coords), "Claimed the wrong number of spill turfs")

	var/list/inside = list()
	for(var/list/coord as anything in spill_coords)
		inside["[coord[1]]-[coord[2]]"] = TRUE

	var/list/outside_before = list()
	for(var/x = 40, x <= 48, x++)
		for(var/y = 7, y <= 22, y++)
			if(inside["[x]-[y]"])
				continue
			var/turf/T = locate(x, y, test_z)
			if(!T)
				continue
			var/turf/below = locate(x, y, test_z - 1)
			var/flora = 0
			for(var/obj/structure/flora/F in T)
				flora++
			outside_before["[x]-[y]"] = list(T.type, below ? below.type : null, flora)

	patchwork.setup_procgen()

	var/inside_flora = 0
	var/inside_water = 0
	var/inside_bare = 0
	var/inside_waterbed = 0
	for(var/list/coord as anything in spill_coords)
		var/turf/T = locate(coord[1], coord[2], test_z)
		var/has_flora = (locate(/obj/structure/flora) in T) ? TRUE : FALSE
		var/is_water = istype(T, /turf/open/transparent/openspace)
		if(has_flora)
			inside_flora++
		if(is_water)
			inside_water++
		if(!has_flora && !is_water)
			inside_bare++
		var/turf/below = locate(coord[1], coord[2], test_z - 1)
		if(istype(below, /turf/open/floor/rogue/lakebed) || istype(below, /turf/open/floor/rogue/riverbot))
			inside_waterbed++

	var/changed_turf = 0
	var/changed_below = 0
	var/gained_flora = 0
	for(var/key in outside_before)
		var/list/coords = splittext(key, "-")
		var/turf/T = locate(text2num(coords[1]), text2num(coords[2]), test_z)
		var/turf/below = locate(text2num(coords[1]), text2num(coords[2]), test_z - 1)
		var/list/before = outside_before[key]
		var/flora = 0
		for(var/obj/structure/flora/F in T)
			flora++
		if(T.type != before[1])
			changed_turf++
		if((below ? below.type : null) != before[2])
			changed_below++
		if(flora > before[3])
			gained_flora++

	note("spill: [length(spill_coords)] cells in area, [length(outside_before)] cells inside the bounding box but outside the area")
	note("spill: inside -> [inside_flora] flora, [inside_water] water tiles, [inside_waterbed] water beds below, [inside_bare] bare")
	note("spill: outside -> [gained_flora] gained flora, [changed_turf] turfs retyped, [changed_below] turfs below retyped")

	TEST_ASSERT(length(outside_before) > 0, "The spill area filled its whole bounding box, so no containment was tested")
	TEST_ASSERT(inside_bare <= length(spill_coords) / 10, "[inside_bare] of [length(spill_coords)] in-area cells are neither flora nor water; containment is not under real pressure")
	TEST_ASSERT(inside_water > 0, "No water was generated inside the spill area, so water containment is untested")
	TEST_ASSERT(inside_waterbed > 0, "No lakebed or riverbot was created below the spill area, so the water is not real")
	TEST_ASSERT_EQUAL(gained_flora, 0, "[gained_flora] turfs outside the area gained flora")
	TEST_ASSERT_EQUAL(changed_turf, 0, "[changed_turf] turfs outside the area were retyped")
	TEST_ASSERT_EQUAL(changed_below, 0, "[changed_below] turfs below the area's footprint were retyped")

/datum/unit_test/procgen_forest/Run()
	test_z = find_test_z()
	TEST_ASSERT(test_z, "No z level on this map has both an up and a down link, so the forest generator cannot be tested")
	note("running on z [test_z] of [length(SSmapping.multiz_levels)] linked levels")

	run_grove()
	run_spill()

	fdel("data/procgen_forest_test.txt")
	var/logfile = file("data/procgen_forest_test.txt")
	for(var/line in report)
		logfile << line

