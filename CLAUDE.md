# CLAUDE.md

Instructions for Claude Code when working in this repository.

## Project
- Dot Racing: a 2D racing game built with Godot 4.6 (GDScript, Forward Plus renderer).
- Scenes live in `scenes/`, scripts in `scripts/`, art in `assets/`.
- `game.gd` spawns racers; `racer.gd` (`class_name Racer`, a `RigidBody2D`) sets its sprite from `DotColor`.
- 2D gravity is disabled in `project.godot` (top-down game).

## Conventions
<!-- Add coding style and naming rules here -->

## Workflow
- Godot is not on PATH. Use the console build by full path:
  `"C:\Program Files\Godot\Godot_v4.6.2-stable_win64_console.exe"`
- After changing scenes or scripts, check for errors with a headless run (the race starts automatically with `--autostart`):
  `<godot> --headless --path . --quit-after 300 -- --autostart`
- To see the game, capture screenshots (opens a window briefly), then view the PNGs:
  `<godot> --path . -s res://tools/capture.gd -- --out=<scratchpad folder> --times=0,2,5,10`
- Add `--laps=1` after `--` to shorten the race (one lap takes about 20 s) when testing the finish and podium.
- Capture options: `--betting` stays on the betting screen; `--bet=RED:200` places a bet before the race.
- After changing betting or rating logic, run the session tests: `<godot> --headless --path . -s res://tools/test_session.gd` (prints PASS/FAIL).
- New scripts and autoloads aren't known to the open Godot editor (and so VS Code) until it rescans: Project → Reload Current Project.
<!-- Add instructions about commits, testing, running the game, etc. -->

## Notes
<!-- Anything else Claude should always keep in mind -->
