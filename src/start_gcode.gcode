; Model: Snapmaker J1 ({nozzle_diameter[0]}/{nozzle_diameter[1]}) - Klipper (KlipperSnapmakerJ1)
; Based on https://github.com/macdylan/3dp-configs (Update 20240922)
; Modified: no cleaning preheat, no purge blobs;
;           cold nozzles are lowered to Z0 at the start of their prime line (sealed),
;           then heated - priming starts as soon as the minimum temperature is reached;
;           prime lines along Y in the exclusive X zones (T0 X5 / T1 X319, symmetric around X162);
;           with both nozzles in use they prime together (dual_carriage MIRROR mode);
;           prime line height, width and amount scale with the nozzle diameter d
; Uses the Snapmaker compatibility macros of snapmaker-j1-macros.cfg
; (T0/T1, M605, M104/M140, M204, M205, M355)
; Printer : [printer_preset]
; Profile : [print_preset]
; Plate   : [plate_name]
; --- initial_extruder: [initial_extruder]
; --- has_wipe_tower: [has_wipe_tower]
; --- total_toolchanges: [total_toolchanges]
; --- T0: {is_extruder_used[0]}
; --- T1: {is_extruder_used[1]}

G90 ; absolute XYZ - Klipper keeps G91 from earlier commands (e.g. an aborted jog)
M83 ; relative E

T[initial_extruder]

M205 V[machine_max_jerk_x] ;square corner velocity (macro -> SET_VELOCITY_LIMIT)

{if plate_name =~/.*IDEXDupl.*/ || plate_name =~/.*IDEXCopy.*/ }
  M605 S2 X162 R0 ;IDEX Duplication
{elsif plate_name =~/.*IDEXMirr.*/}
  M605 S3 ;IDEX Mirror
{elsif plate_name =~/.*IDEXBack.*/}
  M605 S4 ;IDEX Backup
{endif}

; nozzles stay cold until they sit sealed on the bed
M104 T0 S0
M104 T1 S0
M140 S{first_layer_bed_temperature[initial_extruder]}
M204 S100
G28

; bed: continue as soon as the minimum is reached (no settling)
; (the M140 macro caps the bed at 100C)
TEMPERATURE_WAIT SENSOR=heater_bed MINIMUM={min(first_layer_bed_temperature[initial_extruder], 100) - 2}

{if 1==1}; LED (macro -> case_light)
  M355 S1 P64
  G4 P100
  M355 S1 P128
  G4 P100
  M355 S1 P64
  G4 P200
  M355 S1 P255
  G4 P100
{endif}
G28 X Y

{if 1==1 && max(hot_plate_temp_initial_layer[initial_extruder], hot_plate_temp[initial_extruder]) >= 90}
G0 Z0.06 F600
G92 Z0 ;reset z
{endif}

; ------------------------------------------------------------
; Prime lines run along Y inside the zones only one head can reach
; (safe_distance 24: T1 >= X11 while T0 is parked at X-13,
;  T0 <= X314 while T1 is parked at X338):
;   T0: X5, T1: X319
;   cold nozzle down to Z0 at X/Y95 (sealed), heat, wait for the minimum temperature,
;   Y95 -> Y83 ramp up to Z 0.75*d while refilling,
;   Y83 -> Y15 fat line (width 2*d), step 1.75*d toward the bed,
;   Y15 -> Y95 return line (width 1.25*d), then fast Y move to Y195
;   -> the strand tears off in the dead zone.
;   The retraction before the tear-off is undone afterwards: OrcaSlicer assumes an
;   unretracted nozzle and retracts/unretracts itself around its first travel.
; Klipper limits extrusion to 4 x 0.4^2 = 0.64 mm^2 cross section (nozzle_diameter
; of printer.cfg): all moves are capped at 0.60 / 0.55 mm^2 (matters for 0.8 nozzles).
;   d=0.4: ramp E3 (0.60 mm^2), fat E6.8 (0.24 mm^2), return E5.0 (0.15 mm^2)
; Both nozzles in use: they prime together, carriage 1 coupled in MIRROR mode the
; same way _SNAPMAKER_APPLY_MODE does (X5 / X319 -> mirror axis X162).
; Set "1==1" below to "1==0" to prime one after the other instead.
; ------------------------------------------------------------

