/*
Liquid Registry System

This system manages the registration and loading of liquid types.

Main responsibilities include:
- Discovery and registration of liquid types
- Validation and integrity checking for runtime safety
- Reagent/Liquid mapping
- Acting as an extension for liquid behaviors
*/

/datum/liquid_registry
	var/name = "Liquid Registry"
	var/list/registered_liquids
	var/list/reagent_to_liquid_map
	var/list/liquid_to_reagent_map
	var/list/liquid_behaviors
	var/list/flag_behaviors
	var/allow_dynamic_liquids = FALSE // Controls whether dynamic liquids and floor reactions are enabled
	
	// Performance optimization caching
	var/list/behavior_cache // Cache for expensive behavior lookups
	var/list/validation_cache // Cache for validation results
	var/cache_timer = 0
	var/cache_cleanup_interval = 200 // Clean cache every 200 ticks

/datum/liquid_registry/New()
	..()
	registered_liquids = new
	reagent_to_liquid_map = new
	liquid_to_reagent_map = new
	liquid_behaviors = new
	flag_behaviors = new
	behavior_cache = new
	validation_cache = new

	discover_liquid_types()
	build_reagent_maps()
	register_default_behaviors()
	enable_dynamic_liquids()

/datum/liquid_registry/proc/discover_liquid_types()
	registered_liquids.Cut()

	for(var/liquid_type in subtypesof(/datum/liquid))
		register_liquid_type(liquid_type)

/datum/liquid_registry/proc/register_liquid_type(liquid_type)
	if(!liquid_type)
		return FALSE

	if(liquid_type in registered_liquids)
		return TRUE // Already registered

	// Validate the liquid type
	if(!validate_liquid_type(liquid_type))
		return FALSE

	registered_liquids[liquid_type] = new liquid_type
	return TRUE

/datum/liquid_registry/proc/unregister_liquid_type(liquid_type)
	if(liquid_type in registered_liquids)
		var/datum/liquid/instance = registered_liquids[liquid_type]
		if(instance.reagent)
			reagent_to_liquid_map.Remove(instance.reagent)
			liquid_to_reagent_map.Remove(liquid_type)

		registered_liquids.Remove(liquid_type)
		return TRUE
	return FALSE

/datum/liquid_registry/proc/validate_liquid_type(liquid_type)
	if(!ispath(liquid_type, /datum/liquid))
		return FALSE

	// Validate liquid type has required properties
	if(!initial(liquid_type:name))
		log_debug("Liquid Registry: Liquid type [liquid_type] lacks a name property")
		return FALSE

	// Check for valid color (if specified)
	var/color_value = initial(liquid_type:color)
	if(color_value && !istext(color_value) && !isnum(color_value))
		log_debug("Liquid Registry: Liquid type [liquid_type] has invalid color format")
		return FALSE

	// Validate fluid flags are numeric
	var/flags_value = initial(liquid_type:fluid_flags)
	if(flags_value && !isnum(flags_value))
		log_debug("Liquid Registry: Liquid type [liquid_type] has invalid fluid_flags format")
		return FALSE

	// Check reagent mapping validity (if specified)
	var/reagent_type = initial(liquid_type:reagent)
	if(reagent_type && !ispath(reagent_type, /datum/reagent))
		log_debug("Liquid Registry: Liquid type [liquid_type] has invalid reagent mapping: [reagent_type]")
		return FALSE

	return TRUE

/datum/liquid_registry/proc/validate_reagent_mapping(reagent_type, liquid_type)
	if(!reagent_type || !liquid_type)
		return FALSE

	// Validate reagent type is valid
	if(!ispath(reagent_type, /datum/reagent))
		log_debug("Liquid Registry: Invalid reagent type in mapping: [reagent_type]")
		return FALSE

	// Validate liquid type is registered
	if(!has_liquid_type(liquid_type))
		log_debug("Liquid Registry: Liquid type [liquid_type] not registered for reagent mapping")
		return FALSE

	// Check for mapping conflicts
	var/existing_liquid = reagent_to_liquid_map[reagent_type]
	if(existing_liquid && existing_liquid != liquid_type)
		log_debug("Liquid Registry: Reagent [reagent_type] already mapped to different liquid type: [existing_liquid]")
		return FALSE

	var/existing_reagent = liquid_to_reagent_map[liquid_type]
	if(existing_reagent && existing_reagent != reagent_type)
		log_debug("Liquid Registry: Liquid [liquid_type] already mapped to different reagent type: [existing_reagent]")
		return FALSE

	return TRUE

