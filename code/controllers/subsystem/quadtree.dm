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

	var/sleeper_epoch = 0
	var/list/faction_ids
	var/faction_id_next = 0
	var/refreshing_faction_ids = FALSE

	var/tracked_players = 0
	var/tracked_npcs = 0
	var/tracked_hearables = 0

	var/resyncs = 0
	var/moves_applied = 0
	var/relocations = 0

#ifdef VN_BENCH
	var/wake_legacy = FALSE
	var/wake_delta_off = FALSE
	var/wake_instrument = FALSE
	var/wake_i_calls = 0
	var/wake_i_query_us = 0
	var/wake_i_filter_us = 0
	var/wake_i_candidates = 0
	var/wake_i_rejected_self = 0
	var/wake_i_rejected_faction = 0
	var/wake_i_rejected_los = 0
	var/wake_i_woken = 0
#endif

/datum/controller/subsystem/quadtree/Initialize()
	trees = new/list(world.maxz)
	entries = list()
	faction_ids = list()
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
	if(PlayerEntryCounts(entry))
		ShiftNearbyPlayers(entry.x_pos, entry.y_pos, entry.z_pos, -1)
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
	var/was_player = PlayerEntryCounts(entry)
	node.RemoveLocal(entry)
	node.AdjustKinds(entry.kinds, -1)
	CountKinds(entry.kinds, -1)
	entry.kinds = kinds
	CountKinds(kinds, 1)
	node.AdjustKinds(kinds, 1)
	node.AddLocal(entry)
	var/is_player = PlayerEntryCounts(entry)
	if(was_player != is_player)
		ShiftNearbyPlayers(entry.x_pos, entry.y_pos, entry.z_pos, is_player ? 1 : -1)
	if(kinds & QT_KIND_NPC_ANY)
		RecountNearbyPlayers(AM, entry.x_pos, entry.y_pos, entry.z_pos)

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
	if(entry.kinds & QT_KIND_AI_SLEEPING)
		sleeper_epoch++

	if(ismob(AM))
		var/mob/M = AM
		if(M.qt_range)
			M.qt_range.Recenter(new_x, new_y)

	var/old_x = entry.x_pos
	var/old_y = entry.y_pos
	var/old_z = entry.z_pos
	var/is_player = PlayerEntryCounts(entry)

	var/datum/quadtree/node = entry.node
	if(node && entry.z_pos == new_z && new_x >= node.min_x && new_x <= node.max_x && new_y >= node.min_y && new_y <= node.max_y)
		entry.x_pos = new_x
		entry.y_pos = new_y
		if(is_player)
			ShiftNearbyPlayers(old_x, old_y, old_z, -1)
			ShiftNearbyPlayers(new_x, new_y, new_z, 1)
		if(entry.kinds & QT_KIND_NPC_ANY)
			RecountNearbyPlayers(AM, new_x, new_y, new_z)
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
	if(is_player)
		ShiftNearbyPlayers(old_x, old_y, old_z, -1)
		ShiftNearbyPlayers(new_x, new_y, new_z, 1)
	if(entry.kinds & QT_KIND_NPC_ANY)
		RecountNearbyPlayers(AM, new_x, new_y, new_z)
	WakeNearbySleepers(AM, new_z)

/// Recomputes one mob's maintained player-proximity count from the tree.
/datum/controller/subsystem/quadtree/proc/RecountNearbyPlayers(mob/M, x, y, z)
	if(z < 1 || z > length(trees))
		M.nearby_players = 0
		return
	var/datum/quadtree/root = trees[z]
	M.nearby_players = root ? root.CountPlayersBounds(x - AI_HIBERNATION_RANGE, x + AI_HIBERNATION_RANGE, y - AI_HIBERNATION_RANGE, y + AI_HIBERNATION_RANGE) : 0

/// A player appearing at / leaving a position shifts every AI mob whose window covers it.
/// The interest radius is uniform, so "player in mob's window" == "mob within range of player".
/datum/controller/subsystem/quadtree/proc/ShiftNearbyPlayers(x, y, z, sign)
	if(z < 1 || z > length(trees))
		return
	var/datum/quadtree/root = trees[z]
	if(!root)
		return
	root.AdjustNearbyPlayersBounds(x - AI_HIBERNATION_RANGE, x + AI_HIBERNATION_RANGE, y - AI_HIBERNATION_RANGE, y + AI_HIBERNATION_RANGE, sign)

