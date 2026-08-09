PROCESSING_SUBSYSTEM_DEF(faction_ai)
	name = "Faction AI"
	priority = FIRE_PRIORITY_IDLE_NPC
	flags = SS_KEEP_TIMING
	runlevels = RUNLEVEL_GAME
	wait = 5 SECONDS

	var/list/factions = list()
	var/list/factions_by_id = list()

/datum/controller/subsystem/processing/faction_ai/Initialize()
	. = ..()
	NEW_SS_GLOBAL(SSfaction_ai)
	var/list/portal_turfs = list()
	for(var/obj/structure/gob_portal/P in world)
		portal_turfs += get_turf(P)
	initialize_goblin_factions(portal_turfs)

/datum/controller/subsystem/processing/faction_ai/fire(resumed = FALSE)
	for(var/faction_director/F as anything in factions)
		if(F && !QDELETED(F))
			INVOKE_ASYNC(F, TYPE_PROC_REF(/faction_director, ProcessFaction))

/datum/controller/subsystem/processing/faction_ai/proc/RegisterFaction(faction_director/F)
	if(!F || QDELETED(F))
		return FALSE

	if(!(F in factions))
		factions += F
		if(F.faction_id)
			factions_by_id[F.faction_id] = F
		return TRUE
	return FALSE

/datum/controller/subsystem/processing/faction_ai/proc/UnregisterFaction(faction_director/F)
	if(!F)
		return

	factions -= F
	if(F.faction_id && factions_by_id[F.faction_id] == F)
		factions_by_id -= F.faction_id

/datum/controller/subsystem/processing/faction_ai/proc/GetFaction(faction_id)
	return factions_by_id[faction_id]

/faction_director
	var/faction_id = "default"
	var/faction_name = "Unknown Faction"
	var/list/faction_tags = list()

	var/list/resources = list()
	var/list/resource_generation_rate = list()

	var/director_points = 0
	var/points_per_cycle = 10
	var/max_director_points = 1000

	var/list/available_goals = list()
	var/list/active_goals = list()
	var/list/pending_tasks = list()

	var/list/spawn_points = list()
	var/list/spawn_budget = list()
	var/list/current_units = list()

	var/list/controlled_areas = list()
	var/atom/faction_home_base

	var/fortification_level = 0

/faction_director/New(id, name)
	if(id)
		faction_id = id
	if(name)
		faction_name = name

	InitializeResources()
	InitializeGoals()

	SSfaction_ai.RegisterFaction(src)

/faction_director/Destroy()
	SSfaction_ai.UnregisterFaction(src)

	for(var/faction_goal/G as anything in available_goals)
		qdel(G)
	for(var/faction_goal/G as anything in active_goals)
		qdel(G)

	available_goals.Cut()
	active_goals.Cut()
	pending_tasks.Cut()

	return ..()

/faction_director/proc/InitializeResources()
	resources = list(
		"wood" = 0,
		"stone" = 0,
		"food" = 0,
		"metal" = 0
	)

	resource_generation_rate = list(
		"wood" = 0,
		"stone" = 0,
		"food" = 0,
		"metal" = 0
	)

/faction_director/proc/InitializeGoals()
	available_goals += new /faction_goal/gather_resources(src, "wood")
	available_goals += new /faction_goal/gather_resources(src, "stone")
	available_goals += new /faction_goal/gather_resources(src, "food")

/faction_director/proc/ProcessFaction()
	UpdateResources()
	AccumulatePoints()
	EvaluateGoals()
	ProcessActiveGoals()
	ConsiderSpawning()
	UpdateUnitTracking()

/faction_director/proc/UpdateResources()
	for(var/resource_type in resource_generation_rate)
		var/generation = resource_generation_rate[resource_type]
		if(generation > 0)
			AddResource(resource_type, generation)

/faction_director/proc/AccumulatePoints()
	director_points = min(director_points + points_per_cycle, max_director_points)

