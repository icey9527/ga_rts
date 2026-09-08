@echo off
setlocal
set "LOVE_EXE=C:\Program Files\LOVE\love.exe"
set "OUT=%~dp0release"
if not exist "%LOVE_EXE%" (
  echo 找不到 LÖVE：%LOVE_EXE%
  exit /b 1
)
if exist "%OUT%" rmdir /s /q "%OUT%"
mkdir "%OUT%"
robocopy "%~dp0" "%OUT%\game" /e /xd .git release /xf verification-*.png verification.txt verification-error.txt mission-pacing.txt pacing-results.txt
if errorlevel 8 exit /b 1
echo 已生成发布目录：%OUT%\game
echo 如需单 exe，请使用对应 LÖVE 版本的 love.exe + 游戏 .love 合并流程。
endlocal
