// Yes this doesn't align correctly on anything other than 4 width tabs.
// If you want it to go switch everybody to elastic tab stops.
// Actually that'd be great if you could!
#define EFFECT_UPDATE(level)                \
	if (needs_update == LIGHTING_NO_UPDATE) \
		SSlighting.sources_queue += src; \
	if (needs_update < level)               \
		needs_update = level;    \

// This is where the fun begins.
// These are the main datums that emit light.

/datum/light_source
	var/atom/top_atom        // The atom we're emitting light from (for example a mob if we're from a flashlight that's being held).
	var/atom/source_atom     // The atom that we belong to.

	var/turf/source_turf     // The turf under the above.
	var/turf/pixel_turf      // The turf the top_atom appears to over.
	var/light_power    // Intensity of the emitter light.
	/// The range of the emitted light.
	var/light_inner_range
	/// Range where light begins to taper into darkness in tiles.
	var/light_outer_range
	/// Adjusts curve for falloff gradient
	var/light_falloff_curve = LIGHTING_DEFAULT_FALLOFF_CURVE
	var/light_depth		//multiz
	var/light_height
	var/light_color    // The colour of the light, string, decomposed by parse_light_color()

	// Variables for keeping track of the colour.
	var/lum_r
	var/lum_g
	var/lum_b

	// The lumcount values used to apply the light.
	var/tmp/applied_lum_r
	var/tmp/applied_lum_g
	var/tmp/applied_lum_b

	var/list/datum/lighting_corner/effect_str     // List used to store how much we're affecting corners. Not maintained when native-applied.
	var/list/turf/affecting_turfs

	var/applied = FALSE // Whether we have applied our light yet or not.

	var/needs_update = LIGHTING_NO_UPDATE    // Whether we are queued for an update.

	var/vn_light_id = 0
	var/tmp/vn_native_applied = FALSE // TRUE if our last update_corners() packed a native event instead of running the DM loops.

/datum/light_source/New(atom/owner, atom/top)
	vn_light_id = ++SSlighting.vn_next_light_id
	GLOB.all_light_sources += src
	source_atom = owner // Set our new owner.
	add_to_light_sources(source_atom)
	top_atom = top
	if (top_atom != source_atom)
		add_to_light_sources(top_atom)

	source_turf = top_atom
	pixel_turf = get_turf_pixel(top_atom) || source_turf

	light_power = source_atom.light_power
	light_inner_range = source_atom.light_inner_range
	light_outer_range = source_atom.light_outer_range
	light_falloff_curve = source_atom.light_falloff_curve
	light_color = source_atom.light_color

	parse_light_color()

	update()

/datum/light_source/Destroy(force)
	remove_lum()
	GLOB.all_light_sources -= src
	if (source_atom)
		LAZYREMOVE(source_atom.light_sources, src)

	if (top_atom)
		LAZYREMOVE(top_atom.light_sources, src)

	if (needs_update)
		SSlighting.sources_queue -= src

	. = ..()

///add this light source to new_atom_host's light_sources list. updating movement registrations as needed
/datum/light_source/proc/add_to_light_sources(atom/new_atom_host)
	if(QDELETED(new_atom_host))
		return FALSE

	LAZYADD(new_atom_host.light_sources, src)
	//yes, we register the signal to the top atom too, this is intentional and ensures contained lighting updates properly
	if(ismovable(new_atom_host) && new_atom_host == source_atom)
		RegisterSignal(new_atom_host, COMSIG_MOVABLE_MOVED, PROC_REF(update_host_lights))
	return TRUE

///remove this light source from old_atom_host's light_sources list, unsetting movement registrations
/datum/light_source/proc/remove_from_light_sources(atom/old_atom_host)
	if(QDELETED(old_atom_host))
		return FALSE

	LAZYREMOVE(old_atom_host.light_sources, src)
	if(ismovable(old_atom_host) && old_atom_host == source_atom)
		UnregisterSignal(old_atom_host, COMSIG_MOVABLE_MOVED)
	return TRUE

///signal handler for when our host atom moves and we need to update our effects
/datum/light_source/proc/update_host_lights(atom/movable/host)
	SHOULD_NOT_SLEEP(TRUE)
	if(QDELETED(host))
		return

	// If the host is our owner, we want to call their update so they can decide who the top atom should be
	if(host == source_atom)
		host.update_light()
		return

	// Otherwise, our top atom just moved, so we trigger a normal rebuild
	EFFECT_UPDATE(LIGHTING_CHECK_UPDATE)