{if 1==1 and is_extruder_used[0] and is_extruder_used[1] and not (plate_name =~/.*IDEX.*/)}
; ===== both nozzles together (mirror mode) =====
T0
G0 Z5 F600
G0 X5 Y95 F6840.0                            ; carriage 0 -> X5
SET_DUAL_CARRIAGE CARRIAGE=1
G0 X319 F6840.0                              ; carriage 1 -> X319
SET_DUAL_CARRIAGE CARRIAGE=0
SET_DUAL_CARRIAGE CARRIAGE=1 MODE=MIRROR
ACTIVATE_EXTRUDER EXTRUDER=extruder
SYNC_EXTRUDER_MOTION EXTRUDER=extruder1 MOTION_QUEUE=extruder
G0 Z0 F240.0                                 ; cold nozzles sealed on the bed
M104 T0 S{nozzle_temperature_initial_layer[0]}
M104 T1 S{nozzle_temperature_initial_layer[1]}
TEMPERATURE_WAIT SENSOR=extruder MINIMUM={nozzle_temperature_initial_layer[0] - 2}
TEMPERATURE_WAIT SENSOR=extruder1 MINIMUM={nozzle_temperature_initial_layer[1] - 2}
G1 Y83 Z{0.75*nozzle_diameter[0]} E{min(3, 18.75*nozzle_diameter[0]*nozzle_diameter[0])} F600   ; lift off while refilling the nozzles
G1 Y15 E{min(15.5, 42.41*nozzle_diameter[0]*nozzle_diameter[0])} F{(nozzle_diameter[0] > 0.5 ? 1200 : 1800)}   ; fat line
G1 X{5 + 1.75*nozzle_diameter[0]} F1800                                                     ; T1 mirrors to X319 - step
G1 Y95 E{min(18.3, 31.19*nozzle_diameter[0]*nozzle_diameter[0])} F{(nozzle_diameter[0] > 0.5 ? 2000 : 3000)}  ; return line
G1 E-{retraction_length[initial_extruder]} F1800
M204 S3000
G0 Y195 F12000           ; fast Y move tears off the strands
M204 S100
G0 Z2 F240.0
G1 E{retraction_length[initial_extruder]} F1800 ; undo the retraction: OrcaSlicer expects an unretracted nozzle
G92 E0
; back to full control (as _SNAPMAKER_RESET_MODE) and park both carriages
SYNC_EXTRUDER_MOTION EXTRUDER=extruder1 MOTION_QUEUE=extruder1
SET_DUAL_CARRIAGE CARRIAGE=0
G28 X
T[initial_extruder]
M104 T{1 - initial_extruder} S{temperature_vitrification[1 - initial_extruder]}

{else}
; ===== one nozzle after the other =====
; (the following T command parks the carriage that primed first;
;  the other nozzle stays cold at its parking position until its turn)

{if is_extruder_used[0] and initial_extruder != 0}
; prime nozzle 0 (not the initial one)
T0
G0 Z5 F600
G0 X5 Y95 F6840.0
G0 Z0 F240.0                                 ; cold nozzle sealed on the bed
M104 T0 S{nozzle_temperature_initial_layer[0]}
TEMPERATURE_WAIT SENSOR=extruder MINIMUM={nozzle_temperature_initial_layer[0] - 2}
G1 Y83 Z{0.75*nozzle_diameter[0]} E{min(3, 18.75*nozzle_diameter[0]*nozzle_diameter[0])} F600   ; lift off while refilling the nozzle
G1 Y15 E{min(15.5, 42.41*nozzle_diameter[0]*nozzle_diameter[0])} F{(nozzle_diameter[0] > 0.5 ? 1200 : 1800)}   ; fat line
G1 X{5 + 1.75*nozzle_diameter[0]} F1800
G1 Y95 E{min(18.3, 31.19*nozzle_diameter[0]*nozzle_diameter[0])} F{(nozzle_diameter[0] > 0.5 ? 2000 : 3000)}  ; return line
G1 E-{retract_length_toolchange[0]} F1800
M204 S3000
G0 Y195 F12000           ; fast Y move tears off the strand
M204 S100
G0 Z2 F240.0
G1 E{retract_length_toolchange[0]} F1800 ; undo the retraction: OrcaSlicer expects an unretracted nozzle
G92 E0
M104 T0 S{temperature_vitrification[0]}
{endif}

