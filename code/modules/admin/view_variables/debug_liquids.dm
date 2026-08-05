/client/proc/debug_liquids()
	set category = "Debug"
	set name = "Debug Liquids"
	if(!check_rights(R_DEBUG))
		return

	var/datum/liquid_debug_view/LDV = new(src)
	LDV.ui_interact(mob)

#define LIQDBG_POOL_SCAN_CAP 4000
#define LIQDBG_TOP_POOLS 15
#define LIQDBG_LIST_CAP 25
#define LIQDBG_BODY_CAP 4000

/datum/liquid_debug_view
	var/client/viewer
	var/turf/selected
	var/tool = "none" // none | inspect | paint
	var/paint_mode = "add" // add | erase | set | clear
	var/brush_size = 0
	var/brush_str = 25
	var/sel_fluid = "/datum/liquid/water"
	var/overlay_on = FALSE
	var/overlay_range = 12
	var/list/overlay_images = list()
	var/turf/last_paint
	var/list/highlight_images = list()
	var/list/pool_scan = list()
	var/pool_scan_capped = FALSE
	var/list/sel_pool_stats
	var/last_mass = 0
	var/mass_delta = 0
	// vn_fluid_status() walks the whole native grid; cache it so ui_data
	// doesn't pay that on every tgui update
	var/status_next = 0
	var/cached_mass = 0
	var/cached_drained = 0
	var/cached_active = 0
	var/flow_dir_choice = 0
	var/flow_apply_mode = "brush" // brush | body
	var/list/flow_selection = list()
	var/flow_selection_capped = FALSE
	var/list/selection_images = list()

/datum/liquid_debug_view/New(client/C)
	viewer = C

/datum/liquid_debug_view/Destroy()
	cleanup()
	return ..()

/datum/liquid_debug_view/ui_state(mob/user)
	if(!GLOB.admin_states["[R_DEBUG]"])
		GLOB.admin_states["[R_DEBUG]"] = new /datum/ui_state/admin_state(R_DEBUG)
	return GLOB.admin_states["[R_DEBUG]"]

/datum/liquid_debug_view/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "LiquidDebug")
		ui.open()

/datum/liquid_debug_view/ui_close(mob/user)
	. = ..()
	cleanup()

/datum/liquid_debug_view/proc/cleanup()
	overlay_on = FALSE
	clear_overlay()
	clear_highlights()
	clear_flow_selection()
	if(viewer && viewer.click_intercept == src)
		viewer.click_intercept = null
		viewer.mouse_pointer_icon = null
		viewer.mob?.update_mouse_pointer()
	tool = "none"
	selected = null

/datum/liquid_debug_view/proc/band_name(level)
	switch(level)
		if(FLUID_EMPTY) return "empty"
		if(FLUID_VERY_LOW) return "very low"
		if(FLUID_LOW) return "low"
		if(FLUID_MEDIUM) return "medium"
		if(FLUID_HIGH) return "high"
		if(FLUID_VERY_HIGH) return "very high"
		if(FLUID_FULL) return "full"
		else return "overflow"

/datum/liquid_debug_view/proc/status_num(status, key)
	if(!istext(status))
		return -1
	for(var/part in splittext(status, ";"))
		var/list/kv = splittext(part, "=")
		if(length(kv) == 2 && kv[1] == key)
			return text2num(kv[2])
	return -1