/datum/liquid_registry/proc/build_reagent_maps()
	reagent_to_liquid_map.len = 0
	liquid_to_reagent_map.len = 0

	for(var/liquid_type in registered_liquids)
		var/datum/liquid/liquid_instance = registered_liquids[liquid_type]
		if(liquid_instance.reagent)
			reagent_to_liquid_map[liquid_instance.reagent] = liquid_type
			liquid_to_reagent_map[liquid_type] = liquid_instance.reagent

/datum/liquid_registry/proc/get_liquid_from_reagent(reagent_type)
	return reagent_to_liquid_map[reagent_type]

/datum/liquid_registry/proc/get_reagent_from_liquid(liquid_type)
	return liquid_to_reagent_map[liquid_type]

/datum/liquid_registry/proc/get_all_liquid_types()
	return registered_liquids.Copy()

/datum/liquid_registry/proc/get_liquid_instance(liquid_type)
	return registered_liquids[liquid_type]

/datum/liquid_registry/proc/has_liquid_type(liquid_type)
	return liquid_type in registered_liquids

/datum/liquid_registry/proc/get_liquid_count()
	return length(registered_liquids)

/datum/liquid_registry/proc/register_liquid_behavior(liquid_type, behavior_name, behavior_proc)
	if(!has_liquid_type(liquid_type))
		return FALSE

	if(!(liquid_type in liquid_behaviors))
		liquid_behaviors[liquid_type] = list()

	liquid_behaviors[liquid_type][behavior_name] = behavior_proc
	return TRUE

/datum/liquid_registry/proc/get_liquid_behavior(liquid_type, behavior_name)
	if(liquid_type in liquid_behaviors)
		return liquid_behaviors[liquid_type][behavior_name]
	return

/datum/liquid_registry/proc/execute_liquid_behavior(liquid_type, behavior_name, ...)
	var/behavior_proc = get_liquid_behavior(liquid_type, behavior_name)
	if(behavior_proc)
		return call(src, behavior_proc)(arglist(args.Copy(3)))
	return

/datum/liquid_registry/proc/register_flag_behavior(flag, behavior_name, behavior_proc)
	if(!(flag in flag_behaviors))
		flag_behaviors["[flag]"] = list()

	flag_behaviors["[flag]"][behavior_name] = behavior_proc
	return TRUE

/datum/liquid_registry/proc/get_flag_behavior(flag, behavior_name)
	if(flag in flag_behaviors)
		return flag_behaviors["[flag]"][behavior_name]
	return

/datum/liquid_registry/proc/execute_flag_behavior(flag, behavior_name, ...)
	// Use cached behavior lookup for performance
	var/cache_key = "[flag]-[behavior_name]"
	var/behavior_proc = behavior_cache[cache_key]
	
	if(!behavior_proc)
		behavior_proc = get_flag_behavior(flag, behavior_name)
		if(behavior_proc)
			behavior_cache[cache_key] = behavior_proc
	
	if(behavior_proc)
		return call(src, behavior_proc)(arglist(args.Copy(3)))
	return

/datum/liquid_registry/proc/execute_behaviors_for_liquid(liquid_type, behavior_name, ...)
	// First try liquid-specific behaviors
	var/behavior_proc = get_liquid_behavior(liquid_type, behavior_name)
	if(behavior_proc)
		return call(src, behavior_proc)(arglist(args.Copy(3)))

	// Then try flag-based behaviors
	var/datum/liquid/liquid_instance = get_liquid_instance(liquid_type)
	if(liquid_instance)
		for(var/flag = 1; flag <= 32; flag <<= 1) // Check each bit flag
			if(liquid_instance.fluid_flags & flag)
				behavior_proc = get_flag_behavior(flag, behavior_name)
				if(behavior_proc)
					return call(src, behavior_proc)(arglist(args.Copy(3)))
	return

