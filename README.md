[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/jacob3141)

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
4. Select a process **0.xx … @Snapmaker J1 Klipper (0.x nozzle)**, for example
   `0.12 Fine`. They are listed under *User presets*.
5. Optional: select the filament **Generic PETG on Snapmaker J1**, or **Generic Rapid PETG on Snapmaker J1**
   for fast-printing PETG.
6. Set your printer's address (Moonraker) at the Wi-Fi/connection icon next to the printer.
   The presets contain no host.

To update, import the newer `.orca_printer` the same way. The bundle has a fixed id, so
OrcaSlicer updates it and asks before it overwrites a preset. It does not create a second copy.

You can also import the single presets from [`profiles/`](profiles) with the same dialog.
Import the printer first.

> **Upgrading from v1.0.0:** the process presets were renamed from
> `Snapmaker J1 0.x BEST PETG Matte` to the OrcaSlicer naming scheme (see below). The old
> presets stay after the import. Delete them in OrcaSlicer if you no longer need them.
>
> **Upgrading from v1.4.2 or older:** the filament preset `IEMAI PETG Matte @Snapmaker J1 Klipper` is now
> `Generic PETG on Snapmaker J1`. The old preset stays after the import. Delete it in OrcaSlicer if you no
> longer need it.

## How the presets fit together

OrcaSlicer combines three kinds of presets for every print:

| Kind | Decides | In this repository |
|---|---|---|
| **Printer** | machine, nozzle size, firmware flavor, start/end G-code | one per nozzle size |
| **Filament** | temperatures, flow, cooling, retraction, max. volumetric speed | a tuned PETG and a rapid PETG variant; any other OrcaSlicer filament works too |
| **Process** | layer height, line widths, speeds, walls, infill, seam, support | 20: every layer height OrcaSlicer offers for the J1, per nozzle size |

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
| Emit machine limits to G-code | yes | no | Klipper's limits come from `printer.cfg`. OrcaSlicer still uses the values below for its time estimate and caps the print accelerations in the G-code at the extruding limit (and at X / Y). |
| Max. acceleration X / Y / extruding / travel | 10000 / 8000 / 10000 / 10000 | 8000 / 5000 / 4000 / 8000 | tuned on the printer |
| Max. acceleration retracting / E / Z | – | 3000 / 4000 / 40 | tuned on the printer |
| Max. speed X / Y | 350 / 300 | 200 / 200 | the speed of the noise mode the start G-code selects |
| Max. jerk X / Y / Z / E | 10 | 2 / 2 / 1 / 1 | tuned on the printer; X is sent as `M205 V` → Klipper `square_corner_velocity` |
| Nozzle type | – | brass | the nozzles these presets were tuned with |
| Thumbnails | 300×300 | 48×48 + 300×300 PNG | small preview for Mainsail/Fluidd/KlipperScreen file lists |
| Start G-code | Snapmaker original | rewritten (see below) | |

The end G-code is inherited **unchanged**. Its commands (`M104`, `T0`/`T1`, …) are handled
by the Snapmaker compatibility macros.

The toolchange G-code ([`src/change_filament_gcode.gcode`](src/change_filament_gcode.gcode))
is the Snapmaker original with two changes:

- The old nozzle moves to its parking position at print height (`_SNAPMAKER_PARK_CARRIAGE`)
  before the tool select. The move tears off the strand and seals the nozzle. The tool select
  macro would otherwise lift Z by 2 mm first and pull thin strings. It still lifts afterwards,
  in the parking position, so the new nozzle travels to the print 2 mm higher.
- Printing continues as soon as the new nozzle is 5 °C below its target, without waiting for
  the temperature to settle.

The process presets switch OrcaSlicer's ooze prevention off (`ooze_prevention = 0`). A parked
nozzle stays at its print temperature and is sealed by its parking position. **System process
presets keep ooze prevention on:** they cool the parked nozzle by 70 °C and add a waiting `M109`
to every tool selection, including the first one in all prints that use T1.

### What the start G-code does

[`src/start_gcode.gcode`](src/start_gcode.gcode):

