///////////// OVERLAY EFFECTS /////////////
/obj/effect/overlay/water
	icon = 'icons/turf/newwater.dmi'
	icon_state = "bottom"
	density = FALSE
	mouse_opacity = FALSE
	layer = BELOW_MOB_LAYER
	anchored = TRUE

/obj/effect/overlay/water/top
	icon_state = "top"
	layer = MID_TURF_LAYER

/turf/open/water
	gender = PLURAL
	name = "water"
	desc = "Good enough to drink, wet enough to douse fires."
	icon = 'icons/turf/roguefloor.dmi'
	icon_state = "together"
	baseturfs = /turf/open/water
	slowdown = 5
	var/obj/effect/overlay/water/water_overlay
	var/obj/effect/overlay/water/top/water_top_overlay
	bullet_sizzle = TRUE
	bullet_bounce_sound = null //needs a splashing sound one day.
	smoothing_flags = SMOOTH_EDGE
	smoothing_groups = SMOOTH_GROUP_FLOOR_LIQUID
	smoothing_list = SMOOTH_GROUP_OPEN_FLOOR + SMOOTH_GROUP_CLOSED
	neighborlay_self = "edge"
	footstep = null
	barefootstep = null
	clawfootstep = null
	heavyfootstep = null
	landsound = 'sound/foley/jumpland/waterland.wav'
	var/water_color = "#6a9295"
	var/water_reagent = /datum/reagent/water
	var/water_reagent_purified = /datum/reagent/water // If put through a water filtration device, provides this reagent instead
	var/mapped = TRUE // infinite source of water
	var/water_volume = 100 // 100 is 1 bucket
	var/water_maximum = 100
	water_level = 2
	var/wash_in = TRUE
	var/swim_skill = FALSE
	nomouseover = FALSE

/turf/open/water/Initialize()
	.  = ..()
	water_overlay = new(src)
	water_top_overlay = new(src)
	update_icon()

/turf/open/water/update_icon()
	if(water_overlay)
		water_overlay.color = water_color
		water_overlay.icon_state = "bottom[water_level]"
	if(water_top_overlay)
		water_top_overlay.color = water_color
		water_top_overlay.icon_state = "top[water_level]"

/turf/open/water/Exited(atom/movable/AM, atom/newloc)
	. = ..()
	if(!isliving(AM))
		return
	if(water_overlay)
		spawn(6)
			if(!locate(/mob/living) in src)
				water_overlay.layer = BELOW_MOB_LAYER
				water_overlay.plane = GAME_PLANE
	if(AM.throwing)
		return
	var/mob/living/user = AM
	if(user.is_floor_hazard_immune())
		return
	for(var/obj/structure/S in src)
		if(S.obj_flags & BLOCK_Z_OUT_DOWN)
			return
	var/drained = get_stamina_drain(user, get_dir(src, newloc))
	if(drained && !user.stamina_add(drained))
		handle_swim_exhaustion(user)

/turf/open/water/proc/handle_swim_exhaustion(mob/living/user)
	user.Immobilize(30)
	addtimer(CALLBACK(user, TYPE_PROC_REF(/mob/living, Knockdown), 30), 1 SECONDS)

/turf/open/water/proc/get_stamina_drain(mob/living/swimmer, travel_dir)
	var/const/BASE_STAM_DRAIN = 15
	var/const/MIN_STAM_DRAIN = 1
	var/const/STAM_PER_LEVEL = 5
	var/const/UNSKILLED_ARMOR_PENALTY = 40
	if(!isliving(swimmer))
		return 0
	if(!swim_skill)
		return 0 // no stam cost
	if(swimmer.is_floor_hazard_immune())
		return 0 // floating!
	if(cell?.flow_dir && travel_dir && travel_dir == cell.flow_dir)
		return 0
	if(swimmer.buckled)
		return 0
	var/abyssor_swim_bonus = HAS_TRAIT(swimmer, TRAIT_ABYSSOR_SWIM) ? 5 : 0
	var/swimming_skill_level = swimmer.get_skill_level(/datum/skill/misc/swimming) 
	. = max(BASE_STAM_DRAIN - (swimming_skill_level * STAM_PER_LEVEL) - abyssor_swim_bonus, MIN_STAM_DRAIN)
	if(swimmer.mind)
		swimmer.mind.add_sleep_experience(/datum/skill/misc/swimming, swimmer.STAINT * 0.5)
