// Defines for fluid behaviors.

#define FLUID_TRANSFER 1 // Standard transfer amount multiplier for evening out the fluid volume of turfs. This probably shouldn't change but using a define is much more readable.
#define FLUID_THRESHOLD 100 // Threshold over which a fluid fills the turf above it.
#define FLUID_MAX_TRANSFER_RATE 60 // Maximum speed at which liquids get transferred between tiles.
#define MIN_FLUID_VOLUME 1 // At least 1 unit of fluid has to be able to transfer to a turf for the turf to be added to the cells list.
#define MAX_FLUID_VOLUME 100 // Maximum amount of fluid each cell can contain (at this point it's just completely full)
#define LIQUID_ABSORPTION_WETNESS_MULT 3
#define LIQUID_ABSORPTION_INTERVAL (10 SECONDS) // How often absorbent turfs pull liquid_absorption units of standing fluid into wetness
#define LIQUID_ABSORPTION_MAX_DEPTH FLUID_BAND_EDGE_1 // Ground only drains shallow water; anything deeper persists until it spreads thin
#define RAIN_INJECT_INTERVAL (2 SECONDS)
#define RAIN_INJECT_DENSITY 0.027 // Chance per exposed outdoor turf per interval at full severity
#define RAIN_INJECT_AMOUNT 3
#define LIQUID_EVAP_THRESHOLD 5 // Puddles shallower than this evaporate when sun-exposed or near an active fire
#define LIQUID_EVAP_AMOUNT 1
#define LIQUID_EVAP_INTERVAL (112.5 SECONDS) // At LIQUID_EVAP_AMOUNT per pass, a maximal 4-unit puddle dries over 7.5 minutes
#define LIQUID_DOUSE_THRESHOLD 5 // fluid depth at which ground-level fires are snuffed
#define LIQUID_DOUSE_STANDING_THRESHOLD 50 // fluid depth at which waist and chest-level fires are snuffed
#define LIQUID_VIS_HOLD_TICKS 4 // A fluid-level band change must persist this many engine ticks before the overlay shows it
#define LIQUID_SWEEP_SLICE 6000 // Max wet turfs a periodic absorption/reaction pass visits per fire; the cursor rotates until the sweep completes, then the interval timer rearms
#define LIQUID_APPLY_DELTAS_PER_FIRE 400 // Max native fluidsum records applied per fire; the rest of a payload carries over so one collect never spikes the tick. Band/event/fall tails apply the moment a payload opens, so visuals never wait on the volume drain.
#define SUBMERSION_FLUID_THRESHOLD 80 // fluid depth on a bottom-z bed turf at which mobs there (or on the openspace above) submerge
#define SUBMERSION_PRONE_FLUID_THRESHOLD FLUID_BAND_EDGE_1 // a prone mob fully submerges in anything deeper than a puddle

// Fluid level defines for use by the fluid subsystem, these are pretty arbitrary and the actual fluidsum is checked by SSliquid. Use the macro: GET_FLUID_LEVEL(turf)
// Band edges are shared with the native engine (pushed as band1..band6 config at init) - fluidsum <= edge N is band N
#define FLUID_BAND_EDGE_1 20
#define FLUID_BAND_EDGE_2 30
#define FLUID_BAND_EDGE_3 40
#define FLUID_BAND_EDGE_4 55
#define FLUID_BAND_EDGE_5 60
#define FLUID_BAND_EDGE_6 95
#define FLUID_EMPTY 0
#define FLUID_VERY_LOW 1
#define FLUID_LOW 2
#define FLUID_MEDIUM 3
#define FLUID_HIGH 4
#define FLUID_VERY_HIGH 5
#define FLUID_FULL 6
#define FLUID_OVERFLOW 7

#define FLUID_LEVEL_FROM_SUM(sum) ( \
	(sum) <= 0 ? FLUID_EMPTY : \
	(sum) <= FLUID_BAND_EDGE_1 ? FLUID_VERY_LOW : \
	(sum) <= FLUID_BAND_EDGE_2 ? FLUID_LOW : \
	(sum) <= FLUID_BAND_EDGE_3 ? FLUID_MEDIUM : \
	(sum) <= FLUID_BAND_EDGE_4 ? FLUID_HIGH : \
	(sum) <= FLUID_BAND_EDGE_5 ? FLUID_VERY_HIGH : \
	(sum) <= FLUID_BAND_EDGE_6 ? FLUID_FULL : \
	FLUID_OVERFLOW )

// Defines for the wave filter
#define WAVE_COUNT 7

// Bitflags for various fluid properties and state tracking. Currently only FLUID_MOVED is actually being used, the others are for the future and are not yet implemented.

#define FLUID_MOVED 0x01 // State tracker to check if a fluid has been moved during the current update cycle.
#define FLUID_FLAMMABLE 0x02 // This fluid will burn if exposed to an open flame.
#define FLUID_CONDUCTIVE 0x04 // This fluid conducts electricity and will zap any mob touching a puddle when that puddle gets electrocuted
#define FLUID_CORROSIVE 0x8 // This fluid will cause some burning over time on contact and damage to clothes / armor.
#define FLUID_PERMEATING 0x10 // This is going to be used to check if fluids should cause the on touch effect of their associated reagent.
#define FLUID_STICKY 0x20 // For fluids that should stick to mobs who touch them for a while.

// Quick access to common fluid types so you don't have to type the whole path

#define WATER /datum/liquid/water
#define FUEL /datum/liquid/fuel

// Macros

#define GET_FLUID_LEVEL(turf) SSliquid.get_fluid_level(turf)
#define GET_FLUID_AMOUNT(turf, fluid_type) SSliquid.manager.get_fluid_amount(turf, fluid_type)
#define GET_FLUID_DATUM(turf, fluid_type) SSliquid.manager.get_liquid_instance(turf, fluid_type)
#define GET_TOTAL_FLUID(turf) SSliquid.manager.get_total_fluid(turf)
#define GET_ALL_FLUIDS(turf) SSliquid.manager.get_all_fluids(turf)
#define HAS_FLUID_TYPE(turf, fluid_type) SSliquid.manager.has_fluid_type(turf, fluid_type)
#define GET_DOMINANT_FLUID(turf) SSliquid.manager.get_dominant_fluid(turf)
#define CLEAR_ALL_FLUIDS(turf) SSliquid.manager.clear_all_fluids(turf)

// Priority defines for liquid subsystem
#define SS_PRIORITY_LIQUID FIRE_PRIORITY_LIQUID


#define log_debug(msg) world.log << msg

#ifndef M_PI
#define M_PI 3.14159265
#endif

#define RIVER_PUSH_BASE_CD 10

#define LIQUID_FALL_MIST_THRESHOLD 5