- **Noise mode:** the start G-code selects the Snapmaker noise mode `NORMAL` (`M2000 S113 M1`): 200 mm/s with the quiet stealthChop drivers. `LOUD` (300 mm/s, spreadCycle) is faster but much louder; `SILENT` limits every move to 75 mm/s. Travels of the process presets (300 mm/s) therefore run at 200 mm/s. The mode stays set after the print.
- **No purge blobs and no cleaning preheat.** These only make the nozzle ooze.
- **Bed heating:** there is no LED animation. While the bed heats, it moves to Z10 and the nozzles in use preheat to 140 °C. The print continues as soon as the bed reaches its minimum temperature. It does not wait for the temperature to settle, and it does not wait for the 140 °C.
- **Nozzle sealing:** each nozzle moves to the start of its prime line and is lowered to Z0, which seals it. Then it heats to its target. Priming starts as soon as the minimum temperature is reached.
- **Prime line position:** prime lines run along Y in the X zones only one head can reach: T0 at X5, T1 at X319, symmetric around the bed centre X162. Each nozzle draws a fat line, steps over and draws a return line.
- **Cool down and tear off:** the nozzle stays at the end of the prime line. The heater is off and the part cooling fan runs at 100 % until the nozzle reaches 200 °C. A jerk in X to the parking position then tears off the strand and seals the nozzle. With both nozzles priming together, the jerk stops 2 mm short of the parking positions and `G28 X` finishes the way.
- **Print start:** after the tear-off the nozzle holds 180 °C, so OrcaSlicer can retract and unretract around its first travel. On the exact first point of the print, right before the first extrusion, it is lowered to Z0 and heats up there, sealed. The print starts as soon as the nozzle is 5 °C below its target temperature. It does not wait for the temperature to settle. **Exception:** with a prime tower, or with a system process preset and T1, OrcaSlicer needs the nozzle hot before its first travel. It then heats up sealed beside the prime line, waits for `M109`, and only touches down briefly on the start point.
- **Both nozzles used:** with both nozzles in use (and not an IDEX duplication/mirror plate), both nozzles prime **at the same time** in Klipper `dual_carriage` MIRROR mode.
- **Scaling with the nozzle:** prime line height, width and amount scale with the nozzle diameter. They are capped at Klipper's `max_extrude_cross_section` (the default `4 × 0.4²` from `printer.cfg`).
- **IDEX modes:** plate names containing `IDEXDupl`/`IDEXCopy`, `IDEXMirr` or `IDEXBack` switch the IDEX mode with `M605`, as in the original Snapmaker profiles.

The start G-code is based on [macdylan/3dp-configs](https://github.com/macdylan/3dp-configs).

### Process presets – `0.xx <quality> @Snapmaker J1 Klipper (0.x nozzle)`

**Naming.** The names follow OrcaSlicer's scheme `<layer height> <quality> @<printer>`,
like the system preset `0.12 Fine @Snapmaker J1 (0.4 nozzle)`:

- The quality word follows from layer height / nozzle diameter, the same for every nozzle:
  up to 0.2 *Extra Fine*, 0.3 *Fine*, 0.4 *Optimal*, 0.5 *Standard*, 0.65 *Draft*, above
  that *Extra Draft*.
- The `@…` suffix keeps the names unique across nozzle sizes and shows which printer a
  preset belongs to.
- The names contain no material, because a process preset holds nothing
  material-specific. Temperatures, flow, cooling and volumetric speed belong to the
  filament preset.

**`0.12 Fine` with the 0.4 nozzle is tuned by hand.** It inherits from
`0.16 Optimal @Snapmaker J1 (0.4 nozzle)` and changes the following:

| Setting | Value |
|---|---|
| Layer height | 0.12 mm |
| Line widths | outer wall 0.40, inner solid infill 0.45, top surface 0.38, support 0.40 |
| Speeds | inner wall / sparse / solid infill / gap fill 120 mm/s, outer wall 60 mm/s |
| Seam | aligned, back |
| Sparse infill | gyroid |
| Skirt / brim / prime tower | 4 skirt loops, no brim, no prime tower |
| Support | off (interface filament 1 if you switch it on) |
| Overhangs | extra perimeters on overhangs, slow down for curled perimeters |
| Arc fitting | off |
| Max. volumetric extrusion rate slope | 300 mm³/s² |
| Top shell thickness | 0.8 mm (7 layers at 0.12 mm – prevents pillowing on top surfaces) |
| Precise Z height | on |
| Resolution | 0.008 mm |

**All other presets are derived from it** by `build.ps1`. Each inherits from the system
preset with the same nozzle and layer height, and on top of that:

- All line widths and the top shell thickness scale with `d / 0.4`.
- Top and bottom layers follow from the shell thickness (at least 3 each).
- The first layer height stays as in the system preset, except 0.1 mm for all 0.2 nozzle
  presets.
- The values `0.12 Fine` gets from *0.16 Optimal* are set explicitly, because the system
  presets differ in them: 3 walls, elephant foot 0.15, bridge flow 1, bridge 50 mm/s, support
  threshold 25°, first layer 50 mm/s, first-layer infill 80 mm/s.
- Everything else is the same as in `0.12 Fine`: speeds, seam, infill, no support, no brim, no prime tower,
  overhang handling.

| Nozzle | Layer heights (quality) | Outer wall | Inner wall / solid | Top surface | First layer width | Top shell |
|---|---|---|---|---|---|---|
| 0.2 | 0.06 Fine, 0.10 Standard, 0.14 Extra Draft | 0.20 | 0.225 | 0.19 | 0.25 | 0.4 mm |
| 0.4 | 0.08 Extra Fine, **0.12 Fine**, 0.16 Optimal, 0.20 Standard, 0.24 Draft, 0.28 Extra Draft | 0.40 | 0.45 | 0.38 | 0.50 | 0.8 mm |
| 0.6 | 0.18 Fine, 0.24 Optimal, 0.30 Standard, 0.34 Draft, 0.38 Draft, 0.42 Extra Draft | 0.60 | 0.675 | 0.57 | 0.75 | 1.2 mm |
| 0.8 | 0.24 Fine, 0.32 Optimal, 0.36 Standard, 0.40 Standard, 0.48 Draft | 0.80 | 0.90 | 0.76 | 1.00 | 1.6 mm |

**Only `0.12 Fine` with the 0.4 nozzle has been print-tested.** The others are calculated
from it. Very low layers such as `0.08 Extra Fine` showed poor layer adhesion with matte PETG:
parts tore at retractions. Prefer 0.12 mm or higher for this material.

The speeds are the same for every size. With larger nozzles and layer heights, the filament's
maximum volumetric speed usually limits them first.

### Filament preset – `Generic PETG on Snapmaker J1`

A general PETG preset. It was tuned with IEMAI matte PETG, a **0.4 mm brass nozzle** and the
`0.12 Fine` process, and test prints also came out well with GEEETECH, Creality and Elegoo PETG.
It inherits from OrcaSlicer's `Elegoo PETG @System` (in the
OrcaFilamentLibrary, available on every installation) and changes:

