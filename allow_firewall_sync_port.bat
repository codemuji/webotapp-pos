@echo off
:: ======================================================================
:: Grocery POS - Auto-Elevating Windows Firewall Setup for LAN Sync
:: ======================================================================

:: Test if running with Administrator privileges
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting Administrator privileges to allow Sync Port 8085 in Windows Firewall...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

:: Running with Administrator privileges
title Grocery POS - Configuring Firewall...
echo ======================================================================
echo    Grocery POS - Configuring Windows Defender Firewall
echo ======================================================================
echo.
echo 1. Allowing TCP Inbound Port 8085 across all network profiles...
netsh advfirewall firewall delete rule name="Grocery POS LAN Sync Server (Port 8085)" >nul 2>&1
netsh advfirewall firewall add rule name="Grocery POS LAN Sync Server (Port 8085)" dir=in action=allow protocol=TCP localport=8085 profile=any

echo 2. Allowing desktop.exe application inbound...
netsh advfirewall firewall delete rule name="Grocery POS Desktop Application" >nul 2>&1
netsh advfirewall firewall add rule name="Grocery POS Desktop Application" dir=in action=allow program="%~dp0desktop.exe" profile=any

echo.
echo ======================================================================
echo SUCCESS: Port 8085 and Desktop POS are now permanently allowed!
echo Both Wi-Fi Public and Private networks can now connect.
echo You can now scan the QR code on your mobile phone.
echo ======================================================================
echo.
pause