/datum/liquid_debug_view/ui_data(mob/user)
	var/list/data = list()

	var/list/engine = list()
	engine["ready"] = SSliquid.vn_native_fluids_ready
	if(SSliquid.vn_native_fluids_ready)
		if(world.time >= status_next)
			status_next = world.time + 2 SECONDS
			var/status = vn_fluid_status()
			cached_mass = status_num(status, "mass")
			cached_drained = status_num(status, "drained")
			cached_active = status_num(status, "active")
			if(last_mass)
				mass_delta = cached_mass - last_mass
			last_mass = cached_mass
		engine["mass"] = cached_mass
		engine["drained"] = cached_drained
		engine["native_active"] = cached_active
	engine["mass_delta"] = mass_delta
	engine["deltas"] = SSliquid.vn_deltas_applied
	engine["events"] = SSliquid.vn_events_applied
	engine["falls"] = SSliquid.vn_falls_applied
	engine["queue"] = length(SSliquid.vn_edit_queue)
	engine["cells_active"] = length(SSliquid.cell_index)
	engine["cells_sleeping"] = length(SSliquid.sleeping_cells)
	engine["wet_turfs"] = length(SSliquid.pool_manager.liquid_turfs)
	engine["sources"] = length(SSliquid.liquid_sources)
	engine["sinks"] = length(SSliquid.liquid_sinks)
	data["engine"] = engine

	var/list/fluids = list()
	for(var/fluid_path in SSliquid.registry.registered_liquids)
		var/datum/liquid/L = SSliquid.registry.registered_liquids[fluid_path]
		fluids += list(list("name" = L.name, "path" = "[fluid_path]", "color" = L.color || "#5096ff"))
	data["fluids"] = fluids

	data["tool"] = tool
	data["paint_mode"] = paint_mode
	data["brush_size"] = brush_size
	data["brush_str"] = brush_str
	data["sel_fluid"] = sel_fluid
	data["overlay_on"] = overlay_on
	data["overlay_range"] = overlay_range
	data["flow_dir_choice"] = flow_dir_choice
	data["flow_apply_mode"] = flow_apply_mode
	data["flow_selected"] = length(flow_selection)
	data["flow_capped"] = flow_selection_capped

	if(istype(selected) && selected.cell)
		SSliquid.refresh_cell_types(selected)
		var/cell/C = selected.cell
		var/list/cdata = list()
		cdata["x"] = selected.x
		cdata["y"] = selected.y
		cdata["z"] = selected.z
		cdata["turf_type"] = "[selected.type]"
		cdata["fluidsum"] = C.fluidsum
		cdata["band"] = band_name(SSliquid.get_fluid_level(selected))
		cdata["vis_band"] = C.vis_fluid_level < 0 ? "uncommitted" : band_name(C.vis_fluid_level)
		cdata["is_source"] = C.is_liquid_source
		cdata["production_rate"] = C.production_rate
		cdata["is_sink"] = C.is_liquid_sink
		cdata["absorption_rate"] = C.absorption_rate
		cdata["flow_dir"] = C.flow_dir ? dir2text(C.flow_dir) : "none"
		cdata["sim_exempt"] = C.sim_exempt
		cdata["contain_max"] = C.contain_max
		cdata["pressure_mask"] = C.pressure_mask
		cdata["doused"] = C.doused
		var/turf/open/O = selected
		cdata["water_level"] = istype(O) ? O.water_level : 0
		cdata["absorption"] = istype(O) ? O.liquid_absorption : 0
		var/list/vols = list()
		for(var/datum/liquid/F as anything in C.fluid_volume)
			var/amt = C.fluid_volume[F]
			if(amt > 0)
				vols += list(list("name" = F.name, "color" = F.color || "#5096ff", "amount" = amt))
		cdata["volumes"] = vols
		data["cell"] = cdata
	else
		data["cell"] = null

	data["pool"] = sel_pool_stats
	data["pools"] = pool_scan
	data["pools_capped"] = pool_scan_capped

	var/list/sources = list()
	var/count = 0
	for(var/turf/T as anything in SSliquid.liquid_sources)
		if(!T?.cell || ++count > LIQDBG_LIST_CAP)
			break
		sources += list(list("x" = T.x, "y" = T.y, "z" = T.z, "rate" = T.cell.production_rate, "fluidsum" = T.cell.fluidsum))
	data["source_list"] = sources
	data["source_total"] = length(SSliquid.liquid_sources)

	var/list/sinks = list()
	count = 0
	for(var/turf/T as anything in SSliquid.liquid_sinks)
		if(!T?.cell || ++count > LIQDBG_LIST_CAP)
			break
		sinks += list(list("x" = T.x, "y" = T.y, "z" = T.z, "rate" = T.cell.absorption_rate, "fluidsum" = T.cell.fluidsum))
	data["sink_list"] = sinks
	data["sink_total"] = length(SSliquid.liquid_sinks)

	return data

