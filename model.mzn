include "globals.mzn";
include "experimental.mzn";

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
type Constraint = record(
    ConstraintKind: kind,
    StatSpread: requirements,
    1..330: target,
);
type ConstraintGroup = record(
    ConstraintTiming: timing,
    bool: is_talent,
    array[int] of Constraint: body,
    set of 1..: prerequisites
);
type TimingPoint = 0..mastery_steps+2;
set of TimingPoint: ALL_TIMING_POINTS = 1..mastery_steps+2;
int: SENTINEL_POINT = mastery_steps + 3;
enum ConstraintKind = {And, Or, Sum};
enum ConstraintTiming = {FreeTiming, Initial, Preshrine, Postshrine, End, BeforeShrine, AfterShrine};
enum SpecialOath = {Bladeharper, NoSpecialOath};
enum Aspect = {FreeAspect, NoAspect, Adret, Canor, Capra, Celtor, Chrysid, Etrean, Felinor, Ganymede, Gremor, Khan, Kiron, Tiran, Vesperian, Drakkard};
array[Aspect, ALL_STATS] of STAT_RANGE: aspect_stats = [|
    FreeAspect: 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0|
    NoAspect: 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0|
    Adret: 0, 0, 0, 0, 2, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0|
    Canor: 3, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0|
    Capra: 0, 0, 0, 3, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0|
    Celtor: 0, 0, 0, 2, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0|
    Chrysid: 0, 0, 2, 0, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0|
    Etrean: 0, 0, 2, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0|
    Felinor: 0, 0, 3, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0|
    Ganymede: 0, 0, 0, 2, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0|
    Gremor: 2, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0|
    Khan: 3, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0|
    Kiron: 0, 0, 3, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0|
    Tiran: 0, 0, 3, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0|
    Vesperian: 0, 3, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0|
    Drakkard: 0, 2, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0|
|];
array[ConstraintTiming] of var set of TimingPoint: timing_to_range = [
    FreeTiming: {0} union ALL_TIMING_POINTS,
    Initial: {0},
    Preshrine: {shrine_point - 1},
    Postshrine: {shrine_point},
    End: {mastery_steps + 2},
    BeforeShrine: 0..shrine_point - 1,
    AfterShrine: shrine_point..(mastery_steps + 2)
];

SpecialOath: special_oath;
bool: preshrine_blasphemy;
array[int] of ConstraintGroup: constraints;
0..3: mastery_steps;
bool: allow_multifaceted;
Aspect: fixed_aspect;
var Aspect: aspect;
var StatSpread: innate_stats = [aspect_stats[aspect, i] | i in ALL_STATS];

array[{0} union ALL_TIMING_POINTS, ALL_STATS] of var STAT_RANGE: stats;
type MasteryIndex = 1..mastery_steps;
set of MasteryIndex: MASTERY_INDEX_SET = 1..mastery_steps;
array[MASTERY_INDEX_SET] of var {SENTINEL_POINT} union ALL_TIMING_POINTS: mastery_points;
array[MASTERY_INDEX_SET, ALL_STATS] of var 0..3: mastery_delta;
var {SENTINEL_POINT} union ALL_TIMING_POINTS: multifaceted_point;
var ALL_TIMING_POINTS: shrine_point;

predicate is_body(StatSpread: requirements) = forall(i in ALL_STATS) (requirements[i] > 0 <-> i in BODY_STATS) /\ all_equal(i in BODY_STATS) (requirements[i]);
predicate is_mind(StatSpread: requirements) = forall(i in ALL_STATS) (requirements[i] > 0 <-> i in MIND_STATS) /\ all_equal(i in MIND_STATS) (requirements[i]);
predicate is_weapon(StatSpread: requirements) = forall(i in ALL_STATS) (requirements[i] > 0 <-> i in WEAPON_STATS) /\ all_equal(i in WEAPON_STATS) (requirements[i]);
predicate is_element(StatSpread: requirements) = forall(i in ALL_STATS) (requirements[i] > 0 <-> i in UNLIMITED_SHRINE_STATS) /\ all_equal(i in UNLIMITED_SHRINE_STATS) (requirements[i]);
predicate is_category(StatSpread: requirements) = is_body(requirements) \/ is_mind(requirements) \/ is_weapon(requirements) \/ is_element(requirements);

function var set of ALL_STATS: non_zero_indices(var StatSpread: spread) = {i | i in ALL_STATS where spread[i] > 0};

function var 0..330: mastery_diff(var StatSpread: before, var StatSpread: after) = sum(i in ALL_STATS) (max(0, before[i] - after[i]));

predicate satisfy_and(var StatSpread: stats, StatSpread: requirements) = forall(i in ALL_STATS) (stats[i] >= requirements[i]);
predicate satisfy_or(var StatSpread: stats, StatSpread: requirements) = exists(i in non_zero_indices(requirements)) (stats[i] >= requirements[i]);
predicate satisfy_sum(var StatSpread: stats, StatSpread: requirements, 1..330: target) = sum(i in non_zero_indices(requirements)) (stats[i]) >= target;

