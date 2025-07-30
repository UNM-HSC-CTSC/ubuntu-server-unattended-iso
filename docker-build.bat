@echo off
REM Docker wrapper for Ubuntu ISO Builder - Windows Batch version
REM This script simplifies running the ISO builder in a Docker container on Windows

setlocal enabledelayedexpansion

REM Script directory
set "SCRIPT_DIR=%~dp0"
cd /d "%SCRIPT_DIR%"

REM Parse arguments
set "BUILD_IMAGE="
set "NO_CACHE="
set "GENERATE="
set "SHELL="
set "SHOW_HELP="
set "ISO_ARGS="

:parse_args
if "%~1"=="" goto :end_parse
if /i "%~1"=="--build" (
    set "BUILD_IMAGE=1"
    shift
    goto :parse_args
)
if /i "%~1"=="--no-cache" (
    set "NO_CACHE=--no-cache"
    shift
    goto :parse_args
)
if /i "%~1"=="--generate" (
    set "GENERATE=1"
    shift
    goto :parse_args
)
if /i "%~1"=="--shell" (
    set "SHELL=1"
    shift
    goto :parse_args
)
if /i "%~1"=="--help" (
    set "SHOW_HELP=1"
    shift
    goto :parse_args
)
if /i "%~1"=="-h" (
    set "SHOW_HELP=1"
    shift
    goto :parse_args
)
if "%~1"=="--" (
    shift
    :collect_iso_args
    if not "%~1"=="" (
        set "ISO_ARGS=!ISO_ARGS! %1"
        shift
        goto :collect_iso_args
    )
    goto :end_parse
)
set "ISO_ARGS=!ISO_ARGS! %1"
shift
goto :parse_args
:end_parse

REM Show help if requested
if defined SHOW_HELP (
    echo Docker wrapper for Ubuntu ISO Builder - Windows Batch
    echo.
    echo Usage: docker-build.bat [options] [-- ubuntu-iso-options]
    echo.
    echo Options:
    echo     --build         Build/rebuild the Docker image
    echo     --no-cache      Build Docker image without cache
    echo     --generate      Run the interactive generator
    echo     --shell         Start a shell in the container
    echo     --help          Show this help message
    echo.
    echo Examples:
    echo     # Build an ISO using the base configuration
    echo     docker-build.bat
    echo.
    echo     # Build with a custom autoinstall.yaml
    echo     docker-build.bat -- --autoinstall /input/my-config.yaml
    echo.
    echo     # Run the interactive generator
    echo     docker-build.bat --generate
    echo.
    echo     # Rebuild the Docker image and then build ISO
    echo     docker-build.bat --build -- --autoinstall /input/my-config.yaml
    echo.
    echo     # Start a shell for debugging
    echo     docker-build.bat --shell
    echo.
    echo Volume Mounts:
    echo     .\input   - Place your autoinstall.yaml files here
    echo     .\output  - Generated ISOs will be saved here
    echo     .\cache   - Downloaded Ubuntu ISOs are cached here
    echo.
    echo Note: Ensure Docker Desktop is running and Linux containers are selected.
    exit /b 0
)

REM Check if Docker is available
docker --version >nul 2>&1
if errorlevel 1 (
    echo Error: Docker is not installed or not in PATH.
    echo Please install Docker Desktop for Windows.
    exit /b 1
)

REM Check if Docker is running
docker info >nul 2>&1
if errorlevel 1 (
    echo Error: Docker is not running. Please start Docker Desktop.
    exit /b 1
)

REM Create directories if they don't exist
if not exist "input" mkdir input
if not exist "output" mkdir output
if not exist "cache" mkdir cache

REM Load .env file if it exists
if exist ".env" (
    for /f "usebackq tokens=1,2 delims==" %%a in (".env") do (
        if not "%%a"=="" if not "%%b"=="" (
            set "%%a=%%b"
        )
    )
)

REM Build Docker image if requested or if it doesn't exist
docker image inspect ubuntu-iso-builder:latest >nul 2>&1
if errorlevel 1 set "BUILD_IMAGE=1"

if defined BUILD_IMAGE (
    echo Building Docker image...
    docker-compose build %NO_CACHE% builder
    if errorlevel 1 (
        echo Error: Failed to build Docker image
        exit /b 1
    )
    echo Docker image built successfully
)

REM Run the appropriate command
if defined SHELL (
    echo Starting shell in container...
    docker-compose run --rm builder /bin/bash
) else if defined GENERATE (
    echo Starting interactive generator...
    docker-compose run --rm generator
) else (
    REM Default: run ubuntu-iso with provided arguments
    if "!ISO_ARGS!"=="" (
        echo Building ISO with base configuration...
        docker-compose run --rm builder ubuntu-iso --autoinstall /app/share/ubuntu-base/autoinstall.yaml
    ) else (
        echo Running ubuntu-iso with custom arguments...
        docker-compose run --rm builder ubuntu-iso !ISO_ARGS!
    )
)

REM Check if ISO was created
dir output\*.iso >nul 2>&1
if not errorlevel 1 (
    echo.
    echo ISO created successfully!
    echo.
    echo Output files:
    dir /b output\*.iso
)

endlocal