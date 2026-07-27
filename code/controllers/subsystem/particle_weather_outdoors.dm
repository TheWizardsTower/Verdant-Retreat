/datum/time_of_day
	var/name = ""
	var/color = ""
	var/start = 216000 // 6:00 am

/datum/time_of_day/dawn
	name = "Dawn"
	color = list("#394579", "#49385d", "#3a1537")
	start = 8 HOURS //8:00:00 AM

/datum/time_of_day/sunrise
	name = "Sunrise"
	color = list("#F598AB","#e26d6d", "#e96e4f")
	start = 9.5 HOURS  //9:30:00 AM

/datum/time_of_day/daytime
	name = "Daytime"
	color = list("#dbbfbf", "#ddd7bd", "#add1b0", "#a4c0ca", "#ae9dc6", "#d09fbf")
	start = 10 HOURS //10:00:00 AM

/datum/time_of_day/sunset
	name = "Sunset"
	color = "#ff8a63"
	start = 15 HOURS //3:00:00 PM

/datum/time_of_day/dusk
	name = "Dusk"
	color = list("#c26f56", "#c05271", "#b84933")
	start = 15.5 HOURS //3:30:00 PM

/datum/time_of_day/midnight
	name = "Midnight"
	color = list("#100a18", "#0c0412", "#0f0012")
	start = 16 HOURS //4:00:00 PM

GLOBAL_VAR_INIT(GLOBAL_LIGHT_RANGE, 3)
GLOBAL_LIST_EMPTY(SUNLIGHT_QUEUE_WORK)   /* turfs to be stateChecked */
GLOBAL_LIST_EMPTY(SUNLIGHT_QUEUE_UPDATE) /* turfs to have their colors updated via corners (filter out the unroofed dudes) */
GLOBAL_LIST_EMPTY(SUNLIGHT_QUEUE_CORNER) /* turfs to have their color/lights/etc updated */

SUBSYSTEM_DEF(outdoor_effects)
	name = "Outdoor Weather Calc"
	wait = LIGHTING_INTERVAL
	flags = SS_TICKER
	init_order = INIT_ORDER_OUTDOOR_EFFECTS
	var/list/atom/movable/screen/plane_master/weather_effect/weather_planes_need_vis = list()

	var/list/atom/movable/screen/fullscreen/lighting_backdrop/sunlight/sunlighting_planes = list()
	var/datum/time_of_day/current_step_datum
	var/datum/time_of_day/next_step_datum
	var/list/mutable_appearance/sunlight_overlays

	var/last_color = null
	var/picked_color
	//Ensure midnight is the liast step
	var/list/datum/time_of_day/time_cycle_steps = list(new /datum/time_of_day/dawn(),
	                                                   new /datum/time_of_day/sunrise(),
	                                                   new /datum/time_of_day/daytime(),
	                                                   new /datum/time_of_day/sunset(),
	                                                   new /datum/time_of_day/dusk(),
	                                                   new /datum/time_of_day/midnight())
	var/next_day = FALSE // Resets when station_time is less than the next start time.
	var/ceiling_status_caching = FALSE

/datum/controller/subsystem/outdoor_effects/proc/fullPlonk()
	for (var/z in SSmapping.levels_by_trait(ZTRAIT_STATION))
		for (var/turf/T in block(locate(1,1,z), locate(world.maxx,world.maxy,z)))
			GLOB.SUNLIGHT_QUEUE_WORK += T

/datum/controller/subsystem/outdoor_effects/Initialize(timeofday)
	if(!initialized)
		get_time_of_day()
		var/native_done = FALSE
		if(VN_OK && !world.GetConfig("env", "VN_NO_NATIVE_OUTDOOR"))
			ceiling_status_caching = TRUE
			native_done = vn_outdoor_sweep()
			ceiling_status_caching = FALSE
			if(native_done)
				log_world("SSoutdoor_effects: native ceiling sweep applied")
		if(!native_done)
			InitializeTurfs()
		initialized = TRUE
	ceiling_status_caching = TRUE
	fire(FALSE, TRUE)
	ceiling_status_caching = FALSE
	..()

