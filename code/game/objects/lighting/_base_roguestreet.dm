/obj/machinery/light/roguestreet
	icon = 'icons/roguetown/misc/tallstructure.dmi'
	overlayicon = 'icons/roguetown/misc/tallstructure_overlay.dmi'
	icon_state = "slamp1"
	base_state = "slamp"
	brightness = 10
	//nightshift_allowed = FALSE
	fueluse = 0
	bulb_colour = "#fcd294"
	bulb_power = 1
	max_integrity = 0
	pass_flags = LETPASSTHROW
	light_system = STATIC_LIGHT
/obj/machinery/light/roguestreet/midlamp
	icon = 'icons/roguetown/misc/64x64.dmi'
	icon = 'icons/roguetown/misc/64x64_overlay.dmi'	
	icon_state = "midlamp1"
	base_state = "midlamp"
	light_color = "#56ff0d" //roguetown use defines challenge: as yet uncompleted
	pixel_x = -16
	density = TRUE

/obj/machinery/light/roguestreet/proc/lights_out()
	on = FALSE
	set_light(l_on = FALSE)
	update_icon()
	addtimer(CALLBACK(src, PROC_REF(lights_on)), 5 MINUTES)

/obj/machinery/light/roguestreet/proc/lights_on()
	on = TRUE
	set_light(l_on = TRUE)
	update()
	update_icon()

/obj/machinery/light/roguestreet/update_icon()
	SSvis_overlays.remove_vis_overlay(src, managed_vis_overlays)
	
	if(on)
		icon_state = "[base_state]1"
		SSvis_overlays.add_vis_overlay(src, overlayicon, base_state, ABOVE_LIGHTING_LAYER, ABOVE_LIGHTING_PLANE, dir, set_vis_flags = VIS_INHERIT_DIR|VIS_INHERIT_ID)
	else
		icon_state = "[base_state]0"

/obj/machinery/light/roguestreet/update()
	. = ..()
	if(on)
		GLOB.fires_list |= src
	else
		GLOB.fires_list -= src

/obj/machinery/light/roguestreet/Initialize()
	lights_on()
	GLOB.streetlamp_list += src
	update_icon()
	. = ..()

/obj/machinery/light/roguestreet/update_icon()
	if(on)
		icon_state = "[base_state]1"
	else
		icon_state = "[base_state]0"
