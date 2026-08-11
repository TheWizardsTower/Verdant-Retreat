/datum/unit_test/procgen_cave
	var/list/report = list()
	var/test_z = 0
	var/list/restore_area = list()
	var/passes = 3
	var/water_seen = 0

/datum/unit_test/procgen_cave/proc/note(text)
	report += text

/datum/unit_test/procgen_cave/proc/find_test_z()
	for(var/candidate in 1 to length(SSmapping.multiz_levels))
		var/list/level = SSmapping.multiz_levels[candidate]
		if(level[Z_LEVEL_UP] && level[Z_LEVEL_DOWN])
			return candidate
	return 0

// The level below has to be solid too, or the water generator has no bed to carve a lake into
/datum/unit_test/procgen_cave/proc/fill_walls(x1, y1, x2, y2)
	for(var/x = x1, x <= x2, x++)
		for(var/y = y1, y <= y2, y++)
			for(var/z in list(test_z, test_z - 1))
				var/turf/T = locate(x, y, z)
				if(!T)
					continue
				if(istype(T, /turf/closed/mineral/rogue/bedrock))
					continue
				T.ChangeTurf(/turf/closed/mineral/rogue/bedrock)

/datum/unit_test/procgen_cave/proc/claim_turfs(area/procedural_generation/target, list/coords)
	var/list/claimed = list()
	for(var/list/coord as anything in coords)
		var/turf/T = locate(coord[1], coord[2], test_z)
		if(!T)
			continue
		var/area/old_area = T.loc
		if(!restore_area["[T.x]-[T.y]"])
			restore_area["[T.x]-[T.y]"] = old_area
		target.contents += T
		T.change_area(old_area, target)
		claimed += T
	return claimed

/datum/unit_test/procgen_cave/proc/release_turfs(list/turfs)
	for(var/turf/T as anything in turfs)
		var/area/original = restore_area["[T.x]-[T.y]"]
		if(!original)
			continue
		var/area/current = T.loc
		if(current == original)
			continue
		original.contents += T
		T.change_area(current, original)

/datum/unit_test/procgen_cave/proc/rect_coords(x1, y1, x2, y2)
	var/list/out = list()
	for(var/x = x1, x <= x2, x++)
		for(var/y = y1, y <= y2, y++)
			out += list(list(x, y))
	return out

/datum/unit_test/procgen_cave/proc/crescent_coords(center_x, center_y, outer, inner)
	var/list/out = list()
	for(var/x = center_x - outer, x <= center_x + outer, x++)
		for(var/y = center_y - outer, y <= center_y, y++)
			var/distance = sqrt((x - center_x) ** 2 + (y - center_y) ** 2)
			if(distance > outer || distance < inner)
				continue
			out += list(list(x, y))
	return out

/datum/unit_test/procgen_cave/proc/region_sizes(list/cells)
	var/list/pending = cells.Copy()
	var/list/sizes = list()
	while(length(pending))
		var/list/frontier = list(pending[1])
		pending -= pending[1]
		var/size = 0
		var/cursor = 1
		while(cursor <= length(frontier))
			var/key = frontier[cursor++]
			size++
			var/list/coords = splittext(key, "-")
			var/cx = text2num(coords[1])
			var/cy = text2num(coords[2])
			for(var/list/offset as anything in list(list(1, 0), list(-1, 0), list(0, 1), list(0, -1)))
				var/neighbor_key = "[cx + offset[1]]-[cy + offset[2]]"
				if(isnull(pending[neighbor_key]))
					continue
				pending -= neighbor_key
				frontier += neighbor_key
		sizes += size
	sortTim(sizes, /proc/cmp_numeric_dsc)
	return sizes

/datum/unit_test/procgen_cave/proc/run_case(label, list/coords, area_path)
	var/low_x = world.maxx
	var/low_y = world.maxy
	var/high_x = 1
	var/high_y = 1
	for(var/list/coord as anything in coords)
		low_x = min(low_x, coord[1])
		low_y = min(low_y, coord[2])
		high_x = max(high_x, coord[1])
		high_y = max(high_y, coord[2])

	fill_walls(low_x, low_y, high_x, high_y)

	var/list/inside = list()
	for(var/list/coord as anything in coords)
		inside["[coord[1]]-[coord[2]]"] = TRUE

	var/list/outside_before = list()
	for(var/x = low_x, x <= high_x, x++)
		for(var/y = low_y, y <= high_y, y++)
			if(inside["[x]-[y]"])
				continue
			var/turf/T = locate(x, y, test_z)
			if(!T)
				continue
			var/turf/below = locate(x, y, test_z - 1)
			outside_before["[x]-[y]"] = list(T.type, below ? below.type : null)

	var/area/procedural_generation/cave/subject = new area_path
	var/list/claimed = claim_turfs(subject, coords)

	subject.setup_procgen()

	var/list/carved = list()
	for(var/list/coord as anything in coords)
		var/turf/T = locate(coord[1], coord[2], test_z)
		if(T && !iswall(T))
			carved["[coord[1]]-[coord[2]]"] = TRUE

	var/changed_outside = 0
	var/changed_below = 0
	for(var/key in outside_before)
		var/list/coord = splittext(key, "-")
		var/turf/T = locate(text2num(coord[1]), text2num(coord[2]), test_z)
		var/turf/below = locate(text2num(coord[1]), text2num(coord[2]), test_z - 1)
		var/list/before = outside_before[key]
		if(T.type != before[1])
			changed_outside++
		if((below ? below.type : null) != before[2])
			changed_below++

	var/water = 0
	for(var/list/coord as anything in coords)
		if(istype(locate(coord[1], coord[2], test_z), /turf/open/transparent/openspace))
			water++

	var/list/sizes = region_sizes(carved)

	note("[label]: [length(coords)] cells in area, [length(outside_before)] cells in the bounding box but outside it")
	note("[label]: carved [length(carved)] ([round(length(carved) * 100 / length(coords))]%), [water] water, [length(sizes)] separate open regions, largest [length(sizes) ? sizes[1] : 0]")
	note("[label]: outside -> [changed_outside] turfs retyped, [changed_below] turfs below retyped")

	release_turfs(claimed)
	SSprocgen.fluid_cells.Cut()
	SSprocgen.mimic_turfs.Cut()

	return list("carved" = length(carved), "cells" = length(coords), "regions" = length(sizes), "largest" = length(sizes) ? sizes[1] : 0, "outside" = changed_outside, "below" = changed_below, "water" = water, "keys" = carved)