//	. += (swimmer.checkwornweight()*2)
	if(!swimmer.check_armor_skill())
		. += UNSKILLED_ARMOR_PENALTY
	if(.) // this check is expensive so we only run it if we do expect to use stamina	
		for(var/obj/structure/S in src)
			if(S.obj_flags & BLOCK_Z_OUT_DOWN)
				return 0
		for(var/D in GLOB.cardinals) //adjacent to a floor to hold onto
			if(istype(get_step(src, D), /turf/open/floor))
				return 0

// Mobs won't try to path through water if low on stamina,
// and will take advantage of water flow to move faster.
/turf/open/water/get_heuristic_slowdown(mob/traverser, travel_dir)
	/// Mobs will heavily avoid pathing through this turf if their stamina is too low.
	var/const/LOW_STAM_PENALTY = 7 // only go through this if we'd have to go offscreen otherwise
	. = ..()
	if(isliving(traverser) && !HAS_TRAIT(traverser, TRAIT_INFINITE_STAMINA))
		var/mob/living/living_traverser = traverser
		var/remaining_stamina = (living_traverser.max_stamina - living_traverser.stamina)
		if(remaining_stamina < get_stamina_drain(living_traverser, travel_dir)) // not enough stamina reserved to cross
			. += LOW_STAM_PENALTY // really want to avoid this unless we don't have any better options

/turf/open/water/hitby(atom/movable/AM, skipcatch, hitpush, blocked, datum/thrownthing/throwingdatum, damage_flag = "blunt")
	..()
	playsound(src, pick('sound/foley/water_land1.ogg','sound/foley/water_land2.ogg','sound/foley/water_land3.ogg'), 100, FALSE)



/turf/open/water/roguesmooth(adjacencies)
	var/list/Yeah = ..()
	if(water_overlay)
		water_overlay.cut_overlays(TRUE)
		if(Yeah)
			water_overlay.add_overlay(Yeah)
	if(water_top_overlay)
		water_top_overlay.cut_overlays(TRUE)
		if(Yeah)
			water_top_overlay.add_overlay(Yeah)

/turf/open/water/Entered(atom/movable/AM, atom/oldLoc)
	. = ..()
	for(var/obj/structure/S in src)
		if(S.obj_flags & BLOCK_Z_OUT_DOWN)
			return
	try_start_river_current(AM)
	if(istype(AM, /obj/item/reagent_containers/food/snacks/fish))
		var/obj/item/reagent_containers/food/snacks/fish/F = AM
		SEND_GLOBAL_SIGNAL(COMSIG_GLOBAL_FISH_RELEASED, F.type, F.rarity_rank)
		F.visible_message("<span class='warning'>[F] dives into \the [src] and disappears!</span>")
		qdel(F)
	if(isliving(AM) && !AM.throwing)
		var/mob/living/L = AM
		if(HAS_TRAIT(L, TRAIT_CURSE_ABYSSOR))
			L.freak_out()
			L.visible_message(span_warning("[L] spasms violently upon touching the water!"), span_danger("The water... it burns me!"))
			L.adjustFireLoss(25)
			return
		else if(L.fire_stacks > 0)
			var/datum/status_effect/fire_handler/fire_stacks/fire_effect = L.get_status_effect_exact(/datum/status_effect/fire_handler/fire_stacks)
			if(fire_effect)
				fire_effect.extinguish()
				fire_effect.adjust_stacks(-L.fire_stacks)
				L.visible_message(span_notice("[L]'s flames are extinguished by the water!"), span_notice("The water extinguishes the flames!"))
				playsound(L, 'sound/blank.ogg', 50, TRUE)
		if(!(L.movement_type & FLYING))
			if(!(L.mobility_flags & MOBILITY_STAND) || water_level == 3)
				L.SoakMob(FULL_BODY)
			else
				if(water_level == 2)
					L.SoakMob(BELOW_CHEST)
			if(water_overlay)
				if(water_level > 1 && !istype(oldLoc, /turf/open/water))
					playsound(AM, 'sound/foley/waterenter.ogg', 100, FALSE)
				else
					playsound(AM, pick('sound/foley/watermove (1).ogg','sound/foley/watermove (2).ogg'), 100, FALSE)
				if(istype(oldLoc, /turf/open/water))
					water_overlay.layer = ABOVE_MOB_LAYER
					water_overlay.plane = GAME_PLANE
				else
					spawn(6)
						if(AM.loc == src)
							water_overlay.layer = ABOVE_MOB_LAYER
							water_overlay.plane = GAME_PLANE
		if(!istype(L, /mob/living/carbon/human/species/skeleton))
			return
		if(!istype(src, /turf/open/water/sewer))
			return
		if(!istype(src, /turf/open/water/swamp))
			return
		L.apply_damage(30, BRUTE, BODY_ZONE_CHEST, forced = TRUE)
		to_chat(L, span_warningbig("The water seeps into my pores. I am crumbling!"))

