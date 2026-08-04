/*
 * Liquid Manager API
 *
 * This system provides a clean interface for interacting with the liquid simulation
 * subsystem. It encapsulates all liquid operations and provides validation to ensure
 * safe manipulation of fluid data.
 *
 * Main responsibilities:
 * - Fluid addition/removal with proper validation
 * - Reagent <-> Liquid conversion with safety checks
 * - Pool management operations
 * - Debugging and monitoring tools
 */

/datum/liquid_manager
	var/name = "Liquid Manager"

	// Basic validation constants
	var/const/VALIDATE_BASIC = 1

/datum/liquid_manager/New()
	..()

/datum/liquid_manager/proc/add_fluid(turf/target_turf, datum/liquid/fluid_type, amount)
	if(!target_turf?.cell || !fluid_type || !isnum(amount) || amount <= 0)
		return 0

	var/datum/liquid/fluid_instance = get_liquid_instance(target_turf, fluid_type, TRUE)
	if(!fluid_instance)
		log_debug("Liquid Manager: Failed to get liquid instance for [fluid_type]")
		return 0

	var/int_amount = round(amount)
	var/clamped_amount = clamp(int_amount, 0, MAX_FLUID_VOLUME - target_turf.cell.fluidsum)
	target_turf.cell.fluid_volume[fluid_instance] += clamped_amount

	// Update subsystem tracking
	SSliquid.cell_index[target_turf] = TRUE
	SSliquid.update_fluidsum(target_turf)
	vn_fluid_queue(VN_FLUID_OP_SET, target_turf, vn_fluid_mat_id(fluid_instance), target_turf.cell.fluid_volume[fluid_instance])

	return clamped_amount

/datum/liquid_manager/proc/remove_fluid(turf/target_turf, datum/liquid/fluid_type, amount)
	if(!target_turf?.cell || !fluid_type || !isnum(amount) || amount <= 0)
		return 0

	var/datum/liquid/fluid_instance = get_liquid_instance(target_turf, fluid_type)
	if(!fluid_instance)
		log_debug("Liquid Manager: Cannot remove fluid - no instance found for [fluid_type]")
		return 0

	var/int_amount = round(amount)
	var/current_amount = target_turf.cell.fluid_volume[fluid_instance]
	var/remove_amount = min(int_amount, current_amount)

	target_turf.cell.fluid_volume[fluid_instance] -= remove_amount

	// Update subsystem tracking
	SSliquid.update_fluidsum(target_turf)
	vn_fluid_queue(VN_FLUID_OP_SET, target_turf, vn_fluid_mat_id(fluid_instance), target_turf.cell.fluid_volume[fluid_instance])

	return remove_amount

/datum/liquid_manager/proc/transfer_fluid(turf/source_turf, turf/target_turf, datum/liquid/fluid_type, amount)
	if(!source_turf?.cell || !target_turf?.cell || !fluid_type || !isnum(amount) || amount <= 0)
		return 0

	var/removed_amount = remove_fluid(source_turf, fluid_type, amount)
	if(removed_amount <= 0)
		return 0

	var/added_amount = add_fluid(target_turf, fluid_type, removed_amount)

	// If we couldn't add all of it back, restore the difference to source
	var/leftover = removed_amount - added_amount
	if(leftover > 0)
		add_fluid(source_turf, fluid_type, leftover)

	return added_amount

/datum/liquid_manager/proc/get_fluid_amount(turf/target_turf, datum/liquid/fluid_type)
	if(!target_turf?.cell || !fluid_type)
		return 0

	var/datum/liquid/fluid_instance = get_liquid_instance(target_turf, fluid_type)
	if(!fluid_instance)
		return 0

	return target_turf.cell.fluid_volume[fluid_instance]

/datum/liquid_manager/proc/get_total_fluid(turf/target_turf)
	if(!target_turf?.cell)
		return 0

	return target_turf.cell.fluidsum

/datum/liquid_manager/proc/convert_reagent_to_fluid(reagent_type, amount, atom/container, turf/target_turf)
	if(!reagent_type || !container || !target_turf?.cell || !isnum(amount) || amount <= 0)
		return 0

	var/fluid_type = SSliquid.registry.get_liquid_from_reagent(reagent_type)
	var/datum/liquid/fluid_instance = get_liquid_instance(target_turf, fluid_type, TRUE)
	if(!fluid_instance)
		log_debug("Liquid Manager: Failed to get liquid instance for [fluid_type]")
		return 0

	var/max_transfer = MAX_FLUID_VOLUME - target_turf.cell.fluid_volume[fluid_instance]
	var/available_reagent = min(amount, container.reagents.get_reagent_amount(reagent_type))
	var/transfer_amount = round(min(available_reagent, max_transfer))

	if(transfer_amount <= 0)
		return 0

	target_turf.cell.fluid_volume[fluid_instance] += transfer_amount
	container.reagents.remove_reagent(reagent_type, transfer_amount)

	SSliquid.update_fluidsum(target_turf)
	SSliquid.update_cell_image(target_turf)
	SSliquid.cell_index[target_turf] = TRUE

	return transfer_amount