/datum/controller/subsystem/quadtree/proc/PlayerEntryCounts(datum/qt_entry/entry)
	if(!(entry.kinds & QT_KIND_PLAYER))
		return FALSE
	var/mob/P = entry.target
	return P && !isobserver(P)

/datum/controller/subsystem/quadtree/proc/FactionId(f, create)
	if(!f)
		return 0
	var/id = faction_ids[f]
	if(id || !create)
		return id
	id = ++faction_id_next
	faction_ids[f] = id
	RefreshSleeperFactionIds()
	return id

/datum/controller/subsystem/quadtree/proc/PrimaryFactionId(mob/M, create)
	var/own_ref = "[REF(M)]"
	var/word
	for(var/f in M.faction)
		if(f == own_ref)
			continue
		if(copytext(f, 1, 2) == "\[")
			return 0
		if(word)
			return 0
		word = f
	if(!word)
		return 0
	return FactionId(word, create)

/datum/controller/subsystem/quadtree/proc/RefreshFactionIds(mob/M)
	if(!entries)
		return
	M.faction_id = PrimaryFactionId(M, TRUE)
	M.faction_name_id = FactionId(M.name, FALSE)
	var/datum/qt_entry/entry = entries[M]
	if(!entry)
		return
	entry.faction_id = M.ai_root ? M.faction_id : 0
	entry.faction_name_id = M.faction_name_id

/datum/controller/subsystem/quadtree/proc/RefreshSleeperFactionIds()
	if(refreshing_faction_ids || !SSai?.sleeping_mobs)
		return
	refreshing_faction_ids = TRUE
	for(var/mob/living/M as anything in SSai.sleeping_mobs)
		M.faction_id = PrimaryFactionId(M, TRUE)
		M.faction_name_id = FactionId(M.name, FALSE)
		var/datum/qt_entry/entry = entries?[M]
		if(entry)
			entry.faction_id = M.ai_root ? M.faction_id : 0
			entry.faction_name_id = M.faction_name_id
	refreshing_faction_ids = FALSE

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
		sleeper_epoch++
		M.faction_id = PrimaryFactionId(M, TRUE)
		M.faction_name_id = FactionId(M.name, FALSE)
		entry.faction_id = M.ai_root ? M.faction_id : 0
		entry.faction_name_id = M.faction_name_id
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
#ifdef VN_BENCH
	if(wake_legacy)
		WakeNearbySleepersLegacy(mover, root, range)
		return
#endif
	var/list/mover_faction = mover.ai_root ? mover.faction : null
	var/mover_id = mover_faction ? PrimaryFactionId(mover, TRUE) : 0
	var/rmin_x = range.min_x
	var/rmax_x = range.max_x
	var/rmin_y = range.min_y
	var/rmax_y = range.max_y
	var/datum/shape/circle_range = range.is_circle ? range : null

	var/dx = rmin_x - mover.wake_scan_x
	var/dy = rmin_y - mover.wake_scan_y
	var/list/los_pending = mover.wake_los_pending
	var/list/to_wake

	var/delta_ok = mover.wake_scan_z == z && mover.wake_scan_epoch == sleeper_epoch && mover.wake_scan_w == (rmax_x - rmin_x) && mover.wake_scan_faction_id == mover_id && dx >= -1 && dx <= 1 && dy >= -1 && dy <= 1
#ifdef VN_BENCH
	if(wake_delta_off)
		delta_ok = FALSE
