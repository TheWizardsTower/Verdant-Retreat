//TODO: Make this. 

/turf/proc/roguesmooth(adjacencies, use_old_behavior)
/*	if(!use_old_behavior)
		adjacencies = null
		var/turf/neighbortest //completely discard the existing adjacencies, they were calculated incorrectly. 
		for (var/testing_dir in list(NORTH, SOUTH, EAST, WEST, NORTHEAST, NORTHWEST, SOUTHEAST, SOUTHWEST))
			neighbortest = get_step(src, testing_dir)
			if(neighbortest ==null)
				continue
			if(istype(neighbortest, /turf/open/transparent/openspace))
				continue
			if(neighbortest.layer >= src.layer)
				continue
			if(neighbortest.type == src)//TODO: make this take a typecache..
				continue
			if(iswallturf(neighbortest))
				continue
			adjacencies |= dir2neighbor(testing_dir)

	var/list/New
	var/holder

	for(var/A in neighborlay_list)
		cut_overlay("[A]")
		neighborlay_list -= A
	var/usedturf
	if(adjacencies & N_NORTH)
		usedturf = get_step(src, NORTH)
		if(isturf(usedturf))
			var/turf/T = usedturf
			if(neighborlay_override)
				holder = "[neighborlay_override]-n"
				LAZYADD(New, holder)
				neighborlay_list += holder
			else if(T.neighborlay)
				holder = "[T.neighborlay]-n"
				LAZYADD(New, holder)
				neighborlay_list += holder
	if(adjacencies & N_SOUTH)
		usedturf = get_step(src, SOUTH)
		if(isturf(usedturf))
			var/turf/T = usedturf
			if(neighborlay_override)
				holder = "[neighborlay_override]-s"
				LAZYADD(New, holder)
				neighborlay_list += holder
			else if(T.neighborlay)
				holder = "[T.neighborlay]-s"
				LAZYADD(New, holder)
				neighborlay_list += holder
	if(adjacencies & N_WEST)
		usedturf = get_step(src, WEST)
		if(isturf(usedturf))
			var/turf/T = usedturf
			if(neighborlay_override)
				holder = "[neighborlay_override]-w"
				LAZYADD(New, holder)
				neighborlay_list += holder
			else if(T.neighborlay)
				holder = "[T.neighborlay]-w"
				LAZYADD(New, holder)
				neighborlay_list += holder
	if(adjacencies & N_EAST)
		usedturf = get_step(src, EAST)
		if(isturf(usedturf))
			var/turf/T = usedturf
			if(neighborlay_override)
				holder = "[neighborlay_override]-e"
				LAZYADD(New, holder)
				neighborlay_list += holder
			else if(T.neighborlay)
				holder = "[T.neighborlay]-e"
				LAZYADD(New, holder)
				neighborlay_list += holder

	if(smooth & SMOOTH_DIAGONAL)
		if(adjacencies & N_NORTHEAST)
			usedturf = get_step(src, NORTHEAST)
			if(isturf(usedturf))
				var/turf/T = usedturf
				if(neighborlay_override)
					holder = "[neighborlay_override]-ne"
					LAZYADD(New, holder)
					neighborlay_list += holder
				else if(T.neighborlay)
					holder = "[T.neighborlay]-ne"
					LAZYADD(New, holder)
					neighborlay_list += holder
		if(adjacencies & N_NORTHWEST)
			usedturf = get_step(src, NORTHWEST)
			if(isturf(usedturf))
				var/turf/T = usedturf
				if(neighborlay_override)
					holder = "[neighborlay_override]-nw"
					LAZYADD(New, holder)
					neighborlay_list += holder
				else if(T.neighborlay)
					holder = "[T.neighborlay]-nw"
					LAZYADD(New, holder)
					neighborlay_list += holder
		if(adjacencies & N_SOUTHEAST)
			usedturf = get_step(src, SOUTHEAST)
			if(isturf(usedturf))
				var/turf/T = usedturf
				if(neighborlay_override)
					holder = "[neighborlay_override]-se"
					LAZYADD(New, holder)
					neighborlay_list += holder
				else if(T.neighborlay)
					holder = "[T.neighborlay]-se"
					LAZYADD(New, holder)
					neighborlay_list += holder
		if(adjacencies & N_SOUTHWEST)
			usedturf = get_step(src, SOUTHWEST)
			if(isturf(usedturf))
				var/turf/T = usedturf
				if(neighborlay_override)
					holder = "[neighborlay_override]-sw"
					LAZYADD(New, holder)
					neighborlay_list += holder
				else if(T.neighborlay)
					holder = "[T.neighborlay]-sw"
					LAZYADD(New, holder)
					neighborlay_list += holder

 

	if(New)
		add_overlay(New)
	return New
*/
