include "globals.mzn";

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
enum Aspect = {FreeAspect, NoAspect, Adret, Canor, Capra, Celtor, Chrysid, Etrean, Felinor, Ganymede, Gremor, Khan, Kiron, Tiran, Vesperian, Drakkard, Heliodar, Lightborn};
set of Aspect: DEV_ASPECTS = {Drakkard, Heliodar, Lightborn};
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
    Drakkard: 0, 2, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0|
    Heliodar: 3, 3, 2, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0|
    Lightborn: 2, 2, 2, 2, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0|
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
bool: allow_dev_aspects;
Aspect: fixed_aspect;
var (if fixed_aspect != FreeAspect 
        then {fixed_aspect} 
        else if not allow_multifaceted 
            then {NoAspect} 
            else Aspect 
        endif
    endif)
diff ({FreeAspect} union if allow_dev_aspects then {} else DEV_ASPECTS endif): aspect;
var StatSpread: innate_stats = [aspect_stats[aspect, i] | i in ALL_STATS];

array[{0} union ALL_TIMING_POINTS, ALL_STATS] of var STAT_RANGE: stats;
var set of ALL_TIMING_POINTS: mastery_points;
var {SENTINEL_POINT} union ALL_TIMING_POINTS: multifaceted_point;
var ALL_TIMING_POINTS: shrine_point;

predicate is_body(StatSpread: requirements) = forall(i in ALL_STATS) (requirements[i] > 0 <-> i in BODY_STATS) /\ all_equal(i in BODY_STATS) (requirements[i]);
predicate is_mind(StatSpread: requirements) = forall(i in ALL_STATS) (requirements[i] > 0 <-> i in MIND_STATS) /\ all_equal(i in MIND_STATS) (requirements[i]);
predicate is_weapon(StatSpread: requirements) = forall(i in ALL_STATS) (requirements[i] > 0 <-> i in WEAPON_STATS) /\ all_equal(i in WEAPON_STATS) (requirements[i]);
predicate is_element(StatSpread: requirements) = forall(i in ALL_STATS) (requirements[i] > 0 <-> i in UNLIMITED_SHRINE_STATS) /\ all_equal(i in UNLIMITED_SHRINE_STATS) (requirements[i]);
predicate is_category(StatSpread: requirements) = is_body(requirements) \/ is_mind(requirements) \/ is_weapon(requirements) \/ is_element(requirements);

function set of ALL_STATS: non_zero_indices(StatSpread: spread) = {i | i in ALL_STATS where spread[i] > 0};

function var 0..: mastery_diff(var StatSpread: before, var StatSpread: after) = sum(i in ALL_STATS) (max(0, before[i] - after[i]));

predicate satisfy_and(var StatSpread: stats, StatSpread: requirements) = forall(i in ALL_STATS) (stats[i] >= requirements[i]);
predicate satisfy_or(var StatSpread: stats, StatSpread: requirements) = exists(i in non_zero_indices(requirements)) (stats[i] >= requirements[i]);
predicate satisfy_sum(var StatSpread: stats, StatSpread: requirements, 1..330: target) = sum(i in non_zero_indices(requirements)) (stats[i]) >= target;

var set of ALL_TIMING_POINTS union {SENTINEL_POINT}: all_points = mastery_points union {multifaceted_point, shrine_point};
var ALL_TIMING_POINTS union {SENTINEL_POINT}: mex;
constraint forall(i in ALL_TIMING_POINTS where i < mex) (i in all_points);

constraint all_different_except([if x in mastery_points then x else SENTINEL_POINT endif | x in ALL_TIMING_POINTS] ++ [multifaceted_point, shrine_point], {SENTINEL_POINT});
constraint card(mastery_points) <= mastery_steps;
constraint mex > max([i | i in all_points where i != SENTINEL_POINT]);

constraint forall(i in ALL_TIMING_POINTS) (
    if multifaceted_point = i
        then forall(k in ALL_STATS) (stats[multifaceted_point, k] >= stats[multifaceted_point-1, k] - innate_stats[k])
    elseif i >= mex
        then forall(k in ALL_STATS) (stats[i, k] = stats[i-1, k])
    else true endif
);
var 0..3: preshrine_mastery_points_used = sum(i in mastery_points where i < shrine_point) ( 
    let {
        var 1..3: difference = mastery_diff(stats[i-1, ..], stats[i, ..]);
    } in difference
);

var 0..3: postshrine_mastery_points_used = sum(i in mastery_points where i > shrine_point) (
    let {
        var 1..3: difference = mastery_diff(stats[i-1, ..], stats[i, ..]);
    } in difference
);

constraint (preshrine_mastery_points_used + postshrine_mastery_points_used) in 0..3;

