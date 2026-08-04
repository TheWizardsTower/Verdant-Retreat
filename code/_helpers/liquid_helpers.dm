// Helper procs for liquid system

// Check if a turf blocks liquid flow
/proc/iswall(turf/T)
	return istype(T, /turf/closed/wall) || istype(T, /turf/closed/mineral)

/proc/get_chebyshev_distance(x1, y1, x2, y2)
	return max(abs(x2 - x1), abs(y2 - y1))

/proc/curved_rand(minimum, maximum, iterations = 6)
	var/total = 0
	for(var/i = 1, i <= iterations, i++)
		total += rand(minimum, maximum)
	return round(total / iterations)

/proc/Clamp(value, min_val, max_val)
	return clamp(value, min_val, max_val)

/proc/Floor(value)
	return round(value)

/proc/get_key_by_index(list/L, index)
	if(!islist(L) || index < 1 || index > length(L))
		return null
	var/i = 1
	for(var/key in L)
		if(i == index)
			return key
		i++
	return null

/proc/line_encounters_type(turf/start, turf/end, type_to_check)
	var/turf/current = start
	while(current && current != end)
		if(istype(current, type_to_check))
			return TRUE
		current = get_step_towards(current, end)
	return FALSE

/turf/proc/blocks_flow()
	return density

// Get the turf below this one
/proc/GetBelow(turf/T)
	if(!T)
		return null
	return get_step_multiz(T, DOWN)

// Get the turf above this one
/proc/GetAbove(turf/T)
	if(!T)
		return null
	return get_step_multiz(T, UP)

// Check if there's a barrier between two turfs (windows, doors, etc.)
/turf/proc/LinkBlocked(turf/T, turf/neighbor)
	if(!neighbor)
		return TRUE

	// Check for directional barriers
	var/direction = get_dir(T, neighbor)

	// Check for windows or other directional blockers
	for(var/obj/O in T)
		if(O.density && O.dir == direction)
			return TRUE

	for(var/obj/O in neighbor)
		if(O.density && O.dir == turn(direction, 180))
			return TRUE

	return FALSE

// Get the highest fluid by volume on a turf
/turf/proc/get_highest_fluid_by_volume()
	if(!cell || !cell.fluid_volume)
		return null

	var/datum/liquid/highest_fluid = null
	var/highest_amount = 0

	for(var/datum/liquid/fluid as anything in cell.fluid_volume)
		if(cell.fluid_volume[fluid] > highest_amount)
			highest_amount = cell.fluid_volume[fluid]
			highest_fluid = fluid

	return highest_fluid

// Volume-weighted blend of every present fluid's color, mixed the same way
// as /proc/mix_color_from_reagents. A single-fluid cell returns its color
// string untouched.
/turf/proc/get_blended_fluid_color()
	var/list/vols = cell?.fluid_volume
	if(!vols)
		return null

	var/mixcolor
	var/total = 0

	for(var/datum/liquid/fluid as anything in vols)
		var/amt = vols[fluid]
		if(amt <= 0 || !fluid.color)
			continue
		if(!mixcolor)
			mixcolor = fluid.color
			total = amt
			continue
		total += amt
		mixcolor = BlendRGB(mixcolor, fluid.color, amt / total)

	return mixcolor

// Get fluid datum by type or instance. A dynamic /datum/liquid instance
// (bare type, .reagent set) is matched by reagent, since locate-by-type
// would alias every dynamic reagent liquid to whichever is first.
/turf/proc/get_fluid_datum(fluid_type)
	if(!cell || !cell.fluid_volume)
		return null

	if(!ispath(fluid_type) && istype(fluid_type, /datum/liquid))
		var/datum/liquid/instance = fluid_type
		if(instance.type == /datum/liquid && instance.reagent)
			for(var/datum/liquid/existing as anything in cell.fluid_volume)
				if(existing.type == /datum/liquid && existing.reagent == instance.reagent)
					return existing
			return null
		fluid_type = instance.type
	return locate(fluid_type) in cell.fluid_volume

// Operator overload for adding fluid to turf (elegant syntax)
/turf/proc/operator+(datum/liquid/fluid)
	if(!cell)
		cell = new /cell(src)
		cell.InitLiquids()

	return cell.get_fluid_datum(fluid)

// Operator overload for getting fluid amount from turf
/turf/proc/operator[](datum/liquid/fluid)
	if(!cell)
		return 0

	var/datum/liquid/instance = cell.get_fluid_datum(fluid)
	if(!instance)
		return 0

	return cell.fluid_volume[instance]

// Check if turf is openspace (already defined in is_helpers.dm)
// We just need to make sure it works with the liquid system

// Helper to update turf mimic (for openspace)
/turf/proc/update_mimic()
	// This is called by mapgen, implement if needed
	return
