/**
 * Liquid Pool Manager
 *
 * This system manages pools of contiguous liquid turfs. It provides functions for
 * efficiently checking if two turfs are part of the same pool, etc.
 */

GLOBAL_DATUM_INIT(pool_manager, /datum/pool_manager, new)

/datum/pool_manager
    var/name = "Pool Manager"

    /// Every turf currently holding at least MIN_FLUID_VOLUME of liquid.
    var/list/liquid_turfs

    /// Timer for continuous liquid behavior processing
    var/continuous_behavior_timer = 0

    /// Timer for floor chemical reaction processing
    var/reaction_timer = 0

    /// Timer for turf liquid absorption processing
    var/absorption_timer = 0

    /// Timer for rain injection processing
    var/rain_inject_timer = 0

    /// Timer for deferred turf wetness updates
    var/wet_update_timer = 0

    /// Turfs awaiting a deferred update_water() pass
    var/list/wet_update_queue = list()

/datum/pool_manager/New()
    ..()
    liquid_turfs = list()

/**
 * Checks if two turfs are part of the same contiguous liquid pool.
 */
/datum/pool_manager/proc/is_in_same_pool(turf/T1, turf/T2)
    if (!T1?.cell || !T2?.cell || T1.cell.fluidsum < MIN_FLUID_VOLUME || T2.cell.fluidsum < MIN_FLUID_VOLUME)
        return FALSE
    return (T2 in get_pool(T1))

/**
 * Retrieves all turfs belonging to the same pool as the given turf.
 */
/datum/pool_manager/proc/get_pool(turf/T)
    if (!T?.cell || T.cell.fluidsum < MIN_FLUID_VOLUME)
        return list(T) // Return a list containing only itself if invalid.

    var/list/raw = vn_fluid_pool_cells(T.x, T.y, T.z)
    if(!islist(raw))
        vn_check_result(raw, "fluid_pool_cells")
        return list(T)
    var/list/pool_turfs = list()
    for(var/i = 1, i + 2 <= length(raw), i += 3)
        var/turf/member = locate(raw[i], raw[i + 1], raw[i + 2])
        if(member)
            pool_turfs += member
    return length(pool_turfs) ? pool_turfs : list(T)

/**
 * Gets the number of turfs in a specific pool.
 */
/datum/pool_manager/proc/get_pool_size(turf/T)
    if (!T?.cell || T.cell.fluidsum < MIN_FLUID_VOLUME)
        return 1
    var/list/stats = vn_fluid_pool_stats(T.x, T.y, T.z)
    if(islist(stats) && length(stats) >= 1)
        return stats[1]
    return 1

/**
 * Calculates the average fluid volume across all turfs in a pool.
 */
/datum/pool_manager/proc/get_pool_avg_fluid(list/pool)
    if (!length(pool))
        return 0

    var/total_fluid = 0
    for (var/turf/T as anything in pool)
        if (T?.cell)
            total_fluid += T.cell.fluidsum

    return total_fluid / length(pool)

/**
 * Gathers statistics about the current state of all liquid pools.
 */
/datum/pool_manager/proc/get_pool_statistics()
    var/list/seen = list()
    var/total_pools = 0
    var/largest_pool = 0
    for(var/turf/T as anything in liquid_turfs)
        if(seen[T])
            continue
        var/list/pool = get_pool(T)
        total_pools++
        if(length(pool) > largest_pool)
            largest_pool = length(pool)
        for(var/turf/member as anything in pool)
            seen[member] = TRUE
        CHECK_TICK

    return list(
        "total_pools" = total_pools,
        "largest_pool" = largest_pool,
        "total_turfs_in_pools" = length(liquid_turfs),
        "average_pool_size" = total_pools > 0 ? length(liquid_turfs) / total_pools : 0
    )

/**
 * Generates a comprehensive list of all distinct pools for debugging.
 */
/datum/pool_manager/proc/get_all_pools_for_debug()
    var/list/pools = list()
    var/list/seen = list()
    for(var/turf/T as anything in liquid_turfs)
        if(seen[T])
            continue
        var/list/pool = get_pool(T)
        pools += list(pool)
        for(var/turf/member as anything in pool)
            seen[member] = TRUE
        CHECK_TICK
    return pools

/**
 * Processes continuous liquid behaviors for all mobs standing in liquid pools.
 * Should be called periodically from the liquid subsystem.
 */
/datum/pool_manager/proc/process_continuous_behaviors()
    // Process continuous behaviors every 5 seconds
    if(world.time < continuous_behavior_timer)
        return

    continuous_behavior_timer = world.time + 5 SECONDS

    // Process all mobs standing in liquid pools
    for(var/turf/T as anything in liquid_turfs)
        if(!T?.cell || T.cell.fluidsum < MIN_FLUID_VOLUME)
            continue

        // Find all mobs on this liquid turf
        for(var/mob/living/M in T)
            if(!M || M.stat == DEAD)
                continue

            // Apply continuous behaviors for each liquid type
            for(var/datum/liquid/fluid as anything in T.cell.fluid_volume)
                if(T.cell.fluid_volume[fluid] < MIN_FLUID_VOLUME)
                    continue

                // Execute continuous flag-based behaviors with sophisticated exposure
                if(fluid.fluid_flags & FLUID_PERMEATING)
                    // Use the sophisticated exposure system that checks is_drowning
                    GLOB.liquid_registry.apply_liquid_chemical_effects(M, T, fluid)

                if(fluid.fluid_flags & FLUID_CORROSIVE)
                    GLOB.liquid_registry.execute_flag_behavior(FLUID_CORROSIVE, "corrode_mob", M, T, fluid)

                // Execute continuous liquid-specific behaviors
                GLOB.liquid_registry.execute_liquid_behavior(fluid.type, "continuous_effect", M, T)

