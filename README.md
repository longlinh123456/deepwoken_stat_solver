A solver for Deepwoken stat building.

You will have to install [MiniZinc](https://www.minizinc.org/), Python (to run `main.py`), and the `minizinc` library (`pip install minizinc`).

Add constraints (talent, weapon, and oath requirements) to `data.dzn`, then change the variables in `main.py` before running it. The script will output the most optimal way to meet the provided constraints.