/turf/open/water/attackby(obj/item/C, mob/user, params)
	if(user.used_intent.type == /datum/intent/fill)
		if(C.reagents)
			if(C.reagents.holder_full())
				to_chat(user, span_warning("[C] is full."))
				return
			playsound(user, 'sound/foley/drawwater.ogg', 100, FALSE)
			if(do_after(user, 8, target = src))
				user.changeNext_move(CLICK_CD_MELEE)
				C.reagents.add_reagent(water_reagent, 200)
				to_chat(user, span_notice("I fill [C] from [src]."))
				// If the user is filling a water purifier and the water isn't already clean...
				if (istype(C, /obj/item/reagent_containers/glass/bottle/waterskin/purifier) && water_reagent != water_reagent_purified)
					var/obj/item/reagent_containers/glass/bottle/waterskin/purifier/P = C
					P.cleanwater(user)
			return
	. = ..()

/turf/open/water/attack_right(mob/user)
	if(isliving(user))
		var/mob/living/L = user
		if(L.stat != CONSCIOUS)
			return
		var/list/wash = list('sound/foley/waterwash (1).ogg','sound/foley/waterwash (2).ogg')
		playsound(user, pick_n_take(wash), 100, FALSE)
		var/item2wash = user.get_active_held_item()
		if(!item2wash)
			user.visible_message(span_info("[user] starts to wash in [src]."))
			if(do_after(L, 3 SECONDS, target = src))
				if(wash_in)
					wash_atom(user, CLEAN_STRONG)
				playsound(user, pick(wash), 100, FALSE)
/*				if(water_reagent == /datum/reagent/water) //become shittified, checks so bath water can be naturally gross but not discolored
					water_reagent = /datum/reagent/water/gross
					water_color = "#a4955b"
					update_icon()*/
		else
			user.visible_message(span_info("[user] starts to wash [item2wash] in [src]."))
			if(do_after(L, 30, target = src))
				if(wash_in)
					wash_atom(item2wash, CLEAN_STRONG)
				playsound(user, pick(wash), 100, FALSE)
		return
	..()

/turf/open/water/onbite(mob/user)
	if(isliving(user))
		var/mob/living/L = user
		if(L.stat != CONSCIOUS)
			return
		if(iscarbon(user))
			var/mob/living/carbon/C = user
			if(C.is_mouth_covered())
				return
		user.visible_message(span_info("[user] starts to drink from [src]."))
		drink_act(user, L)
		return
	..()

/turf/open/water/proc/drink_act(mob/user, mob/living/L)
	playsound(user, pick('sound/foley/waterwash (1).ogg','sound/foley/waterwash (2).ogg'), 100, FALSE)
	if(L.stat != CONSCIOUS)
		return
	if(do_after(L, 25, target = src))
		var/list/waterl = list()
		waterl[water_reagent] = 5
		var/datum/reagents/reagents = new()
		reagents.add_reagent_list(waterl)
		reagents.trans_to(L, reagents.total_volume, transfered_by = user, method = INGEST)
		playsound(user,pick('sound/items/drink_gen (1).ogg','sound/items/drink_gen (2).ogg','sound/items/drink_gen (3).ogg'), 100, TRUE)
		drink_act(user, L)
	return

/turf/open/water/Destroy()
	. = ..()
	if(water_overlay)
		QDEL_NULL(water_overlay)
	if(water_top_overlay)
		QDEL_NULL(water_top_overlay)

/turf/open/water/hitby(atom/movable/AM, skipcatch, hitpush, blocked, datum/thrownthing/throwingdatum, damage_flag = "blunt")
	if(!isobj(AM))
		return
	var/obj/O = AM
	if(!O.extinguishable)
		return
	O.extinguish()