/datum/liquid_registry/proc/turf_has_liquid_with_flag(turf/T, flag)
	if(!T?.cell)
		return FALSE

	for(var/datum/liquid/fluid as anything in T.cell.fluid_volume)
		if(fluid.fluid_flags & flag)
			return TRUE
	return FALSE

/datum/liquid_registry/proc/create_liquid_from_reagent(reagent_type)
	var/liquid_type = get_liquid_from_reagent(reagent_type)
	if(liquid_type)
		return new liquid_type

	// This part handles dynamic creation for reagents without predefined liquid types.
	if(allow_dynamic_liquids)
		return create_dynamic_liquid(reagent_type)

	return null

/datum/liquid_registry/proc/create_dynamic_liquid(reagent_type)
	if(!reagent_type)
		return

	var/datum/liquid/dyn_liquid = new /datum/liquid
	dyn_liquid.reagent = reagent_type
	dyn_liquid.name = initial(reagent_type:name)
	dyn_liquid.color = initial(reagent_type:color)

	return dyn_liquid

/datum/liquid_registry/proc/get_liquids_by_property(property_name, property_value)
	var/list/matching_liquids = list()

	for(var/liquid_type in registered_liquids)
		var/datum/liquid/liquid_instance = registered_liquids[liquid_type]
		if(liquid_instance.vars[property_name] == property_value)
			matching_liquids += liquid_type

	return matching_liquids

/datum/liquid_registry/proc/get_registry_statistics()
	var/list/stats = list()

	stats["total_liquid_types"] = get_liquid_count()
	stats["mapped_reagents"] = length(reagent_to_liquid_map)
	stats["registered_behaviors"] = length(liquid_behaviors)

	var/has_reagent_count = 0
	var/has_color_count = 0

	for(var/liquid_type in registered_liquids)
		var/datum/liquid/liquid_instance = registered_liquids[liquid_type]
		if(liquid_instance.reagent)
			has_reagent_count++
		if(liquid_instance.color)
			has_color_count++

	stats["liquids_with_reagents"] = has_reagent_count
	stats["liquids_with_colors"] = has_color_count

	return stats

// This helper function should be called in-game to validate the integrity of the liquid registry if there are any issues
// It can be called by accessing SSliquid.registry and calling the proc directly from the variable viewer.
/datum/liquid_registry/proc/validate_registry_integrity()
	var/list/errors = list()

	// Validate all registered liquid types
	for(var/liquid_type in registered_liquids)
		if(!validate_liquid_type(liquid_type))
			errors += "Invalid liquid type registration: [liquid_type]"

		var/datum/liquid/liquid_instance = registered_liquids[liquid_type]
		if(!istype(liquid_instance))
			errors += "Invalid liquid instance for type: [liquid_type]"

	// Validate all reagent mappings
	for(var/reagent_type in reagent_to_liquid_map)
		var/liquid_type = reagent_to_liquid_map[reagent_type]
		if(!validate_reagent_mapping(reagent_type, liquid_type))
			errors += "Invalid reagent mapping: [reagent_type] -> [liquid_type]"

	// Check for duplicate reagent mappings
	var/list/reagent_check = list()
	for(var/reagent_type in reagent_to_liquid_map)
		if(reagent_type in reagent_check)
			errors += "Duplicate reagent mapping found: [reagent_type]"
		reagent_check[reagent_type] = TRUE

	// Check map consistency
	for(var/reagent_type in reagent_to_liquid_map)
		var/liquid_type = reagent_to_liquid_map[reagent_type]
		if(liquid_to_reagent_map[liquid_type] != reagent_type)
			errors += "Inconsistent mapping for reagent: [reagent_type]"

	// Validate behavior system integrity
	for(var/liquid_type in liquid_behaviors)
		if(!(liquid_type in registered_liquids))
			errors += "Behavior registered for unregistered liquid type: [liquid_type]"

		var/list/behaviors = liquid_behaviors[liquid_type]
		if(!islist(behaviors))
			errors += "Invalid behavior list for liquid type: [liquid_type]"

	// Validate flag behaviors
	for(var/flag_key in flag_behaviors)
		var/list/behaviors = flag_behaviors[flag_key]
		if(!islist(behaviors))
			errors += "Invalid flag behavior list for flag: [flag_key]"

	return length(errors) == 0 ? "Registry integrity validated successfully" : jointext(errors, "\n")