/**
 * Processes chemical reactions on liquid turfs when dynamic liquids are enabled.
 * Should be called periodically from the liquid subsystem.
 */
/datum/pool_manager/proc/process_floor_reactions()
    if(!GLOB.liquid_registry.allow_dynamic_liquids)
        return

    // Process floor reactions every 10 seconds - slower than behaviors
    if(world.time < reaction_timer)
        return

    reaction_timer = world.time + 10 SECONDS

    // Process reactions on liquid turfs that have multiple reagent types
    for(var/turf/T as anything in liquid_turfs)
        if(!T?.cell || T.cell.fluidsum < MIN_FLUID_VOLUME)
            continue

        // Only process if there are multiple liquids with reagents that could react
        var/reagent_count = 0
        for(var/datum/liquid/fluid as anything in T.cell.fluid_volume)
            if(fluid.reagent && T.cell.fluid_volume[fluid] >= MIN_FLUID_VOLUME)
                reagent_count++
                if(reagent_count >= 2)
                    break

        if(reagent_count >= 2)
            GLOB.liquid_registry.process_floor_reactions(T)

/**
 * Gets performance statistics for pool operations.
 */
/datum/pool_manager/proc/get_performance_statistics()
    var/list/stats = list()
    stats["total_liquid_turfs"] = length(liquid_turfs)
    return stats

/**
 * Absorbs fluid from liquid-bearing turfs into their tracked wetness, bridging
 * into the existing water_level/mud system. Should be called periodically from
 * the liquid subsystem.
 */
/datum/pool_manager/proc/process_absorption()
    if(world.time < absorption_timer)
        return

    absorption_timer = world.time + 2 SECONDS

    for(var/turf/open/T as anything in liquid_turfs)
        if(!istype(T) || istype(T, /turf/open/water))
            continue
        if(!T.liquid_absorption || !T.cell || T.cell.fluidsum < MIN_FLUID_VOLUME)
            continue

        var/datum/liquid/fluid = T.get_highest_fluid_by_volume()
        if(!fluid)
            continue

        var/absorbed = GLOB.liquid_manager.remove_fluid(T, fluid, T.liquid_absorption)
        if(absorbed > 0)
            T.add_water(absorbed * LIQUID_ABSORPTION_WETNESS_MULT)

/**
 * Queues a turf for a deferred update_water() pass.
 */
/datum/pool_manager/proc/queue_wet_update(turf/open/T)
    wet_update_queue[T] = TRUE

/**
 * Runs deferred update_water() on queued turfs; a turf that returns TRUE is done.
 * Replaces the old SSwaterlevel subsystem. Should be called periodically from
 * the liquid subsystem.
 */
/datum/pool_manager/proc/process_wet_updates()
    if(world.time < wet_update_timer)
        return

    wet_update_timer = world.time + 3 SECONDS

    for(var/turf/open/T as anything in wet_update_queue.Copy())
        if(!istype(T) || QDELETED(T) || T.update_water())
            wet_update_queue -= T

/**
 * Stochastically injects water near players during rain, scaled by weather severity.
 * Should be called periodically from the liquid subsystem.
 */
/datum/pool_manager/proc/process_rain_injection()
    if(world.time < rain_inject_timer)
        return

    rain_inject_timer = world.time + RAIN_INJECT_INTERVAL

    var/datum/particle_weather/W = SSParticleWeather.runningWeather
    if(!W || !W.running || W.target_trait != PARTICLEWEATHER_RAIN)
        return

    var/n = round(RAIN_INJECT_BASE_SAMPLES * W.severityMod())
    for(var/i in 1 to n)
        if(!length(GLOB.player_list))
            break

        var/mob/sampler = pick(GLOB.player_list)
        var/turf/base = get_turf(sampler)
        if(!base)
            continue

        var/turf/raw = locate(base.x + rand(-RAIN_INJECT_RADIUS, RAIN_INJECT_RADIUS), base.y + rand(-RAIN_INJECT_RADIUS, RAIN_INJECT_RADIUS), base.z)
        if(!istype(raw, /turf/open) || istype(raw, /turf/open/water))
            continue

        var/turf/open/candidate = raw
        if(!candidate.outdoor_effect || candidate.outdoor_effect.weatherproof)
            continue

        if(!candidate.cell)
            candidate.cell = new /cell(candidate)
            candidate.cell.InitLiquids()

        var/datum/liquid/water_fluid = candidate.cell.get_fluid_datum(WATER)
        if(water_fluid)
            GLOB.liquid_manager.add_fluid(candidate, water_fluid, RAIN_INJECT_AMOUNT)
        candidate.add_water(RAIN_INJECT_AMOUNT)
