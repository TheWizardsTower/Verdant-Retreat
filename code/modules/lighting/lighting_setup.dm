/proc/create_all_lighting_objects()
	var/n = 0
	for(var/area/A in world)
		if(!IS_DYNAMIC_LIGHTING(A))
			continue

		for(var/turf/T in A)

			if(!IS_DYNAMIC_LIGHTING(T))
				continue

			new/atom/movable/lighting_object(T, TRUE)
			if(!(++n % 1024))
				CHECK_TICK
		CHECK_TICK