/turf/open/water/get_slowdown(mob/user)
	var/returned = slowdown
	returned = max(returned - (user.get_skill_level(/datum/skill/misc/swimming)), 0)
	if(HAS_TRAIT(user, TRAIT_SLOW_SWIMMER))
		returned += 3
	return returned

//turf/open/water/Initialize()
//	dir = pick(NORTH,SOUTH,WEST,EAST)
//	. = ..()


/turf/open/water/bath
	name = "water"
	desc = "Soothing water, with soapy bubbles on the surface."
	icon = 'icons/turf/roguefloor.dmi'
	icon_state = "bathtileW"
	water_level = 2
	water_color = "#FFFFFF"
	slowdown = 3
	water_reagent = /datum/reagent/water/bathwater

/turf/open/water/bath/Initialize()
	.  = ..()
	icon_state = "bathtile"

/turf/open/water/sewer
	name = "sewage"
	desc = "This dark water smells like dead rats and sulphur!"
	icon = 'icons/turf/roguefloor.dmi'
	icon_state = "pavingW"
	water_level = 1
	water_color = "#705a43"
	slowdown = 1
	wash_in = FALSE
	water_reagent = /datum/reagent/water/gross

/turf/open/water/sewer/Initialize()
	icon_state = "paving"
	water_color = pick("#705a43","#697043")
	.  = ..()

/turf/open/water/swamp
	name = "murk"
	desc = "Weeds and algae cover the surface of the water."
	icon = 'icons/turf/roguefloor.dmi'
	icon_state = "dirtW2"
	water_level = 2
	water_color = "#705a43"
	slowdown = 3
	wash_in = TRUE
	water_reagent = /datum/reagent/water/gross

/turf/open/water/bloody
	name = "blood"
	desc = "Is that... a river of blood? EVIL!"
	icon = 'icons/turf/roguefloor.dmi'
	icon_state = "dirtW2"
	water_level = 2
	water_color = "#880808"
	slowdown = 3
	wash_in = TRUE
	water_reagent = /datum/reagent/blood

/turf/open/water/swamp/Initialize()
	icon_state = "dirt"
	dir = pick(GLOB.cardinals)
	water_color = pick("#705a43")
	.  = ..()

/turf/open/water/bloody/Initialize()
	icon_state = "dirt"
	dir = pick(GLOB.cardinals)
	water_color = pick("#880808")
	.  = ..()

/turf/open/water/swamp/Entered(atom/movable/AM, atom/oldLoc)
	. = ..()
	if(HAS_TRAIT(AM, TRAIT_LEECHIMMUNE))
		return
	if(isliving(AM) && !AM.throwing)
		if(ishuman(AM))
			var/mob/living/carbon/human/C = AM
			var/chance = 3
			if(C.m_intent == MOVE_INTENT_RUN)
				chance = 6
			if(C.m_intent == MOVE_INTENT_SNEAK)
				chance = 1
			if(!prob(chance))
				return
			if(C.blood_volume <= 0)
				return
			var/list/zonee = list(BODY_ZONE_R_LEG, BODY_ZONE_L_LEG, BODY_ZONE_CHEST)
			for(var/i = 0, i <= zonee.len, i++)
				var/zone = pick(zonee)
				var/obj/item/bodypart/BP = C.get_bodypart(zone)
				if(!BP)
					continue
				if(BP.skeletonized)
					continue
				var/obj/item/natural/worms/leech/I = new(C)
				BP.add_embedded_object(I, silent = TRUE)
				return .

/turf/open/water/swamp/deep
	name = "murk"
	desc = "Deep water with several weeds and algae on the surface."
	icon_state = "dirtW"
	water_level = 3
	water_color = "#705a43"
	slowdown = 5
	swim_skill = TRUE

