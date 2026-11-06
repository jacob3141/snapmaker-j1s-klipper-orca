;***** Update: 20240823
{if current_extruder != next_extruder}
; Change T[current_extruder] -> T[next_extruder] (layer [layer_num] [toolchange_count]/[total_toolchanges])
; layer [layer_num] at [layer_z]mm
M104 T[current_extruder] S{min(old_filament_temp, max(old_filament_temp - 70, 180))} ;cooldown, never below 180C
T[next_extruder]

 M107 P[current_extruder] ;fan off T[current_extruder]

{if layer_num == 1 &&
 ((filament_type[current_extruder] == "PLA" || filament_type[current_extruder] == "TPU")
  || (filament_type[next_extruder] == "PLA" || filament_type[next_extruder] == "TPU"))
}
; set bed temp: {filament_type[current_extruder]}({bed_temperature[current_extruder]}) -> {filament_type[next_extruder]}({bed_temperature[next_extruder]})
M140 S{min(bed_temperature[current_extruder], bed_temperature[next_extruder])}
{endif}

M2000 S200 V[travel_speed] A[travel_acceleration] ;quick switch extruders, S:200 mode/V:speed/A:acceleration
M104 T[next_extruder] S[new_filament_temp]
TEMPERATURE_WAIT SENSOR=extruder{if next_extruder == 1}1{endif} MINIMUM={new_filament_temp - 5} ;no settling: continue 5C below the target
{if layer_z > first_layer_height && layer_num >= close_fan_the_first_x_layers[next_extruder]}
  M106 P[next_extruder] S{fan_min_speed[next_extruder] * 255.0 / 100.0} ;restore fan speed for T[next_extruder]
{endif}
{elsif ooze_prevention && standby_temperature_delta != 0}
; first tool selection: OrcaSlicer's ooze prevention adds a waiting M109 right after this G-code.
; The part fan damps the overshoot, so the temperature settles sooner. before_layer_change_gcode
; switches it off again.
M106 S255
{endif}
