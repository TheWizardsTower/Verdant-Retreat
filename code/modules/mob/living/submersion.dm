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

/proc/submersion_mask_offset(depth)
	return clamp(SUBMERSION_MASK_OFFSET_WADE + (depth - SUBMERSION_PRONE_FLUID_THRESHOLD) * (SUBMERSION_MASK_OFFSET_FULL - SUBMERSION_MASK_OFFSET_WADE) / (100 - SUBMERSION_PRONE_FLUID_THRESHOLD), SUBMERSION_MASK_OFFSET_WADE, SUBMERSION_MASK_OFFSET_FULL)

/mob/living/proc/update_submersion_filter()
	if(submersion_depth <= SUBMERSION_PRONE_FLUID_THRESHOLD)
		remove_filter(SUBMERSION_FILTER_ID)
		return
	add_filter(SUBMERSION_FILTER_ID, 1, alpha_mask_filter(0, submersion_mask_offset(submersion_depth), icon('icons/effects/icon_cutter.dmi', "icon_cutter"), null, MASK_INVERSE))
	update_vision_cone()

/turf/proc/fluid_depth()
	if(isopenspace(src))
		var/turf/below = GetBelow(src)
		return below?.cell ? below.cell.fluidsum : 0
	return cell ? cell.fluidsum : 0

/turf/open/water/fluid_depth()
	if(water_level <= 1)
		return 0
	return water_level >= 3 ? 100 : 85

/obj/effect/waterline
	name = ""
	layer = FLOAT_LAYER
	plane = FLOAT_PLANE
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	appearance_flags = RESET_COLOR|RESET_ALPHA|RESET_TRANSFORM

/atom/movable/proc/clear_waterline()
	if(!waterline_overlay)
		return
	vis_contents -= waterline_overlay
	QDEL_NULL(waterline_overlay)
	render_target = null

/obj/proc/update_submersion_cut()
	var/static/icon/cutter = icon('icons/effects/icon_cutter.dmi', "icon_cutter")
	var/turf/T = loc
	var/depth = isturf(T) ? T.fluid_depth() : 0
	if(depth <= SUBMERSION_PRONE_FLUID_THRESHOLD)
		clear_waterline()
		remove_filter(SUBMERSION_FILTER_ID)
		return
	if(smoothing_flags || submersion_tiled)
		var/turf/S = get_step(src, SOUTH)
		for(var/obj/O in S)
			if((O.smoothing_flags || O.submersion_tiled) && (istype(O, type) || istype(src, O.type)))
				clear_waterline()
				remove_filter(SUBMERSION_FILTER_ID)
				return
	var/half = 16
	if(icon)
		var/key = "[icon]"
		half = SSliquid.icon_half_heights[key]
		if(isnull(half))
			var/icon/I = icon(icon)
			half = I.Height() / 2
			SSliquid.icon_half_heights[key] = half
	var/waterline = submersion_mask_offset(depth) + 16 - half - pixel_y
	var/matrix/M = transform
	if(!M || (!M.b && !M.d))
		clear_waterline()
		add_filter(SUBMERSION_FILTER_ID, 1, alpha_mask_filter(0, waterline, cutter, null, MASK_INVERSE))
		return
	if(!waterline_overlay)
		if(render_target)
			add_filter(SUBMERSION_FILTER_ID, 1, alpha_mask_filter(0, waterline, cutter, null, MASK_INVERSE))
			return
		remove_filter(SUBMERSION_FILTER_ID)
		render_target = "*[ref(src)]"
		waterline_overlay = new
		waterline_overlay.render_source = render_target
		vis_contents += waterline_overlay
	waterline_overlay.filters = alpha_mask_filter(0, waterline, cutter, null, MASK_INVERSE)

/obj/effect/update_submersion_cut()
	return

/obj/Moved(atom/old_loc, movement_dir, forced)
	. = ..()
	update_submersion_cut()
