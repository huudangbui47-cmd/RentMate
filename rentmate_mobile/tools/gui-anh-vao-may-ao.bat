@echo off
rem Keo tha anh (hoac ca thu muc anh) len file nay de chep vao may ao Android.
rem Anh nam trong Pictures/RentMate, hien ngay trong man chon anh cua app.
rem Meo: chuot phai file nay - Send to - Desktop (create shortcut) de keo tha tu Desktop.

set "ADB=%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe"
if not exist "%ADB%" set "ADB=adb"

if "%~1"=="" (
    echo Hay keo tha anh len file nay, dung mo truc tiep.
    pause
    exit /b
)

"%ADB%" get-state >nul 2>&1
if errorlevel 1 (
    echo Chua thay may ao. Hay mo may ao Android truoc roi thu lai.
    pause
    exit /b
)

"%ADB%" shell mkdir -p /sdcard/Pictures/RentMate

:loop
if "%~1"=="" goto done
echo Dang chep: %~nx1
"%ADB%" push "%~1" /sdcard/Pictures/RentMate/ >nul
shift
goto loop

:done
rem Bao may ao quet lai thu vien anh
"%ADB%" shell content call --method scan_volume --uri content://media --arg external_primary >nul
echo.
echo Xong! Vao app - Them anh - Chon tu thu vien.
timeout /t 3 >nul
