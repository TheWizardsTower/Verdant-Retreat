/*
$$\      $$\  $$$$$$\  $$$$$$$\   $$$$$$\  $$$$$$$$\ $$\   $$\
$$$\    $$$ |$$  __$$\ $$  __$$\ $$  __$$\ $$  _____|$$$\  $$ |
$$$$\  $$$$ |$$ /  $$ |$$ |  $$ |$$ /  \__|$$ |      $$$$\ $$ |
$$\$$\$$ $$ |$$$$$$$$ |$$$$$$$  |$$ |$$$$\ $$$$$\    $$ $$\$$ |
$$ \$$$  $$ |$$  __$$ |$$  ____/ $$ |\_$$ |$$  __|   $$ \$$$$ |
$$ |\$  /$$ |$$ |  $$ |$$ |      $$ |  $$ |$$ |      $$ |\$$$ |
$$ | \_/ $$ |$$ |  $$ |$$ |      \$$$$$$  |$$$$$$$$\ $$ | \$$ |
\__|     \__|\__|  \__|\__|       \______/ \________|\__|  \__|

												- By Plasmatik

PORTABLE STANDALONE VERSION - Procedural Map Generation Subsystem
==================================================================

This is a self-contained, portable version of the mapgen subsystem originally
created for IS12 Reborn. It can be dropped into any BYOND codebase and used
independently.

ORIGINAL HEADER:
================
The following code is designed for randomly generating areas on a map. It is based on a modified drunk-walk algorithm, along with Prim's maze generation algorithm.
Instead of using a 2D list, it stores coordinates as a string, and keys their value to a define to determine what they become, e.g., WALL, FLOOR, HOLE
By default, FALSE (0) is a floor, and TRUE(1) is a wall. The defines below allow for generating various turf types, though.

Absolutely all of this was written by me, so I'm declaring it completely open use
Anyone who wants to use this code can use it without attributing me, and I don't care if their code is open or closed source.
Go ahead and sell it if you want, I don't give a fuck.


USAGE INSTRUCTIONS
==================

1) Define an area for your map as a child of the type of procedural generator you want to use (like area/procedural_generation/cave/spooky_caverns)
2) Place that area on the map and fill it with wall turfs
3) Optionally tweak the generation parameters by overriding the defaults, seen below

That's it. The area will now be procedurally generated.


DEPENDENCIES
============
- Requires liquid subsystem if generate_water = TRUE (can be disabled)
- Requires basic BYOND subsystem architecture (master controller)
- Requires standard turf/area hierarchy

ORIGINAL AUTHOR: Plasmatik
LICENSE: Public Domain / Open Use
PORTED: 2026-01-17
*/

#define DIRT 0
#define WALL 1
#define HOLE 2 // pits and water features
#define MUD  3
#define AQUA 4 // aquifers

GLOBAL_LIST_EMPTY(mapgen_areas)

SUBSYSTEM_DEF(procgen)
	name = "Procgen"
	wait = 10
	flags = SS_NO_FIRE
	can_fire = 0

	var/list/fluid_cells = new
	var/list/mimic_turfs = new

/datum/controller/subsystem/procgen/Initialize(start_timeofday)
	SSliquid.can_fire = 0

	for(var/area/procedural_generation/mapgen_area as anything in GLOB.mapgen_areas)
		mapgen_area.setup_procgen()

	for(var/turf/T as anything in fluid_cells)

		T += /datum/liquid/water * 100
	SSliquid.update_fluidsums()
	//SSliquid.update_cell_images()

	for(var/turf/T as anything in mimic_turfs)
		T.update_mimic()

	SSmapping.check_water_bed_seals()

	if(SSnative?.grid_inited)
		var/flush_guard = 0
		while(length(SSnative.dirty_turfs) && flush_guard++ < 1000)
			SSnative.FlushDirty()

	SSliquid.can_fire = 1
	fluid_cells.Cut()
	mimic_turfs.Cut()

	for(var/obj/effect/liquid/liquid_overlay in world)
		liquid_overlay.update_icon()
	SSnoisemap.make_noisemap("aquafer", NOISE_SIMPLEX)

	return ..()

// Parent area type, this should not be placed on the map ever and will probably cause bugs if it is
/area/procedural_generation
	name = "Procedurally Generated Area"
	icon = 'icons/turf/areas.dmi'
	var/list/generation_map = list()
	var/list/turf_map = list()
	var/list/entrances = list()
	var/list/entrance_turfs = list()

	// The bounds of the area to generate, this gets set by iterating inward over turfs on each axis using 3 1D list operations instead of 1 3D list operation
	var/low_x
	var/low_y
	var/low_z
	var/high_x
	var/high_y
	var/high_z

	// Parameters related to water feature generation
	var/min_lake_size = 16
	var/max_lake_size = 64
	var/min_lakes = 3
	var/max_lakes = 6

	var/generate_water = FALSE // Turns on/off generating rivers and lakes, should probably be turned off for any area that doesn't have walls under it. Currently only works for caves

// Initialize the area by adding it to the list of mapgen areas, setting its boundaries and filling the generation map with initial values

/area/procedural_generation/Initialize()
	. = ..()
	ADD_SORTED(GLOB.mapgen_areas, src, /proc/cmp_area_z_dsc) // We start generating areas from the top down to avoid placing features on top of each other

/area/procedural_generation/proc/setup_procgen()
	// Build our boundary first, this lets us do three 1D operations instead of 1 3D operation, which will break early independently upon hitting the area's bounds
	low_x = world.maxx
	low_y = world.maxy
	low_z = world.maxz
	high_x = 1
	high_y = 1
	high_z = 1 // For future use, in case multiz generation is ever added... for some horrible reason

	var/target_z = src.z
	var/offlevel_turfs = 0
	for(var/turf/T in src)
		if(T.z != target_z)
			offlevel_turfs++
			continue
		if(T.x < low_x)
			low_x = T.x
		if(T.y < low_y)
			low_y = T.y
		if(T.x > high_x)
			high_x = T.x
		if(T.y > high_y)
			high_y = T.y
		turf_map["[T.x]-[T.y]"] = TRUE

	low_z = target_z
	high_z = target_z

	if(offlevel_turfs)
		log_mapping("[type] occupies [offlevel_turfs] turfs outside z [target_z]; only z [target_z] will be generated.")

	for(var/x = low_x, x <= high_x, x++)
		for(var/y = low_y, y <= high_y, y++)
			if(!turf_map["[x]-[y]"])
				continue
			var/turf/current_turf = locate(x, y, src.z)
			if(iswall(current_turf))
				// We use a string key for uniqueness, we don't need to worry about memory use
				// Because this will get deallocated immediately after we finish the mapgen
				generation_map["[x]-[y]"] = TRUE

/area/procedural_generation/proc/in_bounds(check_x, check_y)
	return check_x >= low_x && check_x <= high_x && check_y >= low_y && check_y <= high_y

/area/procedural_generation/proc/in_area(check_x, check_y)
	if(check_x < low_x || check_x > high_x || check_y < low_y || check_y > high_y)
		return FALSE
	return !isnull(turf_map["[check_x]-[check_y]"])

/area/procedural_generation/proc/final_pass() // Override this
	return