/turf/open/water/swamp/deep/Entered(atom/movable/AM, atom/oldLoc)
	. = ..()
	if(HAS_TRAIT(AM, TRAIT_LEECHIMMUNE))
		return
	if(isliving(AM) && !AM.throwing)
		if(ishuman(AM))
			var/mob/living/carbon/human/C = AM
			var/chance = 6
			if(C.m_intent == MOVE_INTENT_RUN)
				chance = 12		//yikes
			if(C.m_intent == MOVE_INTENT_SNEAK)
				chance = 2
			if(!prob(chance))
				return
			if(C.blood_volume <= 0)
				return
			var/list/zonee = list(BODY_ZONE_CHEST,BODY_ZONE_R_LEG,BODY_ZONE_L_LEG,BODY_ZONE_R_ARM,BODY_ZONE_L_ARM)
			for(var/i = 0, i <= zonee.len, i++)
				var/zone = pick(zonee)
				var/obj/item/bodypart/BP = C.get_bodypart(zone)
				if(!BP)
					continue
				if(BP.skeletonized)
					continue
				var/obj/item/natural/worms/leech/I = new(C)
				BP.add_embedded_object(I, silent = TRUE)
				return .

/turf/open/water/cleanshallow
	name = "water"
	desc = "Clear and shallow water, what a blessing!"
	icon = 'icons/turf/roguefloor.dmi'
	icon_state = "rockw2"
	water_level = 2
	slowdown = 3
	wash_in = TRUE
	water_reagent = /datum/reagent/water

/turf/open/water/cleanshallow/Initialize()
	icon_state = "rock"
	dir = pick(GLOB.cardinals)
	.  = ..()

/turf/open/water/river
	name = "river"
	desc = "A river of crystal clear water flows swiftly along the contours of the land."
	baseturfs = /turf/open/transparent/openspace

/turf/open/water/river/Initialize()
	. = ..()

	if(!GetBelow(src))
		var/preserved_dir = dir
		var/turf/stream = ChangeTurf(/turf/open/water/stream, null, CHANGETURF_IGNORE_AIR)
		if(stream)
			stream.setDir(preserved_dir)
			if(stream.cell)
				stream.cell.flow_dir = preserved_dir
			stream.refresh_river_overlay()
		return

	var/turf/new_top = ChangeTurf(/turf/open/transparent/openspace, null, CHANGETURF_IGNORE_AIR)

	var/turf/below = GetBelow(new_top)
	if(below)
		var/turf/river_bottom = below.ChangeTurf(/turf/open/floor/rogue/riverbot, null, CHANGETURF_IGNORE_AIR)
		if(!river_bottom.cell)
			river_bottom.cell = new /cell(river_bottom)
			river_bottom.cell.InitLiquids()

		var/datum/liquid/below_water = river_bottom.cell.get_fluid_datum(WATER)
		if(below_water)
			river_bottom.cell.fluid_volume[below_water] = 100

		river_bottom.cell.flow_dir = dir
		river_bottom.setDir(dir)

		SSliquid.update_fluidsum(river_bottom)
		SSliquid.cell_index[river_bottom] = TRUE
		new_top.refresh_river_overlay()
		SSmapping.register_water_bed(river_bottom)

/turf/open/floor/rogue/riverbot
	name = "river bottom"
	desc = "The rocky bed of a flowing river."
	icon = 'icons/turf/roguefloor.dmi'
	icon_state = "grimshart"
	footstep = FOOTSTEP_WATER
	barefootstep = FOOTSTEP_WATER
	clawfootstep = FOOTSTEP_WATER
	heavyfootstep = FOOTSTEP_WATER

/turf/open/floor/rogue/riverbot/Initialize()
	. = ..()
	if(!cell)
		cell = new /cell(src)
		cell.InitLiquids()
	var/datum/liquid/water_fluid = cell.get_fluid_datum(WATER)
	if(water_fluid)
		cell.fluid_volume[water_fluid] = MAX_FLUID_VOLUME
	cell.make_liquid_source(10)
	SSliquid.update_fluidsum(src)
	SSliquid.cell_index[src] = TRUE
	ensure_liquid_overlay()
	liquid_overlay.layer = ABOVE_MOB_LAYER
	liquid_overlay.plane = GAME_PLANE_HIGHEST

/turf/open/floor/rogue/lakebed
	name = "lakebed"
	desc = "The muddy bottom of a deep lake."
	icon = 'icons/turf/roguefloor.dmi'
	icon_state = "lakebed"
	footstep = FOOTSTEP_WATER
	barefootstep = FOOTSTEP_WATER
	clawfootstep = FOOTSTEP_WATER
	heavyfootstep = FOOTSTEP_WATER

