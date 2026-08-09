// ==============================================================================
// QUADTREE DATUMS
// ==============================================================================

/datum/shape
	var/is_circle = FALSE

	var/center_x = 0
	var/center_y = 0
	var/width = 0
	var/height = 0

	var/initial_width = 0
	var/initial_height = 0

	var/min_x = 0
	var/max_x = 0
	var/min_y = 0
	var/max_y = 0

/datum/shape/proc/RecalcBounds()
	return

/datum/shape/proc/Recenter(x, y)
	center_x = x
	center_y = y
	RecalcBounds()

/datum/shape/proc/Resize(w, h)
	width = w
	height = h
	RecalcBounds()

/datum/shape/proc/ResetSize()
	width = initial_width
	height = initial_height
	RecalcBounds()

/datum/shape/proc/contains_point(px, py)
	return FALSE

/datum/shape/proc/overlaps_box(box_min_x, box_max_x, box_min_y, box_max_y)
	return FALSE

/datum/shape/proc/contains_box(box_min_x, box_max_x, box_min_y, box_max_y)
	return FALSE

/datum/shape/proc/UpdateQTMover(x, y)
	Recenter(x, y)

/datum/shape/rectangle

/datum/shape/rectangle/New(x, y, w, h)
	..()
	center_x = x
	center_y = y
	width = w
	initial_width = w
	height = h
	initial_height = h
	RecalcBounds()

/datum/shape/rectangle/RecalcBounds()
	var/half_w = width * 0.5
	var/half_h = height * 0.5
	min_x = center_x - half_w
	max_x = center_x + half_w
	min_y = center_y - half_h
	max_y = center_y + half_h

/datum/shape/rectangle/contains_point(px, py)
	return (px >= min_x && px <= max_x && py >= min_y && py <= max_y)

/datum/shape/rectangle/overlaps_box(box_min_x, box_max_x, box_min_y, box_max_y)
	return !(max_x < box_min_x || min_x > box_max_x || max_y < box_min_y || min_y > box_max_y)

/datum/shape/rectangle/contains_box(box_min_x, box_max_x, box_min_y, box_max_y)
	return (min_x <= box_min_x && max_x >= box_max_x && min_y <= box_min_y && max_y >= box_max_y)

/datum/shape/circle
	is_circle = TRUE
	var/radius = 0
	var/radius_sq = 0

/datum/shape/circle/New(x, y, r)
	..()
	center_x = x
	center_y = y
	width = r * 2
	initial_width = width
	height = r * 2
	initial_height = height
	RecalcBounds()

/datum/shape/circle/RecalcBounds()
	radius = width * 0.5
	radius_sq = radius * radius
	min_x = center_x - radius
	max_x = center_x + radius
	min_y = center_y - radius
	max_y = center_y + radius

/datum/shape/circle/contains_point(px, py)
	var/dx = px - center_x
	var/dy = py - center_y
	return (dx * dx + dy * dy) <= radius_sq

/datum/shape/circle/overlaps_box(box_min_x, box_max_x, box_min_y, box_max_y)
	var/closest_x = clamp(center_x, box_min_x, box_max_x)
	var/closest_y = clamp(center_y, box_min_y, box_max_y)
	var/dx = center_x - closest_x
	var/dy = center_y - closest_y
	return (dx * dx + dy * dy) <= radius_sq

/datum/shape/circle/contains_box(box_min_x, box_max_x, box_min_y, box_max_y)
	var/dx = max(abs(center_x - box_min_x), abs(center_x - box_max_x))
	var/dy = max(abs(center_y - box_min_y), abs(center_y - box_max_y))
	return (dx * dx + dy * dy) <= radius_sq

/datum/qt_entry
	var/atom/movable/target
	var/x_pos = 0
	var/y_pos = 0
	var/z_pos = 0
	var/kinds = 0
	var/datum/quadtree/node

	var/faction_id = 0
	var/faction_name_id = 0