/area/procedural_generation/proc/apply_generation_map()
	for(var/key in generation_map)
		var/list/coords = splittext(key, "-")
		var/x_coord = text2num(coords[1])
		var/y_coord = text2num(coords[2])
		if(in_bounds(x_coord, y_coord))
			var/turf/destination_turf = locate(x_coord, y_coord, src.z)
			switch(generation_map[key]) // If the coordinate is set to something other than TRUE (1), it means we've carved out a space there, so we change the turf
				if(DIRT) // FALSE
					if(destination_turf && iswall(destination_turf))
						destination_turf.ChangeTurf(/turf/open/floor/rogue/dirt)

				if(HOLE)
					var/turf/destination_turf_below = GetBelow(destination_turf)
					if(generate_water == TRUE)
						if(destination_turf && destination_turf_below && iswall(destination_turf_below))
							destination_turf_below.ChangeTurf(/turf/open/floor/rogue/dirt)
							SSprocgen.fluid_cells += destination_turf_below
					else
						destination_turf_below.ChangeTurf(/turf/open/floor/rogue/dirt)
					destination_turf.ChangeTurf(/turf/open/transparent/openspace)
					SSprocgen.mimic_turfs += destination_turf

				if(MUD)
					if(destination_turf && iswall(destination_turf))
						destination_turf.ChangeTurf(/turf/open/floor/rogue/dirt)

				if(AQUA)
					destination_turf.ChangeTurf(/turf/open/floor/rogue/dirt)
					SSprocgen.fluid_cells += destination_turf

/area/procedural_generation/proc/update_fluid_amounts(list/fluid_cells)


/area/procedural_generation/proc/update_mimics(list/mimics)
	for(var/turf/T as anything in mimics)
		T.update_mimic()

/area/procedural_generation/proc/generate_probes() // This is for creating sound probes to tell clients what sound environments to apply when they recieve playsound calls. It should be overridden based on the mapgen type.
	return
/*
   ____
  / ___|__ ___   _____  ___
 | |   / _` \ \ / / _ \/ __|
 | |__| (_| |\ V /  __/\__ \
  \____\__,_| \_/ \___||___/

These are cave systems generated using a series of tuned drunk-walk algorithms. Generator variables will greatly impact the layout of the resulting area.
It starts by creating a series of caverns, then creating a series of tunnels that may or may not branch off of the caverns.
It then does a second pass to ensure there is a navigable path through the cave and that all entrances are connected to the nearest cavern.

These notes should help get the map to generate in a shape you want:

- The generator will remain constrained to the area's bounds, so if you set the maxes too high for the size of the area, you'll get very inconsistent terrain features
- The default numbers are tuned to generate caverns that are slightly larger than the viewport within a 100x100 tile area
- Fewer, larger caverns will create big open areas with fewer intersections
- Many, smaller caverns will leave more room for tunnels to generate and create more complex intersections
- Tunnel width causes the drunk walk to meander around while carving out tunnels, but may not ensure that tunnels will have a certain width. It just makes it more likely. Set the minimum and maximum to the same amount to reduce the variation
- Tunnels, entrance paths and branches appear similar and are designed to intersect, so it may be unclear what pathways were generated by what proc (just experiment or something idk)
- If generating lakes, they will use caverns as their centers - you want to have more caverns than lakes, or the cave might be mostly water
*/

/area/procedural_generation/cave
	var/list/cavern_centers = list()

// Various tuning knobs for different things in cave generation
// Keep in mind that min_counts and max_counts for individual terrain features are not entirely accurate here
// This is because the total number of terrain features in the generation map is limited by the size of the area to prevent overlapping
// Caverns generate first, followed by tunnels, then branches, so if you create more / larger caverns you will get fewer tunnels and branches

	var/smooth_edges = FALSE // Turns on/off edge smoothing, which carves out tiles that don't have enough neighbors to give caves a rounder appearance
	var/smooth_amount = 1 // Determines how many times the edge smoothing algorithm gets run, more times means smoother caves but may result in boring layouts

	// Tuning branches, these allow for connecting pathways from entrances to occasionally intersect with tunnels and tend to create three-way intersections (fun for gameplay, either combat or exploration)

	var/branch_chance = 15
	var/max_branches = 20
	var/max_branch_length = 8
	var/min_branch_length = 2

	// Tuning caverns, these are larger spaces created with a recursive drunk-walking algorithm that walks around in a circle. Caverns are used as nodes for tunnels and connecting paths.

	var/min_caverns = 1
	var/max_caverns = 10
	var/max_cavern_size = 32
	var/min_cavern_size = 12

	// Tuning tunnels, these are long, narrow cave sections that use a biased drunk walk algorithm that makes random turns. They use caverns as starting nodes and randomly intersect with other caverns or tunnels.
	// Depending on the generation settings, these will create more or less dead ends.

	var/max_tunnels = 64
	var/min_tunnels = 12
	var/max_tunnel_length = 20
	var/min_tunnel_length = 3
	var/max_tunnel_width = 3
	var/min_tunnel_width = 2

/area/procedural_generation/cave/setup_procgen()
	..()
	// Generate separate caverns and winding passages
	generate_caverns()
	generate_tunnels()
	// Ensure there is a path connecting the entrance to every cavern center
	setup_connections()
	// Post process to clean up things we don't want or add things we do
	final_pass()
	// Actually apply our generation map
	apply_generation_map()
	// Generate sound probes
	generate_probes()

	// Empty everything from memory now that we don't need it anymore
	generation_map.Cut()
	turf_map.Cut()
	cavern_centers.Cut()

/area/procedural_generation/cave/final_pass()
	if(smooth_edges == TRUE)
		for(var/i = 1, i >= smooth_amount, i++)
			for(var/turf/T in src)
				if(iswall(T))
					var/ortho_walls = 0
					var/diag_walls = 0
					for(var/dir in GLOB.cardinals)
						var/turf/neighbor = get_turf(get_step(T, dir))
						if(iswall(neighbor))
							ortho_walls++
					for(var/dir in GLOB.diagonals)
						var/turf/neighbor = get_turf(get_step(T, dir))
						if(iswall(neighbor))
							diag_walls++
					if(ortho_walls == 0 && diag_walls == 1 || ortho_walls == 0 && diag_walls == 0)
						generation_map["[T.x]-[T.y]"] = FALSE

	if(generate_water == TRUE)
		generate_water()
		smooth_lakes()
		muddy_shorelines()
/*
/area/procedural_generation/cave/generate_probes()
	for(var/coord in cavern_centers)
		var/turf/soundturf = locate(coord[1], coord[2], src.z)
		var/obj/effect/landmark/sound_probe/probe = new(soundturf, 8)
		probe.//sound_env = 8
*/

// Customized drunk-walk algorithm for cavern generation
/area/procedural_generation/cave/proc/generate_caverns()
	var/current_x, current_y
	for(var/i in min_caverns to max_caverns)
		current_x = rand(low_x, high_x)
		current_y = rand(low_y, high_y)

		var/cavern_size = rand(min_cavern_size, max_cavern_size)
		for(var/j in 1 to cavern_size)
			for(var/rx in -1 to 1)
				for(var/ry in -1 to 1)
					var/nx = clamp(current_x + rx, low_x, high_x)
					var/ny = clamp(current_y + ry, low_y, high_y)
					var/adjacent_key = "[nx]-[ny]"
					generation_map[adjacent_key] = FALSE

			// Randomly move to a new position to continue generating the cavern
			current_x = clamp(current_x + rand(-2, 2), low_x, high_x)
			current_y = clamp(current_y + rand(-2, 2), low_y, high_y)

		// Add the center to the cavern_centers list
		cavern_centers += list(list(current_x, current_y))