/datum/liquid_debug_view/ui_act(action, list/params)
	. = ..()
	if(.)
		return

	switch(action)
		if("set_tool")
			set_tool(params["tool"])
			. = TRUE
		if("set_paint_mode")
			paint_mode = params["mode"]
			. = TRUE
		if("set_brush_size")
			brush_size = clamp(round(text2num(params["value"])), 0, 6)
			. = TRUE
		if("set_brush_str")
			brush_str = clamp(round(text2num(params["value"])), 1, 100)
			. = TRUE
		if("set_fluid")
			var/path = text2path(params["path"])
			if(ispath(path, /datum/liquid))
				sel_fluid = params["path"]
			. = TRUE
		if("toggle_overlay")
			overlay_on = !overlay_on
			if(overlay_on)
				refresh_overlay()
			else
				clear_overlay()
			. = TRUE
		if("set_overlay_range")
			overlay_range = clamp(round(text2num(params["value"])), 4, 20)
			. = TRUE
		if("inspect_here")
			var/turf/T = get_turf(viewer?.mob)
			if(T)
				select_turf(T)
			. = TRUE
		if("jump_to_selected")
			if(istype(selected) && viewer?.mob)
				viewer.mob.forceMove(selected)
			. = TRUE
		if("jump_to")
			var/turf/T = locate(text2num(params["x"]), text2num(params["y"]), text2num(params["z"]))
			if(T && viewer?.mob)
				viewer.mob.forceMove(T)
				select_turf(T)
			. = TRUE
		if("analyze_pool")
			analyze_selected_pool()
			. = TRUE
		if("highlight_pool")
			if(istype(selected))
				highlight_pool(SSliquid.pool_manager.get_pool(selected))
			. = TRUE
		if("scan_pools")
			scan_pools()
			. = TRUE
		if("select_pool")
			var/turf/T = locate(text2num(params["x"]), text2num(params["y"]), text2num(params["z"]))
			if(T)
				select_turf(T)
				analyze_selected_pool()
				highlight_pool(SSliquid.pool_manager.get_pool(T))
			. = TRUE
		if("clear_cell")
			if(istype(selected) && selected.cell)
				SSliquid.clear_cell_fluid(selected)
			. = TRUE
		if("add_to_cell")
			if(istype(selected))
				paint_turf(selected, "add", text2num(params["amount"]) || brush_str)
			. = TRUE
		if("set_flow_dir_choice")
			flow_dir_choice = clamp(round(text2num(params["value"])), 0, 15)
			. = TRUE
		if("set_flow_mode")
			flow_apply_mode = params["mode"]
			. = TRUE
		if("flow_apply")
			apply_flow_to_selection()
			. = TRUE
		if("flow_deselect")
			clear_flow_selection()
			. = TRUE

/datum/liquid_debug_view/proc/set_tool(new_tool)
	tool = new_tool
	last_paint = null
	if(tool != "flow")
		clear_flow_selection()
	if(!viewer)
		return
	if(tool == "inspect" || tool == "paint" || tool == "flow")
		viewer.click_intercept = src
		viewer.mouse_pointer_icon = 'icons/effects/mousemice/human_looking.dmi'
	else
		if(viewer.click_intercept == src)
			viewer.click_intercept = null
			viewer.mouse_pointer_icon = null
			viewer.mob?.update_mouse_pointer()

/datum/liquid_debug_view/proc/select_turf(turf/T)
	selected = T
	sel_pool_stats = null
	if(T && !T.cell)
		T.cell = new /cell(T)
		T.cell.InitLiquids()

/datum/liquid_debug_view/proc/analyze_selected_pool()
	if(!istype(selected) || !selected.cell)
		return
	var/list/pool = SSliquid.pool_manager.get_pool(selected)
	if(!length(pool))
		sel_pool_stats = null
		return
	var/total = 0
	var/minv = INFINITY
	var/maxv = 0
	var/list/fluid_totals = list()
	for(var/turf/P as anything in pool)
		var/sum = P.cell ? P.cell.fluidsum : 0
		total += sum
		minv = min(minv, sum)
		maxv = max(maxv, sum)
		if(P.cell)
			SSliquid.refresh_cell_types(P)
			for(var/datum/liquid/F as anything in P.cell.fluid_volume)
				var/amt = P.cell.fluid_volume[F]
				if(amt > 0)
					fluid_totals[F.name] += amt
	var/dominant = "none"
	var/dom_amt = 0
	for(var/fname in fluid_totals)
		if(fluid_totals[fname] > dom_amt)
			dom_amt = fluid_totals[fname]
			dominant = fname
	sel_pool_stats = list(
		"count" = length(pool),
		"total" = total,
		"avg" = round(total / length(pool), 0.1),
		"min" = minv == INFINITY ? 0 : minv,
		"max" = maxv,
		"dominant" = dominant,
	)

