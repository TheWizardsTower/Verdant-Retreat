/datum/component/fertility
	dupe_mode = COMPONENT_DUPE_UNIQUE
	var/fertility = 0
/datum/component/fertility/Initialize()
	if(!isatom(parent))
		return COMPONENT_INCOMPATIBLE
	var/atom/P = parent
	if(ismovable(parent))
		fertility = 100
	else
		SSnoisemap.make_noisemap("fertility", NOISE_GRADIENT)
		fertility = round(SSnoisemap.get_value("fertility", P.x, P.y, P.z))
	//P.color = rgb(0,0,fertility, space = COLORSPACE_HSV)
	//P.maptext = "[fertility]"
	P.fertility_interaction(fertility)

/datum/component/fertility/proc/adjust_fertility(amount)
	fertility += clamp(fertility+amount, 0, 100)
/atom/proc/fertility_interaction(fert)
	return