/datum/liquid_registry/proc/refresh_registry()
	discover_liquid_types()
	build_reagent_maps()

// This can be called in-game to export the liquid registry data if needed for debugging purposes.
/datum/liquid_registry/proc/export_registry_data()
	var/list/export_data = list()

	export_data["metadata"] = list(
		"generated_at" = time2text(world.time),
		"total_types" = get_liquid_count()
	)

	export_data["liquid_types"] = list()
	for(var/liquid_type in registered_liquids)
		var/datum/liquid/liquid_instance = registered_liquids[liquid_type]
		export_data["liquid_types"]["[liquid_type]"] = list(
			"name" = liquid_instance.name,
			"color" = liquid_instance.color,
			"reagent" = "[liquid_instance.reagent]"
		)

	export_data["reagent_mappings"] = reagent_to_liquid_map.Copy()
	export_data["behaviors"] = liquid_behaviors.Copy()

	return export_data

// Register default liquid behaviors
/datum/liquid_registry/proc/register_default_behaviors()
	// Register flag-based behaviors
	register_flag_behavior(FLUID_CONDUCTIVE, "conduct_shock", /datum/liquid_registry/proc/conduct_shock)
	register_flag_behavior(FLUID_FLAMMABLE, "create_fire_hazard", /datum/liquid_registry/proc/flammable_fire_hazard)
	register_flag_behavior(FLUID_PERMEATING, "apply_touch_effect", /datum/liquid_registry/proc/permeating_touch_effect)

	// Keep some liquid-specific behaviors for special cases
	register_liquid_behavior(/datum/liquid/fuel, "slip_hazard", /datum/liquid_registry/proc/fuel_slip_hazard)

	// Could add more: acid corrosion, poisonous gas emission, freezing, etc.
	// register_flag_behavior(FLUID_CORROSIVE, "corrode_items", /datum/liquid_registry/proc/corrosive_corrosion)


	//register_dynamic_touch_behaviors()

// Register touch behaviors for dynamic liquids created from reagents (turned off by default)
/datum/liquid_registry/proc/register_dynamic_touch_behaviors()
	for(var/liquid_type in registered_liquids)
		var/datum/liquid/liquid_instance = registered_liquids[liquid_type]
		// Only register touch behavior for liquids that have associated reagents
		if(liquid_instance?.reagent)
			register_liquid_behavior(liquid_type, "touch_mob", /datum/liquid_registry/proc/permeating_touch_effect)

// Apply sophisticated chemical effects based on liquid depth and exposure type
/datum/liquid_registry/proc/apply_liquid_chemical_effects(mob/living/M, turf/T, datum/liquid/liquid_instance, exposure_type = "shallow")
	if(!M || !T || !liquid_instance?.reagent)
		return FALSE

	// Use the liquid manager to safely get the liquid amount
	var/liquid_amount = GET_FLUID_AMOUNT(T, liquid_instance.type)
	if(liquid_amount < MIN_FLUID_VOLUME)
		return FALSE

	// Determine exposure level based on liquid depth and mob state
	var/fluid_level = GET_FLUID_LEVEL(T)
	var/actual_exposure = determine_exposure_type(M, T, fluid_level, exposure_type)

	// Calculate effect amount based on exposure type and liquid amount
	var/effect_amount = calculate_chemical_exposure_amount(liquid_amount, actual_exposure)
	if(effect_amount <= 0)
		return FALSE

	// Create temporary reagent holder for the chemical effect
	var/datum/reagents/temp_holder = new /datum/reagents(effect_amount)
	temp_holder.add_reagent(liquid_instance.reagent, effect_amount)

	var/datum/reagent/reagent_instance = temp_holder.get_master_reagent()
	if(!reagent_instance)
		qdel(temp_holder)
		return FALSE

	// Apply effects based on exposure type
	if(!M.reagents)
		return TRUE

	switch(actual_exposure)
		if("touch")
			M.reagents.add_reagent(liquid_instance.reagent, effect_amount * 0.1)
		if("skin_contact")
			M.reagents.add_reagent(liquid_instance.reagent, effect_amount * 0.3)
		if("drowning")
			M.reagents.add_reagent(liquid_instance.reagent, effect_amount * 0.5)

	qdel(temp_holder)
	return TRUE

