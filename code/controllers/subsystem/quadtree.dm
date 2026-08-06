// ==============================================================================
// QUADTREE SUBSYSTEM
// ==============================================================================
GLOBAL_LIST_EMPTY(qt_init_queue)

SUBSYSTEM_DEF(quadtree)
	name = "Quadtree"
	wait = 1
	priority = SS_PRIORITY_QUADTREE
	init_order = INIT_ORDER_QUADTREE
	runlevels = RUNLEVELS_DEFAULT
	flags = SS_KEEP_TIMING | SS_NO_TICK_CHECK

	var/list/trees
	var/list/entries

	var/tracked_players = 0
	var/tracked_npcs = 0
	var/tracked_hearables = 0

	var/resyncs = 0
	var/moves_applied = 0
	var/relocations = 0

/datum/controller/subsystem/quadtree/Initialize()
	trees = new/list(world.maxz)
	entries = list()
	for(var/i in 1 to world.maxz)
		trees[i] = new /datum/quadtree(0.5, world.maxx + 0.5, 0.5, world.maxy + 0.5, i, null)

	GLOB.qt_init_queue.Cut()
	initialized = TRUE
	Resync()
	return ..()

/datum/controller/subsystem/quadtree/proc/KindsFor(atom/movable/AM)
	. = 0
	if(HAS_TRAIT(AM, TRAIT_HEARING_SENSITIVE))
		. |= QT_KIND_HEARABLE
	if(!ismob(AM))
		return
	var/mob/M = AM
	if(M in GLOB.player_list)
		. |= QT_KIND_PLAYER
	if(M in GLOB.npc_list)
		. |= QT_KIND_NPC_LISTED
		if(iscarbon(M))
			. |= QT_KIND_NPC_CARBON
		else if(issimple(M))
			. |= QT_KIND_NPC_SIMPLE

/datum/controller/subsystem/quadtree/proc/CountKinds(kinds, sign)
	if(kinds & QT_KIND_PLAYER)
		tracked_players += sign
	if(kinds & QT_KIND_NPC_LISTED)
		tracked_npcs += sign
	if(kinds & QT_KIND_HEARABLE)
		tracked_hearables += sign

/datum/controller/subsystem/quadtree/proc/Track(atom/movable/AM)
	if(!initialized || !entries)
		GLOB.qt_init_queue |= AM
		return
	if(entries[AM])
		RefreshKinds(AM)
		return
	TrackWithKinds(AM, KindsFor(AM))

/datum/controller/subsystem/quadtree/proc/Untrack(atom/movable/AM)
	GLOB.qt_init_queue -= AM
	if(!entries)
		return
	var/datum/qt_entry/entry = entries[AM]
	if(!entry)
		return
	UnregisterSignal(AM, COMSIG_MOVABLE_MOVED)
	var/datum/quadtree/node = entry.node
	if(node)
		var/datum/quadtree/root = trees[entry.z_pos]
		root.Remove(entry)
	CountKinds(entry.kinds, -1)
	entries -= AM
	qdel(entry)

/datum/controller/subsystem/quadtree/proc/RefreshKinds(atom/movable/AM)
	if(!initialized || !entries)
		return
	var/datum/qt_entry/entry = entries[AM]
	if(!entry)
		Track(AM)
		return
	var/kinds = KindsFor(AM) | (entry.kinds & QT_KIND_AI_SLEEPING)
	if(kinds == entry.kinds)
		return
	if(!(kinds & ~QT_KIND_AI_SLEEPING))
		Untrack(AM)
		return
	var/datum/quadtree/node = entry.node
	if(!node)
		CountKinds(entry.kinds, -1)
		entry.kinds = kinds
		CountKinds(kinds, 1)
		return
	node.RemoveLocal(entry)
	CountKinds(entry.kinds, -1)
	entry.kinds = kinds
	CountKinds(kinds, 1)
	node.AddLocal(entry)

/datum/controller/subsystem/quadtree/proc/OnMoved(atom/movable/AM, atom/old_loc, dir, forced)
	SIGNAL_HANDLER
	if(!entries)
		return
	var/datum/qt_entry/entry = entries[AM]
	if(!entry)
		return
	var/turf/T = get_turf(AM)
	if(!T)
		return
	var/new_x = T.x
	var/new_y = T.y
	var/new_z = T.z
	if(entry.x_pos == new_x && entry.y_pos == new_y && entry.z_pos == new_z)
		return
	moves_applied++

	if(ismob(AM))
		var/mob/M = AM
		if(M.qt_range)
			M.qt_range.Recenter(new_x, new_y)

	var/datum/quadtree/node = entry.node
	if(node && entry.z_pos == new_z && new_x >= node.min_x && new_x <= node.max_x && new_y >= node.min_y && new_y <= node.max_y)
		entry.x_pos = new_x
		entry.y_pos = new_y
		WakeNearbySleepers(AM, new_z)
		return

	relocations++
	if(node)
		var/datum/quadtree/old_root = trees[entry.z_pos]
		old_root.Remove(entry)
	entry.x_pos = new_x
	entry.y_pos = new_y
	entry.z_pos = new_z
	if(new_z < 1 || new_z > length(trees))
		return
	var/datum/quadtree/root = trees[new_z]
	root.Insert(entry)
	WakeNearbySleepers(AM, new_z)

