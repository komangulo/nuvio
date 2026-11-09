@echo off
REM ============================================================
REM   Configurador de Nuvio Desktop - doble clic para ejecutar
REM ============================================================
setlocal
cd /d "%~dp0"

echo.
echo  Iniciando configuracion de Nuvio...
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Instalar-NuvioConfig.ps1" %*
set RC=%ERRORLEVEL%

echo.
if %RC% NEQ 0 (
    echo  [ERROR] El script termino con codigo %RC%
) else (
    echo  [OK] Configuracion completada
)
echo.
pause
endlocal