/datum/controller/subsystem/outdoor_effects/proc/vn_outdoor_row(y, z, list/out)
	var/list/row = list()
	for(var/x in 1 to world.maxx)
		var/turf/T = locate(x, y, z)
		var/p = 0
		if(isclosedturf(T))
			p |= 1
		if(istransparentturf(T))
			p |= 2
		if(T.weatherproof)
			p |= 4
		for(var/obj/structure/S in T.contents)
			if(S.weatherproof == TRUE)
				p |= 8
				break
		if(T.pseudo_roof)
			p |= 16
		var/area/A = T.loc
		if(A.outdoors)
			p |= 32
		row += ascii2text(p + 48)
	out += jointext(row, "")

/datum/controller/subsystem/outdoor_effects/proc/vn_outdoor_sweep()
	var/list/zup = list()
	var/mz = length(SSmapping.multiz_levels)
	for(var/z in 1 to world.maxz)
		var/up = 0
		if(mz >= z && islist(SSmapping.multiz_levels[z]) && SSmapping.multiz_levels[z][Z_LEVEL_UP] && z + 1 <= world.maxz)
			up = z + 1
		zup += up
	var/list/station = SSmapping.levels_by_trait(ZTRAIT_STATION)
	var/list/needed = list()
	for(var/z in station)
		var/cz = z
		while(cz && !(cz in needed))
			needed += cz
			cz = zup[cz]
	if(!vn_check_result(vn_outdoor_begin(world.maxx, world.maxy, world.maxz, zup), "outdoor_begin"))
		return FALSE
	for(var/z in needed)
		var/y = 1
		while(y <= world.maxy)
			var/y1 = min(y + 15, world.maxy)
			var/list/rows = list()
			for(var/yy in y to y1)
				vn_outdoor_row(yy, z, rows)
			if(!vn_check_result(vn_outdoor_rows(z, y, y1, jointext(rows, "")), "outdoor_rows"))
				return FALSE
			y = y1 + 1
			CHECK_TICK
	if(!vn_check_result(vn_outdoor_compute(), "outdoor_compute"))
		return FALSE
	for(var/z in station)
		var/list/effects = vn_outdoor_fetch_effects(z)
		if(!islist(effects))
			vn_check_result(effects, "outdoor_fetch_effects")
			return FALSE
		var/n = length(effects)
		var/i = 1
		while(i < n)
			var/xy = effects[i]
			var/bits = effects[i + 1]
			i += 2
			var/turf/T = locate((xy % world.maxx) + 1, round(xy / world.maxx) + 1, z)
			var/state = (bits >> 2) & 3
			if(!T.outdoor_effect)
				T.outdoor_effect = new /atom/movable/outdoor_effect(T)
			T.outdoor_effect.state = state
			T.outdoor_effect.weatherproof = (bits & 2) ? TRUE : FALSE
			GLOB.SUNLIGHT_QUEUE_UPDATE += T.outdoor_effect
			if(i % 8192 == 1)
				CHECK_TICK
	return TRUE

/datum/controller/subsystem/outdoor_effects/stat_entry(msg)
	msg = "W:[GLOB.SUNLIGHT_QUEUE_WORK.len]|U:[GLOB.SUNLIGHT_QUEUE_UPDATE.len]|C:[GLOB.SUNLIGHT_QUEUE_CORNER.len]"
	return ..()

/datum/controller/subsystem/outdoor_effects/proc/InitializeTurfs(list/targets)
	for (var/z in SSmapping.levels_by_trait(ZTRAIT_STATION))
		for (var/turf/T in block(locate(1,1,z), locate(world.maxx,world.maxy,z)))
			GLOB.SUNLIGHT_QUEUE_WORK += T


/datum/controller/subsystem/outdoor_effects/proc/check_cycle()
	if(!next_step_datum)
		get_time_of_day()
		return TRUE

	if(station_time() > next_step_datum.start)
		if(next_day)
			return FALSE
		get_time_of_day()
		return TRUE
	else if (next_day) // It is now the next morning, reset our next day
		next_day = FALSE

	return FALSE

