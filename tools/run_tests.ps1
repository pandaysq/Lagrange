# Runs headless tests. Requires GODOT_BIN env var (see docs/LOCAL_SETUP.md).
$godot = $env:GODOT_BIN
if (-not $godot -or -not (Test-Path $godot)) {
    Write-Error "GODOT_BIN is not set or file not found. See docs/LOCAL_SETUP.md"
    exit 1
}
$root = Split-Path -Parent $PSScriptRoot
# Import first: builds the class cache so class_name scripts resolve on a fresh checkout.
& $godot --headless --path $root --import 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Error "Godot import step failed with exit code $LASTEXITCODE"
    exit $LASTEXITCODE
}
& $godot --headless --path $root -s res://tests/run_all.gd
exit $LASTEXITCODE
