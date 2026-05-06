@echo off
setlocal

set "PROJECT_ROOT=%~dp0"
set "VENV_PATH=%PROJECT_ROOT%.runtime_venv"
set "PYTHON_EXE=%VENV_PATH%\Scripts\python.exe"
set "PIP_EXE=%VENV_PATH%\Scripts\pip.exe"

if not exist "%PYTHON_EXE%" (
  py -3.13 -m venv "%VENV_PATH%"
)

"%PYTHON_EXE%" -m pip install --upgrade pip
"%PIP_EXE%" install -r "%PROJECT_ROOT%requirements.txt"
"%PYTHON_EXE%" "%PROJECT_ROOT%backendcode.py"
