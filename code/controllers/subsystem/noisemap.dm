#define NOISE_WHITE /Noise/Generator/White
#define NOISE_GRADIENT /Noise/Generator/Gradient
#define NOISE_GRADIENT_VALUE /Noise/Generator/GradientValue
#define NOISE_SIMPLEX /Noise/Generator/Simplex
#define NOISE_SPHERES /Noise/Generator/Spheres
#define NOISE_VALUE /Noise/Generator/Value
#define NOISE_RINGS /Noise/Generator/Cellular/Rings
#define NOISE_VORONOI /Noise/Generator/Cellular/Voronoi
#define NOISE_WORLEY /Noise/Generator/Cellular/Worley
#define NOISE_BILLOW /Noise/Generator/Fractal/Billow
#define NOISE_FASTPLASMA /Noise/Generator/Fractal/FastPlasma
#define NOISE_PLASMA /Noise/Generator/Fractal/Plasma
#define NOISE_RIDGEDMULTI /Noise/Generator/Fractal/RidgedMulti



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

/datum/controller/subsystem/noisemap/proc/make_noisemap(key, noisetype)
	LAZYINITLIST(noisemaps)

	if(!noisemaps[key])
		if(!noisetype)
			log_debug("IDIOT, you forgot to define a type!")
			return 
		noisemaps[key] = new noisetype 

/datum/controller/subsystem/noisemap/proc/get_value(key,x,y,offset,fac = 0.01)
	if(!noisemaps[key] || !key)
		log_debug("INVALID ACCESS FOR [key], RETURNING")
		return
	var/Noise/N = noisemaps[key]
	var/magnitude = 50*(N.get2((x+offset)*fac,(y+offset)*fac)+1) //sets this to 0-100
	return magnitude