// Customized tunneling algorithm for... tunnel generation
/area/procedural_generation/cave/proc/generate_tunnels()
	var/current_x, current_y
	var/tunnels = rand(min_tunnels, max_tunnels)
	for(var/i in 1 to tunnels)
		// Start at a random position, preferably on an existing cavern to ensure connectivity
		var/start_position = length(cavern_centers) ? pick(cavern_centers) : list(rand(low_x, high_x), rand(low_y, high_y))
		current_x = start_position[1]
		current_y = start_position[2]

		var/tunnel_length = rand(min_tunnel_length, max_tunnel_length)
		var/tunnel_width = rand(min_tunnel_width, max_tunnel_width)
		for(var/j in 1 to tunnel_length)
			// Choose a direction weighted towards uncarved spaces
			var/chosen_direction = pick(GLOB.cardinals)

			// Carve the tunnel by setting the map location to FALSE, considering the width
			for(var/w = -Floor(tunnel_width/2); w <= Floor(tunnel_width/2); w++)
				var/width_x = current_x
				var/width_y = current_y

				// Apply width offset based on the direction
				switch(chosen_direction)
					if(NORTH)
						width_x += w
					if(SOUTH)
						width_x += w
					if(EAST)
						width_y += w
					if(WEST)
						width_y += w

				var/key = "[width_x]-[width_y]"
				generation_map[key] = FALSE

			// Move in the chosen direction
			switch(chosen_direction)
				if(NORTH)
					if((current_y + 1) <= high_y)
						current_y++
				if(SOUTH)
					if((current_y - 1) >= low_y)
						current_y--
				if(EAST)
					if((current_x + 1) <= high_x)
						current_x++
				if(WEST)
					if((current_x - 1) >= low_x)
						current_x--

// This checks to make sure the entrance turf is accessible
/area/procedural_generation/cave/proc/setup_connections()
	for(var/list/entrance as anything in entrances)
		var/turf/entrance_turf = locate(entrance[1], entrance[2], entrance[3])
		entrance_turfs += entrance_turf
		if(iswall(entrance))
			entrance_turf.ChangeTurf(/turf/open/floor/rogue/dirt)

	// Now connect the entrances to the nearest cavern
	connect_entrances()
	// And connect caverns to each other
	connect_caverns()

/area/procedural_generation/cave/proc/connect_entrances()
	for(var/list/entrance as anything in entrances)
		var/start_x = entrance[1]
		var/start_y = entrance[2]
		var/min_distance = INFINITY
		var/list/nearest_cavern_center
		for(var/list/cavern_center as anything in cavern_centers)
			var/distance = get_chebyshev_distance(start_x, start_y, cavern_center[1], cavern_center[2])
			if(distance < min_distance)
				min_distance = distance
				nearest_cavern_center = cavern_center

		generate_path(start_x, start_y, nearest_cavern_center[1], nearest_cavern_center[2])

// This connects the entrance to the nearest cavern, then connects that cavern to the cavern closest to it, and so on, until every cavern is connected
/area/procedural_generation/cave/proc/connect_caverns()
	var/list/local_cavern_centers = src.cavern_centers.Copy()
	var/list/start = local_cavern_centers[1]
	var/start_x = start[1]
	var/start_y = start[2]

	// Loop through all cavern centers to connect them
	var/overloops = 0
	while(length(local_cavern_centers))
		overloops++
		var/min_distance = INFINITY
		var/list/nearest_cavern_center
		var/nearest_cavern_index

		// Find the nearest cavern center to the current point (entrance or last connected center)
		for(var/i in 1 to length(local_cavern_centers))
			var/list/center = local_cavern_centers[i]
			var/distance = get_chebyshev_distance(start_x, start_y, center[1], center[2])
			if(distance < min_distance)
				min_distance = distance
				nearest_cavern_center = center
				nearest_cavern_index = i

		generate_path(start_x, start_y, nearest_cavern_center[1], nearest_cavern_center[2])

		for(var/list/center as anything in local_cavern_centers)
			if(prob(branch_chance))
				var/branch_length = rand(min_branch_length, max_branch_length)
				create_branch(center[1], center[2], pick(GLOB.cardinals), branch_length)
		// Update the starting point to the last connected cavern center
		start_x = nearest_cavern_center[1]
		start_y = nearest_cavern_center[2]

		// Remove the connected cavern center from the list
		local_cavern_centers.Cut(nearest_cavern_index, nearest_cavern_index + 1)

		if(overloops > 1000)
			throw EXCEPTION("Infinite loop detected in procedural_generation/connect_entrances_and_caverns!")

/area/procedural_generation/cave/proc/create_branch(start_x, start_y, direction, length)
	for(var/i in 1 to length)
		var/key = "[start_x]-[start_y]"
		generation_map[key] = FALSE  // Carve out the path

		// Move in the chosen direction
		switch(direction)
			if(NORTH)
				start_y++
			if(SOUTH)
				start_y--
			if(EAST)
				start_x++
			if(WEST)
				start_x--

		// Randomly change the direction slightly to create a more natural branch
		if(prob(30))
			direction = pick(GLOB.cardinals)

// The actual path generation for connections is a modified drunk-walk algorithm
/area/procedural_generation/proc/generate_path(start_x, start_y, end_x, end_y, randomness = 40)
	while(start_x != end_x || start_y != end_y)
		var/key = "[start_x]-[start_y]"
		generation_map[key] = FALSE  // Carve the path

		// Calculate the direction vector towards the goal
		var/delta_x = end_x - start_x
		var/delta_y = end_y - start_y
		var/step_x = delta_x ? delta_x / abs(delta_x) : 0  // Normalize the step to be 1, -1, or 0
		var/step_y = delta_y ? delta_y / abs(delta_y) : 0

		if(prob(randomness))
			// Random direction
			var/chosen_direction = pick(GLOB.cardinals)
			switch(chosen_direction)
				if(NORTH)
					if((start_y + 1) <= high_y)
						start_y++
				if(SOUTH)
					if((start_y - 1) >= low_y)
						start_y--
				if(EAST)
					if((start_x + 1) <= high_x)
						start_x++
				if(WEST)
					if((start_x - 1) >= low_x)
						start_x--
		else
			// Biased movement towards the goal
			var/move_x = rand() < abs(delta_x) / (abs(delta_x) + abs(delta_y))
			if(move_x)
				start_x += step_x
			else
				start_y += step_y
/*
  __  __    _     __________ ____
 |  \/  |  / \   |__  / ____/ ___|
 | |\/| | / _ \    / /|  _| \___ \
 | |  | |/ ___ \  / /_| |___ ___) |
 |_|  |_/_/   \_\/____|_____|____/

These are mazes generated using Prim's algorithm. This creates perfect mazes instead of complex mazes, which means they have only one solution and all other branches lead to dead ends.
This is an evil "get fucked" type of maze and should be placed in relatively small areas unless you want to make someone suffer.
*/

/area/procedural_generation/maze
	//sound_env = 13 // STONE CORRIDOR

/area/procedural_generation/maze/setup_procgen()
	..()
	generate_maze()
	apply_generation_map()
	generation_map.Cut()
	turf_map.Cut()