// This proc will cause the light source to update the top atom, and add itself to the update queue.
/datum/light_source/proc/update(atom/new_top_atom)
	// This top atom is different.
	if (new_top_atom && new_top_atom != top_atom)
		if(top_atom != source_atom && top_atom.light_sources) // Remove ourselves from the light sources of that top atom.
			LAZYREMOVE(top_atom.light_sources, src)

		top_atom = new_top_atom

		if (top_atom != source_atom)
			LAZYADD(top_atom.light_sources, src) // Add ourselves to the light sources of our new top atom.

	EFFECT_UPDATE(LIGHTING_CHECK_UPDATE)

// Will force an update without checking if it's actually needed.
/datum/light_source/proc/force_update()
	EFFECT_UPDATE(LIGHTING_FORCE_UPDATE)

// Will cause the light source to recalculate turfs that were removed or added to visibility only.
/datum/light_source/proc/vis_update()
	EFFECT_UPDATE(LIGHTING_VIS_UPDATE)

// Decompile the hexadecimal colour into lumcounts of each perspective.
/datum/light_source/proc/parse_light_color()
	if (light_color)
		lum_r = GetRedPart   (light_color) / 255
		lum_g = GetGreenPart (light_color) / 255
		lum_b = GetBluePart  (light_color) / 255
	else
		lum_r = 1
		lum_g = 1
		lum_b = 1

// Macro that applies light to a new corner.
// It is a macro in the interest of speed, yet not having to copy paste it.
// If you're wondering what's with the backslashes, the backslashes cause BYOND to not automatically end the line.
// As such this all gets counted as a single line.
// The braces and semicolons are there to be able to do this on a single line.
// This is the define used to calculate falloff.
// Assuming a brightness of 1 at range 1, formula should be (brightness = 1 / distance^2)
// However, due to the weird range factor, brightness = (-(distance - full_dark_start) / (full_dark_start - full_light_end)) ^ light_max_bright
#define LUM_FALLOFF(C, T)(CLAMP01(-((((C.x - T.x) ** 2 +(C.y - T.y) ** 2) ** 0.5 - light_outer_range) / max(light_outer_range - light_inner_range, 1))) ** light_falloff_curve)

#define APPLY_CORNER(C)                      \
	. = LUM_FALLOFF(C, pixel_turf);          \
	. *= (light_power ** 2);                \
	. *= light_power < 0 ? -1:1;    		\
	var/OLD = effect_str[C];                 \
	effect_str[C] = .;                       \
											\
	C.update_lumcount                        \
	(                                        \
		(. * lum_r) - (OLD * applied_lum_r), \
		(. * lum_g) - (OLD * applied_lum_g), \
		(. * lum_b) - (OLD * applied_lum_b)  \
	);

#define REMOVE_CORNER(C)                     \
	. = -effect_str[C];                      \
	C.update_lumcount                        \
	(                                        \
		. * applied_lum_r,                   \
		. * applied_lum_g,                   \
		. * applied_lum_b                    \
	);

// This is the define used to calculate falloff.

/datum/light_source/proc/remove_lum()
	applied = FALSE
	var/thing
	for (thing in affecting_turfs)
		var/turf/T = thing
		LAZYREMOVE(T.affecting_lights, src)

	affecting_turfs = null

	if (vn_native_applied)
		var/list/evt = SSlighting.vn_light_events
		evt += VN_LIGHT_EVT_REMOVE
		evt += vn_light_id
		vn_native_applied = FALSE
		effect_str = null
		return

	var/datum/lighting_corner/C
	for (thing in effect_str)
		C = thing
		REMOVE_CORNER(C)

		LAZYREMOVE(C.affecting, src)

	effect_str = null

/datum/light_source/proc/recalc_corner(datum/lighting_corner/C)
	if (vn_native_applied)
		// native events carry active corners only; re-send the whole set so the newly active corner joins it
		EFFECT_UPDATE(LIGHTING_FORCE_UPDATE)
		return

	LAZYINITLIST(effect_str)
	if (effect_str[C]) // Already have one.
		REMOVE_CORNER(C)
		effect_str[C] = 0

	APPLY_CORNER(C)
	UNSETEMPTY(effect_str)