/datum/liquid_registry/proc/determine_exposure_type(mob/living/M, turf/T, fluid_level, requested_type)
	if(M.stat != DEAD && ishuman(M) && FALSE) // Placeholder for future drowning checks
		return "drowning"

	switch(fluid_level)
		if(FLUID_VERY_LOW, FLUID_LOW) // Ankle deep
			return "touch" // Just touching through shoes/clothing
		else
			return "skin_contact"

/datum/liquid_registry/proc/calculate_chemical_exposure_amount(liquid_amount, exposure_type)
	var/base_amount = min(liquid_amount / 10, 10) // Base calculation

	switch(exposure_type)
		if("touch")
			return base_amount * 0.5 // Minimal exposure through clothing/shoes
		if("skin_contact")
			return base_amount // Normal skin contact
		if("drowning")
			return base_amount * 1.5 // Maximum exposure, inhaling and ingesting

	return base_amount

// Legacy wrapper for backwards compatibility
/datum/liquid_registry/proc/permeating_touch_effect(mob/M, turf/T, datum/liquid/liquid_instance)
	return apply_liquid_chemical_effects(M, T, liquid_instance, "skin_contact")

// Conductive liquids shock behavior
/datum/liquid_registry/proc/conduct_shock(mob/living/carbon/C, turf/T, shock_damage, def_zone, siemens_coeff)
	if(!C || !T || !T.cell)
		return FALSE

	SSliquid.refresh_cell_types(T)
	// Find any conductive liquid on this turf
	var/datum/liquid/conductive_fluid = null
	for(var/datum/liquid/fluid as anything in T.cell.fluid_volume)
		if(fluid.fluid_flags & FLUID_CONDUCTIVE)
			conductive_fluid = fluid
			break

	if(!conductive_fluid || T[conductive_fluid] <= 0)
		return FALSE

	var/list/pool = SSliquid.pool_manager.get_pool(T)
	var/avg_fluid = SSliquid.pool_manager.get_pool_avg_fluid(pool)

	var/list/targets = list()
	for(var/turf/P as anything in pool)
		// Check if this pool turf has conductive liquids
		var/has_conductive = FALSE
		for(var/datum/liquid/fluid as anything in P.cell.fluid_volume)
			if(fluid.fluid_flags & FLUID_CONDUCTIVE)
				has_conductive = TRUE
				break

		if(!has_conductive)
			continue

		for(var/mob/living/carbon/target in P)
			if(target && !target.throwing && target != C)
				targets += target

	for(var/mob/living/carbon/target as anything in targets)
		var/turf/L = target.loc
		if(!L)
			continue

		var/adjusted = shock_damage / max(1, sqrt(length(targets)))
		var/mult = L.cell.fluidsum / max(1, avg_fluid)

		if(target.resting || target.lying)
			def_zone = ran_zone()
			target.adjustFireLoss(Floor(max(adjusted, shock_damage)))
			adjusted = Floor(min(0.25 + adjusted * mult, shock_damage))
		else
			def_zone = pick(BODY_ZONE_PRECISE_L_FOOT, BODY_ZONE_PRECISE_R_FOOT, BODY_ZONE_L_LEG, BODY_ZONE_R_LEG)
			adjusted = Floor(min(adjusted * mult, shock_damage))

		if(ishuman(target))
			siemens_coeff = 1

		if(!target.throwing)
			target.electrocute_act(T, adjusted, def_zone, siemens_coeff)

	return TRUE

