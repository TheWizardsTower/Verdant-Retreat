
//These are all the different status effects. Use the paths for each effect in the defines.

#define STATUS_EFFECT_MULTIPLE 0 //if it allows multiple instances of the effect

#define STATUS_EFFECT_UNIQUE 1 //if it allows only one, preventing new instances

#define STATUS_EFFECT_REPLACE 2 //if it allows only one, but new instances replace

#define STATUS_EFFECT_REFRESH 3 // if it only allows one, and new instances just instead refresh the timer

/// tick_interval value for effects that never tick(); they stay out of processing and expire via timer
#define STATUS_EFFECT_NO_TICK -1

/// Deciseconds of effect duration equal to one legacy Life-tick counter unit (measured: Life fires every 20ds)
#define STATUS_COUNTER_UNIT 20

///////////
// BUFFS //
///////////

#define STATUS_EFFECT_GOOD_MUSIC /datum/status_effect/good_music

#define STATUS_EFFECT_ANTIMAGIC /datum/status_effect/antimagic //grants antimagic (and reapplies if lost) for the duration

/////////////
// DEBUFFS //
/////////////

#define STATUS_EFFECT_OFFBALANCED /datum/status_effect/incapacitating/off_balanced

#define STATUS_EFFECT_STUN /datum/status_effect/incapacitating/stun //the affected is unable to move or use items

#define STATUS_EFFECT_KNOCKDOWN /datum/status_effect/incapacitating/knockdown //the affected is unable to stand up

#define STATUS_EFFECT_IMMOBILIZED /datum/status_effect/incapacitating/immobilized //the affected is unable to move

#define STATUS_EFFECT_PARALYZED /datum/status_effect/incapacitating/paralyzed //the affected is unable to move, use items, or stand up.

#define STATUS_EFFECT_UNCONSCIOUS /datum/status_effect/incapacitating/unconscious //the affected is unconscious

#define STATUS_EFFECT_SLEEPING /datum/status_effect/incapacitating/sleeping //the affected is asleep

#define STATUS_EFFECT_CHOKINGSTRAND /datum/status_effect/strandling //Choking Strand

#define STATUS_EFFECT_NECKSLICE /datum/status_effect/neck_slice //Creates the flavor messages for the neck-slice

#define STATUS_EFFECT_SPASMS /datum/status_effect/spasms //causes random muscle spasms

/////////////
// NEUTRAL //
/////////////

#define STATUS_EFFECT_INLOVE /datum/status_effect/in_love //Displays you as being in love with someone else, and makes hearts appear around them.

#define STATUS_EFFECT_BUGGED /datum/status_effect/bugged //Lets other mobs listen in on what it hears

#define STATUS_EFFECT_BOUNTY /datum/status_effect/bounty //rewards the person who added this to the target with refreshed spells and a fair heal

// Silence helpers

#define adjust_silence(duration) adjust_timed_status_effect(duration, /datum/status_effect/silenced)
#define adjust_silence_up_to(duration, up_to) adjust_timed_status_effect(duration, /datum/status_effect/silenced, up_to)
#define set_silence(duration) set_timed_status_effect(duration, /datum/status_effect/silenced)
#define set_silence_if_lower(duration) set_timed_status_effect(duration, /datum/status_effect/silenced, TRUE)
