# Runs the game. Requires GODOT_BIN env var (see docs/LOCAL_SETUP.md).
$godot = $env:GODOT_BIN
if (-not $godot -or -not (Test-Path $godot)) {
    Write-Error "GODOT_BIN is not set or file not found. See docs/LOCAL_SETUP.md"
    exit 1
}
$root = Split-Path -Parent $PSScriptRoot
& $godot --path $root
