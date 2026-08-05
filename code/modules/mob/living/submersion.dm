/mob/living/proc/compute_submersion_level()
	var/turf/T = loc
	if(!isturf(T) || is_floor_hazard_immune())
		return SUBMERSION_NONE
	var/prone = !(mobility_flags & MOBILITY_STAND)
	if(istype(T, /turf/open/water))
		var/turf/open/water/W = T
		if(W.water_level <= 1)
			return SUBMERSION_NONE
		for(var/obj/structure/S in T)
			if(S.obj_flags & BLOCK_Z_OUT_DOWN)
				return SUBMERSION_NONE
		return (prone || W.water_level == 3) ? SUBMERSION_FULL : SUBMERSION_PARTIAL
	if(istype(T, /turf/open/floor/rogue/riverbot) || istype(T, /turf/open/floor/rogue/lakebed))
		if(!T.cell)
			return SUBMERSION_NONE
		if(prone && T.cell.fluidsum > SUBMERSION_PRONE_FLUID_THRESHOLD)
			return SUBMERSION_FULL
		if(T.cell.fluidsum < SUBMERSION_FLUID_THRESHOLD)
			return SUBMERSION_NONE
		return T.cell.fluidsum >= MAX_FLUID_VOLUME ? SUBMERSION_FULL : SUBMERSION_PARTIAL
	if(isopenspace(T))
		for(var/obj/structure/S in T)
			if(S.obj_flags & BLOCK_Z_OUT_DOWN)
				return SUBMERSION_NONE
		var/turf/below = GetBelow(T)
		if(!below?.cell || below.cell.fluidsum < SUBMERSION_FLUID_THRESHOLD)
			return SUBMERSION_NONE
		return prone ? SUBMERSION_FULL : SUBMERSION_PARTIAL
	if(!T.cell)
		return SUBMERSION_NONE
	if(prone && T.cell.fluidsum > SUBMERSION_PRONE_FLUID_THRESHOLD)
		return SUBMERSION_FULL
	if(T.cell.fluidsum >= SUBMERSION_FLUID_THRESHOLD)
		return T.cell.fluidsum >= MAX_FLUID_VOLUME ? SUBMERSION_FULL : SUBMERSION_PARTIAL
	return SUBMERSION_NONE

/mob/living/proc/compute_submersion_depth()
	var/turf/T = loc
	if(!isturf(T) || is_floor_hazard_immune())
		return 0
	if(istype(T, /turf/open/water))
		var/turf/open/water/W = T
		if(W.water_level <= 1)
			return 0
		for(var/obj/structure/S in T)
			if(S.obj_flags & BLOCK_Z_OUT_DOWN)
				return 0
		return W.water_level >= 3 ? 100 : 85
	if(isopenspace(T))
		for(var/obj/structure/S in T)
			if(S.obj_flags & BLOCK_Z_OUT_DOWN)
				return 0
		var/turf/below = GetBelow(T)
		return below?.cell ? below.cell.fluidsum : 0
	return T.cell ? T.cell.fluidsum : 0

/mob/living/proc/update_submersion()
	var/new_level = compute_submersion_level()
	var/new_depth = compute_submersion_depth()
	if(new_level == submersion_level && new_depth == submersion_depth)
		return
	var/old_level = submersion_level
	submersion_level = new_level
	submersion_depth = new_depth
	if(old_level != new_level)
		SEND_SIGNAL(src, COMSIG_LIVING_SUBMERSION_CHANGED, old_level, new_level)
	refresh_submersion_effects(old_level, new_level)

/mob/living/proc/refresh_submersion_effects(old_level, new_level)
	update_submersion_filter()
	if(new_level >= SUBMERSION_PARTIAL)
		underwater_float_start()
	else
		underwater_float_stop()

/mob/living/proc/is_submerged()
	return submersion_level != SUBMERSION_NONE

/mob/living/proc/update_submersion_filter()
	if(submersion_depth <= SUBMERSION_PRONE_FLUID_THRESHOLD)
		remove_filter(SUBMERSION_FILTER_ID)
		return
	var/depth_offset = clamp(SUBMERSION_MASK_OFFSET_WADE + (submersion_depth - SUBMERSION_PRONE_FLUID_THRESHOLD) * (SUBMERSION_MASK_OFFSET_FULL - SUBMERSION_MASK_OFFSET_WADE) / (100 - SUBMERSION_PRONE_FLUID_THRESHOLD), SUBMERSION_MASK_OFFSET_WADE, SUBMERSION_MASK_OFFSET_FULL)
	add_filter(SUBMERSION_FILTER_ID, 1, alpha_mask_filter(0, depth_offset, icon('icons/effects/icon_cutter.dmi', "icon_cutter"), null, MASK_INVERSE))
	update_vision_cone()