{if is_extruder_used[1] and initial_extruder != 1}
; prime nozzle 1 (not the initial one)
T1
G0 Z5 F600
G0 X319 Y95 F6840.0
G0 Z0 F240.0                                 ; cold nozzle sealed on the bed
M104 T1 S{nozzle_temperature_initial_layer[1]}
TEMPERATURE_WAIT SENSOR=extruder1 MINIMUM={nozzle_temperature_initial_layer[1] - 2}
G1 Y83 Z{0.75*nozzle_diameter[1]} E{min(3, 18.75*nozzle_diameter[1]*nozzle_diameter[1])} F600   ; lift off while refilling the nozzle
G1 Y15 E{min(15.5, 42.41*nozzle_diameter[1]*nozzle_diameter[1])} F{(nozzle_diameter[1] > 0.5 ? 1200 : 1800)}   ; fat line
G1 X{319 - 1.75*nozzle_diameter[1]} F1800
G1 Y95 E{min(18.3, 31.19*nozzle_diameter[1]*nozzle_diameter[1])} F{(nozzle_diameter[1] > 0.5 ? 2000 : 3000)}  ; return line
G1 E-{retract_length_toolchange[1]} F1800
M204 S3000
G0 Y195 F12000           ; fast Y move tears off the strand
M204 S100
G0 Z2 F240.0
G1 E{retract_length_toolchange[1]} F1800 ; undo the retraction: OrcaSlicer expects an unretracted nozzle
G92 E0
M104 T1 S{temperature_vitrification[1]}
{endif}

; prime initial nozzle
; (IDEX duplication/mirror plates: the M104 macro heats both nozzles, the right one follows)
T[initial_extruder]
G0 Z5 F600
G0 X{(initial_extruder == 0 ? 5 : 319)} Y95 F6840.0
G0 Z0 F240.0                                 ; cold nozzle sealed on the bed
M104 S{nozzle_temperature_initial_layer[initial_extruder]}
TEMPERATURE_WAIT SENSOR=extruder{if initial_extruder == 1}1{endif} MINIMUM={nozzle_temperature_initial_layer[initial_extruder] - 2}
{if plate_name =~/.*IDEXDupl.*/ || plate_name =~/.*IDEXCopy.*/ || plate_name =~/.*IDEXMirr.*/}
TEMPERATURE_WAIT SENSOR=extruder1 MINIMUM={nozzle_temperature_initial_layer[initial_extruder] - 2}
{endif}
G1 Y83 Z{0.75*nozzle_diameter[initial_extruder]} E{min(3, 18.75*nozzle_diameter[initial_extruder]*nozzle_diameter[initial_extruder])} F600   ; lift off while refilling the nozzle
G1 Y15 E{min(15.5, 42.41*nozzle_diameter[initial_extruder]*nozzle_diameter[initial_extruder])} F{(nozzle_diameter[initial_extruder] > 0.5 ? 1200 : 1800)}   ; fat line
G1 X{(initial_extruder == 0 ? 5 + 1.75*nozzle_diameter[initial_extruder] : 319 - 1.75*nozzle_diameter[initial_extruder])} F1800
G1 Y95 E{min(18.3, 31.19*nozzle_diameter[initial_extruder]*nozzle_diameter[initial_extruder])} F{(nozzle_diameter[initial_extruder] > 0.5 ? 2000 : 3000)}  ; return line
G1 E-{retraction_length[initial_extruder]} F1800
M204 S3000
G0 Y195 F12000           ; fast Y move tears off the strand
M204 S100
G0 Z2 F240.0
G1 E{retraction_length[initial_extruder]} F1800 ; undo the retraction: OrcaSlicer expects an unretracted nozzle
G92 E0
{endif}

; ready [plate_name]