/datum/qt_entry/Destroy()
	target = null
	node = null
	..()
	return QDEL_HINT_IWILLGC

/datum/quadtree
	var/datum/quadtree/parent
	var/datum/quadtree/nw_branch
	var/datum/quadtree/ne_branch
	var/datum/quadtree/sw_branch
	var/datum/quadtree/se_branch

	var/min_x = 0
	var/max_x = 0
	var/min_y = 0
	var/max_y = 0
	var/center_x = 0
	var/center_y = 0

	var/z_level = 0
	var/is_divided = FALSE
	var/final_divide = FALSE

	var/list/players
	var/list/npc_carbons
	var/list/npc_simples
	var/list/hearables
	var/list/ai_sleeping
	var/local_count = 0
	var/subtree_count = 0
	var/subtree_sleeping = 0

	/// Bitmask of QT_KIND_* present anywhere in this subtree; queries prune on one read.
	var/subtree_kinds = 0
	var/subtree_players = 0
	var/subtree_npcs = 0
	var/subtree_hearables = 0

/datum/quadtree/New(x1, x2, y1, y2, z, datum/quadtree/branch_parent)
	..()
	min_x = x1
	max_x = x2
	min_y = y1
	max_y = y2
	center_x = (x1 + x2) * 0.5
	center_y = (y1 + y2) * 0.5
	z_level = z
	parent = branch_parent
	if((max_x - min_x) <= QUADTREE_BOUNDARY_MINIMUM_WIDTH || (max_y - min_y) <= QUADTREE_BOUNDARY_MINIMUM_HEIGHT)
		final_divide = TRUE

/datum/quadtree/Destroy()
	nw_branch = null
	ne_branch = null
	sw_branch = null
	se_branch = null
	parent = null
	players = null
	npc_carbons = null
	npc_simples = null
	hearables = null
	ai_sleeping = null
	..()
	return QDEL_HINT_IWILLGC

/datum/quadtree/proc/ChildFor(px, py)
	if(py < center_y)
		return (px < center_x) ? sw_branch : se_branch
	return (px < center_x) ? nw_branch : ne_branch

/datum/quadtree/proc/AddLocal(datum/qt_entry/entry)
	var/kinds = entry.kinds
	if(kinds & QT_KIND_PLAYER)
		LAZYADD(players, entry)
	if(kinds & QT_KIND_NPC_CARBON)
		LAZYADD(npc_carbons, entry)
	if(kinds & QT_KIND_NPC_SIMPLE)
		LAZYADD(npc_simples, entry)
	if(kinds & QT_KIND_HEARABLE)
		LAZYADD(hearables, entry)
	if(kinds & QT_KIND_AI_SLEEPING)
		LAZYADD(ai_sleeping, entry)
	entry.node = src
	local_count++

/datum/quadtree/proc/RemoveLocal(datum/qt_entry/entry)
	var/kinds = entry.kinds
	if(kinds & QT_KIND_PLAYER)
		LAZYREMOVE(players, entry)
	if(kinds & QT_KIND_NPC_CARBON)
		LAZYREMOVE(npc_carbons, entry)
	if(kinds & QT_KIND_NPC_SIMPLE)
		LAZYREMOVE(npc_simples, entry)
	if(kinds & QT_KIND_HEARABLE)
		LAZYREMOVE(hearables, entry)
	if(kinds & QT_KIND_AI_SLEEPING)
		LAZYREMOVE(ai_sleeping, entry)
	entry.node = null
	local_count--

