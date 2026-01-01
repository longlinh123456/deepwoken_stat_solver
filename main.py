from minizinc import Instance, Model, Solver
from attribute import *
import time
import sys


# change these variables
mastery_steps = 3  # the number of mastery steps to search
optimize = []  # add the stats you want to optimize here from left to right order


objective_value = []
result = None
search_annotation = ":: set_search([mastery_points], anti_first_fail, indomain_split) :: int_search([shrine_point, multifaceted_point] ++ array1d(stats), anti_first_fail, indomain_split)"


def generate_warm_start():
    if result is None:
        return ""
    stats = [str(element) for row in result.solution.stats for element in row]
    mex = result.solution.mex
    mastery_points = [str(element) for element in result.solution.mastery_points]
    shrine_point = result.solution.shrine_point
    multifaceted_point = result.solution.multifaceted_point

    return f""" :: warm_start(
        array1d(stats) ++ [shrine_point, multifaceted_point, mex],
        [{", ".join(stats)}, {shrine_point}, {multifaceted_point}, {mex}]
    ) :: warm_start([mastery_points], [{{{", ".join(mastery_points)}}}])"""


def print_results():
    stats = result.solution.stats
    mastery_points = result.solution.mastery_points
    mex = result.solution.mex
    multifaceted_point = result.solution.multifaceted_point
    shrine_point = result.solution.shrine_point
    aspect = result.solution.aspect

    print(f"Aspect: {aspect}")
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


class Minimize:
    def __init__(self, expr):
        self.expr = expr

    def solve_statement(self):
        return f"solve{generate_warm_start()} {search_annotation} minimize {self.expr};"


class Maximize:
    def __init__(self, expr):
        self.expr = expr

    def solve_statement(self):
        return f"solve{generate_warm_start()} {search_annotation} maximize {self.expr};"


optimize_pre = [Maximize(f"stats[{mastery_steps+2}, {i}]") for i in optimize] + [
    Minimize("bool2int(aspect != NoAspect)"),
    Minimize("bool2int(multifaceted_point != SENTINEL_POINT)"),
    Minimize("card(mastery_points)"),
]

optimize_post = [
    Minimize("count(i in mastery_points) (i < shrine_point)"),
    Minimize("count(i in mastery_points) (i > shrine_point)"),
    Minimize("preshrine_mastery_points_used"),
    Minimize("postshrine_mastery_points_used"),
]


def perform_objective(objective):
    global result
    global last_finished
    with instance.branch() as child:
        child.add_string(objective.solve_statement())
        result = child.solve(
            processes=16,
            optimisation_level=2,
            intermediate_solutions=False,
            free_search=True,
            params="symmetry_level:4",
        )
        objective_value.append(result.objective)
    instance.add_string(f"constraint {objective.expr} = {result.objective};")
    if not result.status.has_solution():
        print("Constraints are unsatisfiable, exiting.")
        sys.exit(0)
    print(
        f"finished optimizing objective {objective.expr} = {result.objective} in {time.perf_counter() - last_finished:.2f} seconds"
    )
    last_finished = time.perf_counter()
    print_results()


last_finished = time.perf_counter()
start_time = time.perf_counter()
model = Model("model.mzn")
cp_sat = Solver.lookup("cp-sat")
instance = Instance(cp_sat, model)
instance.add_file("data.dzn")
instance.add_string(f"mastery_steps = {mastery_steps};")
for objective in optimize_pre:
    perform_objective(objective)

optimize_mid = [
    Minimize(f"sum(i in ALL_STATS) (stats[{i}, i])")
    for i in range(0, objective_value[-1] + 2)
] + [
    Maximize(f"sum(i in ALL_STATS) (stats[{i}, i] ^ 2)")
    for i in range(0, objective_value[-1] + 2)
]
for objective in optimize_mid:
    perform_objective(objective)
for objective in optimize_post:
    perform_objective(objective)

print(f"Took {time.perf_counter() - start_time:.3f} seconds")