/faction_director/proc/EvaluateGoals()
	if(!length(available_goals))
		return

	var/list/scored_goals = list()
	for(var/faction_goal/G as anything in available_goals)
		if(G.CanActivate(src))
			var/score = G.CalculateScore(src)
			if(score > 0)
				scored_goals[G] = score

	if(!length(scored_goals))
		return

	var/list/sorted_goals = sortTim(scored_goals, /proc/cmp_numeric_dsc, TRUE)

	for(var/faction_goal/G as anything in sorted_goals)
		if(director_points >= G.activation_cost)
			ActivateGoal(G)
			SpendPoints(G.activation_cost)
			break

/faction_director/proc/ActivateGoal(faction_goal/G)
	if(!G || (G in active_goals))
		return FALSE

	active_goals += G
	G.OnActivate(src)
	return TRUE

/faction_director/proc/DeactivateGoal(faction_goal/G)
	if(!G || !(G in active_goals))
		return FALSE

	active_goals -= G
	G.OnDeactivate(src)
	return TRUE

/faction_director/proc/ProcessActiveGoals()
	for(var/faction_goal/G as anything in active_goals)
		G.Process(src)

		if(G.IsComplete(src))
			G.OnComplete(src)
			DeactivateGoal(G)

/faction_director/proc/ConsiderSpawning()
	return

/faction_director/proc/UpdateUnitTracking()
	for(var/mob_type in current_units)
		current_units[mob_type] = 0

	for(var/mob/living/M in GLOB.mob_living_list)
		if(QDELETED(M) || M.stat == DEAD)
			continue

		if(IsFactionMember(M))
			var/mob_type = M.type
			if(mob_type in current_units)
				current_units[mob_type]++
			else
				current_units[mob_type] = 1

/faction_director/proc/IsFactionMember(mob/living/M)
	if(!M)
		return FALSE

	for(var/tag in faction_tags)
		if(tag in M.faction)
			return TRUE

	return FALSE

/faction_director/proc/RequestTask(mob/living/M)
	if(!length(pending_tasks))
		return null

	var/faction_task/best
	var/best_priority
	for(var/faction_task/T as anything in pending_tasks)
		if(!best || T.task_priority > best_priority)
			best = T
			best_priority = T.task_priority

	pending_tasks -= best
	return best

/faction_director/proc/get_random_work_turf(min_dist = 5, max_dist = 15)
	var/atom/home = faction_home_base
	if(!home)
		return null
	var/turf/home_turf = get_turf(home)
	if(!home_turf)
		return null
	for(var/i in 1 to 10)
		var/dist = rand(min_dist, max_dist)
		var/dir = pick(GLOB.alldirs)
		var/turf/candidate = get_ranged_target_turf(home_turf, dir, dist)
		if(istype(candidate) && !candidate.density)
			return candidate
	return home_turf

/faction_director/proc/AddTask(faction_task/T)
	if(!T)
		return
	pending_tasks += T

/faction_director/proc/AddResource(resource_type, amount)
	if(!(resource_type in resources))
		resources[resource_type] = 0
	resources[resource_type] += amount

/faction_director/proc/SpendResource(resource_type, amount)
	if(!(resource_type in resources))
		return FALSE
	if(resources[resource_type] < amount)
		return FALSE

	resources[resource_type] -= amount
	return TRUE

/faction_director/proc/GetResource(resource_type)
	return resources[resource_type] || 0

/faction_director/proc/SpendPoints(amount)
	if(director_points < amount)
		return FALSE
	director_points -= amount
	return TRUE

/faction_director/proc/SpawnUnit(mob_type, turf/spawn_location)
	if(!spawn_location)
		if(!length(spawn_points))
			return null
		spawn_location = pick(spawn_points)

	var/mob/living/M = new mob_type(spawn_location)
	if(!M)
		return null

	if(length(faction_tags))
		M.set_faction(faction_tags.Copy())

	if(M.ai_root?.blackboard)
		M.ai_root.blackboard[AIBLK_FACTION_DIRECTOR] = src

	return M

/faction_goal
	var/goal_name = "Unknown Goal"
	var/goal_description = "No description"
	var/activation_cost = 50
	var/base_score = 100
	var/active = FALSE

/faction_goal/New(faction_director/director, ...)
	..()

/faction_goal/Destroy()
	active = FALSE
	return ..()

