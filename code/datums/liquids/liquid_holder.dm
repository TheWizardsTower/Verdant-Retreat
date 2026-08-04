/cell
	parent_type = /datum

	var/pressure_mask = 0 // Bitmask tracking flow directions: NORTH=1, SOUTH=2, EAST=4, WEST=8

	// The simulation buffers live in verdant_native; this list is a read
	// cache kept in sync from the engine's per-tick deltas.
	var/list/fluid_volume // Associative list mapping fluid datums to integer amounts
	var/fluidsum = 0 // Total amount of fluid from all types

	var/flow_dir = 0 // Direction bitmask for flow modification (rivers, currents)
	var/flow_rate = 1
	var/contain_max = 0
	var/sim_exempt = FALSE
	var/is_liquid_source = FALSE // Make this TRUE to make a turf spawn fluid.
	var/production_rate = 0 // Amount of the fluid produced each processing loop.
	var/source_fluid_type = WATER // The fluid type a source produces. Sources produce exactly one type.
	var/is_liquid_sink = FALSE // Make this TRUE to make a turf despawn fluid.
	var/absorption_rate = 0 // Amount of fluid deleted per processing loop by the sink.
	var/last_fluid_level = 0 // Tracks the amount of fluid in the last processing loop. So we know if we need to update the icon or not.
	var/vis_fluid_level = -1 // Fluid band the overlay currently shows, set by native band commits; -1 until the first commit
	var/datum/liquid/shown_fluid // Dominant fluid the overlay last showed; delta application skips redraws while band and dominant fluid are both unchanged
	var/shown_mix = 10 // Dominant fluid's share of the last-shown blend in tenths (10 = pure); redraws fire when a mixed cell's ratio bucket shifts
	var/last_fluid_time = 0 // When this turf last had significant fluid (for pool persistence)
	var/doused = FALSE // Whether the standing-fluid douse event already fired for the current wetting

	var/fluid_flags // A bitfield of flags for fluids. Look in code\__defines\liquid.dm for definitions.
	var/coords/coords
	var/pool_id = 0 // A numeric reference to the generic datum that is used as a wrapper to store a list of cells that form a pool. 0 means no pool.

/cell/New(turf/target_turf)
	..()
	coords = new(target_turf.x, target_turf.y, target_turf.z) // This way we can avoid circular references.

/cell/proc/InitLiquids()
	fluid_volume = list()
	fluid_flags = 0
	for(var/fluid in SSliquid.registry.registered_liquids)
		var/datum/liquid/newfluid = new fluid
		if(newfluid.reagent)
			newfluid.color = initial(newfluid.reagent:color)
		fluid_volume[newfluid] = 0

	// Cell API methods for safe fluid manipulation
/cell/proc/add_fluid_safe(datum/liquid/fluid_type, amount)
	return SSliquid.manager.add_fluid(get_turf_from_cell(), fluid_type, amount)

/cell/proc/remove_fluid_safe(datum/liquid/fluid_type, amount)
	return SSliquid.manager.remove_fluid(get_turf_from_cell(), fluid_type, amount)

/cell/proc/get_fluid_amount_safe(datum/liquid/fluid_type)
	return GET_FLUID_AMOUNT(get_turf_from_cell(), fluid_type)

/cell/proc/get_total_fluid_safe()
	return GET_TOTAL_FLUID(get_turf_from_cell())

/cell/proc/get_dominant_fluid_safe()
	return GET_DOMINANT_FLUID(get_turf_from_cell())

/cell/proc/has_fluid_type_safe(datum/liquid/fluid_type)
	return HAS_FLUID_TYPE(get_turf_from_cell(), fluid_type)

/cell/proc/get_all_fluids_safe()
	return GET_ALL_FLUIDS(get_turf_from_cell())

/cell/proc/clear_all_fluids_safe()
	return CLEAR_ALL_FLUIDS(get_turf_from_cell())