| Setting | Value | Why |
|---|---|---|
| Nozzle temperature | 245 °C first layer, then 240 °C | good bed and layer adhesion |
| Part cooling fan | off on layer 1, 20 % on long layers, up to 40 % on short layers, target speed from layer 4 | cools small details and top surfaces without weakening layer adhesion |
| Overhang fan | 100 % from 25 % overhang | cools only where edges would curl up |
| Flow ratio | 1.00 | no over-extrusion on top surfaces |
| Max. volumetric speed | 8 mm³/s | conservative limit for matte PETG |
| Retraction | 0.8 mm at 25 mm/s, only from 3 mm travel | less pull on freshly printed lines |
| Z-hop | off | the nozzle does not lift the sticky PETG |
| Pressure advance | 0.062 | calibrated for the 0.4 nozzle |
| Shrinkage XY / Z | 99.5 % | compensates PETG shrinkage |
| Air filtration / exhaust fan | on, 10 % | |

Notes:

- **Other nozzle sizes:** temperatures, cooling and flow carry over. Pressure advance
  depends on the nozzle; recalibrate it for 0.2 / 0.6 / 0.8 (*Calibration → Pressure advance*).
- **Nozzle material:** these values are for **brass**. Hardened steel conducts heat worse;
  add about 5–10 °C. Matte filaments contain matting additives that wear brass over time.
  When stringing increases or the line width becomes uneven, check the nozzle.
- **Other PETGs:** for the best result, calibrate flow ratio and pressure advance for each
  spool brand.

### Filament preset – `Generic Rapid PETG on Snapmaker J1`

A copy of `Generic PETG on Snapmaker J1` for fast-printing ("rapid") PETG. It inherits from
the same `Elegoo PETG @System` and differs from `Generic PETG on Snapmaker J1` only in:

| Setting | Generic PETG | Generic Rapid PETG |
|---|---|---|
| Nozzle temperature | 245 °C first layer, then 240 °C | 240 °C first layer, then 235 °C |
| Max. volumetric speed | 8 mm³/s | 15 mm³/s |
| Flow ratio | 1.00 | 0.98 |
| Part cooling fan | 20 % to 40 % | 40 % to 80 %, 80 % for layers under 5 s |
| Min. print speed when slowing down for cooling | from the parent | 30 mm/s |
| Retraction | 0.8 mm at 25 mm/s | 1.4 mm at 45 mm/s |
| Wipe while retracting | off | on |

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