/datum/liquid_manager/proc/convert_fluid_to_reagent(datum/liquid/fluid_type, amount, atom/container, turf/source_turf)
	if(!fluid_type || !container || !source_turf?.cell || !isnum(amount) || amount <= 0)
		return 0

	var/datum/liquid/fluid_instance = get_liquid_instance(source_turf, fluid_type)
	if(!fluid_instance)
		log_debug("Liquid Manager: Failed to get liquid instance for [fluid_type] on [source_turf]")
		return 0

	var/max_container_space
	if(istype(container, /obj/item/reagent_containers))
		var/obj/item/reagent_containers/RC = container
		max_container_space = RC.volume - RC.reagents.total_volume
	else
		max_container_space = container.reagents.maximum_volume - container.reagents.total_volume

	var/available_fluid = source_turf.cell.fluid_volume[fluid_instance]
	var/transfer_amount = round(min(amount, available_fluid, max_container_space))

	if(transfer_amount <= 0)
		return 0

	source_turf.cell.fluid_volume[fluid_instance] -= transfer_amount
	container.reagents.add_reagent(fluid_type.reagent, transfer_amount)

	SSliquid.update_fluidsum(source_turf)
	SSliquid.update_cell_image(source_turf)

	return transfer_amount

/datum/liquid_manager/proc/get_liquid_instance(turf/target_turf, datum/liquid/fluid_type, create_if_missing = FALSE)
	if(!target_turf?.cell || !fluid_type)
		return null

	// dynamic reagent liquids all share exact type /datum/liquid, so locate()
	// by type would alias different reagents to the first entry - match by
	// .reagent instead. Statics keep the plain locate-by-type lookup.
	var/is_dynamic = (fluid_type.type == /datum/liquid && fluid_type.reagent)
	var/datum/liquid/instance
	if(is_dynamic)
		for(var/datum/liquid/existing as anything in target_turf.cell.fluid_volume)
			if(existing.type == /datum/liquid && existing.reagent == fluid_type.reagent)
				instance = existing
				break
	else
		instance = locate(fluid_type.type) in target_turf.cell.fluid_volume

	if(!instance && create_if_missing) // This is a fallback, mainly intended for when "dynamic liquids" is turned on.
		instance = new fluid_type.type
		if(is_dynamic)
			instance.reagent = fluid_type.reagent
			instance.name = fluid_type.name
		if(instance.reagent)
			instance.color = initial(instance.reagent:color)
		target_turf.cell.fluid_volume[instance] = 0

	return instance

// Internal helper for safe fluid volume access
/datum/liquid_manager/proc/get_fluid_volume_safe(turf/target_turf, datum/liquid/fluid_instance)
	if(!target_turf?.cell || !fluid_instance)
		return 0
	return target_turf.cell.fluid_volume[fluid_instance]

// Internal helper for safe fluid volume modification
/datum/liquid_manager/proc/set_fluid_volume_safe(turf/target_turf, datum/liquid/fluid_instance, amount)
	if(!target_turf?.cell || !fluid_instance || !isnum(amount))
		return FALSE
	target_turf.cell.fluid_volume[fluid_instance] = amount
	vn_fluid_queue(VN_FLUID_OP_SET, target_turf, vn_fluid_mat_id(fluid_instance), amount)
	return TRUE

/datum/liquid_manager/proc/get_dominant_fluid(turf/target_turf)
	if(!target_turf?.cell)
		return null

	return target_turf.get_highest_fluid_by_volume()

/datum/liquid_manager/proc/has_fluid_type(turf/target_turf, datum/liquid/fluid_type)
	return get_fluid_amount(target_turf, fluid_type) > 0

/datum/liquid_manager/proc/get_all_fluids(turf/target_turf)
	if(!target_turf?.cell)
		return list()

	var/list/fluid_list = list()
	for(var/datum/liquid/fluid in target_turf.cell.fluid_volume)
		if(target_turf.cell.fluid_volume[fluid] > 0)
			fluid_list[fluid] = target_turf.cell.fluid_volume[fluid]

	return fluid_list

/datum/liquid_manager/proc/clear_all_fluids(turf/target_turf)
	if(!target_turf?.cell)
		return FALSE

	for(var/datum/liquid/fluid in target_turf.cell.fluid_volume)
		target_turf.cell.fluid_volume[fluid] = 0

	SSliquid.update_fluidsum(target_turf)
	SSliquid.update_cell_image(target_turf)
	vn_fluid_queue(VN_FLUID_OP_CLEAR, target_turf)

	return TRUE