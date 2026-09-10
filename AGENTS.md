# Repository Guidelines

## Project Structure & Module Organization

`rogue-like-play/` is the Godot 4.6 project root; open its `project.godot` to run the game. Gameplay code is grouped by responsibility: `actors/` contains player and enemy behavior, `combat/` resolves attacks, `game/` coordinates the hub, run lifecycle, saves, and turns, while `world/` owns grids, dungeon generation, visibility, and layouts. Inventory and progression logic live in `items/` and `progression/`. Editable balance definitions are Godot Resources under `data/`. UI scenes and scripts are in `ui/`. Automated and visual checks are in `tests/`. Product specifications and acceptance notes live in the repository-level `docs/` directory.

## Build, Test, and Development Commands

Run commands from `rogue-like-play/` with Godot available as `godot`:

- `godot --editor --path .`: open the project for local development and F5 playtesting.
- `godot --headless --path . --editor --import --quit`: import assets and validate scripts/scenes.
- `godot --headless --path . --log-file .godot/combat-tests.log --script res://tests/test_combat.gd`: run one focused test suite.
- `godot --headless --path . --log-file .godot/playthrough-tests.log --script res://tests/test_playthrough.gd`: exercise the full 1F–10F loop.
- `godot --headless --path . --log-file .godot/smoke-test.log --quit-after 5`: perform a short startup check.

## Coding Style & Naming Conventions

Use UTF-8 GDScript with tabs for indentation. Follow `snake_case` for files, functions, signals, and variables; use `PascalCase` for named classes and Resource types; use `UPPER_SNAKE_CASE` for constants. Add explicit types where they clarify node, Resource, collection, or signal boundaries. Keep tunable stats in `.tres` files and preserve the existing separation between `TurnManager`, `Run`, combat rules, actors, and dungeon state.

## Testing Guidelines

Tests are standalone `SceneTree` scripts named `test_<area>.gd`. Update the focused suite for every behavior change, then run related regression suites. Use `capture_<area>.gd` only in a graphical environment for visual evidence. Write logs inside `.godot/`; this directory is ignored. There is no numeric coverage target, so cover rules, state transitions, failure paths, and turn-order regressions directly.

## Commit & Pull Request Guidelines

History uses concise Conventional Commit subjects, for example `feat: rebalance weapons and enemy encounters`. Keep commits scoped to one coherent change. Pull requests should explain the player-facing behavior, list validation commands, link relevant issues when available, and include screenshots for UI or rendering changes. Never commit `.godot/`, local save data, credentials, or generated test captures.