/datum/unit_test/procgen_cave/proc/run_crescent(pass)
	var/list/coords = crescent_coords(85, 100, 17, 10)
	var/list/stats = run_case("crescent #[pass]", coords, /area/procedural_generation/cave/test)

	TEST_ASSERT(stats["cells"] > 200, "The crescent test shape only has [stats["cells"]] cells, too small to test anything")
	TEST_ASSERT_EQUAL(stats["outside"], 0, "[stats["outside"]] turfs outside the crescent were retyped")
	TEST_ASSERT_EQUAL(stats["below"], 0, "[stats["below"]] turfs below the crescent's bounding box were retyped")
	TEST_ASSERT(stats["carved"] > 0, "Nothing was carved inside the crescent")
	TEST_ASSERT_EQUAL(stats["regions"], 1, "The crescent generated [stats["regions"]] disconnected open regions; the cave is not navigable end to end")

/datum/unit_test/procgen_cave/proc/run_flooded(pass)
	var/list/coords = crescent_coords(85, 100, 17, 10)
	var/list/stats = run_case("flooded #[pass]", coords, /area/procedural_generation/cave/test/flooded)

	water_seen += stats["water"]

	TEST_ASSERT_EQUAL(stats["outside"], 0, "[stats["outside"]] turfs outside the flooded crescent were retyped")
	TEST_ASSERT_EQUAL(stats["below"], 0, "[stats["below"]] lake bed turfs were carved outside the flooded crescent")
	TEST_ASSERT(stats["carved"] > 0, "Nothing was carved inside the flooded crescent")

/datum/unit_test/procgen_cave/proc/run_islands(pass)
	var/list/west = rect_coords(70, 60, 77, 67)
	var/list/east = rect_coords(90, 60, 97, 67)
	var/list/stats = run_case("islands #[pass]", west + east, /area/procedural_generation/cave/test)

	var/list/carved = stats["keys"]
	var/west_carved = 0
	var/east_carved = 0
	for(var/list/coord as anything in west)
		if(carved["[coord[1]]-[coord[2]]"])
			west_carved++
	for(var/list/coord as anything in east)
		if(carved["[coord[1]]-[coord[2]]"])
			east_carved++

	note("islands #[pass]: west [west_carved]/[length(west)] carved, east [east_carved]/[length(east)] carved")

	TEST_ASSERT_EQUAL(stats["outside"], 0, "[stats["outside"]] turfs between the two islands were retyped")
	TEST_ASSERT(west_carved > 0, "The west island was left completely solid")
	TEST_ASSERT(east_carved > 0, "The east island was left completely solid")
	TEST_ASSERT_EQUAL(stats["regions"], 2, "Two disconnected islands produced [stats["regions"]] open regions")

/datum/unit_test/procgen_cave/proc/run_rectangle(pass)
	var/list/coords = rect_coords(72, 70, 96, 82)
	var/list/stats = run_case("rectangle #[pass]", coords, /area/procedural_generation/cave)

	TEST_ASSERT_EQUAL(stats["outside"], 0, "[stats["outside"]] turfs outside the rectangle were retyped")
	TEST_ASSERT(stats["carved"] > 0, "Nothing was carved inside the rectangle")
	TEST_ASSERT_EQUAL(stats["regions"], 1, "The rectangle generated [stats["regions"]] disconnected open regions")

/datum/unit_test/procgen_cave/Run()
	test_z = find_test_z()
	TEST_ASSERT(test_z, "No z level on this map has both an up and a down link")
	note("running on z [test_z] of [length(SSmapping.multiz_levels)] linked levels")

	for(var/pass in 1 to passes)
		run_rectangle(pass)
		run_islands(pass)
		run_crescent(pass)
		run_flooded(pass)

	// Without this the flooded case still passes its containment asserts while generating no water at all
	TEST_ASSERT(water_seen > 0, "No water was generated across [passes] passes of the flooded crescent, so lake containment is untested")

	fdel("data/procgen_cave_test.txt")
	var/logfile = file("data/procgen_cave_test.txt")
	for(var/line in report)
		logfile << line
