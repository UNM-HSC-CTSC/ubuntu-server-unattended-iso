# Pipeline Status Check Guide

## Quick Links
- Pipelines: https://hsc-ctsc-git.health.unm.edu/noops/ubuntu-server-unattended-iso/-/pipelines
- Jobs: https://hsc-ctsc-git.health.unm.edu/noops/ubuntu-server-unattended-iso/-/jobs
- Artifacts: https://hsc-ctsc-git.health.unm.edu/noops/ubuntu-server-unattended-iso/-/artifacts

## What to Check

### 1. Pipeline Overview
Look for the latest pipeline on master branch:
- 🟢 Green = All jobs passed
- 🔴 Red = One or more jobs failed
- 🔵 Blue = Currently running
- ⚪ Gray = Skipped or manual

### 2. Expected Jobs
1. **test:validate** - Should run first
   - Runs test.sh
   - Validates environment
   - Expected duration: 1-2 minutes

2. **build:profiles** - Runs if tests pass
   - Downloads Ubuntu ISO
   - Builds ISOs for all profiles
   - Expected duration: 5-15 minutes
   - Creates artifacts

### 3. Common Issues and Solutions

#### If test:validate fails:
- **"No ISO manipulation tool found"**
  - Expected if no mount permissions
  - Should fall back to Python method

- **"Loop device support not available"**
  - Normal in Docker without privileged mode
  - Not critical if Python fallback works

#### If build:profiles fails:
- **"Failed to download ISO"**
  - Check network connectivity
  - Verify Ubuntu mirror is accessible

- **"Permission denied" on mount**
  - Docker needs privileged mode
  - Will use Python fallback

- **"No space left on device"**
  - ISO building needs ~5GB free space

### 4. Checking Job Logs
1. Click on the failed job
2. Look for lines starting with:
   - `[Error]` or `Error:`
   - `[FAILED]`
   - Stack traces

### 5. Downloading Artifacts
If build succeeds:
1. Go to the pipeline page
2. Click "Download artifacts" button
3. ISOs will be in `output/` directory

## Manual Pipeline Trigger
To run a single profile:
1. Go to CI/CD → Pipelines
2. Click "Run Pipeline"
3. Add variable: `PROFILE_NAME` = `example-minimal`
4. Click "Run Pipeline"