# Monorepo Test Runner
Write-Host "=== Testing packages/billing_engine ===" -ForegroundColor Cyan
Set-Location "$PSScriptRoot/../packages/billing_engine"
dart test
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "=== Testing packages/database ===" -ForegroundColor Cyan
Set-Location "$PSScriptRoot/../packages/database"
dart test
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "=== Testing packages/sync_protocol ===" -ForegroundColor Cyan
Set-Location "$PSScriptRoot/../packages/sync_protocol"
dart test
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "=== Testing apps/mobile ===" -ForegroundColor Cyan
Set-Location "$PSScriptRoot/../apps/mobile"
flutter test
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "=== Testing apps/desktop ===" -ForegroundColor Cyan
Set-Location "$PSScriptRoot/../apps/desktop"
flutter test
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Set-Location "$PSScriptRoot/.."
Write-Host "=== All monorepo tests passed! ===" -ForegroundColor Green
