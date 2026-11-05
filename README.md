# Snapmaker J1 / J1s – Klipper presets for OrcaSlicer

> **Based on the official Snapmaker J1 presets that ship with OrcaSlicer.** Those presets
> target the stock **Marlin** firmware (`gcode_flavor: marlin2`). This repository builds on
> them and optimizes them for **Klipper**.

OrcaSlicer printer and process presets for a Snapmaker J1/J1s IDEX printer running
**Klipper** (KlipperSnapmakerJ1 with its Snapmaker compatibility macros
`snapmaker-j1-macros.cfg`), for 0.2 / 0.4 / 0.6 / 0.8 mm nozzles.

## Install

Requirements: OrcaSlicer 2.4 or newer. The presets build on the **Snapmaker J1** system
presets that ship with OrcaSlicer. A preset whose parent system preset is missing is
skipped silently during import. If presets are missing after the import, add the
*Snapmaker J1* once in the printer setup wizard (vendor *Snapmaker*) and import again.

1. Download [`dist/Snapmaker-J1-Klipper.orca_printer`](dist/Snapmaker-J1-Klipper.orca_printer).
2. In OrcaSlicer, choose **File → Import → Import Configs…** and select the file.
3. Select the printer **Snapmaker J1 Klipper (0.x nozzle)** that matches your nozzle.
4. Select the process **0.xx Fine @Snapmaker J1 Klipper (0.x nozzle)**. It is listed
   under *User presets*.
5. Optional: select the filament **IEMAI PETG Matte @Snapmaker J1 Klipper**, or use it as a
   starting point for other matte PETGs.
6. Set your printer's address (Moonraker) at the Wi-Fi/connection icon next to the printer.
   The presets contain no host.

To update, import the newer `.orca_printer` the same way. The bundle has a fixed id, so
OrcaSlicer updates it and asks before it overwrites a preset. It does not create a second copy.

You can also import the single presets from [`profiles/`](profiles) with the same dialog.
Import the printer first.

> **Upgrading from v1.0.0:** the process presets were renamed from
> `Snapmaker J1 0.x BEST PETG Matte` to the OrcaSlicer naming scheme (see below). The old
> presets stay after the import. Delete them in OrcaSlicer if you no longer need them.

## How the presets fit together

OrcaSlicer combines three kinds of presets for every print:

| Kind | Decides | In this repository |
|---|---|---|
| **Printer** | machine, nozzle size, firmware flavor, start/end G-code | one per nozzle size |
| **Filament** | temperatures, flow, cooling, retraction, max. volumetric speed | one tuned matte PETG; any other OrcaSlicer filament works too |
| **Process** | layer height, line widths, speeds, walls, infill, seam, support | one per nozzle size |

A preset stores only its differences from the preset it `inherits`. All presets here
inherit from the Snapmaker J1 system presets. Everything they do not change comes from
there: bed shape, retraction, the toolchange and end G-code, and so on.

OrcaSlicer lists only the process presets that are compatible with the selected printer.
This repository's presets inherit their compatibility from their parents. With a
*0.4 nozzle* printer selected, you therefore see only the 0.4 process presets: the
system ones under *System presets* and these under *User presets*.

### Printer presets – `Snapmaker J1 Klipper (0.x nozzle)`

Each preset inherits from `Snapmaker J1 (0.x nozzle)` with the same nozzle size. It
differs from that preset only in these settings:

| Setting | Snapmaker J1 (Marlin) | Snapmaker J1 Klipper | Why |
|---|---|---|---|
| G-code flavor | `marlin2` | `klipper` | Klipper |
| Emit machine limits to G-code | yes | no | Klipper's limits come from `printer.cfg`. Here the values below are used only for OrcaSlicer's time estimate. |
| Max. acceleration X / Y / extruding / travel | 10000 / 8000 / 10000 / 10000 | 8000 / 5000 / 8000 / 8000 | closer to what the Klipper configuration allows |
| Max. speed X / Y | 350 / 300 | 200 / 200 | same reason |
| Max. jerk X / Y | 10 | 5 | sent as `M205 V` → Klipper `square_corner_velocity` |
| Thumbnails | 300×300 | 48×48 + 300×300 PNG | small preview for Mainsail/Fluidd/KlipperScreen file lists |
| Start G-code | Snapmaker original | rewritten (see below) | |

