# Snapmaker J1 / J1s – Klipper presets for OrcaSlicer

OrcaSlicer printer and process presets for a Snapmaker J1/J1s IDEX printer running
**Klipper** (KlipperSnapmakerJ1 with its
Snapmaker compatibility macros `snapmaker-j1-macros.cfg`), for 0.2 / 0.4 / 0.6 / 0.8 mm nozzles.

## Install

Requirements: OrcaSlicer 2.4 or newer. The presets build on the **Snapmaker J1** system
presets that ship with OrcaSlicer. A preset whose parent system preset is missing is
skipped silently during import. If presets are missing after the import, add the
*Snapmaker J1* once in the printer setup wizard (vendor *Snapmaker*) and import again.

1. Download [`dist/Snapmaker-J1-Klipper.orca_printer`](dist/Snapmaker-J1-Klipper.orca_printer).
2. In OrcaSlicer, choose **File → Import → Import Configs…** and select the file.
3. Select the printer **Snapmaker J1 Klipper (0.x nozzle)** that matches your nozzle.
4. Select the process **Snapmaker J1 0.x BEST PETG Matte**.
5. Set your printer's address (Moonraker) at the Wi-Fi/connection icon next to the printer.
   The presets contain no host.

To update, import the newer `.orca_printer` the same way. The bundle has a fixed id, so
OrcaSlicer updates it and asks before it overwrites a preset. It does not create a second copy.

You can also import the single presets from [`profiles/`](profiles) with the same dialog.
Import the printer before its process.

## What the start G-code does

[`src/start_gcode.gcode`](src/start_gcode.gcode):

- **No purge blobs and no cleaning preheat.** These only make the nozzle ooze.
- **Bed heating:** the print continues as soon as the bed reaches its minimum temperature. It does not wait for the temperature to settle.
- **Nozzle sealing:** each nozzle moves **cold** to the start of its prime line and is lowered to Z0, which seals it. Then it heats. Priming starts as soon as the minimum temperature is reached.
- **Prime line position:** prime lines run along Y in the X zones only one head can reach: T0 at X5, T1 at X319, symmetric around the bed centre X162. Each nozzle draws a fat line, steps over and draws a return line. A fast 100 mm Y move then tears off the strand.
- **Both nozzles used:** with both nozzles in use (and not an IDEX duplication/mirror plate), both nozzles prime **at the same time** in Klipper `dual_carriage` MIRROR mode.
- **Scaling with the nozzle:** prime line height, width and amount scale with the nozzle diameter. They are capped at Klipper's `max_extrude_cross_section` (the default `4 × 0.4²` from `printer.cfg`).
- **IDEX modes:** plate names containing `IDEXDupl`/`IDEXCopy`, `IDEXMirr` or `IDEXBack` switch the IDEX mode with `M605`, as in the original Snapmaker profiles.

The start G-code is based on [macdylan/3dp-configs](https://github.com/macdylan/3dp-configs).

## Process presets

`Snapmaker J1 0.4 BEST PETG Matte` is tuned by hand:

- 0.12 mm layers, gyroid infill, seam aligned at the back
- 120 mm/s, outer wall 60 mm/s
- 4 skirt loops, no brim, supports on, precise Z height

The 0.2 / 0.6 / 0.8 versions are derived from it by `build.ps1`:

- layer height and all line widths scale with `d / 0.4`
- top shell thickness scales the same way
- all other settings stay the same

## Repository layout

| Path | Content |
|---|---|
| `src/bundle.json` | bundle id, name, **version**, author |
| `src/printer.json` | settings shared by all printer presets |
| `src/start_gcode.gcode` | machine start G-code |
| `src/process-0.4.json` | the 0.4 process preset (the source for all nozzle sizes) |
| `build.ps1` | generates `profiles/` and `dist/` |
| `profiles/` | generated single presets |
| `dist/` | generated `.orca_printer` bundle |

Edit only `src/`, then run:

```powershell
powershell -ExecutionPolicy Bypass -File .\build.ps1
```

The build is deterministic: unchanged sources give byte-identical output. Bump
`version` in `src/bundle.json` for every release.

### The bundle format

An `.orca_printer` file is a zip archive:

```
bundle_structure.json
printer/<preset name>.json
process/<preset name>.json
```

The preset files are ordinary OrcaSlicer user presets. They store only the differences from
their `inherits` system preset, plus `name`, `version` and `printer_settings_id` /
`print_settings_id`. OrcaSlicer detects the preset type from those last two keys.

OrcaSlicer 2.4 reads `id`, `name`, `version`, `author` and `description` from
`bundle_structure.json` and stores the bundle in `user/<user>/_local/<id>/`. OrcaSlicer's
own *File → Export → Export Preset Bundle* writes no `id`, so every import of such an export
creates a new bundle. The fixed `id` here prevents that. The legacy keys (`bundle_id`,
`bundle_type`, `printer_config`, `process_config`) match Orca's own export.

## License

[MIT](LICENSE). The start G-code is based on
[macdylan/3dp-configs](https://github.com/macdylan/3dp-configs).
