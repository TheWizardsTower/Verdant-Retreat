/particles/water_mist
	icon = 'icons/effects/particles/smoke.dmi'
	icon_state = list("steam_cloud_1" = 5, "steam_cloud_2" = 5, "steam_cloud_3" = 5)
	color = "#FFFFFFAA"
	count = 2
	spawning = 0.2
	lifespan = 1 SECONDS
	fade = 0.5 SECONDS
	fadein = 0.2 SECONDS
	position = generator(GEN_BOX, list(-10, -8, 0), list(10, 8, 0), NORMAL_RAND)
	drift = generator(GEN_SPHERE, list(-0.01, 0), list(0.01, 0.01), UNIFORM_RAND)
	gravity = list(0, 0.15)
	friction = 0.3
	grow = 0.025

/obj/effect/mist_generator
	name = "mist"
	icon_state = "nothing"
	anchored = TRUE
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	var/obj/effect/abstract/particle_holder/cached/particle_effect

/obj/effect/mist_generator/Initialize()
	. = ..()
	particle_effect = new(src, /particles/water_mist, 4)
	particle_effect.vis_flags &= ~VIS_INHERIT_PLANE

/obj/effect/mist_generator/Destroy()
	QDEL_NULL(particle_effect)
	return ..()

/obj/effect/temp_visual/liquid_splash_mist
	duration = 8
	randomdir = FALSE
	var/obj/effect/abstract/particle_holder/cached/particle_effect

/obj/effect/temp_visual/liquid_splash_mist/Initialize()
	. = ..()
	particle_effect = new(src, /particles/water_mist, 4)
	particle_effect.vis_flags &= ~VIS_INHERIT_PLANE

/obj/effect/temp_visual/liquid_splash_mist/Destroy()
	QDEL_NULL(particle_effect)
	return ..()
