<#
.SYNOPSIS
  Builds the OrcaSlicer presets of this repository.

.DESCRIPTION
  Sources (src/):
    bundle.json        bundle id/name/version/author (bump "version" on every release)
    printer.json       settings shared by all printer presets (on top of the Snapmaker system presets)
    start_gcode.gcode  machine start G-code (nozzle-parametric)
    process-0.4.json   the hand-tuned 0.4 process preset; the 0.2/0.6/0.8 presets are derived from it
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
# 0.4 is used as is; 0.2/0.6/0.8 are scaled by k = d / 0.4:
#   layer height and all line widths x k (effective 0.4 widths incl. the inherited ones),
#   top shell thickness x k, everything else (speeds, seam, infill, support...) unchanged.
# The 0.4 parent "0.16 Optimal" sets a few non-width values the other nozzle parents
# lack - they are copied so all sizes behave the same.
$proc04 = Read-Preset (Join-Path $src 'process-0.4.json')
$widths04 = [ordered]@{
    line_width = 0.42; inner_wall_line_width = 0.45; sparse_infill_line_width = 0.45; initial_layer_line_width = 0.5
    outer_wall_line_width = 0.4; internal_solid_infill_line_width = 0.45; top_surface_line_width = 0.38; support_line_width = 0.4
}
$fromParent04 = @{
    bottom_shell_layers = '4'; bridge_flow = '1'; elefant_foot_compensation = '0.15'; initial_layer_infill_speed = '80'
    support_threshold_angle = '25'; top_shell_layers = '5'; wall_loops = '3'
}
$procParent = @{
    '0.2' = '0.06 Standard @Snapmaker J1 (0.2 nozzle)'
    '0.6' = '0.18 Standard @Snapmaker J1 (0.6 nozzle)'
    '0.8' = '0.24 Standard @Snapmaker J1 (0.8 nozzle)'
}
$layer04 = [double]::Parse($proc04['layer_height'], $inv)

foreach ($d in $nozzles) {
    # Orca naming scheme: "<layer height> <quality> @<printer>" (like the system presets,
    # e.g. "0.12 Fine @Snapmaker J1 (0.4 nozzle)"); layer height = 0.3 * d -> "Fine"
    $k = [double]::Parse($d, $inv) / 0.4
    $name = "$(([math]::Round($layer04 * $k, 2)).ToString('0.00', $inv)) Fine @Snapmaker J1 Klipper ($d nozzle)"
    $p = $proc04.Clone()
    $p['name'] = $name
    $p['print_settings_id'] = $name
    if ($d -ne '0.4') {
        $p['inherits'] = $procParent[$d]
        $p['layer_height'] = Fmt ($layer04 * $k)
        foreach ($w in $widths04.Keys) { $p[$w] = Fmt ($widths04[$w] * $k) }
        foreach ($f in $fromParent04.Keys) { $p[$f] = $fromParent04[$f] }
        $p['top_shell_thickness'] = Fmt ([double]::Parse($proc04['top_shell_thickness'], $inv) * $k)
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