/cell/proc/get_turf_from_cell()
	return locate(coords.x_pos, coords.y_pos, coords.z_pos)

	// Helper to get existing fluid datum by type or instance - eliminates
	// verbose locate() calls! A dynamic /datum/liquid instance (bare type,
	// .reagent set) is matched by reagent instead of aliasing to whichever
	// dynamic instance happens to be first via locate().
/cell/proc/get_fluid_datum(fluid_type)
	if(!ispath(fluid_type) && istype(fluid_type, /datum/liquid))
		var/datum/liquid/instance = fluid_type
		if(instance.type == /datum/liquid && instance.reagent)
			for(var/datum/liquid/existing as anything in fluid_volume)
				if(existing.type == /datum/liquid && existing.reagent == instance.reagent)
					return existing
			return null
		fluid_type = instance.type
	return locate(fluid_type) in fluid_volume

	// Fluid flag management methods
/cell/proc/set_fluid_flag(flag)
	fluid_flags |= flag

/cell/proc/clear_fluid_flag(flag)
	fluid_flags &= ~flag

/cell/proc/has_fluid_flag(flag)
	return (fluid_flags & flag) != 0

/cell/proc/toggle_fluid_flag(flag)
	fluid_flags ^= flag

	// Pool management methods
/cell/proc/set_pool_id(new_id)
	pool_id = new_id

/cell/proc/get_pool_id()
	return pool_id

/cell/proc/clear_pool_id()
	pool_id = 0

	// Flow direction methods
/cell/proc/set_flow_dir(new_dir)
	flow_dir = new_dir
	vn_fluid_queue(VN_FLUID_OP_SET_FLOW_DIR, get_turf_from_cell(), new_dir)

/cell/proc/clear_flow_dir()
	flow_dir = 0
	vn_fluid_queue(VN_FLUID_OP_SET_FLOW_DIR, get_turf_from_cell(), 0)

/cell/proc/has_flow_modification()
	return flow_dir != 0

	// Must be used instead of writing contain_max directly: the subsystem
	// counter lets the per-delta containment check short-circuit when no
	// contained cells exist anywhere
/cell/proc/set_contain_max(value)
	if(!contain_max != !value)
		SSliquid.contained_cells += value ? 1 : -1
	contain_max = value

	// Source/sink management
/cell/proc/make_liquid_source(rate = 1, fluid_type = WATER)
	is_liquid_source = TRUE
	production_rate = rate
	source_fluid_type = fluid_type
	var/turf/T = get_turf_from_cell()
	if(T)
		SSliquid.liquid_sources += T
		vn_fluid_queue(VN_FLUID_OP_SET_SOURCE, T, vn_fluid_mat_id(fluid_type), rate)

/cell/proc/make_liquid_sink(rate = 1)
	is_liquid_sink = TRUE
	absorption_rate = rate
	var/turf/T = get_turf_from_cell()
	if(T)
		SSliquid.liquid_sinks += T
		vn_fluid_queue(VN_FLUID_OP_SET_SINK, T, 0, rate)

/cell/proc/remove_liquid_source()
	is_liquid_source = FALSE
	production_rate = 0
	var/turf/T = get_turf_from_cell()
	if(T)
		SSliquid.liquid_sources -= T
		vn_fluid_queue(VN_FLUID_OP_CLEAR_SOURCE, T)

/cell/proc/remove_liquid_sink()
	is_liquid_sink = FALSE
	absorption_rate = 0
	var/turf/T = get_turf_from_cell()
	if(T)
		SSliquid.liquid_sinks -= T
		vn_fluid_queue(VN_FLUID_OP_CLEAR_SINK, T)

	// Fluid level tracking
/cell/proc/update_last_fluid_level()
	last_fluid_level = SSliquid.get_fluid_level(get_turf_from_cell())

/cell/proc/get_last_fluid_level()
	return last_fluid_level

	// Direct access discouraged methods
/cell/proc/get_raw_fluid_volume()
	return fluid_volume
