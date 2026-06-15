@echo off
echo ===================================================
echo   AutoFoto Legal Expres - Instalator i Budowniczy
echo ===================================================
echo.

:: 1. Install required Python packages
echo [1/3] Instalacja zaleznosci (PyQt6, MediaPipe, Pillow, PyInstaller)...
pip install -r requirements.txt
if %errorlevel% neq 0 (
    echo.
    echo Blad: Nie udalo sie zainstalowac pakietow pip. Upewnij sie, ze Python jest w PATH.
    pause
    exit /b %errorlevel%
)
echo Instalacja zakonczona pomyslnie.
echo.

:: 2. Compile using PyInstaller
echo [2/3] Kompilacja programu do pliku standalone .exe za pomoca PyInstaller...
echo Uwaga: To moze potrwac kilka minut...

if exist "logo.ico" (
    echo Wykryto plik logo.ico. Kompilowanie z ikona...
    pyinstaller --onefile --windowed --icon="logo.ico" --name="AutoFoto Legal Expres" --collect-data mediapipe main.py
) else (
    echo Brak pliku logo.ico. Kompilowanie z ikona domyslna...
    pyinstaller --onefile --windowed --name="AutoFoto Legal Expres" --collect-data mediapipe main.py
)
if %errorlevel% neq 0 (
    echo.
    echo Blad: Kompilacja przez PyInstaller zakonczona niepowodzeniem.
    pause
    exit /b %errorlevel%
)
echo Kompilacja zakonczona pomyslnie.
echo.

:: 3. Copy output to Desktop
echo [3/3] Kopiowanie pliku AutoFoto Legal Expres.exe na Pulpit...
if exist "dist\AutoFoto Legal Expres.exe" (
    copy "dist\AutoFoto Legal Expres.exe" "%USERPROFILE%\Desktop\AutoFoto Legal Expres.exe"
    echo.
    echo ===================================================
    echo   SUKCES! Program został zainstalowany na Pulpicie!
    echo   Mozesz teraz uruchomic "AutoFoto Legal Expres.exe"
    echo ===================================================
) else (
    echo Blad: Nie znaleziono skompilowanego pliku exe w folderze dist.
)

echo.
pause
