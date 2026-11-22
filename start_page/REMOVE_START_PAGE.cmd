@echo off
setlocal
set "TARGET=%~dp0"
if "%TARGET:~-1%"=="\" set "TARGET=%TARGET:~0,-1%"
set "START_PAGE_TARGET=%TARGET%"
start "" /b powershell -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -Command ^
  "$target = [IO.Path]::GetFullPath($env:START_PAGE_TARGET);" ^
  "if ([IO.Path]::GetFileName($target) -ne 'start_page') { throw 'Unexpected target path' };" ^
  "Start-Sleep -Milliseconds 900;" ^
  "Set-Location -LiteralPath ([IO.Path]::GetDirectoryName($target));" ^
  "if (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target -Recurse -Force };"
endlocal