/datum/liquid_registry/proc/flammable_fire_hazard(turf/T, ignition_source)
	if(!T?.cell)
		return FALSE

	SSliquid.refresh_cell_types(T)
	// Find any flammable liquid on this turf
	var/datum/liquid/flammable_fluid = null
	var/total_flammable_amount = 0

	for(var/datum/liquid/fluid as anything in T.cell.fluid_volume)
		if(fluid.fluid_flags & FLUID_FLAMMABLE)
			flammable_fluid = fluid
			total_flammable_amount += T[fluid]

	if(!flammable_fluid || total_flammable_amount <= 5)  // Need minimum flammable liquid amount
		return FALSE

	// Check if there's enough flammable liquid to create a fire hazard
	if(total_flammable_amount >= 20)
		// Liquid itself is flammable, no need to set cell flags
		return TRUE

	return FALSE

// Example fuel slip hazard behavior
/datum/liquid_registry/proc/fuel_slip_hazard(mob/living/M, turf/T)
	if(!M || !T?.cell)
		return FALSE

	var/datum/liquid/fuel/fuel_fluid = T.get_fluid_datum(/datum/liquid/fuel)
	if(!fuel_fluid || T[fuel_fluid] <= 10)  // Need minimum fuel amount
		return FALSE

	if(prob(15 + min(T[fuel_fluid]/5, 30)))
		M.visible_message("<span class='warning'>[M] slips on the fuel!</span>")
		M.Knockdown(20)
		return TRUE

	return FALSE

// Trigger behaviors when a mob enters a liquid turf
/datum/liquid_registry/proc/trigger_behavior_on_enter(mob/living/M, turf/T)
	if(!M || !T?.cell || T.cell.fluidsum < MIN_FLUID_VOLUME)
		return

	// Trigger entry behaviors for each liquid type on this turf
	for(var/datum/liquid/fluid as anything in T.cell.fluid_volume)
		if(T.cell.fluid_volume[fluid] < MIN_FLUID_VOLUME)
			continue

		// Execute liquid-specific entry behaviors
		execute_liquid_behavior(fluid.type, "on_enter", M, T)

		// Execute flag-based entry behaviors
		if(fluid.fluid_flags & FLUID_PERMEATING)
			apply_liquid_chemical_effects(M, T, fluid)

/**
 * Processes chemical reactions between liquids on a turf's floor.
 * This mimics the chemistry system but operates on the liquid layer.
 * Only works when allow_dynamic_liquids is enabled.
 */
/datum/liquid_registry/proc/process_floor_reactions(turf/T)
	if(!allow_dynamic_liquids || !T?.cell || T.cell.fluidsum < MIN_FLUID_VOLUME)
		return FALSE
		
	// Perform cache maintenance during processing
	maintain_cache_health()

	// Create a temporary reagent holder to simulate chemistry reactions
	var/datum/reagents/temp_holder = new /datum/reagents(T.cell.fluidsum)

	// Add all liquid reagents to the temporary holder
	var/list/liquid_amounts = list()
	for(var/datum/liquid/fluid as anything in T.cell.fluid_volume)
		if(!fluid.reagent || T.cell.fluid_volume[fluid] < MIN_FLUID_VOLUME)
			continue

		var/amount = T.cell.fluid_volume[fluid]
		liquid_amounts[fluid] = amount
		temp_holder.add_reagent(fluid.reagent, amount)

	// Process reactions in the temporary holder
	var/reactions_occurred = 0

	if(reactions_occurred)
		// Clear existing liquids on the turf
		for(var/datum/liquid/fluid as anything in liquid_amounts)
			T.cell.fluid_volume[fluid] = 0

		// Convert reaction products back to floor liquids
		for(var/datum/reagent/product in temp_holder.reagent_list)
			if(product.volume < MIN_FLUID_VOLUME)
				continue

			// Get or create liquid type for this reagent
			var/datum/liquid/product_liquid = create_liquid_from_reagent(product.type)
			if(!product_liquid)
				continue

			// Add the product liquid to the floor
			var/datum/liquid/floor_liquid = SSliquid.manager.get_liquid_instance(T, product_liquid.type, TRUE)
			if(floor_liquid)
				T.cell.fluid_volume[floor_liquid] = product.volume

		// Update fluid sum and mark for processing
		SSliquid.update_fluidsum(T)
		T.cell.fluid_flags |= FLUID_MOVED
		SSliquid.cell_index[T] = TRUE

	qdel(temp_holder)
	return reactions_occurred