/faction_goal/proc/CanActivate(faction_director/director)
	return !active

/faction_goal/proc/CalculateScore(faction_director/director)
	return base_score

/faction_goal/proc/OnActivate(faction_director/director)
	active = TRUE

/faction_goal/proc/OnDeactivate(faction_director/director)
	active = FALSE

/faction_goal/proc/Process(faction_director/director)
	return

/faction_goal/proc/IsComplete(faction_director/director)
	return FALSE

/faction_goal/proc/OnComplete(faction_director/director)
	return

/faction_goal/gather_resources
	goal_name = "Gather Resources"
	activation_cost = 30
	base_score = 80

	var/resource_type = "wood"
	var/target_amount = 100
	var/tasks_created = 0
	var/max_tasks = 3

/faction_goal/gather_resources/New(faction_director/director, res_type)
	..()
	if(res_type)
		resource_type = res_type
	goal_name = "Gather [resource_type]"

/faction_goal/gather_resources/CalculateScore(faction_director/director)
	var/current = director.GetResource(resource_type)
	var/deficit = target_amount - current

	if(deficit <= 0)
		return 0

	return base_score + (deficit / 10)

/faction_goal/gather_resources/OnActivate(faction_director/director)
	. = ..()
	tasks_created = 0

/faction_goal/gather_resources/Process(faction_director/director)
	if(tasks_created < max_tasks)
		var/faction_task/gather/T = new /faction_task/gather()
		T.resource_type = resource_type
		T.amount_to_gather = 10
		T.gather_location = director.get_random_work_turf()
		director.AddTask(T)
		tasks_created++

/faction_goal/gather_resources/IsComplete(faction_director/director)
	return director.GetResource(resource_type) >= target_amount

/faction_goal/spawn_unit
	goal_name = "Recruit Units"
	activation_cost = 100
	base_score = 60

	var/mob_type_to_spawn
	var/spawn_count = 1
	var/resource_cost_type = "food"
	var/resource_cost_amount = 50

/faction_goal/spawn_unit/CanActivate(faction_director/director)
	if(!..())
		return FALSE

	return director.GetResource(resource_cost_type) >= resource_cost_amount

/faction_goal/spawn_unit/CalculateScore(faction_director/director)
	var/current_units = 0
	for(var/count in director.current_units)
		current_units += director.current_units[count]

	if(current_units >= 20)
		return 0

	return base_score + (20 - current_units) * 5

/faction_goal/spawn_unit/OnActivate(faction_director/director)
	. = ..()

	if(director.SpendResource(resource_cost_type, resource_cost_amount))
		var/spawned_any = FALSE
		for(var/i = 1 to spawn_count)
			var/mob/living/M = director.SpawnUnit(mob_type_to_spawn)
			if(M)
				spawned_any = TRUE
		if(!spawned_any)
			director.AddResource(resource_cost_type, resource_cost_amount)

/faction_goal/spawn_unit/IsComplete(faction_director/director)
	return TRUE

/faction_task
	var/task_name = "Unknown Task"
	var/task_description = "No description"
	var/task_priority = 50
	var/assigned_to
	var/completed = FALSE

/faction_task/proc/CanExecute(mob/living/M)
	return TRUE

/faction_task/proc/Execute(mob/living/M)
	return NODE_FAILURE

/faction_task/proc/OnComplete(mob/living/M)
	completed = TRUE

/faction_task/gather
	task_name = "Gather Resources"
	var/resource_type = "wood"
	var/amount_to_gather = 10
	var/turf/gather_location
	var/phase = FACTION_TASK_TRAVEL
	var/work_start_time = 0

