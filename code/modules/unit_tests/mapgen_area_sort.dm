/datum/unit_test/mapgen_area_sort/Run()
	var/list/sorted = list()
	for(var/entry in list(4, 1, 7, 7, 2, 9, 3, 9, 0))
		ADD_SORTED(sorted, entry, /proc/cmp_numeric_dsc)

	TEST_ASSERT_EQUAL(length(sorted), 9, "ADD_SORTED dropped or duplicated entries")
	for(var/i in 2 to length(sorted))
		TEST_ASSERT(sorted[i - 1] >= sorted[i], "ADD_SORTED produced [sorted[i - 1]] before [sorted[i]] at index [i]")

	var/area/high_area
	var/area/low_area
	var/list/area_sorted = list()
	for(var/area/candidate as anything in GLOB.areas)
		if(!candidate.z)
			continue
		if(!high_area || candidate.z > high_area.z)
			high_area = candidate
		if(!low_area || candidate.z < low_area.z)
			low_area = candidate
		ADD_SORTED(area_sorted, candidate, /proc/cmp_area_z_dsc)

	TEST_ASSERT_NOTNULL(high_area, "No area reported a nonzero z, so cmp_area_z_dsc cannot order mapgen areas")
	TEST_ASSERT_NOTEQUAL(high_area.z, low_area.z, "Test map has no areas on differing z levels, ordering is untested")
	TEST_ASSERT(cmp_area_z_dsc(high_area, low_area) < 0, "cmp_area_z_dsc did not rank the higher z area before the lower one")
	TEST_ASSERT(cmp_area_z_dsc(low_area, high_area) > 0, "cmp_area_z_dsc did not rank the lower z area after the higher one")

	for(var/i in 2 to length(area_sorted))
		var/area/earlier = area_sorted[i - 1]
		var/area/later = area_sorted[i]
		TEST_ASSERT(earlier.z >= later.z, "ADD_SORTED with cmp_area_z_dsc put z [earlier.z] ([earlier.type]) before z [later.z] ([later.type])")

	for(var/i in 2 to length(GLOB.mapgen_areas))
		var/area/procedural_generation/earlier = GLOB.mapgen_areas[i - 1]
		var/area/procedural_generation/later = GLOB.mapgen_areas[i]
		TEST_ASSERT(earlier.z >= later.z, "mapgen_areas is not ordered top-down: [earlier.type] at z [earlier.z] precedes [later.type] at z [later.z]")