The end G-code and the toolchange G-code are inherited **unchanged**. Their commands
(`M104`, `M605`, `T0`/`T1`, …) are handled by the Snapmaker compatibility macros.

### What the start G-code does

[`src/start_gcode.gcode`](src/start_gcode.gcode):

- **No purge blobs and no cleaning preheat.** These only make the nozzle ooze.
- **Bed heating:** the print continues as soon as the bed reaches its minimum temperature. It does not wait for the temperature to settle.
- **Nozzle sealing:** each nozzle moves **cold** to the start of its prime line and is lowered to Z0, which seals it. Then it heats. Priming starts as soon as the minimum temperature is reached.
- **Prime line position:** prime lines run along Y in the X zones only one head can reach: T0 at X5, T1 at X319, symmetric around the bed centre X162. Each nozzle draws a fat line, steps over and draws a return line. A fast 100 mm Y move then tears off the strand.
- **Both nozzles used:** with both nozzles in use (and not an IDEX duplication/mirror plate), both nozzles prime **at the same time** in Klipper `dual_carriage` MIRROR mode.
- **Scaling with the nozzle:** prime line height, width and amount scale with the nozzle diameter. They are capped at Klipper's `max_extrude_cross_section` (the default `4 × 0.4²` from `printer.cfg`).
- **IDEX modes:** plate names containing `IDEXDupl`/`IDEXCopy`, `IDEXMirr` or `IDEXBack` switch the IDEX mode with `M605`, as in the original Snapmaker profiles.