/datum/light_source/proc/update_corners()
	var/update = FALSE
	var/atom/source_atom = src.source_atom

	if (QDELETED(source_atom))
		qdel(src)
		return

	if (source_atom.light_power != light_power)
		light_power = source_atom.light_power
		update = TRUE

	if (source_atom.light_inner_range != light_inner_range)
		light_inner_range = source_atom.light_inner_range
		update = TRUE

	if (source_atom.light_outer_range != light_outer_range)
		light_outer_range = source_atom.light_outer_range
		update = TRUE

	if (source_atom.light_depth != light_depth)
		light_depth = source_atom.light_depth
		update = TRUE

	if (source_atom.light_height != light_height)
		light_height = source_atom.light_height
		update = TRUE

	if (!top_atom)
		top_atom = source_atom
		update = TRUE

	if (!light_outer_range || !light_power)
		qdel(src)
		return

	if (isturf(top_atom))
		if (source_turf != top_atom)
			source_turf = top_atom
			pixel_turf = source_turf
			update = TRUE
	else if (top_atom.loc != source_turf)
		source_turf = top_atom.loc
		pixel_turf = get_turf_pixel(top_atom)
		update = TRUE
	else
		var/P = get_turf_pixel(top_atom)
		if (P != pixel_turf)
			pixel_turf = P
			update = TRUE

	if (!isturf(source_turf))
		if (applied)
			remove_lum()
		return

	if (source_atom.light_falloff_curve != light_falloff_curve)
		light_falloff_curve = source_atom.light_falloff_curve
		update = TRUE

	if (light_outer_range && light_power && !applied)
		update = TRUE

	if (source_atom.light_color != light_color)
		light_color = source_atom.light_color
		parse_light_color()
		update = TRUE

	else if (applied_lum_r != lum_r || applied_lum_g != lum_g || applied_lum_b != lum_b)
		update = TRUE

	if (update)
		needs_update = LIGHTING_CHECK_UPDATE
		applied = TRUE
	else if (needs_update == LIGHTING_CHECK_UPDATE)
		return //nothing's changed

	var/native_ok = VN_OK && GLOB.vn_lighting_native
	if (native_ok && source_turf)
		if (source_turf.z > GLOB.vn_light_inited_maxz)
			native_ok = FALSE
		else if (light_height >= 1 && source_turf.z + 1 > GLOB.vn_light_inited_maxz)
			native_ok = FALSE

	var/list/datum/lighting_corner/corners = list()
	var/list/turf/turfs                    = list()
	var/list/turf_ids                      = list()
	var/thing
	var/turf/T
	var/datum/lighting_corner/C
	if (source_turf)
		var/oldlum = source_turf.luminosity
		source_turf.luminosity = CEILING(light_outer_range, 1)
		if (native_ok)
			var/mz = length(SSmapping.multiz_levels)
			var/has_down1 = light_depth >= 1 && mz && SSmapping.multiz_levels[source_turf.z][Z_LEVEL_DOWN]
			var/has_down2 = has_down1 && light_depth > 1 && SSmapping.multiz_levels[source_turf.z - 1][Z_LEVEL_DOWN]
			var/has_down3 = has_down2 && light_depth > 2 && SSmapping.multiz_levels[source_turf.z - 2][Z_LEVEL_DOWN]
			var/has_up1 = light_height >= 1 && mz && SSmapping.multiz_levels[source_turf.z][Z_LEVEL_UP]
			for(T in view(CEILING(light_outer_range, 1), source_turf))
				if((T.dynamic_lighting || T.light_sources) && !T.has_opaque_atom)
					turf_ids += VN_LIGHT_TURF_ID(T)
				turfs += T
				var/turf/open/transparent/O = T
				if(istype(O) && has_down1)
					var/turf/open/B = get_step(T, DOWN)
					if(isopenturf(B))
						if((B.dynamic_lighting || B.light_sources) && !B.has_opaque_atom)
							turf_ids += VN_LIGHT_TURF_ID(B)
						turfs += B
						if(has_down2)
							if(istype(B, /turf/open/transparent))
								B = get_step(B, DOWN)
								if(isopenturf(B))
									if((B.dynamic_lighting || B.light_sources) && !B.has_opaque_atom)
										turf_ids += VN_LIGHT_TURF_ID(B)
									turfs += B
						if(has_down3)
							if(istype(B, /turf/open/transparent))
								B = get_step(B, DOWN)
								if(isopenturf(B))
									if((B.dynamic_lighting || B.light_sources) && !B.has_opaque_atom)
										turf_ids += VN_LIGHT_TURF_ID(B)
									turfs += B
				if(has_up1)
					var/turf/open/B = get_step(T, UP)
					if(istype(B, /turf/open/transparent))
						if((B.dynamic_lighting || B.light_sources) && !B.has_opaque_atom)
							turf_ids += VN_LIGHT_TURF_ID(B)
						turfs += B
		else
			for(T in view(CEILING(light_outer_range, 1), source_turf))
				for (thing in T.get_corners(source_turf))
					C = thing
					corners[C] = 0
				turfs += T
				var/turf/open/transparent/O = T
				if(istype(O) && light_depth >= 1)
					var/turf/open/B = get_step_multiz(T, DOWN)
					if(isopenturf(B))
						for(thing in B.get_corners(source_turf))
							C = thing
							corners[C] = 0
						turfs += B
						if(light_depth > 1)
							if(istype(B, /turf/open/transparent))
								B = get_step_multiz(B, DOWN)
								if(isopenturf(B))
									for(thing in B.get_corners(source_turf))
										C = thing
										corners[C] = 0
									turfs += B
							if(light_depth > 2)
								if(istype(B, /turf/open/transparent))
									B = get_step_multiz(B, DOWN)
									if(isopenturf(B))
										for(thing in B.get_corners(source_turf))
											C = thing
											corners[C] = 0
										turfs += B
				if(light_height >= 1)
					var/turf/open/B = get_step_multiz(T, UP)
					if(istype(B, /turf/open/transparent))
						for(thing in B.get_corners(source_turf))
							C = thing
							corners[C] = 0
						turfs += B
		source_turf.luminosity = oldlum

	LAZYINITLIST(affecting_turfs)
	var/list/L = turfs - affecting_turfs // New turfs, add us to the affecting lights of them.
	affecting_turfs += L
	for(thing in L)
		T = thing
		LAZYADD(T.affecting_lights, src)

	L = affecting_turfs - turfs // Now-gone turfs, remove us from the affecting lights.
	affecting_turfs -= L
	for (thing in L)
		T = thing
		LAZYREMOVE(T.affecting_lights, src)

	if (native_ok)
		if (!vn_native_applied && length(effect_str)) // taking over from DM application: zero our DM contribution first
			for (thing in effect_str)
				C = thing
				REMOVE_CORNER(C)
				LAZYREMOVE(C.affecting, src)
		effect_str = null

		var/list/evt = SSlighting.vn_light_events
		evt += VN_LIGHT_EVT_ADD_TURFS
		evt += vn_light_id
		evt += pixel_turf.x
		evt += pixel_turf.y
		evt += pixel_turf.z
		evt += light_power
		evt += light_inner_range
		evt += light_outer_range
		evt += light_falloff_curve
		evt += lum_r
		evt += lum_g
		evt += lum_b
		evt += length(turf_ids)
		evt += turf_ids

		vn_native_applied = TRUE
	else
		if (vn_native_applied) // taking over from native application: queue removal of its contribution
			var/list/evt = SSlighting.vn_light_events
			evt += VN_LIGHT_EVT_REMOVE
			evt += vn_light_id
			vn_native_applied = FALSE
		LAZYINITLIST(effect_str)
		if (needs_update == LIGHTING_VIS_UPDATE)
			for (thing in  corners - effect_str) // New corners
				C = thing
				LAZYADD(C.affecting, src)
				if (!C.active)
					effect_str[C] = 0
					continue
				APPLY_CORNER(C)
		else
			L = corners - effect_str
			for (thing in L) // New corners
				C = thing
				LAZYADD(C.affecting, src)
				if (!C.active)
					effect_str[C] = 0
					continue
				APPLY_CORNER(C)

			for (thing in corners - L) // Existing corners
				C = thing
				if (!C.active)
					effect_str[C] = 0
					continue
				APPLY_CORNER(C)

		L = effect_str - corners
		for (thing in L) // Old, now gone, corners.
			C = thing
			REMOVE_CORNER(C)
			LAZYREMOVE(C.affecting, src)
		effect_str -= L

		UNSETEMPTY(effect_str)

	applied_lum_r = lum_r
	applied_lum_g = lum_g
	applied_lum_b = lum_b

	UNSETEMPTY(affecting_turfs)

#undef EFFECT_UPDATE
#undef LUM_FALLOFF
#undef REMOVE_CORNER
#undef APPLY_CORNER