/faction_task/gather/Execute(mob/living/M)
	if(!M?.ai_root)
		return NODE_FAILURE
	var/faction_director/director = M.ai_root.blackboard[AIBLK_FACTION_DIRECTOR]
	if(!director || QDELETED(director))
		return NODE_FAILURE

	switch(phase)
		if(FACTION_TASK_TRAVEL)
			if(!gather_location)
				return NODE_FAILURE
			M.ai_root.blackboard[AIBLK_FACTION_TASK_DEST] = gather_location
			if(get_dist(M, gather_location) <= 1)
				phase = FACTION_TASK_WORK
				work_start_time = 0
				M.set_ai_path_to(null)
				M.ai_root.blackboard -= AIBLK_FACTION_TASK_DEST
				return NODE_RUNNING
			if(M.set_ai_path_to(gather_location))
				return NODE_RUNNING
			return NODE_FAILURE
		if(FACTION_TASK_WORK)
			if(!work_start_time)
				work_start_time = world.time
			if(world.time < work_start_time + 15 SECONDS)
				return NODE_RUNNING
			phase = FACTION_TASK_RETURN
			return NODE_RUNNING
		if(FACTION_TASK_RETURN)
			var/atom/home = director.faction_home_base
			if(!home)
				return NODE_SUCCESS
			M.ai_root.blackboard[AIBLK_FACTION_TASK_DEST] = home
			if(get_dist(M, home) <= 1)
				M.set_ai_path_to(null)
				M.ai_root.blackboard -= AIBLK_FACTION_TASK_DEST
				return NODE_SUCCESS
			if(M.set_ai_path_to(home))
				return NODE_RUNNING
			return NODE_SUCCESS
	return NODE_FAILURE

/faction_task/gather/OnComplete(mob/living/M)
	. = ..()
	if(!M?.ai_root)
		return
	var/faction_director/director = M.ai_root.blackboard[AIBLK_FACTION_DIRECTOR]
	if(!director || QDELETED(director))
		return
	director.AddResource(resource_type, amount_to_gather)

/faction_task/scavenge
	task_name = "Scavenge"
	task_priority = 40
	var/turf/scavenge_location
	var/collected = 0
	var/max_collected = 3
	var/phase = FACTION_TASK_TRAVEL
	var/work_start_time = 0

/faction_task/scavenge/Execute(mob/living/M)
	if(!M?.ai_root)
		return NODE_FAILURE
	var/faction_director/director = M.ai_root.blackboard[AIBLK_FACTION_DIRECTOR]
	if(!director || QDELETED(director))
		return NODE_FAILURE

	switch(phase)
		if(FACTION_TASK_TRAVEL)
			if(!scavenge_location)
				return NODE_FAILURE
			M.ai_root.blackboard[AIBLK_FACTION_TASK_DEST] = scavenge_location
			if(get_dist(M, scavenge_location) <= 1)
				phase = FACTION_TASK_WORK
				work_start_time = world.time
				M.set_ai_path_to(null)
				M.ai_root.blackboard -= AIBLK_FACTION_TASK_DEST
				return NODE_RUNNING
			if(M.set_ai_path_to(scavenge_location))
				return NODE_RUNNING
			return NODE_FAILURE
		if(FACTION_TASK_WORK)
			if(collected >= max_collected || world.time >= work_start_time + 20 SECONDS)
				phase = FACTION_TASK_RETURN
				return NODE_RUNNING
			var/obj/item/best
			for(var/obj/item/I in view(3, M))
				if(!isturf(I.loc))
					continue
				if(I.anchored)
					continue
				best = I
				break
			if(!best)
				return NODE_RUNNING
			if(get_dist(M, best) <= 1)
				qdel(best)
				collected++
				return NODE_RUNNING
			M.set_ai_path_to(best)
			return NODE_RUNNING
		if(FACTION_TASK_RETURN)
			var/atom/home = director.faction_home_base
			if(!home)
				return NODE_SUCCESS
			M.ai_root.blackboard[AIBLK_FACTION_TASK_DEST] = home
			if(get_dist(M, home) <= 1)
				M.set_ai_path_to(null)
				M.ai_root.blackboard -= AIBLK_FACTION_TASK_DEST
				return NODE_SUCCESS
			if(M.set_ai_path_to(home))
				return NODE_RUNNING
			return NODE_SUCCESS
	return NODE_FAILURE

/faction_task/scavenge/OnComplete(mob/living/M)
	. = ..()
	if(!M?.ai_root)
		return
	var/faction_director/director = M.ai_root.blackboard[AIBLK_FACTION_DIRECTOR]
	if(!director || QDELETED(director))
		return
	director.AddResource("scrap", collected * 5)