predicate is_participating_stat(ALL_STATS: i) = stats[shrine_point-1, i] > if multifaceted_point < shrine_point then 0 else innate_stats[i] endif;

constraint let {
    var STAT_RANGE diff {0}: floor_stat;
    constraint 
        sum(i in ALL_STATS where is_participating_stat(i)) (
            if i in LIMITED_SHRINE_STATS 
                then min(stats[shrine_point-1, i] - floor_stat, 25)
                else stats[shrine_point-1, i] - floor_stat
            endif
        )
        in 0..(count(i in ALL_STATS) (is_participating_stat(i) /\ stats[shrine_point-1, i] <= 25 + floor_stat) - 1);
} in forall(i in ALL_STATS where is_participating_stat(i)) (stats[shrine_point, i] >= if i in LIMITED_SHRINE_STATS then max(floor_stat, stats[shrine_point-1, i] - 25) else floor_stat endif);

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
    var TimingPoint: final_satisfied = max([if satisfy_constraint(stats[i, ..], constraint_group) then i else 0 endif | i in range]);
} in forall(i in mastery_points, requirement in body where i > final_satisfied) (
    let {
        ConstraintKind: kind = requirement.kind;
        StatSpread: requirements = requirement.requirements;
    } in (kind = And \/ (kind = Or /\ (not is_category(requirements)))) -> 
        forall(s in non_zero_indices(requirements)) ((stats[i, s] = stats[i-1, s]) \/ (stats[i, s] >= requirements[s]))
);

constraint (fixed_aspect = FreeAspect /\ allow_multifaceted /\ aspect != NoAspect) -> (multifaceted_point != SENTINEL_POINT);
constraint (aspect = NoAspect \/ (not allow_multifaceted)) -> (multifaceted_point = SENTINEL_POINT);

constraint aspect != NoAspect -> forall(i in 0..multifaceted_point-1, j in ALL_STATS) (stats[i, j] >= innate_stats[j]);

constraint forall(i in {0} union ALL_TIMING_POINTS) (sum(stats[i, ..]) - max(0, count(j in UNLIMITED_SHRINE_STATS) (stats[i, j] > 0) - 1) in 0..330);
constraint exists(i in 0..shrine_point-1) (sum(stats[i, ..]) - max(0, count(j in UNLIMITED_SHRINE_STATS) (stats[i, j] > 0) - 1) >= if preshrine_blasphemy then 90 else 135 endif);
constraint (special_oath = Bladeharper) -> exists(i in shrine_point..mastery_steps+2) (
    (stats[i, 1] >= 25 \/ stats[i, 3] >= 25) /\ 
    (stats[i, 8] >= 75 \/ sum(stats[i, 7..9]) >= 90)
);
constraint forall(
    i in UNLIMITED_SHRINE_STATS, j in ALL_TIMING_POINTS, k in ATTUNEMENT_THRESHOLDS
    where j in mastery_points /\ j != shrine_point + 1
)
    ((stats[j-1, i] >= k) -> (stats[j, i] >= k));
constraint (shrine_point + 1 != SENTINEL_POINT /\ shrine_point + 1 in mastery_points) -> 
    forall(i in UNLIMITED_SHRINE_STATS, j in ATTUNEMENT_THRESHOLDS diff {1})
        ((stats[shrine_point, i] > j \/ stats[shrine_point-1, i] >= j) -> (stats[shrine_point + 1, i] >= j)) /\ 
    forall(i in UNLIMITED_SHRINE_STATS) ((stats[shrine_point, i] >= 1) -> (stats[shrine_point + 1, i] >= 1));
constraint forall(i in ALL_STATS, j in mastery_points where j < shrine_point) (
    (stats[j-1, i] - stats[j, i] > 0) ->  
    forall(k in j+1..shrine_point-1) (stats[k, i] <= stats[j-1, i])
);
constraint forall(i in ALL_STATS, j in mastery_points where j > shrine_point) ( 
    (stats[j-1, i] - stats[j, i] > 0) ->
    forall(k in ALL_TIMING_POINTS diff {multifaceted_point} where k > j) (stats[k, i] <= stats[j-1, i])
);
constraint multifaceted_point = SENTINEL_POINT \/ exists(i in ALL_STATS where innate_stats[i] > 0) (
    if multifaceted_point < shrine_point 
        then forall(j in ALL_TIMING_POINTS where j in multifaceted_point..shrine_point-1) (stats[j, i] <= stats[multifaceted_point-1, i])
    elseif multifaceted_point > shrine_point
        then forall(j in ALL_TIMING_POINTS where j >= multifaceted_point) (stats[j, i] <= stats[multifaceted_point-1, i])
    endif
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