/datum/liquid_debug_view/proc/scan_pools()
	pool_scan = list()
	pool_scan_capped = FALSE
	var/list/seen = list()
	var/visited = 0
	for(var/turf/T as anything in SSliquid.pool_manager.liquid_turfs)
		if(seen[T] || !istype(T) || !T.cell)
			continue
		if(visited >= LIQDBG_POOL_SCAN_CAP)
			pool_scan_capped = TRUE
			break
		var/list/pool = SSliquid.pool_manager.get_pool(T)
		var/total = 0
		for(var/turf/P as anything in pool)
			seen[P] = TRUE
			total += P.cell ? P.cell.fluidsum : 0
		visited += length(pool)
		var/list/row = list("x" = T.x, "y" = T.y, "z" = T.z, "count" = length(pool), "total" = total, "avg" = round(total / max(1, length(pool)), 0.1))
		var/inserted = FALSE
		for(var/i in 1 to length(pool_scan))
			var/list/other = pool_scan[i]
			if(total > other["total"])
				pool_scan.Insert(i, list(row))
				inserted = TRUE
				break
		if(!inserted)
			pool_scan += list(row)
		if(length(pool_scan) > LIQDBG_TOP_POOLS)
			pool_scan.Cut(LIQDBG_TOP_POOLS + 1)

/datum/liquid_debug_view/proc/InterceptClickOn(user, params, atom/A)
	var/list/modifiers = params2list(params)
	if(modifiers["right"])
		set_tool("none")
		SStgui.update_uis(src)
		return TRUE
	if(istype(A, /atom/movable/screen))
		return FALSE
	var/turf/T = get_turf(A)
	if(!T)
		return TRUE
	switch(tool)
		if("inspect")
			select_turf(T)
			SStgui.update_uis(src)
		if("paint")
			last_paint = T
			apply_brush(T)
		if("flow")
			if(flow_apply_mode == "body")
				select_water_body(T)
				SStgui.update_uis(src)
			else
				last_paint = T
				apply_flow_brush(T)
	return TRUE

/datum/liquid_debug_view/proc/InterceptMouseDrag(atom/over_object)
	if(tool != "paint" && !(tool == "flow" && flow_apply_mode == "brush"))
		return FALSE
	var/turf/T = get_turf(over_object)
	if(!T || T == last_paint)
		return TRUE
	last_paint = T
	if(tool == "paint")
		apply_brush(T)
	else
		apply_flow_brush(T)
	return TRUE

/datum/liquid_debug_view/proc/apply_brush(turf/center)
	for(var/turf/open/T in range(brush_size, center))
		var/dx = T.x - center.x
		var/dy = T.y - center.y
		if(dx * dx + dy * dy > brush_size * brush_size + 1)
			continue
		paint_turf(T, paint_mode, brush_str)

/datum/liquid_debug_view/proc/paint_turf(turf/T, mode, amount)
	if(!istype(T, /turf/open))
		return
	if(!T.cell)
		T.cell = new /cell(T)
		T.cell.InitLiquids()
	var/fluid_path = text2path(sel_fluid) || /datum/liquid/water
	switch(mode)
		if("add")
			SSliquid.manager.add_fluid(T, fluid_path, amount)
		if("erase")
			SSliquid.refresh_cell_types(T)
			for(var/datum/liquid/F as anything in T.cell.fluid_volume)
				if(T.cell.fluid_volume[F] > 0)
					SSliquid.manager.remove_fluid(T, F, amount)
		if("set")
			SSliquid.clear_cell_fluid(T)
			if(amount > 0)
				SSliquid.manager.add_fluid(T, fluid_path, amount)
		if("clear")
			SSliquid.clear_cell_fluid(T)
		if("source")
			if(T.cell.is_liquid_source)
				T.cell.remove_liquid_source()
			T.cell.make_liquid_source(amount, fluid_path)
		if("sink")
			if(T.cell.is_liquid_sink)
				T.cell.remove_liquid_sink()
			T.cell.make_liquid_sink(amount)
		if("endpoint_clear")
			if(T.cell.is_liquid_source)
				T.cell.remove_liquid_source()
			if(T.cell.is_liquid_sink)
				T.cell.remove_liquid_sink()
	SSliquid.update_cell_image(T)

// --- fluid-count maptext overlay ---

/datum/liquid_debug_view/proc/overlay_label(cell/C, n)
	var/color = "#b0b0b8"
	switch(n)
		if(21 to 40) color = "#5096ff"
		if(41 to 60) color = "#50c8ff"
		if(61 to 95) color = "#a090e0"
		if(96 to INFINITY) color = "#ff6868"
	var/label = "[n]"
	if(C.is_liquid_source)
		label += "<font color='#5fdc80'>+[C.production_rate]</font>"
	if(C.is_liquid_sink)
		label += "<font color='#ff6868'>-[C.absorption_rate]</font>"
	if(C.flow_dir)
		switch(C.flow_dir)
			if(NORTH) label += "^"
			if(SOUTH) label += "v"
			if(EAST) label += ">"
			if(WEST) label += "<"
	return "<center><span style=\"font-family: 'Small Fonts'; font-size: 7pt; color: [color];\">[label]</span></center>"

