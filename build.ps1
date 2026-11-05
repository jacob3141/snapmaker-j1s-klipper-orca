<#
.SYNOPSIS
  Builds the OrcaSlicer presets of this repository.

.DESCRIPTION
  Sources (src/):
    bundle.json        bundle id/name/version/author (bump "version" on every release)
    printer.json       settings shared by all printer presets (on top of the Snapmaker system presets)
    start_gcode.gcode  machine start G-code (nozzle-parametric)
    process-0.4.json   the hand-tuned 0.12 mm / 0.4 nozzle process preset; all others are derived from it
    filament/*.json    filament presets, used as is

  Output:
    profiles/{printer,process,filament}/*.json         single presets (File > Import > Import Configs)
    dist/Snapmaker-J1-Klipper.orca_printer             bundle with all presets (same import dialog)

  The output is deterministic: running the script twice produces byte-identical files.
#>
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression

$root  = $PSScriptRoot
$src   = Join-Path $root 'src'
$utf8  = New-Object System.Text.UTF8Encoding($false)
$inv   = [Globalization.CultureInfo]::InvariantCulture
$nozzles = '0.2', '0.4', '0.6', '0.8'

# ---------------------------------------------------------------- JSON helpers
# Orca preset values are only strings or arrays of strings - a tiny writer keeps the
# output stable and formatted like Orca's own files (tabs, sorted keys).
function ConvertTo-JsonString([string]$s) {
    $sb = New-Object Text.StringBuilder '"'
    foreach ($c in $s.ToCharArray()) {
        switch ($c) {
            '"'  { [void]$sb.Append('\"') }
            '\'  { [void]$sb.Append('\\') }
            "`n" { [void]$sb.Append('\n') }
            "`r" { [void]$sb.Append('\r') }
            "`t" { [void]$sb.Append('\t') }
            default {
                if ([int]$c -lt 0x20) { [void]$sb.AppendFormat('\u{0:x4}', [int]$c) } else { [void]$sb.Append($c) }
            }
        }
    }
    [void]$sb.Append('"')
    $sb.ToString()
}

function ConvertTo-PresetJson($map) {
    [string[]]$keys = @($map.Keys)
    [Array]::Sort($keys, [StringComparer]::Ordinal)   # same order as Orca (std::map)
    $lines = foreach ($k in $keys) {
        $v = $map[$k]
        if ($v -is [array]) {
            $items = ($v | ForEach-Object { "`t`t" + (ConvertTo-JsonString $_) }) -join ",`n"
            "`t$(ConvertTo-JsonString $k): [`n$items`n`t]"
        } else {
            "`t$(ConvertTo-JsonString $k): $(ConvertTo-JsonString $v)"
        }
    }
    "{`n" + ($lines -join ",`n") + "`n}`n"
}

function Read-Preset([string]$path) {
    $obj = [IO.File]::ReadAllText($path, $utf8) | ConvertFrom-Json
    $map = @{}
    foreach ($p in $obj.PSObject.Properties) {
        if ($p.Value -is [array]) { $map[$p.Name] = @($p.Value | ForEach-Object { [string]$_ }) }
        else { $map[$p.Name] = [string]$p.Value }
    }
    $map
}

function Fmt([double]$x) { ([math]::Round($x, 3)).ToString($inv) }

# ---------------------------------------------------------------- printer presets
$gcode = [IO.File]::ReadAllText((Join-Path $src 'start_gcode.gcode'), $utf8).Replace("`r`n", "`n").TrimEnd("`n")
$printerBase = Read-Preset (Join-Path $src 'printer.json')

$presets = [ordered]@{}   # zip path -> json text

foreach ($d in $nozzles) {
    $name = "Snapmaker J1 Klipper ($d nozzle)"
    $p = $printerBase.Clone()
    $p['from'] = 'User'
    $p['inherits'] = "Snapmaker J1 ($d nozzle)"     # system preset shipped with OrcaSlicer
    $p['name'] = $name
    $p['printer_settings_id'] = $name
    $p['machine_start_gcode'] = $gcode
    $presets["printer/$name.json"] = ConvertTo-PresetJson $p
}

# ---------------------------------------------------------------- process presets
# src/process-0.4.json (0.12 mm, 0.4 nozzle) is the blueprint and is used as is.
# All other presets are derived from it, one for every layer height OrcaSlicer offers
# for the J1. They inherit from the system preset with the same nozzle and layer height.
#
#   k = d / 0.4
#   - line widths and top shell thickness x k
#   - top/bottom shell layers follow from the blueprint's shell thickness (at least 3)
#   - first layer height stays as in the system parent (it fits nozzle and layer height);
#     exception: 0.1 mm for all 0.2 nozzle presets
#   - the blueprint's settings (speeds, seam, infill, no support, no brim...) are unchanged
#   - $fromBlueprintParent: effective blueprint values that come from its parent
#     "0.16 Optimal" and differ between the system presets; set explicitly on all of them
$proc04 = Read-Preset (Join-Path $src 'process-0.4.json')
$widths04 = [ordered]@{
    line_width = 0.42; inner_wall_line_width = 0.45; sparse_infill_line_width = 0.45; initial_layer_line_width = 0.5
    outer_wall_line_width = 0.4; internal_solid_infill_line_width = 0.45; top_surface_line_width = 0.38; support_line_width = 0.4
}
$fromBlueprintParent = @{
    bridge_flow = '1'; bridge_speed = '50'; elefant_foot_compensation = '0.15'; initial_layer_infill_speed = '80'
    initial_layer_speed = '50'; ironing_flow = '10%'; support_threshold_angle = '25'; wall_loops = '3'
}
$topShell04    = [double]::Parse($proc04['top_shell_thickness'], $inv)   # 0.8 mm
$bottomShell04 = 4 * [double]::Parse($proc04['layer_height'], $inv)      # 4 layers x 0.12 mm

# nozzle, layer height, quality word of the system parent
$processes = @(
    @('0.2', '0.06', 'Standard'), @('0.2', '0.10', 'Standard'), @('0.2', '0.14', 'Standard'),
    @('0.4', '0.08', 'Extra Fine'), @('0.4', '0.12', ''), @('0.4', '0.16', 'Optimal'),
    @('0.4', '0.20', 'Standard'), @('0.4', '0.24', 'Draft'), @('0.4', '0.28', 'Extra Draft'),
    @('0.6', '0.18', 'Standard'), @('0.6', '0.24', 'Standard'), @('0.6', '0.30', 'Standard'),
    @('0.6', '0.34', 'Standard'), @('0.6', '0.38', 'Standard'), @('0.6', '0.42', 'Draft'),
    @('0.8', '0.24', 'Standard'), @('0.8', '0.32', 'Standard'), @('0.8', '0.36', 'Standard'),
    @('0.8', '0.40', 'Standard'), @('0.8', '0.48', 'Draft')
)

# Quality word from layer height / nozzle diameter, the same for every nozzle size
function Get-Quality([double]$ratio) {
    if ($ratio -le 0.2001) { 'Extra Fine' }
    elseif ($ratio -le 0.3001) { 'Fine' }
    elseif ($ratio -le 0.4001) { 'Optimal' }
    elseif ($ratio -le 0.5001) { 'Standard' }
    elseif ($ratio -le 0.6501) { 'Draft' }
    else { 'Extra Draft' }
}

foreach ($entry in $processes) {
    $d = $entry[0]; $hs = $entry[1]
    $dv = [double]::Parse($d, $inv); $h = [double]::Parse($hs, $inv); $k = $dv / 0.4
    # Orca naming scheme: "<layer height> <quality> @<printer>", like the system presets
    $name = "$hs $(Get-Quality ($h / $dv)) @Snapmaker J1 Klipper ($d nozzle)"
    $p = $proc04.Clone()
    $p['name'] = $name
    $p['print_settings_id'] = $name
    if ($entry[2]) {
        $p['inherits'] = "$hs $($entry[2]) @Snapmaker J1 ($d nozzle)"
        $p['layer_height'] = Fmt $h
        foreach ($w in $widths04.Keys) { $p[$w] = Fmt ($widths04[$w] * $k) }
        foreach ($f in $fromBlueprintParent.Keys) { $p[$f] = $fromBlueprintParent[$f] }
        $p['top_shell_thickness'] = Fmt ($topShell04 * $k)
        $p['top_shell_layers'] = [string][math]::Max(3, [math]::Ceiling($topShell04 * $k / $h - 1e-9))
        $p['bottom_shell_layers'] = [string][math]::Max(3, [math]::Ceiling($bottomShell04 * $k / $h - 1e-9))
        if ($d -eq '0.2') { $p['initial_layer_print_height'] = '0.1' }
    }
    $presets["process/$name.json"] = ConvertTo-PresetJson $p
}

# ---------------------------------------------------------------- filament presets
# src/filament/*.json are used as is (normalized formatting)
Get-ChildItem (Join-Path $src 'filament') -Filter *.json | Sort-Object Name | ForEach-Object {
    $p = Read-Preset $_.FullName
    $presets["filament/$($p['name']).json"] = ConvertTo-PresetJson $p
}

# ---------------------------------------------------------------- write single presets
$profiles = Join-Path $root 'profiles'
if (Test-Path $profiles) { Remove-Item $profiles -Recurse -Force }
foreach ($entry in $presets.Keys) {
    $path = Join-Path $profiles $entry
    New-Item -ItemType Directory -Force (Split-Path $path) | Out-Null
    [IO.File]::WriteAllText($path, $presets[$entry], $utf8)
}

# ---------------------------------------------------------------- bundle
# bundle_structure.json: OrcaSlicer >= 2.4 reads id/name/version/author/description and
# imports into its own local bundle folder (user/<id>/_local/<id>); a fixed id makes a
# re-import of a newer release update the same bundle instead of creating a second one.
# The legacy keys keep the layout of Orca's own "Printer config bundle" export.
$bundle = Read-Preset (Join-Path $src 'bundle.json')
$bundle['bundle_id']   = $bundle['id']
$bundle['bundle_type'] = 'printer config bundle'
$bundle['printer_preset_name'] = "Snapmaker J1 Klipper (0.4 nozzle)"
$bundle['printer_config']  = @($presets.Keys | Where-Object { $_ -like 'printer/*' })
$bundle['process_config']  = @($presets.Keys | Where-Object { $_ -like 'process/*' })
$bundle['filament_config'] = @($presets.Keys | Where-Object { $_ -like 'filament/*' })
$bundleJson = ConvertTo-PresetJson $bundle

$dist = Join-Path $root 'dist'
New-Item -ItemType Directory -Force $dist | Out-Null
$zipPath = Join-Path $dist 'Snapmaker-J1-Klipper.orca_printer'
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }

$stamp = New-Object DateTimeOffset 2026, 1, 1, 0, 0, 0, ([TimeSpan]::Zero)
$fs = [IO.File]::Open($zipPath, [IO.FileMode]::CreateNew)
try {
    $zip = New-Object IO.Compression.ZipArchive($fs, [IO.Compression.ZipArchiveMode]::Create)
    $entries = [ordered]@{ 'bundle_structure.json' = $bundleJson }
    foreach ($k in $presets.Keys) { $entries[$k] = $presets[$k] }
    foreach ($k in $entries.Keys) {
        $e = $zip.CreateEntry($k, [IO.Compression.CompressionLevel]::Optimal)
        $e.LastWriteTime = $stamp
        $w = New-Object IO.StreamWriter($e.Open(), $utf8)
        $w.Write($entries[$k]); $w.Dispose()
    }
    $zip.Dispose()
} finally { $fs.Dispose() }

"bundle  $zipPath ($($bundle['version']))"
$presets.Keys | ForEach-Object { "  $_" }
