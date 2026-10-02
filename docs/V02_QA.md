# v0.2 QA harness

`tests/v02_regression.gd` is a domain suite. Direct fixture state setup is intentional and MUST NOT be presented as input playthrough evidence. It requires the v0.2 production core and fails loudly against schema 2.

`tests/input_walkthrough.gd` only drives gameplay through Input.parse_input_event. Scene construction and UI focus are harness setup; position, phase, world, battle, and rewards are read-only. Default route covers new game, classroom switch and corridor travel only. A complete ending claim requires an explicit route and completion assertion.

Run Godot 4.7.2 with `--headless --path <worktree> --log-file <unique writable log> --script res://tests/v02_regression.gd -- --qa-profile=<unique-id>`; substitute `input_walkthrough.gd` and append `--route=res://tests/routes/<route>.json` for input routes. IDs must identify the worktree and run. Do not point at live userdata.

Route is a JSON array. Supported steps: click(label: Button name or text), action(action: InputMap ID), move(x,y: world coordinates), interact(id: content object), wait(frames), until(path,value,timeout_frames), assert(path,value). Paths read GameSession properties, e.g. profile.completed. Buttons must be visible and enabled. Movement timeout, collision, missing button, assertion and report failure all exit nonzero. No emit_signal or production method invocation is used for gameplay.

Actual checks so far: 2026-10-03, Godot 4.7.2, input smoke 7/7 steps passed on the pre-v0.2 baseline. Domain draft syntax loaded and deliberately rejected schema 2/missing v0.2 core. Windows sandbox root certificate-store read errors occurred and are environment errors, not clean engine success. Cold editor import also reported exit resource leaks. No GUI, screenshot, ending or human-time validation was performed by this workstream yet.

Save fault tests distinguish simulated hooks from a real failure where a regular file occupies the intended parent directory. Neither covers disk-full or physical disk loss.

## Expanded coverage and discovered gaps (core 42ac40e)

Actual domain run on 2026-10-03: 396 assertions passed, covering two drag proof paths, accept/refuse route state machines, manual falling-gate timing, chase catch and local rewind, dodge duration, completion idempotency and restore. Fixtures are unit setup, not three-loop user input completion.

`tests/adversarial_contracts.gd` deliberately keeps strict failure assertions for production gaps. Observed on 42ac40e:

- Evidence metadata accepts array origin_actor, source_cycle inconsistent with source_event_id, and future evidence tick. Science result recomputation correctly rejects forged observations.
- Restore accepts model mode without a battle and world mode with one, plus fractional cycle numbers. Contradictory modes normalize silently instead of rejecting atomically.
- Historical switch payload `value: []` passes validation; invalid input should reject before restore.
- Finale prediction has no nested numeric/origin checks; a string time_s survives restore. Completed phase can disagree with profile.completed.
- Echo command context is accepted merely when nonempty and near a target. A fabricated c1:e999 source with wrong room can mutate power, without a matching sealed event.
- Caught phase snapshots normalize mode to world; reloading unpauses simulation while still caught (additional regression pending rerun when authored).

Future versions in backup, unknown/predicted cited IDs, invalid checkpoint dictionaries and modified observed measurements correctly reject. These cases are maintained alongside failing cases, not marked as skips or expected passes.