/area/procedural_generation/maze/proc/generate_maze()
	var/list/entrance = entrances[1]
	var/entrance_x = entrance[1]
	var/entrance_y = entrance[2]
	var/entrance_key = "[entrance_x]-[entrance_y]"
	generation_map[entrance_key] = FALSE
	var/list/frontier = list()

	// Initialize frontier using the entrance
	for(var/dx = -1, dx <= 1, dx += 1)
		for(var/dy = -1, dy <= 1, dy += 1)
			if(abs(dx) != abs(dy))  // Exclude diagonals and self
				var/wall_x = entrance_x + dx
				var/wall_y = entrance_y + dy
				var/wall_key = "[wall_x]-[wall_y]"
				if(in_bounds(wall_x, wall_y) && generation_map[wall_key] == TRUE)
					frontier += wall_key

	// While there are frontiers, continue to carve out the maze
	while(length(frontier))
		var/random_index = rand(1, length(frontier))
		var/wall_key = frontier[random_index]
		frontier.Cut(random_index, random_index + 1)
		var/list/wall_coords = splittext(wall_key, "-")
		var/wall_x = text2num(wall_coords[1])
		var/wall_y = text2num(wall_coords[2])

		// Determine the cell that this wall divides from the maze
		var/list/directions = list("NORTH" = list(0, -1), "SOUTH" = list(0, 1), "EAST" = list(1, 0), "WEST" = list(-1, 0))
		var/visited_cells = 0
		for(var/dir in directions)
			var/modifier = directions[dir]
			var/check_x = wall_x + modifier[1]
			var/check_y = wall_y + modifier[2]
			var/check_key = "[check_x]-[check_y]"
			if(in_bounds(check_x, check_y))
				if(generation_map[check_key] == FALSE)
					visited_cells++

		if(visited_cells == 1)  // Only if exactly one of the two cells divided by the wall is visited
			generation_map[wall_key] = FALSE // Carve the wall
			// Add the neighboring walls of the newly added cell to the frontier
			for(var/dx = -1, dx <= 1, dx += 1)
				for(var/dy = -1, dy <= 1, dy += 1)
					if(abs(dx) != abs(dy))  // Exclude diagonals and self
						var/new_x = wall_x + dx
						var/new_y = wall_y + dy
						var/new_wall_key = "[new_x]-[new_y]"
						if(in_bounds(new_x, new_y) && generation_map[new_wall_key] == TRUE)
							frontier += new_wall_key  // Add to frontier if it's a wall

		// Repeat the process for the exit, ensuring it's connected to the maze.
		var/list/exit = entrances[2]
		var/exit_x = exit[1]
		var/exit_y = exit[2]
		var/exit_key = "[exit_x]-[exit_y]"
		if(generation_map[exit_key] == TRUE)  // If the exit is not carved out, connect it
			var/list/adjacent_cells = list()
			for(var/dx = -1, dx <= 1, dx += 1)
				for(var/dy = -1, dy <= 1, dy += 1)
					if(abs(dx) != abs(dy))  // Exclude diagonals and self
						var/adj_x = exit_x + dx
						var/adj_y = exit_y + dy
						var/adj_key = "[adj_x]-[adj_y]"
						if(in_bounds(adj_x, adj_y) && generation_map[adj_key] == TRUE)
							adjacent_cells += adj_key

			if(length(adjacent_cells))
				var/connecting_cell_key = adjacent_cells[rand(1, length(adjacent_cells))]
				var/list/connecting_wall_coords = splittext(connecting_cell_key, "-")
				var/connecting_wall_x = text2num(connecting_wall_coords[1])
				var/connecting_wall_y = text2num(connecting_wall_coords[2])
				var/connecting_wall_key = "[connecting_wall_x]-[connecting_wall_y]"
				// Carve out the wall between the exit and the maze
				generation_map[connecting_wall_key] = FALSE

				// Add the neighboring walls of the exit cell to the frontier
				for(var/dx = -1, dx <= 1, dx += 1)
					for(var/dy = -1, dy <= 1, dy += 1)
						if(abs(dx) != abs(dy))  // Exclude diagonals and self
							var/new_x = connecting_wall_x + dx
							var/new_y = connecting_wall_y + dy
							var/new_wall_key = "[new_x]-[new_y]"
							if(in_bounds(new_x, new_y) && generation_map[new_wall_key] == TRUE && (new_wall_key in frontier))
								frontier |= new_wall_key  // Add to frontier if it's a wall
/*
 __        ___  _____ _____ ____
 \ \      / / \|_   _| ____|  _ \
  \ \ /\ / / _ \ | | |  _| | |_) |
   \ V  V / ___ \| | | |___|  _ <
	\_/\_/_/   \_\_| |_____|_| \_\

This is for generating terrain features that have water in them, like lakes or rivers.

Lakes are generated by scattering a random number of seeds around a center point and drunk walking around each of them.
Gaps between the scattered points are then filled in to ensure that they are contiguous.

Notes about water generation:

- Due to the second pass that connects the scatter points, the wider your scatter_range and the higher your scatter_points in create_lake_at, the bigger your lakes will be, regardless of lake_size
- Since scatter variables get randomized, they are not defined as variables of the area. Just modify the numbers in the proc itself, or create an override for your specific area if you'd prefer (sorry)
- Lake generation will tend to skip caverns that are too small, so if you set the mins too high, you will end up with small caverns of land and huge caverns of water
- Rivers are not yet implemented, as I have concerns about needlessly hogging performance; this will be addressed at some point, but for now, I'm planning to fake it if I can
- Water feature generation for different types of areas should be handled differently, so the procs are designed as parent overrides. Currently though, only caves are implemented

*/

/area/procedural_generation/proc/generate_water()
	return

/area/procedural_generation/proc/can_place_lake(list/central_point, lake_size)
	return

/area/procedural_generation/proc/create_lake_at(list/central_point, lake_size)
	return

/area/procedural_generation/cave/generate_water()
	var/list/pick_from_caverns = cavern_centers.Copy()
	var/lakes = rand(min_lakes, max_lakes)
	for(var/i in 1 to lakes)
		var/list/central_point = pick(pick_from_caverns)
		var/lake_size = curved_rand(min_lake_size, max_lake_size)
		if(can_place_lake(central_point, lake_size)) // This only helps us determine if there are suitable wall turfs directly under the cavern, it does not account for the size of the entire lake
			create_lake_at(central_point, lake_size)
			pick_from_caverns -= central_point

/area/procedural_generation/cave/can_place_lake(list/central_point, lake_size)
	var/cx = central_point[1]
	var/cy = central_point[2]
	var/lake_radius = sqrt(lake_size / M_PI)
	var/edge_threshold = 0.8 // How close to the radius the tile must be to be considered an edge tile (0 to 1, with 1 being at the exact radius)

	for(var/dx = -lake_radius, dx <= lake_radius, dx++)
		for(var/dy = -lake_radius, dy <= lake_radius, dy++)
			var/distance_squared = dx * dx + dy * dy
			if(distance_squared > lake_radius * lake_radius) // Check if the tile is outside the circle
				continue // Skip this iteration as this tile is outside of the lake's circular area

			var/turf/below_turf = GetBelow(locate(cx + dx, cy + dy, low_z))
			if(!below_turf || !iswall(below_turf)) // Check if below turf is a wall and exists
				return FALSE

			// Check if the tile is on the edge of the circle
			if(distance_squared >= (lake_radius * edge_threshold) * (lake_radius * edge_threshold))
				var/list/neighbors = below_turf.Adjacent()
				for(var/turf/below_neighbor in neighbors)
					if(!iswall(below_neighbor)) // Check if neighbor turfs are walls
						return FALSE
	return TRUE

