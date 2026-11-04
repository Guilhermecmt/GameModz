@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install.ps1" %*
if errorlevel 1 (
 echo.
 echo Nao foi possivel instalar. Confira a mensagem acima.
 pause
 exit /b 1
)
echo.
echo Instalacao concluida. Use o atalho na area de trabalho.
pause