/datum/quadtree/proc/ApplyKindDelta(kinds, sign)
	if(kinds & QT_KIND_PLAYER)
		subtree_players += sign
		if(subtree_players)
			subtree_kinds |= QT_KIND_PLAYER
		else
			subtree_kinds &= ~QT_KIND_PLAYER
	if(kinds & QT_KIND_NPC_ANY)
		subtree_npcs += sign
		if(subtree_npcs)
			subtree_kinds |= QT_KIND_NPC_ANY
		else
			subtree_kinds &= ~QT_KIND_NPC_ANY
	if(kinds & QT_KIND_HEARABLE)
		subtree_hearables += sign
		if(subtree_hearables)
			subtree_kinds |= QT_KIND_HEARABLE
		else
			subtree_kinds &= ~QT_KIND_HEARABLE
	if(kinds & QT_KIND_AI_SLEEPING)
		subtree_sleeping += sign
		if(subtree_sleeping)
			subtree_kinds |= QT_KIND_AI_SLEEPING
		else
			subtree_kinds &= ~QT_KIND_AI_SLEEPING

/// Walks to the root applying a kind delta; used when an entry's kinds change in place.
/datum/quadtree/proc/AdjustKinds(kinds, sign)
	var/datum/quadtree/walk = src
	while(walk)
		walk.ApplyKindDelta(kinds, sign)
		walk = walk.parent

/datum/quadtree/proc/AdjustSleeping(delta)
	AdjustKinds(QT_KIND_AI_SLEEPING, delta)

/datum/quadtree/proc/Subdivide()
	sw_branch = new /datum/quadtree(min_x, center_x, min_y, center_y, z_level, src)
	se_branch = new /datum/quadtree(center_x, max_x, min_y, center_y, z_level, src)
	nw_branch = new /datum/quadtree(min_x, center_x, center_y, max_y, z_level, src)
	ne_branch = new /datum/quadtree(center_x, max_x, center_y, max_y, z_level, src)
	is_divided = TRUE

	var/list/moving = list()
	if(players)
		moving |= players
	if(npc_carbons)
		moving |= npc_carbons
	if(npc_simples)
		moving |= npc_simples
	if(hearables)
		moving |= hearables
	if(ai_sleeping)
		moving |= ai_sleeping
	players = null
	npc_carbons = null
	npc_simples = null
	hearables = null
	ai_sleeping = null
	local_count = 0

	for(var/datum/qt_entry/entry as anything in moving)
		var/datum/quadtree/child = ChildFor(entry.x_pos, entry.y_pos)
		child.subtree_count++
		child.ApplyKindDelta(entry.kinds, 1)
		child.AddLocal(entry)
	for(var/datum/quadtree/child as anything in list(sw_branch, se_branch, nw_branch, ne_branch))
		if(child.local_count > QUADTREE_CAPACITY && !child.final_divide)
			child.Subdivide()

/datum/quadtree/proc/Collapse()
	if(!is_divided)
		return
	sw_branch.HarvestInto(src)
	se_branch.HarvestInto(src)
	nw_branch.HarvestInto(src)
	ne_branch.HarvestInto(src)
	sw_branch = null
	se_branch = null
	nw_branch = null
	ne_branch = null
	is_divided = FALSE

/datum/quadtree/proc/HarvestInto(datum/quadtree/destination)
	if(is_divided)
		sw_branch.HarvestInto(destination)
		se_branch.HarvestInto(destination)
		nw_branch.HarvestInto(destination)
		ne_branch.HarvestInto(destination)
		return
	var/list/moving = list()
	if(players)
		moving |= players
	if(npc_carbons)
		moving |= npc_carbons
	if(npc_simples)
		moving |= npc_simples
	if(hearables)
		moving |= hearables
	if(ai_sleeping)
		moving |= ai_sleeping
	for(var/datum/qt_entry/entry as anything in moving)
		destination.AddLocal(entry)
	players = null
	npc_carbons = null
	npc_simples = null
	hearables = null
	ai_sleeping = null
	local_count = 0

/datum/quadtree/proc/Insert(datum/qt_entry/entry)
	var/datum/quadtree/node = src
	var/kinds = entry.kinds
	while(TRUE)
		node.subtree_count++
		node.ApplyKindDelta(kinds, 1)
		if(!node.is_divided)
			node.AddLocal(entry)
			if(node.local_count > QUADTREE_CAPACITY && !node.final_divide)
				node.Subdivide()
			return
		node = node.ChildFor(entry.x_pos, entry.y_pos)