/datum/controller/subsystem/outdoor_effects/proc/get_time_of_day()

	//Set our current color as last_color so newly initialized sunlight screens have a color
	if(current_step_datum)
		last_color = picked_color

	//Get the next time step (first time where NOW > START_TIME)
	//If we don't find one - grab the LAST time step (which should be midnight)
	var/time = station_time()
	var/datum/time_of_day/new_step = null

	for(var/i in 1 to length(time_cycle_steps))
		if(time >= time_cycle_steps[i].start)
			new_step = time_cycle_steps[i]
			next_step_datum = i == length(time_cycle_steps) ? time_cycle_steps[1] : time_cycle_steps[i + 1]

	//New time is the last time step in list (midnight) - next time will be the first step
	if(!new_step)
		new_step = time_cycle_steps[length(time_cycle_steps)]
		next_step_datum = time_cycle_steps[1]

	current_step_datum = new_step
	picked_color = pick(current_step_datum.color)

	// If the next start time is less than the current start time (i.e 10 PM vs 5 AM) then set our NextDay value
	if(next_step_datum.start <= current_step_datum.start)
		next_day = TRUE

	//If it is round-start, we wouldn't have had a current_step_datum, so set our last_color to the current one
	if(!last_color)
		last_color = picked_color

/* set sunlight color + add weather effect to clients */
/datum/controller/subsystem/outdoor_effects/fire(resumed, init_tick_checks)
	MC_SPLIT_TICK_INIT(3)
	if(!init_tick_checks)
		MC_SPLIT_TICK
	var/i = 0

	//Add our weather particle obj to any new weather screens
	if(SSParticleWeather.initialized)
		while (i < length(weather_planes_need_vis))
			var/atom/movable/screen/plane_master/weather_effect/W = weather_planes_need_vis[++i]
			if(W)
				W.vis_contents = list(SSParticleWeather.getweatherEffect())
			if(init_tick_checks)
				CHECK_TICK
			else if (MC_TICK_CHECK)
				break
		if (i)
			weather_planes_need_vis.Cut(1, min(i, length(weather_planes_need_vis)) + 1)
			i = 0

	while (i < length(GLOB.SUNLIGHT_QUEUE_WORK))
		var/turf/T = GLOB.SUNLIGHT_QUEUE_WORK[++i]
		if(T)
			T.get_sky_and_weather_states()
			if(T.outdoor_effect)
				GLOB.SUNLIGHT_QUEUE_UPDATE += T.outdoor_effect

		if(init_tick_checks)
			CHECK_TICK
		else if (MC_TICK_CHECK)
			break
	if (i)
		GLOB.SUNLIGHT_QUEUE_WORK.Cut(1, min(i, length(GLOB.SUNLIGHT_QUEUE_WORK)) + 1)
		i = 0


	if(!init_tick_checks)
		MC_SPLIT_TICK

	while (i < length(GLOB.SUNLIGHT_QUEUE_UPDATE))
		var/atom/movable/outdoor_effect/U = GLOB.SUNLIGHT_QUEUE_UPDATE[++i]
		if(U)
			U.process_state()
			update_outdoor_effect_overlays(U)

		if(init_tick_checks)
			CHECK_TICK
		else if (MC_TICK_CHECK)
			break
	if (i)
		GLOB.SUNLIGHT_QUEUE_UPDATE.Cut(1, min(i, length(GLOB.SUNLIGHT_QUEUE_UPDATE)) + 1)
		i = 0


	if(!init_tick_checks)
		MC_SPLIT_TICK

	while (i < length(GLOB.SUNLIGHT_QUEUE_CORNER))
		var/turf/T = GLOB.SUNLIGHT_QUEUE_CORNER[++i]
		var/atom/movable/outdoor_effect/U = T.outdoor_effect

		/* if we haven't initialized but we are affected, create new and check state */
		if(!U)
			T.outdoor_effect = new /atom/movable/outdoor_effect(T)
			T.get_sky_and_weather_states()
			U = T.outdoor_effect

			/* in case we aren't indoor somehow, wack us into the proc queue, we will be skipped on next indoor check */
			if(U.state != SKY_BLOCKED)
				GLOB.SUNLIGHT_QUEUE_UPDATE += T.outdoor_effect

		if(U.state != SKY_BLOCKED)
			continue

		//This might need to be run more liberally
		update_outdoor_effect_overlays(U)


		if(init_tick_checks)
			CHECK_TICK
		else if (MC_TICK_CHECK)
			break

	if (i)
		GLOB.SUNLIGHT_QUEUE_CORNER.Cut(1, min(i, length(GLOB.SUNLIGHT_QUEUE_CORNER)) + 1)
		i = 0

	if(check_cycle())
		for (var/atom/movable/screen/fullscreen/lighting_backdrop/sunlight/SP in sunlighting_planes)
			transition_sunlight_color(SP)