/datum/controller/subsystem/quadtree/proc/SetSleeping(mob/living/M, sleeping)
	if(!entries)
		return
	var/datum/qt_entry/entry = entries[M]
	if(!entry)
		return
	var/was_sleeping = (entry.kinds & QT_KIND_AI_SLEEPING) ? TRUE : FALSE
	if(was_sleeping == (sleeping ? TRUE : FALSE))
		return
	var/datum/quadtree/node = entry.node
	if(node)
		node.RemoveLocal(entry)
	if(sleeping)
		entry.kinds |= QT_KIND_AI_SLEEPING
	else
		entry.kinds &= ~QT_KIND_AI_SLEEPING
	if(node)
		node.AddLocal(entry)
		node.AdjustSleeping(sleeping ? 1 : -1)

/datum/controller/subsystem/quadtree/proc/WakeNearbySleepers(atom/movable/AM, z)
	if(!isliving(AM))
		return
	var/mob/living/mover = AM
	var/datum/shape/range = mover.qt_range
	if(!range || z < 1 || z > length(trees))
		return
	var/datum/quadtree/root = trees[z]
	if(!root || !root.subtree_sleeping)
		return
	var/list/sleepers = list()
	root.Query(range, sleepers, QT_KIND_AI_SLEEPING, 0)
	if(!length(sleepers))
		return
	var/mover_is_ai = mover.ai_root ? TRUE : FALSE
	for(var/mob/living/sleeper as anything in sleepers)
		if(sleeper == mover || !sleeper.ai_root)
			continue
		if(mover_is_ai && mover.faction_check_mob(sleeper))
			continue
		if(los_blocked(mover, sleeper))
			continue
		SSai.WakeUp(sleeper)

/datum/controller/subsystem/quadtree/proc/Resync()
	resyncs++
	for(var/atom/movable/AM as anything in entries)
		var/datum/qt_entry/entry = entries[AM]
		UnregisterSignal(AM, COMSIG_MOVABLE_MOVED)
		qdel(entry)
	entries.Cut()
	tracked_players = 0
	tracked_npcs = 0
	tracked_hearables = 0
	for(var/i in 1 to length(trees))
		trees[i] = new /datum/quadtree(0.5, world.maxx + 0.5, 0.5, world.maxy + 0.5, i, null)

	var/list/kinds_by_atom = list()
	for(var/mob/M as anything in GLOB.player_list)
		if(!QDELETED(M))
			kinds_by_atom[M] |= QT_KIND_PLAYER
	for(var/mob/M as anything in GLOB.npc_list)
		if(QDELETED(M))
			continue
		var/npc_kinds = QT_KIND_NPC_LISTED
		if(iscarbon(M))
			npc_kinds |= QT_KIND_NPC_CARBON
		else if(issimple(M))
			npc_kinds |= QT_KIND_NPC_SIMPLE
		kinds_by_atom[M] |= npc_kinds
	for(var/atom/movable/AM as anything in GLOB.hearables)
		if(!QDELETED(AM))
			kinds_by_atom[AM] |= QT_KIND_HEARABLE

	for(var/atom/movable/AM as anything in kinds_by_atom)
		TrackWithKinds(AM, kinds_by_atom[AM])

/datum/controller/subsystem/quadtree/proc/TrackWithKinds(atom/movable/AM, kinds)
	if(!kinds || entries[AM])
		return
	var/turf/T = get_turf(AM)
	if(!T || T.z < 1 || T.z > length(trees))
		return
	var/datum/qt_entry/entry = new
	entry.target = AM
	entry.x_pos = T.x
	entry.y_pos = T.y
	entry.z_pos = T.z
	entry.kinds = kinds
	entries[AM] = entry
	var/datum/quadtree/root = trees[T.z]
	root.Insert(entry)
	CountKinds(kinds, 1)
	RegisterSignal(AM, COMSIG_MOVABLE_MOVED, PROC_REF(OnMoved), TRUE)

/datum/controller/subsystem/quadtree/fire(resumed = FALSE)
	if(tracked_players != length(GLOB.player_list) || tracked_npcs != length(GLOB.npc_list) || tracked_hearables != length(GLOB.hearables))
		Resync()

/datum/controller/subsystem/quadtree/proc/QueryKinds(datum/shape/range, z_level, kind_mask, flags = 0)
	. = list()
	if(!range || !trees || z_level < 1 || z_level > length(trees))
		return
	var/datum/quadtree/root = trees[z_level]
	if(!root)
		return
	root.Query(range, ., kind_mask, flags)

/datum/controller/subsystem/quadtree/proc/players_in_range(datum/shape/range, z_level, flags = 0)
	return QueryKinds(range, z_level, QT_KIND_PLAYER, flags)

/datum/controller/subsystem/quadtree/proc/npcs_in_range(datum/shape/range, z_level)
	return QueryKinds(range, z_level, QT_KIND_NPC_ANY)

/datum/controller/subsystem/quadtree/proc/npc_carbons_in_range(datum/shape/range, z_level)
	return QueryKinds(range, z_level, QT_KIND_NPC_CARBON)

/datum/controller/subsystem/quadtree/proc/npc_simples_in_range(datum/shape/range, z_level)
	return QueryKinds(range, z_level, QT_KIND_NPC_SIMPLE)

/datum/controller/subsystem/quadtree/proc/hearables_in_range(datum/shape/range, z_level)
	return QueryKinds(range, z_level, QT_KIND_HEARABLE)

/datum/controller/subsystem/quadtree/proc/RegisterMob(mob/living/M)
	Track(M)

/datum/controller/subsystem/quadtree/proc/UnregisterMob(mob/living/M)
	Untrack(M)
