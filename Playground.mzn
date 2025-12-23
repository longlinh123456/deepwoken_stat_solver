include "all_equal.mzn";

% stats in order: str, ftd, agi, int, wll, cha, hvy, med, lht, fir, ice, ltn, wnd, sdw, mtl, bld
set of int: ALL_STATS = 1..16;
set of int: LIMITED_SHRINE_STATS = 1..9;
set of int: UNLIMITED_SHRINE_STATS = 10..16;
set of int: STAT_RANGE = 0..100;
set of STAT_RANGE: ATTUNEMENT_THRESHOLDS = {1, 20, 30, 50};
set of ALL_STATS: MIND_STATS = 4..6;
set of ALL_STATS: BODY_STATS = 1..3; 
set of ALL_STATS: WEAPON_STATS = 7..9;

type StatSpread = array[ALL_STATS] of STAT_RANGE;
type SumConstraint = record(
    set of ALL_STATS: stats,
    1..330: target
);
type ConstraintCollection = record(
    array[int, ALL_STATS] of STAT_RANGE: and,
    array[int, ALL_STATS] of STAT_RANGE: or,
);
type Constraints = record(
    ConstraintCollection: talent,
    ConstraintCollection: non_talent,
    array[int] of SumConstraint: sum,
);
enum SpecialOath = {Bladeharper, None};

predicate is_body(var StatSpread: requirements) = forall(i in ALL_STATS) (requirements[i] > 0 <-> i in BODY_STATS) /\ all_equal(i in BODY_STATS) (requirements[i]);
predicate is_mind(var StatSpread: requirements) = forall(i in ALL_STATS) (requirements[i] > 0 <-> i in MIND_STATS) /\ all_equal(i in MIND_STATS) (requirements[i]);
predicate is_weapon(var StatSpread: requirements) = forall(i in ALL_STATS) (requirements[i] > 0 <-> i in WEAPON_STATS) /\ all_equal(i in WEAPON_STATS) (requirements[i]);
predicate is_category(var StatSpread: requirements) = is_body(requirements) \/ is_mind(requirements) \/ is_weapon(requirements);

function var set of ALL_STATS: non_zero_indices(var StatSpread: spread) = {i | i in ALL_STATS where spread[i] > 0};

predicate shrine(var StatSpread: preshrine, var StatSpread: postshrine) = let {
    var STAT_RANGE diff {0}: floor_stat;
    var set of ALL_STATS: nonzero_stats = non_zero_indices(preshrine);
    constraint 
        sum(i in nonzero_stats) (if i in LIMITED_SHRINE_STATS then min(preshrine[i] - floor_stat, 25) else preshrine[i] - floor_stat endif) in 
        0..(count(i in nonzero_stats) (preshrine[i] <= 25 + floor_stat) - 1);
} in forall(j in nonzero_stats) (postshrine[j] >= if j in LIMITED_SHRINE_STATS then max(floor_stat, preshrine[j] - 25) else floor_stat endif);

function var 0..330: mastery_diff(var StatSpread: before, var StatSpread: after) = sum(i in ALL_STATS) (max(0, before[i] - after[i]));

predicate satisfy_and(var StatSpread: stats, var StatSpread: requirements) = forall(i in ALL_STATS) (stats[i] >= requirements[i]);
predicate satisfy_or(var StatSpread: stats, var StatSpread: requirements) = exists(i in non_zero_indices(requirements)) (stats[i] >= requirements[i]);
predicate satisfy_sum(var StatSpread: stats, var SumConstraint: requirements) = sum(i in requirements.stats) (stats[i]) >= requirements.target;

StatSpread: initial_constraint;
StatSpread: preshrine_constraint;
StatSpread: postshrine_constraint;
SpecialOath: special_oath;
bool: preshrine_blasphemy;
var Constraints: constraints;
int: shrine_steps;


% index 1 is initial, index 2 to 4 is mastery steps
array[1..(shrine_steps + 1), ALL_STATS] of var STAT_RANGE: preshrine;
array[2..(shrine_steps + 1)] of var bool: preshrine_mastery_active;
array[1..(shrine_steps + 1), ALL_STATS] of var STAT_RANGE: postshrine;
array[2..(shrine_steps + 1)] of var bool: postshrine_mastery_active;
array[1..(2*(shrine_steps + 1)), ALL_STATS] of var STAT_RANGE: stat_chain = preshrine ++ postshrine;

constraint forall(i in 3..(shrine_steps + 1)) ((preshrine_mastery_active[i] -> preshrine_mastery_active[i-1]) /\ (postshrine_mastery_active[i] -> postshrine_mastery_active[i-1]));

constraint forall(i in 2..(shrine_steps + 1)) (
    if preshrine_mastery_active[i] 
        then sum(preshrine[i, ALL_STATS]) <= sum(preshrine[i-1, ALL_STATS]) 
        else forall(j in ALL_STATS) (preshrine[i, j] = preshrine[i-1, j])
    endif /\
    if postshrine_mastery_active[i] 
        then sum(postshrine[i, ALL_STATS]) <= sum(postshrine[i-1, ALL_STATS]) 
        else forall(j in ALL_STATS) (postshrine[i, j] = postshrine[i-1, j])
    endif
);