/turf/open/floor/rogue/lakebed/Initialize()
	. = ..()
	if(!cell)
		cell = new /cell(src)
		cell.InitLiquids()
	var/datum/liquid/water_fluid = cell.get_fluid_datum(WATER)
	if(water_fluid)
		cell.fluid_volume[water_fluid] = MAX_FLUID_VOLUME
	cell.make_liquid_source(10)
	SSliquid.update_fluidsum(src)
	SSliquid.cell_index[src] = TRUE
	ensure_liquid_overlay()
	liquid_overlay.layer = ABOVE_MOB_LAYER
	liquid_overlay.plane = GAME_PLANE_HIGHEST

/turf/proc/river_flow_cell()
	if(isopenspace(src))
		var/turf/below = GetBelow(src)
		if(below?.cell && (istype(below, /turf/open/floor/rogue/riverbot) || istype(below, /turf/open/floor/rogue/lakebed)))
			return below.cell
		return null
	if(istype(src, /turf/open/water))
		return cell
	if(istype(src, /turf/open/floor/rogue/riverbot) || istype(src, /turf/open/floor/rogue/lakebed))
		return cell
	return null

/turf/proc/refresh_river_overlay()
	if(isopenspace(src) || istype(src, /turf/open/water) || istype(src, /turf/open/floor/rogue/riverbot) || istype(src, /turf/open/floor/rogue/lakebed))
		SSliquid.update_cell_image(src)

/turf/proc/can_river_push(mob/living/L)
	if(!isliving(L))
		return FALSE
	if(L.anchored || L.buckled || L.pulledby)
		return FALSE
	if(L.is_floor_hazard_immune())
		return FALSE
	return TRUE

/turf/proc/river_push_cooldown(rate)
	return round(RIVER_PUSH_BASE_CD / clamp(rate, 0.25, 4))

/turf/proc/handle_river_current()
	var/cell/fc = river_flow_cell()
	if(!fc?.flow_dir)
		return FALSE
	if(isopenspace(src))
		var/turf/below = GetBelow(src)
		if(!below?.cell || below.cell.fluidsum < 80)
			return FALSE
	for(var/obj/structure/S in src)
		if(S.obj_flags & BLOCK_Z_OUT_DOWN)
			return FALSE
	. = FALSE
	for(var/mob/living/L in contents.Copy())
		if(!can_river_push(L))
			continue
		. = TRUE
		if(!COOLDOWN_FINISHED(L, river_push_cd))
			continue
		COOLDOWN_START(L, river_push_cd, river_push_cooldown(fc.flow_rate))
		L.ConveyorMove(fc.flow_dir)

/turf/proc/try_start_river_current(atom/movable/AM)
	if(!isliving(AM))
		return
	var/cell/fc = river_flow_cell()
	if(!fc?.flow_dir)
		return
	START_PROCESSING(SSfastprocess, src)

/turf/open/water/process()
	if(!handle_river_current())
		STOP_PROCESSING(SSfastprocess, src)

/turf/proc/resolve_flow_origin_turf()
	if(isopenspace(src))
		var/turf/below = GetBelow(src)
		if(below && (istype(below, /turf/open/floor/rogue/riverbot) || istype(below, /turf/open/floor/rogue/lakebed)))
			return below
		return null
	if(istype(src, /turf/open/water) || istype(src, /turf/open/floor/rogue/riverbot) || istype(src, /turf/open/floor/rogue/lakebed))
		return src
	return null

/turf/proc/flow_body_class()
	if(istype(src, /turf/open/floor/rogue/riverbot))
		return "riverbot"
	if(istype(src, /turf/open/floor/rogue/lakebed))
		return "lakebed"
	if(istype(src, /turf/open/water))
		return "[type]"
	return null

/turf/proc/flow_body_members(cap = 4000)
	var/body_class = flow_body_class()
	if(!body_class)
		return list(src)
	var/list/found = list(src)
	var/list/frontier = list(src)
	var/list/seen = list()
	seen[src] = TRUE
	while(length(frontier) && length(found) < cap)
		var/turf/cur = frontier[length(frontier)]
		frontier.len--
		for(var/D in GLOB.cardinals)
			var/turf/N = get_step(cur, D)
			if(!N || seen[N])
				continue
			seen[N] = TRUE
			if(N.flow_body_class() != body_class)
				continue
			found += N
			frontier += N
	return found