array[1..mastery_steps+2] of var ALL_TIMING_POINTS union {SENTINEL_POINT}: all_points = mastery_points ++ [multifaceted_point, shrine_point];
var ALL_TIMING_POINTS union {SENTINEL_POINT}: mex;
constraint forall(i in ALL_TIMING_POINTS) ((i < mex) -> i in all_points);

constraint all_different_except(all_points, {SENTINEL_POINT});
constraint increasing(mastery_points);
constraint mex > max(i in all_points) (if i < SENTINEL_POINT then i else 1 endif);

constraint forall(i in ALL_TIMING_POINTS) (
    if multifaceted_point = i
        then forall(k in ALL_STATS) (stats[multifaceted_point, k] >= stats[multifaceted_point-1, k] - innate_stats[k])
    elseif i >= mex
        then forall(k in ALL_STATS) (stats[i, k] = stats[i-1, k])
    else true endif
);
constraint forall(i in MASTERY_INDEX_SET) ((mastery_points[i] != SENTINEL_POINT) -> forall(j in ALL_STATS) (
    if mastery_delta[i, j] > 0 
        then stats[mastery_points[i], j] = stats[mastery_points[i]-1, j] - mastery_delta[i, j] 
        else stats[mastery_points[i], j] >= stats[mastery_points[i]-1, j] 
    endif
));

predicate is_participating_stat(ALL_STATS: i) = stats[shrine_point-1, i] > if multifaceted_point < shrine_point then 0 else innate_stats[i] endif;

constraint let {
    var STAT_RANGE diff {0}: floor_stat;
    constraint 
        sum(i in ALL_STATS) 
            (if is_participating_stat(i) 
                then if i in LIMITED_SHRINE_STATS 
                    then min(stats[shrine_point-1, i] - floor_stat, 25)
                    else stats[shrine_point-1, i] - floor_stat
                endif
                else 0
            endif)
        in 0..(count(i in ALL_STATS) (is_participating_stat(i) /\ stats[shrine_point-1, i] <= 25 + floor_stat) - 1);
} in forall(i in ALL_STATS) (is_participating_stat(i) -> stats[shrine_point, i] >= if i in LIMITED_SHRINE_STATS then max(floor_stat, stats[shrine_point-1, i] - 25) else floor_stat endif);

predicate satisfy_constraint(var StatSpread: stats, ConstraintGroup: constraint_group) = let {
    array[int] of Constraint: body = constraint_group.body;
} in forall(requirement in body) (
    let {
        ConstraintKind: kind = requirement.kind;
        StatSpread: requirements = requirement.requirements;
    } in if kind = And then
        satisfy_and(stats, requirements)
    elseif kind = Or then
        satisfy_or(stats, requirements)
    else
        satisfy_sum(stats, requirements, requirement.target)
    endif
);

predicate mastery_constraint(ConstraintGroup: constraint_group) = constraint_group.is_talent -> let {
    array[int] of Constraint: body = constraint_group.body;
    var set of TimingPoint: range = timing_to_range[constraint_group.timing];
    var TimingPoint: final_satisfied = max([if satisfy_constraint(stats[i, ..], constraint_group) then i else 1 endif | i in ALL_TIMING_POINTS]);
} in forall(i in ALL_TIMING_POINTS, requirement in body) (
    let {
        ConstraintKind: kind = requirement.kind;
        StatSpread: requirements = requirement.requirements;
    } in ((kind = And \/ (kind = Or /\ (not is_category(requirements)))) /\ i in mastery_points /\ i > final_satisfied) -> 
        forall(s in non_zero_indices(requirements)) ((stats[i, s] = stats[i-1, s]) \/ (stats[i, s] >= requirements[s]))
);

var 0..3: preshrine_mastery_points_used = sum(i in MASTERY_INDEX_SET) (if mastery_points[i] < shrine_point then sum(mastery_delta[i, ..]) else 0 endif);
var 0..3: postshrine_mastery_points_used = sum(mastery_delta) - preshrine_mastery_points_used;

constraint sum(mastery_delta) <= 3;
constraint if fixed_aspect != FreeAspect then aspect = fixed_aspect else 
    if allow_multifaceted then aspect != FreeAspect else aspect = NoAspect endif
endif;
constraint (aspect = NoAspect \/ (not allow_multifaceted)) -> (multifaceted_point = SENTINEL_POINT);
constraint forall(i in MASTERY_INDEX_SET) (if mastery_points[i] != SENTINEL_POINT
    then sum(mastery_delta[i, ..]) > 0
    else mastery_delta[i, ..] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
endif);

