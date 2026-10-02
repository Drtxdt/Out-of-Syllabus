# v0.2 visual samples

These are source references, **not approved runtime sprites**. `.gdignore` prevents accidental import/export. Keep the existing editable `world/pixel_actor.gd` placeholder until a sprite passes pixel and animation review.

Generation used the built-in imagegen tool, not a paid CLI fallback. `student-generated.png` and `student-corrected.png` were visually inspected. Both fail `quality_audit.py --grid 32 --max-colors 12 --json`; exact diagnostics are beside each image. The correction still contains a wrong-facing frame and unsuitable raster dimensions. Do not silently rescale this into a production sprite sheet.

Locked palette: `111e28 172930 284247 426069 537879 92c6bb d8e2dd e1bc78 b48655 6f4a3a d88775 292b36`. Intended student frame 32×48 logical pixels, sheet 3 columns × 4 rows, down/left/right/up, idle/step A/step B. Binary alpha and a stable feet baseline are required. Native world grid is 32×32 at 640×360.

`world/lab_rig_visual.gd` is a separate, editable code-native apparatus sample at the canonical A=(144,144), B=(464,144), C=(304,152) positions. Add it at local origin under the lab visual root only. Call `render({powered,a_active,b_active,releasing})` with presentation values. It does not decide interaction range, holds, outcomes or timing. It uses integer rectangles and the locked palette; headless script parsing passed. Actual in-engine screenshot acceptance remains integration work.

## Generation prompts

Initial: game sprite production sample for Chinese science mystery RPG Out-of-Syllabus. Student investigator, dark short hair, navy school uniform, ochre notebook. 4 rows DOWN LEFT RIGHT UP, 3 columns idle/walking-left-step/walking-right-step. Each cell 32×48 logical pixels, nearest-neighbor 8×, total 768×1536. No spacing, centered consistent scale and feet baseline. Locked palette above, modern restrained pixel art, sharp square pixels, no antialiasing, gradients, text or watermark, transparent background.

Correction: preserve costume and arrangement; all three row-2 frames LEFT and row-3 frames RIGHT. Correct to exactly 96×192 logical pixels shown at 8×. Hard binary alpha, remove fuzzy edges and orphan pixels. Quantize only to the locked palette. Keep idle/left-foot/right-foot columns and large clean clusters.

Laboratory concept: compact school physics lab, orthographic top-down RPG view, logical canvas 640×360, 32×32 tile grid. Left pressure stabilizer, center falling-ball/paper cylinder, right safety interlock. Copper/teal conduit connects consoles, walkable navy floor below, upper shelves and amber desk lamp, chalkboard abstract diagrams without words. Locked palette, hard edges, no character or UI. This is an art direction reference, not a runtime tileset.