/turf/proc/flow_body_surface()
	if(istype(src, /turf/open/floor/rogue/riverbot) || istype(src, /turf/open/floor/rogue/lakebed))
		var/turf/above = GetAbove(src)
		if(above && isopenspace(above))
			return above
		return null
	if(istype(src, /turf/open/water))
		return src
	return null

/turf/open/water/stream
	name = "stream"
	desc = "A shallow stream of clear water rushes over the rocks."
	icon = 'icons/turf/roguefloor.dmi'
	icon_state = "riverbot"
	water_level = 2

/turf/open/water/stream/Initialize()
	. = ..()
	if(!cell)
		cell = new /cell(src)
		cell.InitLiquids()
	var/datum/liquid/water_fluid = cell.get_fluid_datum(WATER)
	if(water_fluid)
		cell.fluid_volume[water_fluid] = MAX_FLUID_VOLUME
	cell.flow_dir = dir
	cell.sim_exempt = TRUE
	cell.make_liquid_sink(10)
	SSliquid.update_fluidsum(src)
	ensure_liquid_overlay()
	liquid_overlay.layer = ABOVE_MOB_LAYER
	liquid_overlay.plane = GAME_PLANE_HIGHEST
	SSliquid.update_cell_image(src)

/turf/open/water/stream/Destroy()
	SSliquid.liquid_sinks -= src
	return ..()

/turf/open/water/river/get_heuristic_slowdown(mob/traverser, travel_dir)
	var/const/UPSTREAM_PENALTY = 2
	var/const/DOWNSTREAM_BONUS = -2
	. = ..()
	if(traverser.is_floor_hazard_immune())
		return
	for(var/obj/structure/S in src)
		if(S.obj_flags & BLOCK_Z_OUT_DOWN)
			return
	if(!cell?.flow_dir)
		return
	if(travel_dir == cell.flow_dir)
		. += DOWNSTREAM_BONUS
	else if(travel_dir == GLOB.reverse_dir[cell.flow_dir])
		. += UPSTREAM_PENALTY

/turf/open/water/ocean
	name = "salt water"
	desc = "The waves lap at the coast, hungry to swallow the land. Doesn't look too deep."
	icon_state = "ash"
	icon = 'icons/turf/roguefloor.dmi'
	water_level = 2
	water_color = "#3e7459"
	slowdown = 4
	swim_skill = TRUE
	wash_in = TRUE
	water_reagent = /datum/reagent/water/salty

/turf/open/water/ocean/deep
	name = "salt water"
	desc = "Deceptively deep, be careful not to find yourself this far out."
	icon_state = "water"
	icon = 'icons/turf/roguefloor.dmi'
	water_level = 3
	water_color = "#3e7459"
	slowdown = 8
	swim_skill = TRUE
	wash_in = TRUE

/turf/open/water/pond
	name = "pond"
	desc = "Still and idyllic water that flows through meadows."
	icon_state = "pond"
	icon = 'icons/turf/roguefloor.dmi'
	water_level = 3
	water_color = "#367e94"
	slowdown = 3
	swim_skill = TRUE
	wash_in = TRUE
	water_reagent = /datum/reagent/water

/turf/open/water/lake
	name = "lake"
	desc = "Still, deep water. Peaceful and serene."
	icon = 'icons/turf/roguefloor.dmi'
	icon_state = "rock"
	slowdown = 5
	wash_in = TRUE
	swim_skill = TRUE
	water_level = 3
	baseturfs = /turf/open/transparent/openspace

/turf/open/water/lake/Initialize()
	. = ..()

	if(!GetBelow(src))
		return

	var/turf/new_top = ChangeTurf(/turf/open/transparent/openspace, null, CHANGETURF_IGNORE_AIR)

	var/turf/below = GetBelow(new_top)
	if(below)
		var/turf/lake_bottom = below.ChangeTurf(/turf/open/floor/rogue/lakebed, null, CHANGETURF_IGNORE_AIR)
		if(!lake_bottom.cell)
			lake_bottom.cell = new /cell(lake_bottom)
			lake_bottom.cell.InitLiquids()

		var/datum/liquid/below_water = lake_bottom.cell.get_fluid_datum(WATER)
		if(below_water)
			lake_bottom.cell.fluid_volume[below_water] = 100

		SSliquid.update_fluidsum(lake_bottom)
		SSliquid.cell_index[lake_bottom] = TRUE
		new_top.refresh_river_overlay()
		SSmapping.register_water_bed(lake_bottom)
