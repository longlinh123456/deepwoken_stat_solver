from minizinc import Instance, Model, Solver
from attribute import *
import time


# change these variables
mastery_steps = 3  # the number of mastery steps to search
optimize = []  # add the stats you want to optimize here from left to right order


objective_value = []
result = None


def generate_warm_start():
    if result is None:
        return ""
    stats = [str(element) for row in result.solution.stats for element in row]
    mastery_delta = [
        str(element) for row in result.solution.mastery_delta for element in row
    ]
    mex = result.solution.mex
    mastery_points = [str(element) for element in result.solution.mastery_points]
    shrine_point = result.solution.shrine_point
    multifaceted_point = result.solution.multifaceted_point

    return f""" :: warm_start(
        array1d(stats) ++ array1d(mastery_delta) ++ mastery_points ++ [shrine_point, multifaceted_point, mex],
        [{", ".join(stats + mastery_delta + mastery_points)}, {shrine_point}, {multifaceted_point}, {mex}]
    )"""


class Minimize:
    def __init__(self, expr):
        self.expr = expr

    def solve_statement(self):
        return f"solve{generate_warm_start()} :: int_search([shrine_point, multifaceted_point] ++ mastery_points ++ array1d(stats), input_order, indomain_median) minimize {self.expr};"


class Maximize:
    def __init__(self, expr):
        self.expr = expr

    def solve_statement(self):
        return f"solve{generate_warm_start()} :: int_search([shrine_point, multifaceted_point] ++ mastery_points ++ array1d(stats), input_order, indomain_median) maximize {self.expr};"


optimize_pre = [Maximize(f"stats[5, {i}]") for i in optimize] + [
    Maximize("stats[5, 13]"),
    Minimize("bool2int(aspect != NoAspect)"),
    Minimize("bool2int(multifaceted_point != SENTINEL_POINT)"),
    Minimize("count(i in MASTERY_INDEX_SET) (mastery_points[i] != SENTINEL_POINT)"),
]

optimize_post = [
    Minimize("count(i in MASTERY_INDEX_SET) (mastery_points[i] < shrine_point)"),
    Minimize(
        "count(i in MASTERY_INDEX_SET) (mastery_points[i] != SENTINEL_POINT /\\ mastery_points[i] >= shrine_point)"
    ),
    Minimize("preshrine_mastery_points_used"),
    Minimize("postshrine_mastery_points_used"),
]


def perform_objective(objective):
    global result
    with instance.branch() as child:
        child.add_string(objective.solve_statement())
        result = child.solve(
            processes=16,
            optimisation_level=2,
            intermediate_solutions=False,
            free_search=True,
        )
        objective_value.append(result.objective)
    instance.add_string(f"constraint {objective.expr} = {result.objective};")
    print(f"finished optimizing objective {objective.expr} = {result.objective}")


start_time = time.time()
model = Model("model.mzn")
cp_sat = Solver.lookup("cp-sat")
instance = Instance(cp_sat, model)
instance.add_file("data.dzn")
instance.add_string(f"mastery_steps = {mastery_steps};")
for objective in optimize_pre:
    perform_objective(objective)

optimize_mid = [
    Minimize(f"sum(i in ALL_STATS) (stats[{i}, i])")
    for i in range(0, objective_value[2] + 2)
] + [
    Maximize(f"sum(i in ALL_STATS) (stats[{i}, i] ^ 2)")
    for i in range(0, objective_value[2] + 2)
]
for objective in optimize_mid:
    perform_objective(objective)
for objective in optimize_post:
    perform_objective(objective)

stats = result.solution.stats
mastery_points = result.solution.mastery_points
mex = result.solution.mex
multifaceted_point = result.solution.multifaceted_point
shrine_point = result.solution.shrine_point

for i in range(mex):
    if i in mastery_points:
        print("SoM step: ", end="")
    elif i == multifaceted_point:
        print("Multifaceted step: ", end="")
    elif i == shrine_point:
        print("SoO step: ", end="")
    else:
        print("Initial step: ", end="")
    print(stats[i])
print(f"Took {time.time() - start_time:.3f} seconds")
