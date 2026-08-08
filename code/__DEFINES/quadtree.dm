/// Sentinel: a submitted native path request has not finished yet.
#define PATH_PENDING "pending"

// ==============================================================================
// QUADTREE DEFINES
// ==============================================================================

#define SS_PRIORITY_QUADTREE		68
#define INIT_ORDER_QUADTREE  10

#define QUADTREE_CAPACITY 12

#define QUADTREE_MERGE_THRESHOLD 6
#define QUADTREE_BOUNDARY_MINIMUM_WIDTH 12
#define QUADTREE_BOUNDARY_MINIMUM_HEIGHT 12
#define QTREE_EXCLUDE_OBSERVER 1
#define QTREE_SCAN_MOBS 2
#define QTREE_SCAN_HEARABLES 4

#define QT_KIND_PLAYER		(1<<0)
#define QT_KIND_NPC_CARBON	(1<<1)
#define QT_KIND_NPC_SIMPLE	(1<<2)
#define QT_KIND_HEARABLE	(1<<3)

#define QT_KIND_NPC_LISTED	(1<<4)

#define QT_KIND_AI_SLEEPING	(1<<5)
#define QT_KIND_NPC_ANY		(QT_KIND_NPC_CARBON|QT_KIND_NPC_SIMPLE)
#define QT_KIND_ALL			(QT_KIND_PLAYER|QT_KIND_NPC_ANY|QT_KIND_HEARABLE)

#define RECT new /datum/shape/rectangle


#define QT_SHAPE_CONTAINS_POINT(S, PX, PY) ((PX) >= (S).min_x && (PX) <= (S).max_x && (PY) >= (S).min_y && (PY) <= (S).max_y && (!(S).is_circle || (S).contains_point(PX, PY)))

#define QT_SHAPE_OVERLAPS_BOX(S, BMINX, BMAXX, BMINY, BMAXY) (!((S).max_x < (BMINX) || (S).min_x > (BMAXX) || (S).max_y < (BMINY) || (S).min_y > (BMAXY)) && (!(S).is_circle || (S).overlaps_box(BMINX, BMAXX, BMINY, BMAXY)))

#define QT_SHAPE_CONTAINS_BOX(S, BMINX, BMAXX, BMINY, BMAXY) ((S).min_x <= (BMINX) && (S).max_x >= (BMAXX) && (S).min_y <= (BMINY) && (S).max_y >= (BMAXY) && (!(S).is_circle || (S).contains_box(BMINX, BMAXX, BMINY, BMAXY)))

#define ENTITIES_IN_RANGE(npc) (SSquadtree.players_in_range((npc).qt_range, (npc).z, QTREE_SCAN_MOBS|QTREE_EXCLUDE_OBSERVER) + SSquadtree.npcs_in_range((npc).qt_range, (npc).z))