The start G-code is based on [macdylan/3dp-configs](https://github.com/macdylan/3dp-configs).

### Process presets – `0.xx Fine @Snapmaker J1 Klipper (0.x nozzle)`

**Naming.** The names follow OrcaSlicer's scheme `<layer height> <quality> @<printer>`,
like the system preset `0.12 Fine @Snapmaker J1 (0.4 nozzle)`:

- *Fine* means a layer height of 0.3 × nozzle diameter.
- The `@…` suffix keeps the names unique across nozzle sizes and shows which printer a
  preset belongs to.
- The names contain no material, because a process preset holds nothing
  material-specific. Temperatures, flow, cooling and volumetric speed belong to the
  filament preset.

**The 0.4 preset is tuned by hand.** It inherits from `0.16 Optimal @Snapmaker J1 (0.4 nozzle)`
and changes the following:

| Setting | Value |
|---|---|
| Layer height | 0.12 mm |
| Line widths | outer wall 0.40, inner solid infill 0.45, top surface 0.38, support 0.40 |
| Speeds | inner wall / sparse / solid infill / gap fill 120 mm/s, outer wall 60 mm/s |
| Seam | aligned, back |
| Sparse infill | gyroid |
| Skirt / brim | 4 skirt loops, no brim |
| Support | on, interface with filament 1 |
| Top shell thickness | 0.8 mm (7 layers at 0.12 mm – prevents pillowing on top surfaces) |
| Precise Z height | on |
| Resolution | 0.008 mm |

**The 0.2 / 0.6 / 0.8 presets are derived from it** by `build.ps1`. Each inherits from the
system preset of its nozzle size, and on top of that:

- Layer height, all line widths and the top shell thickness scale with `d / 0.4`.
- The values the 0.4 preset gets from *0.16 Optimal* are copied, because the other system
  parents do not set them (they would fall back to Orca's generic defaults): 3 walls, 5 top / 4 bottom layers, elephant foot 0.15,
  bridge flow 1, support threshold 25°, first-layer infill 80 mm/s.
- Everything else is the same as in the 0.4 preset.

| Preset | Parent | Layer | Outer wall | Inner wall / solid | Top surface | First layer | Top shell |
|---|---|---|---|---|---|---|---|
| 0.06 Fine (0.2) | 0.06 Standard | 0.06 | 0.20 | 0.225 | 0.19 | 0.25 | 0.4 mm |
| 0.12 Fine (0.4) | 0.16 Optimal | 0.12 | 0.40 | 0.45 | 0.38 | 0.50 | 0.8 mm |
| 0.18 Fine (0.6) | 0.18 Standard | 0.18 | 0.60 | 0.675 | 0.57 | 0.75 | 1.2 mm |
| 0.24 Fine (0.8) | 0.24 Standard | 0.24 | 0.80 | 0.90 | 0.76 | 1.00 | 1.6 mm |

The speeds are the same for every size. With 0.6 and 0.8 nozzles, the filament's maximum
volumetric speed usually limits them first.

### Filament preset – `IEMAI PETG Matte @Snapmaker J1 Klipper`

Tuned for IEMAI matte PETG with a **0.4 mm brass nozzle**, together with the
`0.12 Fine` process. It inherits from OrcaSlicer's `Elegoo PETG @System` (in the
OrcaFilamentLibrary, available on every installation) and changes:

| Setting | Value | Why |
|---|---|---|
| Nozzle temperature | 245 °C first layer, then 230 °C | good adhesion; less stringing and oozing afterwards |
| Part cooling fan | off on layer 1, 20 % on normal layers, up to 60 % on short layers (small features), full from layer 4; overhangs 80 % | cools small details and top surfaces without weakening layer adhesion on larger parts |
| Flow ratio | 1.00 | no over-extrusion on top surfaces |
| Max. volumetric speed | 8 mm³/s | conservative limit for matte PETG |
| Retraction | 1.2 mm at 35 mm/s | less stringing between small features (Klipper allows up to 40 mm/s) |
| Pressure advance | 0.062 | calibrated for the 0.4 nozzle |
| Shrinkage XY / Z | 99.5 % | compensates PETG shrinkage |
| Air filtration / exhaust fan | on, 10 % | |

Notes:

- **Other nozzle sizes:** temperatures, cooling and flow carry over. Pressure advance
  depends on the nozzle; recalibrate it for 0.2 / 0.6 / 0.8 (*Calibration → Pressure advance*).
- **Nozzle material:** these values are for **brass**. Hardened steel conducts heat worse;
  add about 5–10 °C. Matte filaments contain matting additives that wear brass over time.
  When stringing increases or the line width becomes uneven, check the nozzle.
- **Other matte PETGs:** use the preset as a starting point, but calibrate flow ratio and
  pressure advance for each spool brand.

## Repository layout

| Path | Content |
|---|---|
| `src/bundle.json` | bundle id, name, **version**, author |
| `src/printer.json` | settings shared by all printer presets |
| `src/start_gcode.gcode` | machine start G-code |
| `src/process-0.4.json` | the 0.4 process preset (the source for all nozzle sizes) |
| `src/filament/` | filament presets, used as is |
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
filament/<preset name>.json
```

The preset files are ordinary OrcaSlicer user presets. They store only the differences from
their `inherits` system preset, plus `name`, `version` and `printer_settings_id` /
`print_settings_id` / `filament_settings_id`. OrcaSlicer detects the preset type from those
last keys.

OrcaSlicer 2.4 reads `id`, `name`, `version`, `author` and `description` from
`bundle_structure.json` and stores the bundle in `user/<user>/_local/<id>/`. OrcaSlicer's
own *File → Export → Export Preset Bundle* writes no `id`, so every import of such an export
creates a new bundle. The fixed `id` here prevents that. The legacy keys (`bundle_id`,
`bundle_type`, `printer_config`, `process_config`) match Orca's own export.

## License

[MIT](LICENSE). The start G-code is based on
[macdylan/3dp-configs](https://github.com/macdylan/3dp-configs).