/datum/quadtree/proc/Remove(datum/qt_entry/entry)
	var/datum/quadtree/node = entry.node
	if(!node)
		return
	var/kinds = entry.kinds
	node.RemoveLocal(entry)
	var/datum/quadtree/collapse_at
	var/datum/quadtree/walk = node
	while(walk)
		walk.subtree_count--
		walk.ApplyKindDelta(kinds, -1)
		if(walk.is_divided && walk.subtree_count <= QUADTREE_MERGE_THRESHOLD)
			collapse_at = walk
		walk = walk.parent
	if(collapse_at)
		collapse_at.Collapse()

/datum/quadtree/proc/Harvest(list/found, kind_mask, flags)
	if(!(kind_mask & subtree_kinds))
		return
	if(is_divided)
		sw_branch.Harvest(found, kind_mask, flags)
		se_branch.Harvest(found, kind_mask, flags)
		nw_branch.Harvest(found, kind_mask, flags)
		ne_branch.Harvest(found, kind_mask, flags)
		return
	if((kind_mask & QT_KIND_PLAYER) && players)
		for(var/datum/qt_entry/entry as anything in players)
			AddPlayerResult(entry, found, flags)
	if((kind_mask & QT_KIND_NPC_CARBON) && npc_carbons)
		for(var/datum/qt_entry/entry as anything in npc_carbons)
			if(entry.target)
				found += entry.target
	if((kind_mask & QT_KIND_NPC_SIMPLE) && npc_simples)
		for(var/datum/qt_entry/entry as anything in npc_simples)
			if(entry.target)
				found += entry.target
	if((kind_mask & QT_KIND_HEARABLE) && hearables)
		for(var/datum/qt_entry/entry as anything in hearables)
			if(entry.target)
				found += entry.target
	if((kind_mask & QT_KIND_AI_SLEEPING) && ai_sleeping)
		for(var/datum/qt_entry/entry as anything in ai_sleeping)
			if(entry.target)
				found += entry.target

/datum/quadtree/proc/AddPlayerResult(datum/qt_entry/entry, list/found, flags)
	var/mob/player = entry.target
	if(!player)
		return
	if((flags & QTREE_EXCLUDE_OBSERVER) && isobserver(player))
		return
	if(flags & QTREE_SCAN_MOBS)
		found += player
	else if(player.client)
		found += player.client

/datum/quadtree/proc/WakeScan(rmin_x, rmax_x, rmin_y, rmax_y, datum/shape/circle_range, contained, mob/living/mover, list/mover_faction, mover_id, list/to_wake, list/los_pending)
	if(!subtree_sleeping)
		return to_wake
	if(!contained)
		if(rmax_x < min_x || rmin_x > max_x || rmax_y < min_y || rmin_y > max_y)
			return to_wake
		if(!circle_range && rmin_x <= min_x && rmax_x >= max_x && rmin_y <= min_y && rmax_y >= max_y)
			contained = TRUE
	if(is_divided)
		to_wake = sw_branch.WakeScan(rmin_x, rmax_x, rmin_y, rmax_y, circle_range, contained, mover, mover_faction, mover_id, to_wake, los_pending)
		to_wake = se_branch.WakeScan(rmin_x, rmax_x, rmin_y, rmax_y, circle_range, contained, mover, mover_faction, mover_id, to_wake, los_pending)
		to_wake = nw_branch.WakeScan(rmin_x, rmax_x, rmin_y, rmax_y, circle_range, contained, mover, mover_faction, mover_id, to_wake, los_pending)
		to_wake = ne_branch.WakeScan(rmin_x, rmax_x, rmin_y, rmax_y, circle_range, contained, mover, mover_faction, mover_id, to_wake, los_pending)
		return to_wake
	if(!ai_sleeping)
		return to_wake
	for(var/datum/qt_entry/entry as anything in ai_sleeping)
		if(!contained)
			var/ex = entry.x_pos
			if(ex < rmin_x || ex > rmax_x)
				continue
			var/ey = entry.y_pos
			if(ey < rmin_y || ey > rmax_y)
				continue
			if(circle_range && !circle_range.contains_point(ex, ey))
				continue
		var/entry_id = entry.faction_id
		if(mover_id && entry_id && (mover_id == entry_id || mover_id == entry.faction_name_id))
			continue
		var/mob/living/sleeper = entry.target
		if(!sleeper || sleeper == mover || !sleeper.ai_root)
			continue
		if(mover_id && entry_id)
			if(!los_blocked(mover, sleeper))
				LAZYADD(to_wake, sleeper)
			else if(los_pending)
				los_pending[sleeper] = TRUE
			continue
		if(mover_faction)
			var/sleeper_name = sleeper.name
			var/list/sleeper_faction = sleeper.faction
			var/allied = FALSE
			for(var/f in mover_faction)
				if(f == sleeper_name || (f in sleeper_faction))
					allied = TRUE
					break
			if(allied)
				continue
		if(los_blocked(mover, sleeper))
			if(los_pending)
				los_pending[sleeper] = TRUE
			continue
		LAZYADD(to_wake, sleeper)
	return to_wake

