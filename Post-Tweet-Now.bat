@echo off
title Luna Stream 4K IPTV - Instant Tweet Poster (Official X API)
cd /d "%~dp0"
echo Posting a new promotional IPTV tweet to your X account right now...
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0bot_engine.ps1" -PostOnceAndExit
echo.
pause