constraint (aspect != NoAspect) -> forall(i in {0} union ALL_TIMING_POINTS, j in ALL_STATS) ((i < multifaceted_point) -> (stats[i, j] >= innate_stats[j]));
constraint forall(i in {0} union ALL_TIMING_POINTS) (sum(stats[i, ..]) - max(0, count(j in UNLIMITED_SHRINE_STATS) (stats[i, j] > 0) - 1) in 0..330);
constraint exists(i in {0} union ALL_TIMING_POINTS) ((i < shrine_point) /\ (sum(stats[i, ..]) - max(0, count(j in UNLIMITED_SHRINE_STATS) (stats[i, j] > 0) - 1) >= if preshrine_blasphemy then 90 else 135 endif));
constraint (special_oath = Bladeharper) -> exists(i in ALL_TIMING_POINTS) ((i >= shrine_point) /\ (
    (stats[i, 1] >= 25 \/ stats[i, 3] >= 25) /\ 
    (stats[i, 8] >= 75 \/ sum(stats[i, 7..9]) >= 90)
));
constraint forall(i in UNLIMITED_SHRINE_STATS, j in ALL_TIMING_POINTS, k in ATTUNEMENT_THRESHOLDS)
    ((j in mastery_points /\ j != shrine_point + 1 /\ j != SENTINEL_POINT /\ stats[j-1, i] >= k) -> (stats[j, i] >= k));
constraint (shrine_point + 1 != SENTINEL_POINT /\ shrine_point + 1 in mastery_points) -> 
    forall(i in UNLIMITED_SHRINE_STATS, j in ATTUNEMENT_THRESHOLDS diff {1})
        (((stats[shrine_point, i] > j)) -> (stats[shrine_point + 1, i] >= j)) /\ 
    forall(i in UNLIMITED_SHRINE_STATS) ((stats[shrine_point, i] >= 1) -> (stats[shrine_point + 1, i] >= 1));
constraint forall(i in ALL_STATS, j in MASTERY_INDEX_SET where mastery_points[j] < shrine_point) ((mastery_delta[j, i] > 0) -> ( 
    forall(k in mastery_points[j]+1..shrine_point-1) (stats[k, i] = stats[mastery_points[j], i]) /\
    forall(k in j+1..mastery_steps) ((mastery_points[k] < shrine_point) -> (mastery_delta[k, i] = 0))
));
constraint forall(i in ALL_STATS, j in MASTERY_INDEX_SET where mastery_points[j] > shrine_point /\ mastery_points[j] != SENTINEL_POINT) ((mastery_delta[j, i] > 0) -> 
    (
        forall(k in ALL_TIMING_POINTS) ((k > mastery_points[j] /\ k != multifaceted_point) -> (stats[k, i] = stats[mastery_points[j], i])) /\
        forall(k in j+1..mastery_steps) (mastery_delta[k, i] = 0)
    )
);
constraint forall(i in UNLIMITED_SHRINE_STATS) ((stats[shrine_point-1, i] = 0) -> (
    stats[shrine_point, i] = 0 /\ 
    forall(j in shrine_point+1..mastery_steps+2) (stats[j, i] != 1))
);
    
constraint forall(constraint_group in constraints) (
    exists(i in timing_to_range[constraint_group.timing]) (satisfy_constraint(stats[i, ..], constraint_group)) /\
    mastery_constraint(constraint_group) /\
    forall(prerequisite_idx in constraint_group.prerequisites) (
        let {
            ConstraintGroup: prerequisite = constraints[prerequisite_idx];
        } in prerequisite_idx in index_set(constraints) /\ 
            min([if satisfy_constraint(stats[i, ..], prerequisite) then i else SENTINEL_POINT endif | i in timing_to_range[prerequisite.timing]]) <=
            max([if satisfy_constraint(stats[i, ..], constraint_group) then i else -1 endif | i in timing_to_range[constraint_group.timing]]) 
    )
);
% solve :: goal_hierarchy(
%     [
%         int_min_goal(bool2int(aspect != NoAspect)),
%         int_min_goal(bool2int(multifaceted_point != SENTINEL_POINT)),
%     ] ++
%     [int_min_goal(sum(i in ALL_STATS) (stats[j, i])) | j in {0} union ALL_TIMING_POINTS] ++
%     [int_max_goal(sum(i in ALL_STATS) (stats[j, i] ^ 2)) | j in {0} union ALL_TIMING_POINTS] ++
%     [
%         int_min_goal(count(i in MASTERY_INDEX_SET) (mastery_points[i] < shrine_point)),
%         int_min_goal(count(i in MASTERY_INDEX_SET) (mastery_points[i] != SENTINEL_POINT /\ mastery_points[i] >= shrine_point)),
%         int_min_goal(preshrine_mastery_points_used),
%         int_min_goal(postshrine_mastery_points_used)
%     ]
% ) satisfy;
% output ["Aspect: " ++ show(aspect) ++ "\n"] ++ [ 
%     if fix(i) < fix(mex) then
%         if fix(i) = 0 then "Initial step: " elseif fix(i) in fix(mastery_points) then "SOM step: " elseif fix(i) = fix(shrine_point) then "SOO step: " elseif fix(i) = fix(multifaceted_point) then "Multifaceted step: " else "" endif ++ 
%         show(stats[i, ..]) ++ "\n"
%     else "" endif
%     | i in {0} union ALL_TIMING_POINTS
% ];