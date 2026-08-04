//System for controlling the noisemap dll to pull when needed. 

SUBSYSTEM_DEF(noisemap)
	name = "Signal Noisemap"
	init_order = INIT_ORDER_NOISEMAP
	flags = SS_NO_FIRE
	wait = 1
	runlevels = RUNLEVEL_LOBBY | RUNLEVELS_DEFAULT
	var/list/noisemaps 
	var/Noise/Generator/Gradient/gradient_noise = new

/datum/controller/subsystem/noisemap/Initialize()
	noisemaps = list()
	noisemaps += gradient_noise 
	return ..()
