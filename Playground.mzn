% stats in order: str, ftd, agi, int, wll, cha, hvy, med, lht, fir, ice, ltn, wnd, sdw, mtl, bld
set of int: ALL_STATS = 1..16;
set of int: LIMITED_SHRINE_STATS = 1..9;
set of int: UNLIMITED_SHRINE_STATS = 10..16;
set of int: STAT_RANGE = 0..100;

type StatSpread = array[ALL_STATS] of STAT_RANGE;

function var set of ALL_STATS: non_zero_indices(var StatSpread: spread) = {i | i in ALL_STATS where spread[i] > 0};

predicate shrine(var StatSpread: preshrine, var StatSpread: postshrine) = let {
    var STAT_RANGE diff {0}: floor_stat;
    var set of ALL_STATS: nonzero_stats = non_zero_indices(preshrine);
    constraint 
        sum(i in nonzero_stats) (if i in LIMITED_SHRINE_STATS then min(preshrine[i] - floor_stat, 25) else preshrine[i] - floor_stat endif) in 
        0..(count(i in nonzero_stats) (preshrine[i] <= 25 + floor_stat) - 1);
} in forall(j in nonzero_stats) (postshrine[j] >= if j in LIMITED_SHRINE_STATS then max(floor_stat, preshrine[j] - 25) else floor_stat endif);

StatSpread: preshrine_constraint;
StatSpread: postshrine_constraint;
bool: preshrine_blasphemy;
array[int, ALL_STATS] of STAT_RANGE: constraints;


var StatSpread: preshrine;
var StatSpread: postshrine;

constraint shrine(preshrine, postshrine);
constraint sum(preshrine) - max(0, count(i in UNLIMITED_SHRINE_STATS) (preshrine[i] > 0) - 1) in (if preshrine_blasphemy then 90 else 135 endif)..330;
constraint sum(postshrine) - max(0, count(i in UNLIMITED_SHRINE_STATS) (postshrine[i] > 0) - 1) <= 330;
constraint forall(i in ALL_STATS) (
    preshrine[i] >= preshrine_constraint[i]
    /\ postshrine[i] >= postshrine_constraint[i]
);
constraint forall(i in index_set_1of2(constraints)) (
    forall(j in ALL_STATS) (preshrine[j] >= constraints[i, j]) \/
    forall(j in ALL_STATS) (postshrine[j] >= constraints[i, j])
);
solve minimize 37036927 * sum(preshrine) - 334 * sum(i in ALL_STATS) (preshrine[i] ^ 2) + sum(postshrine);