/turf/open/floor/carpet
	name = "carpet"
	desc = "Plush fabric softens your step. Did you remember to wipe your shoes?"
	icon = 'icons/turf/floors.dmi'
	icon_state = "carpet"
	broken_states = list("damaged")
	smoothing_groups = SMOOTH_GROUP_OPEN_FLOOR + SMOOTH_GROUP_FLOOR_CARPET
	flags_1 = NONE
	bullet_bounce_sound = null
	footstep = FOOTSTEP_CARPET
	barefootstep = FOOTSTEP_SOFT_BAREFOOT
	clawfootstep = FOOTSTEP_SOFT_BAREFOOT
	heavyfootstep = FOOTSTEP_GENERIC_HEAVY
	spread_chance = 15
	landsound = 'sound/foley/jumpland/carpetland.wav'
/turf/open/floor/carpet/Initialize()
	. = ..()
	update_icon()

/turf/open/floor/carpet/update_icon()
	if(!..())
		return FALSE
	if(smoothing_flags & SMOOTH_BITMASK)
		QUEUE_SMOOTH(src)
/turf/open/floor/carpet/purple
	icon = 'icons/turf/smooth/floors/carpet_purple.dmi'
	icon_state = MAP_SWITCH("carpet", "carpet-0")
	smoothing_flags = SMOOTH_BITMASK

/turf/open/floor/carpet/inn
	icon = 'icons/turf/floors/inn.dmi'

/turf/open/floor/carpet/stellar
	icon = 'icons/turf/smooth/floors/carpet_stellar.dmi'
	icon_state = MAP_SWITCH("carpet", "carpet-0")
	smoothing_flags = SMOOTH_BITMASK

/turf/open/floor/carpet/red
	icon = 'icons/turf/smooth/floors/carpet_red.dmi'
	icon_state = MAP_SWITCH("carpet", "carpet-0")
	smoothing_flags = SMOOTH_BITMASK

/turf/open/floor/carpet/royalblack
	icon = 'icons/turf/smooth/floors/carpet_royalblack.dmi'
	icon_state = MAP_SWITCH("carpet", "carpet-0")
	smoothing_flags = SMOOTH_BITMASK


/turf/open/floor/carpet/break_tile()
	broken = TRUE
	update_icon()

/turf/open/floor/carpet/burn_tile()
	burnt = TRUE
	update_icon()

/turf/open/floor/carpet/get_smooth_underlay_icon(mutable_appearance/underlay_appearance, turf/asking_turf, adjacency_dir)
	return FALSE

//REpath this.

/turf/open/floor/rogue/carpet
	icon_state = "carpet"
	desc = "Plush fabric softens your step. Did you remember to wipe your shoes?"
	landsound = 'sound/foley/jumpland/carpetland.wav'
	footstep = FOOTSTEP_CARPET
	barefootstep = FOOTSTEP_SOFT_BAREFOOT
	clawfootstep = FOOTSTEP_SOFT_BAREFOOT
	heavyfootstep = FOOTSTEP_GENERIC_HEAVY
	smoothing_groups = SMOOTH_GROUP_FLOOR_CARPET

/turf/open/floor/rogue/carpet/lord
	icon_state = ""

/turf/open/floor/rogue/carpet/lord/Initialize()
	. = ..()
	if(GLOB.lordprimary)
		lordcolor(GLOB.lordprimary,GLOB.lordsecondary)
	GLOB.lordcolor += src

/turf/open/floor/rogue/carpet/lord/Destroy()
	GLOB.lordcolor -= src
	return ..()

/turf/open/floor/rogue/carpet/lord/lordcolor(primary,secondary)
	if(!primary || !secondary)
		return
	var/mutable_appearance/M = mutable_appearance(icon, "[icon_state]_primary", -(layer+0.1))
	M.color = primary
	add_overlay(M)

/turf/open/floor/rogue/carpet/lord/center
	icon_state = "carpet_c"


/turf/open/floor/rogue/carpet/lord/left
	icon_state = "carpet_l"

/turf/open/floor/rogue/carpet/lord/right
	icon_state = "carpet_r"

//These aren't fucking TURFS

/obj/effect/decal/carpet
	name = "exotic rug"
	desc = "Dazzling symmetrical patterns flow with an old culture's style."
	pixel_w = -16
	pixel_z = -17
	icon = 'icons/roguetown/misc/64x64.dmi'
	icon_state = "kover"

/obj/effect/decal/carpet/kover_darkred
	name = "exotic red rug"
	desc = "Dazzling symmetrical patterns flow with an old culture's style."
	icon = 'icons/roguetown/misc/64x64.dmi'
	icon_state = "kover_darkred"

/obj/effect/decal/carpet/kover_purple
	name = "exotic purple rug"
	desc = "Dazzling symmetrical patterns flow with an old culture's style."
	icon = 'icons/roguetown/misc/64x64.dmi'
	icon_state = "kover_purple"

/obj/effect/decal/carpet/kover_black
	name = "exotic black carpet"
	desc = "Dazzling symmetrical patterns flow with an old culture's style."
	icon = 'icons/roguetown/misc/64x64.dmi'
	icon_state = "kover_black"

/obj/effect/decal/carpet/square
	name = "green carpet"
	desc = "Soft green carpeting that reminds you of grassy meadows."
	pixel_w = -16
	pixel_z = -16
	icon = 'icons/roguetown/misc/64x64.dmi'
	icon_state = "greencarpet"

/obj/effect/decal/carpet/square/black
	name = "black carpet"
	desc = "As black as the night sky during a storm."
	icon = 'icons/roguetown/misc/64x64.dmi'
	icon_state = "blackcarpet"