/area/procedural_generation/cave/create_lake_at(central_point, lake_size)
	var/attempts = 0
	var/max_attempts = 50
	var/lake_generated = FALSE
	var/list/lake_points
	var/list/edge_points

	while(!lake_generated && attempts < max_attempts)
		attempts++
		lake_points = list(central_point) // Initialize lake_points
		edge_points = list(central_point) // Initialize edge_points with central_point

		// Define a scattering range around the central point
		var/scatter_range = round(rand(lake_size/8, lake_size/6))

		// Scatter several points around the central point
		var/scatter_points = rand(2, 5)
		for(var/i in 1 to scatter_points)
			var/scatter_x = central_point[1] + rand(-scatter_range, scatter_range)
			var/scatter_y = central_point[2] + rand(-scatter_range, scatter_range)
			edge_points += list(list(scatter_x, scatter_y)) // Add point to edge_points list

		var/iterations = 0
		while(length(lake_points) < lake_size && iterations < 1000)
			iterations++
			var/list/new_edge_points = list()
			for(var/point in edge_points)
				var/current_x = point[1]
				var/current_y = point[2]

				// Loop through surrounding tiles
				for(var/adj_x in -1 to 1)
					for(var/adj_y in -1 to 1)
						if(adj_x == 0 && adj_y == 0)
							continue // Skip the center point
						var/new_x = current_x + adj_x
						var/new_y = current_y + adj_y
						var/list/new_point = list(new_x, new_y)

						// Add point to lake_points and new_edge_points if it's not already there
						if(!(new_point in lake_points))
							lake_points += list(new_point)
							new_edge_points += list(new_point)

			edge_points = new_edge_points // Update edge points for next expansion

		// Use flood-fill to check if a cohesive lake has formed
		if(length(lake_points) >= lake_size)
			lake_generated = TRUE
			// Update the map with lake and mud tiles
			for(var/point in lake_points)
				var/list/coord = point
				var/key = "[coord[1]]-[coord[2]]"
				generation_map[key] = HOLE
		else
			log_debug("Failed to create a cohesive lake or not enough points: [length(lake_points)] after [attempts] attempts.")

	if(!lake_generated)
		log_debug("Failed to generate a lake after [max_attempts] attempts.")

/area/procedural_generation/proc/muddy_shorelines()
	for(var/key in generation_map)
		var/list/coords = splittext(key, "-")
		var/x_coord = text2num(coords[1])
		var/y_coord = text2num(coords[2])
		if(generation_map[key] != HOLE && generation_map[key] != TRUE)
			var/adjacent_open = FALSE
			for(var/dx = -1, dx <= 1, dx++)
				for(var/dy = -1, dy <= 1, dy++)
					if(dx == 0 && dy == 0)
						continue
					var/adj_key = "[x_coord + dx]-[y_coord + dy]"
					if(generation_map[adj_key] == HOLE)
						adjacent_open = TRUE
						break
				if(adjacent_open)
					break

			if(adjacent_open)
				generation_map[key] = MUD

/area/procedural_generation/proc/smooth_lakes(connection_range = 3)
	var/list/open_turfs = list()
	var/list/checked_turfs = list()
	var/max_attempts = 10

	for(var/key in generation_map)
		if(generation_map[key] == HOLE)
			open_turfs += key

	for(var/key in open_turfs)
		if(key in checked_turfs) // Skip already checked turfs
			continue

		var/list/coords = splittext(key, "-")
		var/x_coord = text2num(coords[1])
		var/y_coord = text2num(coords[2])

		for(var/other_key in open_turfs - key)
			var/list/other_coords = splittext(other_key, "-")
			var/other_x = text2num(other_coords[1])
			var/other_y = text2num(other_coords[2])

			var/distance = sqrt((other_x - x_coord) ** 2 + (other_y - y_coord) ** 2)
			if(distance <= connection_range)
				for(var/i in 1 to max_attempts)
					if(connect_lake_turfs(x_coord, y_coord, other_x, other_y))
						break

		checked_turfs += key // Mark this turf as checked

/area/procedural_generation/proc/connect_lake_turfs(start_x, start_y, end_x, end_y, min_width = 1, max_width = 3, meander_chance = 30)
	var/current_x = start_x
	var/current_y = start_y
	var/list/try_keys = list()

	while(current_x != end_x || current_y != end_y)
		// Calculate the direction vector towards the goal
		var/delta_x = end_x - current_x
		var/delta_y = end_y - current_y
		var/step_x = delta_x ? delta_x / abs(delta_x) : 0  // Normalize the step to be 1, -1, or 0
		var/step_y = delta_y ? delta_y / abs(delta_y) : 0

		// Decide if this step will meander
		if(prob(meander_chance))
			// Random direction
			step_x = rand(-1, 1)
			step_y = rand(-1, 1)
		else
			// Biased movement towards the goal
			var/move_x = rand() < abs(delta_x) / (abs(delta_x) + abs(delta_y))
			if(move_x)
				current_x += step_x
			else
				current_y += step_y

		// Ensure we're still within bounds
		current_x = clamp(current_x, low_x, high_x)
		current_y = clamp(current_y, low_y, high_y)

		// Carve out a path with variable thickness
		var/path_width = rand(min_width, max_width)
		for(var/wx = -path_width, wx <= path_width, wx++)
			for(var/wy = -path_width, wy <= path_width, wy++)
				// The actual offset from the center of the path
				var/offset_x = current_x + wx
				var/offset_y = current_y + wy

				// Ensure the offsets are within bounds and create a rounded path
				if(abs(wx) + abs(wy) <= path_width && in_bounds(offset_x, offset_y))
					var/key = "[offset_x]-[offset_y]"
					try_keys[key] = HOLE // Carve the path with water

		// Check if we've reached the goal
		if(current_x == end_x && current_y == end_y)
			for(var/key in try_keys)
				generation_map[key] = try_keys[key]
				generation_map[key] = HOLE
			return TRUE
		else
			return FALSE

/area/procedural_generation/aquifer
	generate_water = TRUE
	var/min_aquifers = 8
	var/max_aquifers = 15
	var/min_aquifer_size = 8
	var/max_aquifer_size = 16
	var/list/aquifer_centers = new

/area/procedural_generation/aquifer/setup_procgen()
	..()
	generate_aquifers()
	apply_generation_map()
	generate_probes()
	generation_map.Cut()
	turf_map.Cut()
	aquifer_centers.Cut()

/*
/area/procedural_generation/aquifer/generate_probes()
	for(var/coord in aquifer_centers)
		var/turf/soundturf = locate(coord[1], coord[2], src.z)
		var/obj/effect/landmark/sound_probe/probe = new(soundturf, 8)
		probe.//sound_env = 8
*/
/area/procedural_generation/aquifer/proc/generate_aquifers()
	var/current_x, current_y
	for(var/i in min_aquifers to max_aquifers)
		current_x = rand(low_x, high_x)
		current_y = rand(low_y, high_y)

		var/aquifer_size = rand(min_aquifer_size, max_aquifer_size)
		for(var/j in 1 to aquifer_size)
			for(var/rx in -1 to 1)
				for(var/ry in -1 to 1)
					var/nx = clamp(current_x + rx, low_x, high_x)
					var/ny = clamp(current_y + ry, low_y, high_y)
					var/adjacent_key = "[nx]-[ny]"
					generation_map[adjacent_key] = AQUA

			// Randomly move to a new position to continue generating the cavern
			current_x = clamp(current_x + rand(-2, 2), low_x, high_x)
			current_y = clamp(current_y + rand(-2, 2), low_y, high_y)

		// Add the center to the cavern_centers list
		aquifer_centers += list(list(current_x, current_y))

/area/procedural_generation/river
	generate_water = TRUE
	var/source_x
	var/source_y
	var/mouth_x
	var/mouth_y
	var/min_river_width
	var/max_river_width
	var/curvature

/area/procedural_generation/river/setup_procgen()
	..()
	generate_river()
	apply_generation_map()
	generation_map.Cut()
	turf_map.Cut()

