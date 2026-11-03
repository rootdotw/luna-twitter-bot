@echo off
title Luna Stream 4K IPTV - Twitter / X Auto-Promoter Bot
cd /d "%~dp0"
echo Starting Luna Stream X / Twitter Auto-Promoter Control Panel...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0bot_engine.ps1" -Port 8090
pause