var 0..3: blasphemy_points_used = sum(i in 2..(shrine_steps + 1)) (
    if preshrine_mastery_active[i] then mastery_diff(preshrine[i-1, ..], preshrine[i, ..]) else 0 endif +
    if postshrine_mastery_active[i] then mastery_diff(postshrine[i-1, ..], postshrine[i, ..]) else 0 endif
);

constraint blasphemy_points_used <= 3;

constraint shrine(preshrine[shrine_steps + 1, ..], postshrine[1, ..]);
constraint forall(i in 1..(shrine_steps + 1)) (sum(preshrine[i, ..]) - max(0, count(j in UNLIMITED_SHRINE_STATS) (preshrine[i, j] > 0) - 1) in 0..330);
constraint exists(i in 1..(shrine_steps + 1)) (sum(preshrine[i, ..]) - max(0, count(j in UNLIMITED_SHRINE_STATS) (preshrine[i, j] > 0) - 1) >= if preshrine_blasphemy then 90 else 135 endif);
constraint forall(i in 1..(shrine_steps + 1)) (sum(postshrine[i, ..]) - max(0, count(j in UNLIMITED_SHRINE_STATS) (postshrine[i, j] > 0) - 1) in 0..330);
constraint forall(i in ALL_STATS) (
    preshrine[shrine_steps + 1, i] >= preshrine_constraint[i]
    /\ postshrine[shrine_steps + 1, i] >= postshrine_constraint[i]
    /\ preshrine[1, i] >= initial_constraint[i]
);
constraint (special_oath = Bladeharper) -> exists(i in 1..(shrine_steps + 1)) (
    (postshrine[i, 1] >= 25 \/ postshrine[i, 3] >= 25) /\ 
    (postshrine[i, 8] >= 75 \/ sum(postshrine[i, 7..9]) >= 90)
);
constraint forall(i in UNLIMITED_SHRINE_STATS, j in 2..(2*(shrine_steps + 1)) diff {shrine_steps + 2}, k in ATTUNEMENT_THRESHOLDS) ((stat_chain[j-1, i] >= k) -> (stat_chain[j, i] >= k));
constraint forall(i in ALL_STATS, j in 3..(2*(shrine_steps + 1)) diff {shrine_steps + 2, shrine_steps + 3}) ((stat_chain[j-1, i] < stat_chain[j-2, i]) -> (stat_chain[j, i] = stat_chain[j-1, i]));
constraint let {array[int, ALL_STATS] of var STAT_RANGE: requirements = constraints.talent.and} in forall(i in index_set_1of2(requirements)) (
    exists(j in 1..(2*(shrine_steps + 1))) (satisfy_and(stat_chain[j, ..], requirements[i, ..])) /\
    forall(j in 2..(2*(shrine_steps + 1)) diff {shrine_steps + 2})
        (forall(s in non_zero_indices(requirements[i, ..])) (stat_chain[j, s] >= stat_chain[j-1, s]) \/ 
            (not(
                exists(k in (j+1)..(2*(shrine_steps + 1))) (satisfy_and(stat_chain[k, ..], requirements[i, ..])))
                -> satisfy_and(stat_chain[j, ..], requirements[i, ..])
            )
        )
);
constraint let {array[int, ALL_STATS] of var STAT_RANGE: requirements = constraints.talent.or} in forall(i in index_set_1of2(requirements)) (
    exists(j in 1..(2*(shrine_steps + 1))) (satisfy_or(stat_chain[j, ..], requirements[i, ..])) /\
    forall(j in 2..(2*(shrine_steps + 1)) diff {shrine_steps + 2})
        (forall(s in non_zero_indices(requirements[i, ..])) (stat_chain[j, s] >= stat_chain[j-1, s]) \/ 
            ((not(is_category(requirements[i, ..])) /\ 
                not(exists(k in (j+1)..(2*(shrine_steps + 1))) (satisfy_or(stat_chain[k, ..], requirements[i, ..])))
             ) -> satisfy_or(stat_chain[j, ..], requirements[i, ..]))
        )
);
constraint let {array[int, ALL_STATS] of var STAT_RANGE: requirements = constraints.non_talent.and} in forall(i in index_set_1of2(requirements)) (
    exists(j in 1..(2*(shrine_steps + 1))) (satisfy_and(stat_chain[j, ..], requirements[i, ..]))
);
constraint let {array[int, ALL_STATS] of var STAT_RANGE: requirements = constraints.non_talent.or} in forall(i in index_set_1of2(requirements)) (
    exists(j in 1..(2*(shrine_steps + 1))) (satisfy_or(stat_chain[j, ..], requirements[i, ..]))
);
constraint let {array[int] of var SumConstraint: requirements = constraints.sum} in forall(i in index_set(requirements)) (
    exists(j in 1..(2*(shrine_steps + 1))) (satisfy_sum(stat_chain[j, ..], requirements[i]))
);
solve minimize 68283.51691 * sum(i in preshrine_mastery_active ++ postshrine_mastery_active) (bool2int(i)) + 22761.17230 * blasphemy_points_used + 68.97331 * sum(preshrine[1, ..]) + 0.20901 * sum(postshrine[1, ..]) - 0.00001 * sum(i in ALL_STATS) (preshrine[1, i] ^ 2);