#endif
	if(delta_ok && !circle_range)
		if(dx)
			var/cx = dx > 0 ? rmax_x : rmin_x
			to_wake = root.WakeScan(cx, cx, rmin_y, rmax_y, null, FALSE, mover, mover_faction, mover_id, to_wake, los_pending)
		if(dy)
			var/cy = dy > 0 ? rmax_y : rmin_y
			var/row_min_x = dx > 0 ? rmin_x : (dx < 0 ? rmin_x + 1 : rmin_x)
			var/row_max_x = dx > 0 ? rmax_x - 1 : rmax_x
			to_wake = root.WakeScan(row_min_x, row_max_x, cy, cy, null, FALSE, mover, mover_faction, mover_id, to_wake, los_pending)
		to_wake = RecheckLosPending(mover, rmin_x, rmax_x, rmin_y, rmax_y, to_wake)
	else
		los_pending = list()
		mover.wake_los_pending = los_pending
		to_wake = root.WakeScan(rmin_x, rmax_x, rmin_y, rmax_y, circle_range, FALSE, mover, mover_faction, mover_id, null, los_pending)

	mover.wake_scan_x = rmin_x
	mover.wake_scan_y = rmin_y
	mover.wake_scan_z = z
	mover.wake_scan_w = rmax_x - rmin_x
	mover.wake_scan_epoch = sleeper_epoch
	mover.wake_scan_faction_id = mover_id

	if(!to_wake)
		return
	for(var/mob/living/sleeper as anything in to_wake)
		los_pending -= sleeper
		SSai.WakeUp(sleeper)

/datum/controller/subsystem/quadtree/proc/RecheckLosPending(mob/living/mover, rmin_x, rmax_x, rmin_y, rmax_y, list/to_wake)
	var/list/pending = mover.wake_los_pending
	if(!length(pending))
		return to_wake
	for(var/mob/living/sleeper as anything in pending)
		var/datum/qt_entry/entry = entries[sleeper]
		if(!entry || !(entry.kinds & QT_KIND_AI_SLEEPING))
			pending -= sleeper
			continue
		var/ex = entry.x_pos
		var/ey = entry.y_pos
		if(ex < rmin_x || ex > rmax_x || ey < rmin_y || ey > rmax_y)
			pending -= sleeper
			continue
		if(!los_blocked(mover, sleeper))
			LAZYADD(to_wake, sleeper)
	return to_wake

#ifdef VN_BENCH
/datum/controller/subsystem/quadtree/proc/ResetWakeInstrument()
	wake_i_calls = 0
	wake_i_query_us = 0
	wake_i_filter_us = 0
	wake_i_candidates = 0
	wake_i_rejected_self = 0
	wake_i_rejected_faction = 0
	wake_i_rejected_los = 0
	wake_i_woken = 0

/datum/controller/subsystem/quadtree/proc/WakeNearbySleepersLegacy(mob/living/mover, datum/quadtree/root, datum/shape/range)
	var/instrument = wake_instrument
	if(instrument)
		rustg_time_reset("vnqwi")
	var/list/sleepers = list()
	root.Query(range, sleepers, QT_KIND_AI_SLEEPING, 0)
	var/n_sleepers = length(sleepers)
	if(instrument)
		wake_i_query_us += rustg_time_microseconds("vnqwi")
	if(!n_sleepers)
		return
	if(instrument)
		wake_i_calls++
		wake_i_candidates += n_sleepers
		rustg_time_reset("vnqwi")
	var/mover_is_ai = mover.ai_root ? TRUE : FALSE
	for(var/mob/living/sleeper as anything in sleepers)
		if(sleeper == mover || !sleeper.ai_root)
			if(instrument)
				wake_i_rejected_self++
			continue
		if(mover_is_ai && mover.faction_check_mob(sleeper))
			if(instrument)
				wake_i_rejected_faction++
			continue
		if(los_blocked(mover, sleeper))
			if(instrument)
				wake_i_rejected_los++
			continue
		if(instrument)
			wake_i_woken++
		SSai.WakeUp(sleeper)
	if(instrument)
		wake_i_filter_us += rustg_time_microseconds("vnqwi")
#endif

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
	RebuildNearbyPlayers()

/// Full recompute; the tripwire safety net for the maintained counters.
/datum/controller/subsystem/quadtree/proc/RebuildNearbyPlayers()
	for(var/atom/movable/AM as anything in entries)
		var/datum/qt_entry/entry = entries[AM]
		if(entry.kinds & QT_KIND_NPC_ANY)
			RecountNearbyPlayers(AM, entry.x_pos, entry.y_pos, entry.z_pos)

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
	if(PlayerEntryCounts(entry))
		ShiftNearbyPlayers(entry.x_pos, entry.y_pos, entry.z_pos, 1)
	if(kinds & QT_KIND_NPC_ANY)
		RecountNearbyPlayers(AM, entry.x_pos, entry.y_pos, entry.z_pos)
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