/// Counts matching entries without building a result list. Players only, non-observer,
/// matching players_in_range(QTREE_EXCLUDE_OBSERVER) semantics.
/datum/quadtree/proc/CountPlayersBounds(rmin_x, rmax_x, rmin_y, rmax_y)
	if(!(subtree_kinds & QT_KIND_PLAYER))
		return 0
	if(rmax_x < min_x || rmin_x > max_x || rmax_y < min_y || rmin_y > max_y)
		return 0
	if(is_divided)
		return sw_branch.CountPlayersBounds(rmin_x, rmax_x, rmin_y, rmax_y) \
			+ se_branch.CountPlayersBounds(rmin_x, rmax_x, rmin_y, rmax_y) \
			+ nw_branch.CountPlayersBounds(rmin_x, rmax_x, rmin_y, rmax_y) \
			+ ne_branch.CountPlayersBounds(rmin_x, rmax_x, rmin_y, rmax_y)
	if(!players)
		return 0
	. = 0
	for(var/datum/qt_entry/entry as anything in players)
		var/ex = entry.x_pos
		if(ex < rmin_x || ex > rmax_x)
			continue
		var/ey = entry.y_pos
		if(ey < rmin_y || ey > rmax_y)
			continue
		var/mob/P = entry.target
		if(!P || isobserver(P))
			continue
		.++

/// Applies a delta to nearby_players on every AI-kind mob within the box.
/datum/quadtree/proc/AdjustNearbyPlayersBounds(rmin_x, rmax_x, rmin_y, rmax_y, sign)
	if(!(subtree_kinds & QT_KIND_NPC_ANY))
		return
	if(rmax_x < min_x || rmin_x > max_x || rmax_y < min_y || rmin_y > max_y)
		return
	if(is_divided)
		sw_branch.AdjustNearbyPlayersBounds(rmin_x, rmax_x, rmin_y, rmax_y, sign)
		se_branch.AdjustNearbyPlayersBounds(rmin_x, rmax_x, rmin_y, rmax_y, sign)
		nw_branch.AdjustNearbyPlayersBounds(rmin_x, rmax_x, rmin_y, rmax_y, sign)
		ne_branch.AdjustNearbyPlayersBounds(rmin_x, rmax_x, rmin_y, rmax_y, sign)
		return
	for(var/list/bucket in list(npc_carbons, npc_simples))
		for(var/datum/qt_entry/entry as anything in bucket)
			var/ex = entry.x_pos
			if(ex < rmin_x || ex > rmax_x)
				continue
			var/ey = entry.y_pos
			if(ey < rmin_y || ey > rmax_y)
				continue
			var/mob/M = entry.target
			if(M)
				M.nearby_players += sign