/datum/liquid_debug_view/proc/refresh_overlay()
	clear_overlay()
	if(!overlay_on || !viewer?.mob)
		return
	var/turf/center = get_turf(viewer.mob)
	if(center)
		for(var/turf/T in range(overlay_range, center))
			var/cell/C = T.cell
			if(!C)
				continue
			if(!C.fluidsum && !C.is_liquid_source && !C.is_liquid_sink)
				continue
			var/image/I = image(null, T)
			I.plane = POINT_PLANE
			I.maptext_width = 32
			I.maptext_height = 16
			I.maptext = overlay_label(C, C.fluidsum)
			viewer.images += I
			overlay_images += I
	addtimer(CALLBACK(src, PROC_REF(refresh_overlay)), 10, TIMER_UNIQUE)

/datum/liquid_debug_view/proc/clear_overlay()
	if(viewer)
		for(var/image/I in overlay_images)
			viewer.images -= I
	overlay_images = list()

// --- pool highlight flash ---

/datum/liquid_debug_view/proc/highlight_pool(list/pool)
	clear_highlights()
	if(!viewer || !length(pool))
		return
	for(var/turf/T as anything in pool)
		var/image/I = image(null, T)
		I.appearance = T.appearance
		I.override = TRUE
		I.color = "#8878c8"
		viewer.images += I
		highlight_images += I
	addtimer(CALLBACK(src, PROC_REF(clear_highlights)), 8 SECONDS, TIMER_UNIQUE | TIMER_OVERRIDE)

/datum/liquid_debug_view/proc/clear_highlights()
	if(viewer)
		for(var/image/I in highlight_images)
			viewer.images -= I
	highlight_images = list()

// --- flow direction tools ---

/datum/liquid_debug_view/proc/set_turf_flow(turf/T, dir)
	if(!istype(T, /turf/open))
		return
	if(!T.cell)
		T.cell = new /cell(T)
		T.cell.InitLiquids()
	if(dir)
		T.cell.set_flow_dir(dir)
	else
		T.cell.clear_flow_dir()
	SSliquid.update_cell_image(T)

/datum/liquid_debug_view/proc/apply_flow_brush(turf/center)
	for(var/turf/open/T in range(brush_size, center))
		var/dx = T.x - center.x
		var/dy = T.y - center.y
		if(dx * dx + dy * dy > brush_size * brush_size + 1)
			continue
		set_turf_flow(T, flow_dir_choice)

/datum/liquid_debug_view/proc/is_water_body_member(turf/T)
	if(!T?.cell)
		return FALSE
	return T.cell.fluidsum >= MIN_FLUID_VOLUME || istype(T, /turf/open/water)

/datum/liquid_debug_view/proc/select_water_body(turf/origin)
	clear_flow_selection()
	if(isopenspace(origin))
		var/turf/below = GetBelow(origin)
		if(is_water_body_member(below))
			origin = below
	if(!is_water_body_member(origin))
		return
	var/list/seen = list()
	var/list/queue = list(origin)
	seen[origin] = TRUE
	while(length(queue))
		var/turf/T = queue[1]
		queue.Cut(1, 2)
		flow_selection += T
		if(length(flow_selection) >= LIQDBG_BODY_CAP)
			flow_selection_capped = TRUE
			break
		for(var/D in GLOB.cardinals)
			var/turf/N = get_step(T, D)
			if(!N || seen[N] || !is_water_body_member(N))
				continue
			seen[N] = TRUE
			queue += N
	refresh_selection_images()

/datum/liquid_debug_view/proc/apply_flow_to_selection()
	for(var/turf/T as anything in flow_selection)
		set_turf_flow(T, flow_dir_choice)
		CHECK_TICK
	refresh_selection_images()

/datum/liquid_debug_view/proc/refresh_selection_images()
	if(viewer)
		for(var/image/I in selection_images)
			viewer.images -= I
	selection_images = list()
	if(!viewer)
		return
	for(var/turf/T as anything in flow_selection)
		var/image/I = image(null, T)
		I.appearance = T.appearance
		I.override = TRUE
		I.color = "#a99ae0"
		I.filters = filter(type = "outline", size = 1, color = "#a090e0")
		viewer.images += I
		selection_images += I

/datum/liquid_debug_view/proc/clear_flow_selection()
	if(viewer)
		for(var/image/I in selection_images)
			viewer.images -= I
	selection_images = list()
	flow_selection = list()
	flow_selection_capped = FALSE

#undef LIQDBG_POOL_SCAN_CAP
#undef LIQDBG_TOP_POOLS
#undef LIQDBG_LIST_CAP