/area/procedural_generation/river/proc/generate_river()
    var/current_x = source_x
    var/current_y = source_y

    // Carve out a path for the river
    while(current_x != mouth_x || current_y != mouth_y)
        carve_river_path(current_x, current_y, min_river_width, max_river_width)

        // Determine the next step toward the river mouth, with possible meandering
        var/delta_x = mouth_x - current_x
        var/delta_y = mouth_y - current_y
        var/step_x = delta_x ? delta_x / abs(delta_x) : 0
        var/step_y = delta_y ? delta_y / abs(delta_y) : 0

        // Decide if this step will meander
        if(prob(curvature))
            step_x = rand(-1, 1)
            step_y = rand(-1, 1)

        // Attempt to move toward the mouth, while staying in bounds
        current_x = clamp(current_x + step_x, low_x, high_x)
        current_y = clamp(current_y + step_y, low_y, high_y)

    // Carve the final approach to the mouth
    carve_river_path(mouth_x, mouth_y, min_river_width, max_river_width)

// Helper method to carve out the river path
/area/procedural_generation/river/proc/carve_river_path(current_x, current_y, min_width, max_width)
	var/path_width = rand(min_width, max_width)
	for(var/wx = -path_width; wx <= path_width; wx++)
		for(var/wy = -path_width; wy <= path_width; wy++)
			var/offset_x = current_x + wx
			var/offset_y = current_y + wy
			if(in_bounds(offset_x, offset_y) && abs(wx) + abs(wy) <= path_width)
				var/river_key = "[offset_x]-[offset_y]"
				generation_map[river_key] = HOLE // Carve the river path

/*
  _____ ___  ____  _____ ____ _____
 |  ___/ _ \|  _ \| ____/ ___|_   _|
 | |_ | | | | |_) |  _| \___ \ | |
 |  _|| |_| |  _ <| |___ ___) || |
 |_|   \___/|_| \_\_____|____/ |_|

Forests are generated using cellular automata with the Moore neighborhood:
- Initial random seed of woodland/clearing cells
- Iterative smoothing passes using Moore neighborhood (8 surrounding cells)
- This creates organic-looking clearings and woodland regions
- Trees are then planted into those regions by density, not one per cell
- Additional passes populate undergrowth and convert turfs to grass
*/

#define FOREST_CLEAR 10
#define FOREST_TREE 11
#define LAKE 12
#define RIVER 13

/area/procedural_generation/forest
	// Sky-visible turfs are moved to /area/rogue/outdoors by update_see_sky if their area is not outdoors
	outdoors = TRUE

	// Cellular automata parameters
	var/initial_tree_chance = 45 // Initial random fill percentage
	var/ca_iterations = 4 // Number of cellular automata smoothing passes
	var/birth_threshold = 5 // Neighbors needed to become a tree
	var/survival_min = 4 // Minimum neighbors to stay a tree
	var/survival_max = 8 // Maximum neighbors to stay a tree

	var/tree_density_forest = 45
	var/tree_density_clearing = 3
	var/min_tree_spacing = 1

	// Flora variety settings
	var/grass_conversion_chance = 60 // Chance to convert dirt to grass
	var/undergrowth_density = 15 // Percentage for bushes, herbs, etc.

	// Water feature parameters
	var/generate_lakes = TRUE
	min_lakes = 1
	max_lakes = 3
	min_lake_size = 30
	max_lake_size = 80

	var/generate_rivers = TRUE
	var/min_rivers = 1
	var/max_rivers = 2
	var/river_inertia = 80 // % chance to keep going straight
	var/river_width = 2 // River thickness
	var/list/river_flow_map = list() // Stores flow_dir per river tile, keyed by "x-y"
	var/river_primary = SOUTH
	var/river_cross = EAST

/area/procedural_generation/forest/setup_procgen()
	..()
	clear_walls()
	initialize_random_forest()
	apply_cellular_automata()
	if(generate_lakes)
		generate_lakes()
	if(generate_rivers)
		generate_rivers()
		resolve_river_flow()
	convert_to_grass()
	populate_trees()
	SStreesetup.InitializeTrees()
	populate_undergrowth()
	final_pass()

	generation_map.Cut()
	turf_map.Cut()
	river_flow_map.Cut()

/area/procedural_generation/forest/proc/clear_walls()
	for(var/x = low_x, x <= high_x, x++)
		for(var/y = low_y, y <= high_y, y++)
			if(!in_area(x, y))
				continue
			var/turf/current_turf = locate(x, y, src.z)
			if(iswall(current_turf))
				current_turf.ChangeTurf(/turf/open/floor/rogue/dirt)

// Initial random seeding of the forest
/area/procedural_generation/forest/proc/initialize_random_forest()
	for(var/x = low_x, x <= high_x, x++)
		for(var/y = low_y, y <= high_y, y++)
			if(!in_area(x, y))
				continue
			var/key = "[x]-[y]"
			if(prob(initial_tree_chance))
				generation_map[key] = FOREST_TREE
			else
				generation_map[key] = FOREST_CLEAR

// Apply cellular automata using Moore neighborhood
/area/procedural_generation/forest/proc/apply_cellular_automata()
	for(var/iteration in 1 to ca_iterations)
		var/list/new_map = list()

		for(var/x = low_x, x <= high_x, x++)
			for(var/y = low_y, y <= high_y, y++)
				if(!in_area(x, y))
					continue
				var/key = "[x]-[y]"
				var/tree_neighbors = count_tree_neighbors(x, y)
				var/current_state = generation_map[key]

				if(current_state == FOREST_TREE)
					if(tree_neighbors >= survival_min && tree_neighbors <= survival_max)
						new_map[key] = FOREST_TREE
					else
						new_map[key] = FOREST_CLEAR
				else
					if(tree_neighbors >= birth_threshold)
						new_map[key] = FOREST_TREE
					else
						new_map[key] = FOREST_CLEAR

		// Update the generation map with the new state
		generation_map = new_map

// Count tree neighbors using Moore neighborhood (all 8 surrounding cells)
/area/procedural_generation/forest/proc/count_tree_neighbors(center_x, center_y)
	var/count = 0
	for(var/dx in -1 to 1)
		for(var/dy in -1 to 1)
			if(dx == 0 && dy == 0)
				continue // Skip the center cell

			var/nx = center_x + dx
			var/ny = center_y + dy

			// Handle edges by treating out-of-bounds as clear
			if(!in_bounds(nx, ny))
				continue

			var/neighbor_key = "[nx]-[ny]"
			if(generation_map[neighbor_key] == FOREST_TREE)
				count++

	return count

/area/procedural_generation/forest/proc/convert_to_grass()
	for(var/x = low_x, x <= high_x, x++)
		for(var/y = low_y, y <= high_y, y++)
			if(!in_area(x, y))
				continue
			var/turf/current_turf = locate(x, y, src.z)
			if(istype(current_turf, /turf/open/floor/rogue/dirt))
				if(prob(grass_conversion_chance))
					current_turf.ChangeTurf(/turf/open/floor/rogue/grass)