/datum/quadtree/proc/Query(datum/shape/range, list/found, kind_mask, flags)
	QueryBounds(range.min_x, range.max_x, range.min_y, range.max_y, range.is_circle ? range : null, found, kind_mask, flags)

/datum/quadtree/proc/QueryBounds(rmin_x, rmax_x, rmin_y, rmax_y, datum/shape/circle_range, list/found, kind_mask, flags)
	if(!(kind_mask & subtree_kinds))
		return
	if(rmax_x < min_x || rmin_x > max_x || rmax_y < min_y || rmin_y > max_y)
		return
	if(circle_range ? circle_range.contains_box(min_x, max_x, min_y, max_y) : (rmin_x <= min_x && rmax_x >= max_x && rmin_y <= min_y && rmax_y >= max_y))
		Harvest(found, kind_mask, flags)
		return
	if(is_divided)
		sw_branch.QueryBounds(rmin_x, rmax_x, rmin_y, rmax_y, circle_range, found, kind_mask, flags)
		se_branch.QueryBounds(rmin_x, rmax_x, rmin_y, rmax_y, circle_range, found, kind_mask, flags)
		nw_branch.QueryBounds(rmin_x, rmax_x, rmin_y, rmax_y, circle_range, found, kind_mask, flags)
		ne_branch.QueryBounds(rmin_x, rmax_x, rmin_y, rmax_y, circle_range, found, kind_mask, flags)
		return
	if((kind_mask & QT_KIND_PLAYER) && players)
		for(var/datum/qt_entry/entry as anything in players)
			var/ex = entry.x_pos
			if(ex < rmin_x || ex > rmax_x)
				continue
			var/ey = entry.y_pos
			if(ey < rmin_y || ey > rmax_y)
				continue
			if(circle_range && !circle_range.contains_point(ex, ey))
				continue
			AddPlayerResult(entry, found, flags)
	if((kind_mask & QT_KIND_NPC_CARBON) && npc_carbons)
		for(var/datum/qt_entry/entry as anything in npc_carbons)
			var/ex = entry.x_pos
			if(ex < rmin_x || ex > rmax_x)
				continue
			var/ey = entry.y_pos
			if(ey < rmin_y || ey > rmax_y)
				continue
			if(circle_range && !circle_range.contains_point(ex, ey))
				continue
			if(entry.target)
				found += entry.target
	if((kind_mask & QT_KIND_NPC_SIMPLE) && npc_simples)
		for(var/datum/qt_entry/entry as anything in npc_simples)
			var/ex = entry.x_pos
			if(ex < rmin_x || ex > rmax_x)
				continue
			var/ey = entry.y_pos
			if(ey < rmin_y || ey > rmax_y)
				continue
			if(circle_range && !circle_range.contains_point(ex, ey))
				continue
			if(entry.target)
				found += entry.target
	if((kind_mask & QT_KIND_HEARABLE) && hearables)
		for(var/datum/qt_entry/entry as anything in hearables)
			var/ex = entry.x_pos
			if(ex < rmin_x || ex > rmax_x)
				continue
			var/ey = entry.y_pos
			if(ey < rmin_y || ey > rmax_y)
				continue
			if(circle_range && !circle_range.contains_point(ex, ey))
				continue
			if(entry.target)
				found += entry.target
	if((kind_mask & QT_KIND_AI_SLEEPING) && ai_sleeping)
		for(var/datum/qt_entry/entry as anything in ai_sleeping)
			var/ex = entry.x_pos
			if(ex < rmin_x || ex > rmax_x)
				continue
			var/ey = entry.y_pos
			if(ey < rmin_y || ey > rmax_y)
				continue
			if(circle_range && !circle_range.contains_point(ex, ey))
				continue
			if(entry.target)
				found += entry.target
