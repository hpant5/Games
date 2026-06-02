import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
LEVELS = ROOT / "levels"


def car_cells(car):
    x = int(car["x"])
    y = int(car["y"])
    length = int(car["length"])
    orientation = car["orientation"]
    cells = []
    for i in range(length):
        cells.append((x + i, y) if orientation == "h" else (x, y + i))
    return cells


def validate_level(path):
    data = json.loads(path.read_text())
    width = int(data["width"])
    height = int(data["height"])
    exit_data = data["exit"]
    if exit_data["side"] != "right":
        raise AssertionError(f"{path.name}: only right-side exits are supported")

    exit_row = int(exit_data["row"])
    if not 0 <= exit_row < height:
        raise AssertionError(f"{path.name}: exit row is out of bounds")

    cars = data["cars"]
    targets = [car for car in cars if car.get("target", False)]
    if len(targets) != 1:
        raise AssertionError(f"{path.name}: expected exactly one target car")

    occupied = {}
    for car in cars:
        if car["orientation"] not in {"h", "v"}:
            raise AssertionError(f"{path.name}: car {car['id']} has bad orientation")
        for cell in car_cells(car):
            x, y = cell
            if not 0 <= x < width or not 0 <= y < height:
                raise AssertionError(f"{path.name}: car {car['id']} is out of bounds at {cell}")
            if cell in occupied:
                raise AssertionError(
                    f"{path.name}: car {car['id']} overlaps car {occupied[cell]} at {cell}"
                )
            occupied[cell] = car["id"]

    target = targets[0]
    if target["orientation"] != "h":
        raise AssertionError(f"{path.name}: target must start facing the right-side exit")
    if int(target["y"]) != exit_row:
        raise AssertionError(f"{path.name}: target must start on the exit row")

    target_cells = set(car_cells(target))
    nose_x = int(target["x"]) + int(target["length"])
    for x in range(nose_x, width):
        blocker = occupied.get((x, exit_row))
        if blocker is not None and (x, exit_row) not in target_cells:
            raise AssertionError(f"{path.name}: target escape lane blocked by {blocker}")

    return data["name"]


def main():
    level_paths = sorted(LEVELS.glob("level_*.json"), key=lambda p: int(p.stem.split("_")[1]))
    if not level_paths:
        raise AssertionError("No level files found")

    names = []
    for path in level_paths:
        names.append(validate_level(path))

    print(f"Validated {len(names)} levels:")
    for index, name in enumerate(names, start=1):
        print(f"  {index}. {name}")


if __name__ == "__main__":
    main()