/area/procedural_generation/forest/proc/populate_trees()
	var/list/planted = list()
	var/canopy_cells = 0
	for(var/x = low_x, x <= high_x, x++)
		for(var/y = low_y, y <= high_y, y++)
			if(!in_area(x, y))
				continue
			var/key = "[x]-[y]"

			// Skip water tiles
			var/tile_type = generation_map[key]
			if(tile_type == LAKE || tile_type == RIVER)
				continue

			if(!prob(tile_type == FOREST_TREE ? tree_density_forest : tree_density_clearing))
				continue

			if(too_close_to_tree(planted, x, y))
				continue

			var/turf/current_turf = locate(x, y, src.z)

			// Only place trees on grass or dirt
			if(!istype(current_turf, /turf/open/floor/rogue/grass) && !istype(current_turf, /turf/open/floor/rogue/dirt))
				continue

			// Check for existing structures
			if(locate(/obj/structure) in current_turf)
				continue

			planted[key] = TRUE
			if(istype(get_step_multiz(current_turf, UP), /turf/open/transparent/openspace))
				canopy_cells++

			// Mix of old and new tree types
			if(prob(70))
				new /obj/structure/flora/newtree(current_turf)
			else
				new /obj/structure/flora/roguetree(current_turf)

	if(length(planted) && !canopy_cells)
		log_mapping("[type] planted [length(planted)] trees with no openspace above any of them; trees will have no branches or leaves.")

/area/procedural_generation/forest/proc/too_close_to_tree(list/planted, center_x, center_y)
	if(min_tree_spacing <= 0)
		return FALSE
	for(var/dx = -min_tree_spacing, dx <= min_tree_spacing, dx++)
		for(var/dy = -min_tree_spacing, dy <= min_tree_spacing, dy++)
			if(planted["[center_x + dx]-[center_y + dy]"])
				return TRUE
	return FALSE

/area/procedural_generation/forest/proc/populate_undergrowth()
	for(var/x = low_x, x <= high_x, x++)
		for(var/y = low_y, y <= high_y, y++)
			if(!in_area(x, y))
				continue
			var/key = "[x]-[y]"
			var/tile_type = generation_map[key]

			// Skip water tiles
			if(tile_type == LAKE || tile_type == RIVER)
				continue

			var/turf/current_turf = locate(x, y, src.z)

			// Only place undergrowth on grass or dirt
			if(!istype(current_turf, /turf/open/floor/rogue/grass) && !istype(current_turf, /turf/open/floor/rogue/dirt))
				continue

			// Don't place on tiles that already have stuff
			if(locate(/obj/structure) in current_turf || locate(/obj/item) in current_turf)
				continue

			if(prob(undergrowth_density))
				var/i = rand(1, 100)
				var/flora_type = null
				switch(i)
					if(1 to 40)
						flora_type = /obj/structure/flora/roguegrass
					if(41 to 55)
						flora_type = /obj/structure/flora/roguegrass/bush
					if(56 to 60)
						flora_type = /obj/structure/flora/roguegrass/herb/random
					if(61 to 70)
						flora_type = /obj/structure/flora/roguegrass/bush/westleach
					if(71 to 73)
						flora_type = /obj/structure/flora/roguegrass/bush/jackberry
					if(74 to 76)
						flora_type = /obj/structure/flora/roguetree/stump
					if(77 to 87)
						flora_type = /obj/item/grown/log/tree/stick
					if(88 to 91)
						flora_type = /obj/structure/flora/roguetree/stump/log
					if(92 to 96)
						flora_type = /obj/item/natural/stone
					if(97 to 99)
						flora_type = /obj/item/natural/rock
					if(100)
						flora_type = /obj/structure/closet/dirthole/closed/loot
				
				if(flora_type)
					new flora_type(current_turf)

// Place water features
/area/procedural_generation/forest/final_pass()
	for(var/x = low_x, x <= high_x, x++)
		for(var/y = low_y, y <= high_y, y++)
			var/key = "[x]-[y]"
			var/tile_type = generation_map[key]

			if(tile_type == LAKE)
				place_lake_tile(x, y)
			else if(tile_type == RIVER)
				place_river_tile(x, y, river_flow_map[key] || river_primary)

/area/procedural_generation/forest/proc/contain_water(turf/target)
	if(!target)
		return
	if(!target.cell)
		target.cell = new /cell(target)
		target.cell.InitLiquids()
	target.cell.set_contain_max(MAX_FLUID_VOLUME)

/area/procedural_generation/forest/proc/clear_flora(turf/target)
	if(!target)
		return
	for(var/obj/structure/flora/growth in target)
		qdel(growth)

/area/procedural_generation/forest/proc/place_lake_tile(x, y)
	if(!in_area(x, y))
		return
	var/turf/current_turf = locate(x, y, src.z)
	if(!current_turf)
		return

	// Branches are built before the water is carved, so anything standing here has to go first
	clear_flora(current_turf)

	// Bottom turf: lakebed. This has to happen first, a hole cannot open over a closed turf
	var/turf/below = GetBelow(current_turf)
	if(below)
		var/turf/lake_bottom = below.ChangeTurf(/turf/open/floor/rogue/lakebed, null, CHANGETURF_IGNORE_AIR)
		SSmapping.register_water_bed(lake_bottom)
		contain_water(lake_bottom)

	// Top turf: open space, surface overlay and sink are managed by update_cell_image
	var/turf/lake_surface = current_turf.ChangeTurf(/turf/open/transparent/openspace, null, CHANGETURF_IGNORE_AIR)
	contain_water(lake_surface)

/area/procedural_generation/forest/proc/place_river_tile(x, y, flow_dir = SOUTH)
	if(!in_area(x, y))
		return
	var/turf/current_turf = locate(x, y, src.z)
	if(!current_turf)
		return

	// Branches are built before the water is carved, so anything standing here has to go first
	clear_flora(current_turf)

	// Bottom turf: riverbot. This has to happen first, a hole cannot open over a closed turf
	var/turf/below = GetBelow(current_turf)
	if(!below)
		return

	var/turf/riverbot = below.ChangeTurf(/turf/open/floor/rogue/riverbot, null, CHANGETURF_IGNORE_AIR)
	if(riverbot.cell)
		riverbot.cell.flow_dir = flow_dir
	riverbot.setDir(flow_dir)
	SSmapping.register_water_bed(riverbot)

	contain_water(riverbot)

	// Top turf: open space, surface overlay and sink are managed by update_cell_image
	var/turf/river_surface = current_turf.ChangeTurf(/turf/open/transparent/openspace, null, CHANGETURF_IGNORE_AIR)
	contain_water(river_surface)
	SSliquid.update_cell_image(river_surface)

// Lake Generation - "Droplet Method" (Iterative Expansion)
/area/procedural_generation/forest/proc/generate_lakes()
	if(!length(turf_map))
		return

	var/num_lakes = rand(min_lakes, max_lakes)

	for(var/i in 1 to num_lakes)
		var/list/coords = splittext(pick(turf_map), "-")
		var/lake_size = rand(min_lake_size, max_lake_size)

		create_forest_lake_at(text2num(coords[1]), text2num(coords[2]), lake_size)

	smooth_lake_edges()

/area/procedural_generation/forest/proc/create_forest_lake_at(center_x, center_y, target_size)
	if(!in_area(center_x, center_y))
		return

	var/list/lake_tiles = list()
	var/start_key = "[center_x]-[center_y]"
	lake_tiles += start_key
	generation_map[start_key] = LAKE

	// Iterative expansion from center
	for(var/i in 1 to target_size)
		if(!length(lake_tiles))
			break

		// Pick a random existing lake tile
		var/origin_key = pick(lake_tiles)
		var/list/coords = splittext(origin_key, "-")
		var/origin_x = text2num(coords[1])
		var/origin_y = text2num(coords[2])

		// Pick a random cardinal neighbor
		var/dir = pick(GLOB.cardinals)
		var/nx = origin_x
		var/ny = origin_y

		switch(dir)
			if(NORTH)
				ny++
			if(SOUTH)
				ny--
			if(EAST)
				nx++
			if(WEST)
				nx--

		// Check bounds
		if(!in_area(nx, ny))
			continue

		var/new_key = "[nx]-[ny]"
		if(generation_map[new_key] != LAKE) // Don't add twice
			generation_map[new_key] = LAKE
			lake_tiles += new_key