/**
 * Enables dynamic liquid creation and floor reactions.
 * This allows reagents to automatically become liquids and react on the floor.
 */
/datum/liquid_registry/proc/enable_dynamic_liquids()
	allow_dynamic_liquids = TRUE

/**
 * Disables dynamic liquid creation and floor reactions.
 * This is the default state for performance reasons.
 */
/datum/liquid_registry/proc/disable_dynamic_liquids()
	allow_dynamic_liquids = FALSE

/**
 * Checks if dynamic liquids are currently enabled.
 */
/datum/liquid_registry/proc/dynamic_liquids_enabled()
	return allow_dynamic_liquids

//================================================================
// --- Performance Optimization Functions ---
// These functions implement caching and optimization for the
// liquid registry to reduce lookup and validation overhead.
//================================================================

/**
 * Cleans up behavior and validation caches to prevent memory accumulation.
 * Should be called periodically to maintain performance.
 */
/datum/liquid_registry/proc/cleanup_caches()
	cache_timer++
	
	if(cache_timer >= cache_cleanup_interval)
		// Clear behavior cache
		behavior_cache.len = 0
		
		// Clear validation cache
		validation_cache.len = 0
		
		cache_timer = 0
		

/**
 * Optimized validation using cached results for expensive checks.
 * Reduces overhead for repeated validation operations.
 *
 * @param liquid_type The liquid type to validate.
 * @return TRUE if valid, FALSE otherwise.
 */
/datum/liquid_registry/proc/validate_liquid_type_cached(liquid_type)
	var/cache_key = "[liquid_type]"
	
	// Check cache first
	if(validation_cache[cache_key])
		return validation_cache[cache_key]
	
	// Perform validation and cache result
	var/result = validate_liquid_type(liquid_type)
	validation_cache[cache_key] = result
	
	return result

/**
 * Gets comprehensive performance statistics for registry operations.
 * Provides detailed information about caching effectiveness and usage.
 *
 * @return An associative list of performance statistics.
 */
/datum/liquid_registry/proc/get_performance_statistics()
	var/list/stats = list()
	
	stats["registered_liquids"] = length(registered_liquids)
	stats["behavior_cache_size"] = length(behavior_cache)
	stats["validation_cache_size"] = length(validation_cache)
	stats["cache_timer"] = cache_timer
	stats["cache_cleanup_interval"] = cache_cleanup_interval
	stats["allow_dynamic_liquids"] = allow_dynamic_liquids
	
	// Registry mapping statistics
	stats["reagent_mappings"] = length(reagent_to_liquid_map)
	stats["liquid_behaviors"] = length(liquid_behaviors)
	stats["flag_behaviors"] = length(flag_behaviors)
	
	return stats

/**
 * Forces immediate cleanup of all caches.
 * Used for emergency optimization or manual cache management.
 */
/datum/liquid_registry/proc/force_cache_cleanup()
	behavior_cache.len = 0
	validation_cache.len = 0
	cache_timer = 0

/**
 * Checks cache health and performs maintenance if needed.
 * Monitors cache sizes and triggers cleanup if they grow too large.
 */
/datum/liquid_registry/proc/maintain_cache_health()
	var/total_cache_size = length(behavior_cache) + length(validation_cache)
	
	// Force cleanup if caches get too large
	if(total_cache_size > 1000)
		world.log << "REGISTRY WARNING: Cache sizes excessive ([total_cache_size] entries), forcing cleanup"
		force_cache_cleanup()
	
	// Regular cleanup check
	cleanup_caches()