//Transition from our last color to our current color (i.e if it is going from daylight (white) to sunset (red), we transition to red in the first hour of sunset)
/datum/controller/subsystem/outdoor_effects/proc/transition_sunlight_color(atom/movable/screen/fullscreen/lighting_backdrop/sunlight/SP)
	/* transistion in an hour or time diff from now to our next step, whichever is smaller */
	if(!next_step_datum)
		get_time_of_day()

	var timeDiff = min((1 HOURS / SSticker.station_time_rate_multiplier ),daytimeDiff(station_time(), next_step_datum.start))
	animate(SP,color=picked_color, time = timeDiff)

// Updates overlays and vis_contents for outdoor effects
/datum/controller/subsystem/outdoor_effects/proc/update_outdoor_effect_overlays(atom/movable/outdoor_effect/OE)

	var/mutable_appearance/MA
	if (OE.state != SKY_BLOCKED)
		MA = get_sunlight_overlay(1,1,1,1) /* fully lit */
	else //Indoor - do proper corner checks
		/* check if we are globally affected or not */
		var/static/datum/lighting_corner/dummy/dummy_lighting_corner = new

		var/list/corners = OE.source_turf.corners
		var/datum/lighting_corner/cr = corners[3] || dummy_lighting_corner
		var/datum/lighting_corner/cg = corners[2] || dummy_lighting_corner
		var/datum/lighting_corner/cb = corners[4] || dummy_lighting_corner
		var/datum/lighting_corner/ca = corners[1] || dummy_lighting_corner

		var/fr = cr.sunFalloff
		var/fg = cg.sunFalloff
		var/fb = cb.sunFalloff
		var/fa = ca.sunFalloff

		MA = get_sunlight_overlay(fr, fg, fb, fa)

	OE.sunlight_overlay = MA
	//Get weather overlay if not weatherproof
	OE.overlays = OE.weatherproof ? list(OE.sunlight_overlay) : list(OE.sunlight_overlay, get_weather_overlay())
	OE.luminosity = MA.luminosity

//Retrieve an overlay from the list - create if necessary
/datum/controller/subsystem/outdoor_effects/proc/get_sunlight_overlay(fr, fg, fb, fa)

	var/index = "[fr]|[fg]|[fb]|[fa]"
	LAZYINITLIST(sunlight_overlays)
	if(!sunlight_overlays[index])
		sunlight_overlays[index] = create_sunlight_overlay(fr, fg, fb, fa)
	return sunlight_overlays[index]


//get our weather overlay
/datum/controller/subsystem/outdoor_effects/proc/get_weather_overlay() //TODO VANDERLIN: Restore this to 32x48 for some extra
	var/mutable_appearance/MA = new /mutable_appearance()
	MA.icon 			  = 'icons/effects/weather_overlay.dmi'
	MA.icon_state 		  = "weather_overlay"
	MA.plane			  = WEATHER_OVERLAY_PLANE
	MA.blend_mode   	  = BLEND_OVERLAY
	MA.invisibility 	  = INVISIBILITY_LIGHTING
	return MA



//Create an overlay appearance from corner values
/datum/controller/subsystem/outdoor_effects/proc/create_sunlight_overlay(fr, fg, fb, fa)

	var/mutable_appearance/MA = new /mutable_appearance()

	MA.blend_mode   = BLEND_OVERLAY
	MA.icon		 = LIGHTING_ICON
	MA.icon_state   = null
	MA.plane		= SUNLIGHTING_PLANE /* we put this on a lower level than lighting so we dont multiply anything */
	MA.invisibility = INVISIBILITY_LIGHTING


	//MA gets applied as an overlay, but we pull luminosity out to set our outdoor_effect object's lum
	#if LIGHTING_SOFT_THRESHOLD != 0
	MA.luminosity = max(fr, fg, fb, fa) > LIGHTING_SOFT_THRESHOLD
	#else
	MA.luminosity = max(fr, fg, fb, fa) > 1e-6
	#endif

	if((fr & fg & fb & fa) && (fr + fg + fb + fa == 4)) /* this will likely never happen */
		MA.color = LIGHTING_BASE_MATRIX
	else if(!MA.luminosity)
		MA.color = SUNLIGHT_DARK_MATRIX
	else
		MA.color = list(
					fr, fr, fr,  00 ,
					fg, fg, fg,  00 ,
					fb, fb, fb,  00 ,
					fa, fa, fa,  00 ,
					00, 00, 00,  01 )
	return MA