/area/procedural_generation/forest/proc/smooth_lake_edges()
	var/list/new_map = generation_map.Copy()

	for(var/key in generation_map)
		if(generation_map[key] != LAKE)
			continue

		var/list/coords = splittext(key, "-")
		var/x = text2num(coords[1])
		var/y = text2num(coords[2])

		// Count lake neighbors
		var/lake_neighbors = 0
		for(var/dx in -1 to 1)
			for(var/dy in -1 to 1)
				if(dx == 0 && dy == 0)
					continue
				var/nx = x + dx
				var/ny = y + dy
				if(!in_area(nx, ny))
					continue
				var/neighbor_key = "[nx]-[ny]"
				if(generation_map[neighbor_key] == LAKE)
					lake_neighbors++

		// Apply 4-5 rule to smooth
		if(lake_neighbors < 4)
			new_map[key] = FOREST_CLEAR // Remove isolated lake tiles

	generation_map = new_map

// River Generation - "Drunkard's Walk with Inertia"
/area/procedural_generation/forest/proc/generate_rivers()
	var/num_rivers = rand(min_rivers, max_rivers)

	var/prefer_vertical = prob(50)
	river_primary = prefer_vertical ? SOUTH : EAST
	river_cross = prefer_vertical ? EAST : SOUTH

	for(var/i in 1 to num_rivers)
		// Start from a random edge
		var/start_x, start_y, end_x, end_y

		if(prefer_vertical)
			start_x = rand(low_x, high_x)
			start_y = high_y
			end_x = rand(low_x, high_x)
			end_y = low_y
		else
			start_x = low_x
			start_y = rand(low_y, high_y)
			end_x = high_x
			end_y = rand(low_y, high_y)

		create_river(start_x, start_y, end_x, end_y)

/area/procedural_generation/forest/proc/create_river(start_x, start_y, end_x, end_y)
	var/current_x = start_x
	var/current_y = start_y
	var/last_direction = get_dir(locate(start_x, start_y, low_z), locate(end_x, end_y, low_z))
	var/max_steps = (high_x - low_x) + (high_y - low_y) // Safety limit
	for(var/step in 1 to max_steps)
		// Mark current position as river with flow direction
		carve_river_tile(current_x, current_y)

		// Check if we reached the end
		if(current_x == end_x && current_y == end_y)
			break

		// Inertia: 80% keep going, 20% turn
		var/new_direction
		if(prob(river_inertia))
			// Keep going in last direction
			new_direction = last_direction
		else
			// Turn 45 or 90 degrees
			if(prob(60))
				new_direction = turn(last_direction, 45)
			else
				new_direction = turn(last_direction, -45)

		// If we've gone too far off course, correct toward target
		var/distance_to_target = abs(end_x - current_x) + abs(end_y - current_y)
		if(distance_to_target > (max_steps / 4)) // Too far off
			new_direction = get_dir(locate(current_x, current_y, low_z), locate(end_x, end_y, low_z))

		// Move in the new direction
		switch(new_direction)
			if(NORTH)
				current_y = min(current_y + 1, high_y)
			if(SOUTH)
				current_y = max(current_y - 1, low_y)
			if(EAST)
				current_x = min(current_x + 1, high_x)
			if(WEST)
				current_x = max(current_x - 1, low_x)
			if(NORTHEAST)
				current_x = min(current_x + 1, high_x)
				current_y = min(current_y + 1, high_y)
			if(NORTHWEST)
				current_x = max(current_x - 1, low_x)
				current_y = min(current_y + 1, high_y)
			if(SOUTHEAST)
				current_x = min(current_x + 1, high_x)
				current_y = max(current_y - 1, low_y)
			if(SOUTHWEST)
				current_x = max(current_x - 1, low_x)
				current_y = max(current_y - 1, low_y)

		last_direction = new_direction

/area/procedural_generation/forest/proc/resolve_river_flow()
	var/static/list/flow_steps = list("[NORTH]" = list(0, 1), "[SOUTH]" = list(0, -1), "[EAST]" = list(1, 0), "[WEST]" = list(-1, 0))
	var/list/river_keys = list()
	for(var/key in generation_map)
		if(generation_map[key] == RIVER)
			river_keys[key] = TRUE
	if(!length(river_keys))
		return

	var/list/downstream = flow_steps["[river_primary]"]
	var/list/distance = list()
	var/list/frontier = list()

	var/list/river_coords = list()
	for(var/key in river_keys)
		var/list/coords = splittext(key, "-")
		river_coords[key] = list(text2num(coords[1]), text2num(coords[2]))

	for(var/key in river_keys)
		var/list/at = river_coords[key]
		if(in_area(at[1] + downstream[1], at[2] + downstream[2]))
			continue
		distance[key] = 0
		frontier += key

	if(!length(frontier))
		var/best_key
		var/best_rank
		for(var/key in river_keys)
			var/list/at = river_coords[key]
			var/rank = (river_primary == SOUTH) ? -at[2] : at[1]
			if(isnull(best_rank) || rank > best_rank)
				best_rank = rank
				best_key = key
		distance[best_key] = 0
		frontier += best_key

	var/cursor = 1
	while(cursor <= length(frontier))
		var/key = frontier[cursor++]
		var/list/at = river_coords[key]
		var/x = at[1]
		var/y = at[2]
		for(var/probe in flow_steps)
			var/list/offset = flow_steps[probe]
			var/neighbor_key = "[x + offset[1]]-[y + offset[2]]"
			if(!river_keys[neighbor_key] || !isnull(distance[neighbor_key]))
				continue
			distance[neighbor_key] = distance[key] + 1
			frontier += neighbor_key

	for(var/key in river_keys)
		var/list/at = river_coords[key]
		var/x = at[1]
		var/y = at[2]
		var/best_distance = distance[key]
		if(isnull(best_distance))
			river_flow_map[key] = river_primary
			continue
		var/best_dir = river_primary
		for(var/probe in flow_steps)
			var/list/offset = flow_steps[probe]
			var/neighbor_distance = distance["[x + offset[1]]-[y + offset[2]]"]
			if(isnull(neighbor_distance) || neighbor_distance >= best_distance)
				continue
			best_distance = neighbor_distance
			best_dir = text2num(probe)

		if(best_dir != river_primary && best_dir != river_cross)
			best_dir = river_primary
		river_flow_map[key] = best_dir

/area/procedural_generation/forest/proc/carve_river_tile(center_x, center_y)
	for(var/dx in -river_width to river_width)
		for(var/dy in -river_width to river_width)
			if(abs(dx) + abs(dy) <= river_width)
				var/nx = center_x + dx
				var/ny = center_y + dy
				if(in_area(nx, ny))
					generation_map["[nx]-[ny]"] = RIVER

/area/procedural_generation/forest/test
	name = "test forest"
	icon_state = "woods"
	generate_lakes = FALSE
	generate_rivers = FALSE

/area/procedural_generation/forest/test/spill
	name = "test forest spill"
	generate_lakes = TRUE
	generate_rivers = TRUE
	min_lakes = 2
	max_lakes = 3
	min_rivers = 2
	max_rivers = 2
	tree_density_forest = 100
	tree_density_clearing = 100
	min_tree_spacing = 0
	undergrowth_density = 100

#undef FOREST_TREE
#undef FOREST_CLEAR
#undef LAKE
#undef RIVER

#undef DIRT
#undef WALL
#undef HOLE
#undef MUD
#undef AQUA
