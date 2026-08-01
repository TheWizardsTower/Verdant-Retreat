//Ticks active status effects. Only effects that actually tick() live here; static timed effects expire through SStimer instead.

PROCESSING_SUBSYSTEM_DEF(statuseffects)
	name = "Status Effects"
	wait = 2
	stat_tag = "STE"
	processing_flag = PROCESSING_STATUSEFFECTS
