
//Base stubs for status helpers; the real implementations live on /mob/living atop the status effect engine.

///Set the slowdown of a mob
/mob/proc/Slowdown(amount)
	return

///Whether the mob's vision is blocked by temporary blindness
/mob/proc/is_blind()
	return FALSE

///Blur strength in legacy counter units, for fullscreen filter backdrops
/mob/proc/get_eye_blur_units()
	return 0

/mob/proc/psydo_nyte()
	sleep(2)
	overlay_fullscreen("LYVES", /atom/movable/screen/fullscreen/zezuspsyst)
	sleep(2)
	clear_fullscreen("LYVES")

///Adjust the disgust level of a mob
/mob/proc/adjust_disgust(amount)
	return

///Set the disgust level of a mob
/mob/proc/set_disgust(amount)
	return

///Adjust the body temperature of a mob, with min/max settings
/mob/proc/adjust_bodytemperature(amount,min_temp=0,max_temp=INFINITY)
	if(bodytemperature >= min_temp && bodytemperature <= max_temp)
		bodytemperature = CLAMP(bodytemperature + amount,min_temp,max_temp)
