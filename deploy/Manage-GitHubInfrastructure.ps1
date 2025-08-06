<#
.SYNOPSIS
    Manages the complete GitHub Enterprise infrastructure
.DESCRIPTION
    This script provides unified management for GitHub Enterprise Server and associated runner VMs.
    It can start, stop, check status, backup, and perform other maintenance operations.
.PARAMETER Action
    Action to perform: Status, Start, Stop, Restart, Backup, Health, Update
.PARAMETER Component
    Component to manage: All, Enterprise, Runners, or specific VM name
.PARAMETER Force
    Force the action without confirmation
.EXAMPLE
    .\Manage-GitHubInfrastructure.ps1 -Action Status
.EXAMPLE
    .\Manage-GitHubInfrastructure.ps1 -Action Start -Component All
.EXAMPLE
    .\Manage-GitHubInfrastructure.ps1 -Action Stop -Component Runners -Force
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("Status", "Start", "Stop", "Restart", "Backup", "Health", "Update", "Connect")]
    [string]$Action,
    
    [Parameter()]
    [string]$Component = "All",
    
    [Parameter()]
    [switch]$Force
)

# Configuration
$script:Config = @{
    EnterpriseVMName = "hsc-ctsc-github-enterprise"
    RunnerVMPattern = "*github-runner*"
    SSHUser = "sysadmin"
    BackupPath = "C:\Backups\GitHub"
}

# Helper functions
function Write-StepHeader {
    param([string]$Message)
    Write-Host "`n==== $Message ====" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Write-ErrorMessage {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Yellow
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

# Function to get all GitHub infrastructure VMs
function Get-GitHubVMs {
    $VMs = @()
    
    # Get Enterprise VM
    $EnterpriseVM = Get-VM -Name $script:Config.EnterpriseVMName -ErrorAction SilentlyContinue
    if ($EnterpriseVM) {
        $VMs += @{
            Name = $EnterpriseVM.Name
            Type = "Enterprise"
            VM = $EnterpriseVM
        }
    }
    
    # Get Runner VMs
    $RunnerVMs = Get-VM | Where-Object { $_.Name -like $script:Config.RunnerVMPattern }
    foreach ($RunnerVM in $RunnerVMs) {
        $VMs += @{
            Name = $RunnerVM.Name
            Type = "Runner"
            VM = $RunnerVM
        }
    }
    
    return $VMs
}

# Function to get VM details
function Get-VMDetails {
    param($VM)
    
    $Details = @{
        Name = $VM.Name
        State = $VM.State
        CPUUsage = $VM.CPUUsage
        MemoryAssigned = [math]::Round($VM.MemoryAssigned / 1GB, 2)
        MemoryDemand = [math]::Round($VM.MemoryDemand / 1GB, 2)
        Uptime = $VM.Uptime
        Status = $VM.Status
    }
    
    # Get IP addresses
    $IPs = $VM | Get-VMNetworkAdapter | Select-Object -ExpandProperty IPAddresses
    $Details.IPAddresses = $IPs | Where-Object { $_ -match '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$' }
    
    return $Details
}

# Action functions
function Show-Status {
    Write-StepHeader "GitHub Infrastructure Status"
    
    $VMs = Get-GitHubVMs
    
    if ($VMs.Count -eq 0) {
        Write-Warning "No GitHub infrastructure VMs found"
        return
    }
    
    # Summary
    $Running = ($VMs | Where-Object { $_.VM.State -eq 'Running' }).Count
    $Total = $VMs.Count
    
    Write-Host "Infrastructure Summary:" -ForegroundColor Green
    Write-Host "  Total VMs: $Total"
    Write-Host "  Running: $Running"
    Write-Host "  Stopped: $($Total - $Running)"
    Write-Host ""
    
    # Enterprise Server
    Write-Host "GitHub Enterprise Server:" -ForegroundColor Yellow
    $EnterpriseVM = $VMs | Where-Object { $_.Type -eq "Enterprise" } | Select-Object -First 1
    if ($EnterpriseVM) {
        $Details = Get-VMDetails -VM $EnterpriseVM.VM
        Write-Host "  Name: $($Details.Name)"
        Write-Host "  State: $($Details.State)" -ForegroundColor $(if ($Details.State -eq 'Running') { 'Green' } else { 'Red' })
        Write-Host "  CPU Usage: $($Details.CPUUsage)%"
        Write-Host "  Memory: $($Details.MemoryAssigned)GB assigned, $($Details.MemoryDemand)GB demand"
        if ($Details.IPAddresses) {
            Write-Host "  IP: $($Details.IPAddresses -join ', ')"
        }
        if ($Details.State -eq 'Running' -and $Details.Uptime) {
            Write-Host "  Uptime: $($Details.Uptime)"
        }
    } else {
        Write-Host "  Not found" -ForegroundColor Red
    }
    
    # Runner VMs
    Write-Host "`nGitHub Runners:" -ForegroundColor Yellow
    $RunnerVMs = $VMs | Where-Object { $_.Type -eq "Runner" }
    if ($RunnerVMs.Count -gt 0) {
        foreach ($RunnerVM in $RunnerVMs) {
            $Details = Get-VMDetails -VM $RunnerVM.VM
            Write-Host "  $($Details.Name):"
            Write-Host "    State: $($Details.State)" -ForegroundColor $(if ($Details.State -eq 'Running') { 'Green' } else { 'Red' })
            if ($Details.State -eq 'Running') {
                Write-Host "    CPU: $($Details.CPUUsage)% | Memory: $($Details.MemoryAssigned)GB"
                if ($Details.IPAddresses) {
                    Write-Host "    IP: $($Details.IPAddresses[0])"
                }
            }
        }
    } else {
        Write-Host "  No runner VMs found" -ForegroundColor Red
    }
}

function Start-Infrastructure {
    param([string]$Component)
    
    Write-StepHeader "Starting GitHub Infrastructure"
    
    $VMs = Get-GitHubVMs
    $VMsToStart = @()
    
    # Determine which VMs to start
    switch ($Component) {
        "All" {
            $VMsToStart = $VMs
        }
        "Enterprise" {
            $VMsToStart = $VMs | Where-Object { $_.Type -eq "Enterprise" }
        }
        "Runners" {
            $VMsToStart = $VMs | Where-Object { $_.Type -eq "Runner" }
        }
        default {
            $VMsToStart = $VMs | Where-Object { $_.Name -eq $Component }
        }
    }
    
    if ($VMsToStart.Count -eq 0) {
        Write-Warning "No VMs found matching component: $Component"
        return
    }
    
    # Start Enterprise first if starting all
    if ($Component -eq "All") {
        $Enterprise = $VMsToStart | Where-Object { $_.Type -eq "Enterprise" }
        $Runners = $VMsToStart | Where-Object { $_.Type -eq "Runner" }
        
        if ($Enterprise) {
            Write-Info "Starting GitHub Enterprise Server..."
            Start-VM -VM $Enterprise.VM -ErrorAction SilentlyContinue
            Write-Success "Started: $($Enterprise.Name)"
            
            # Wait for Enterprise to initialize
            Write-Info "Waiting 60 seconds for Enterprise Server to initialize..."
            Start-Sleep -Seconds 60
        }
        
        # Start runners
        foreach ($Runner in $Runners) {
            Write-Info "Starting $($Runner.Name)..."
            Start-VM -VM $Runner.VM -ErrorAction SilentlyContinue
            Write-Success "Started: $($Runner.Name)"
            
            # Stagger runner startup
            if ($Runner -ne $Runners[-1]) {
                Start-Sleep -Seconds 30
            }
        }
    } else {
        # Start specified VMs
        foreach ($VM in $VMsToStart) {
            Write-Info "Starting $($VM.Name)..."
            Start-VM -VM $VM.VM -ErrorAction SilentlyContinue
            Write-Success "Started: $($VM.Name)"
        }
    }
    
    Write-Success "Infrastructure start completed"
}

function Stop-Infrastructure {
    param([string]$Component)
    
    Write-StepHeader "Stopping GitHub Infrastructure"
    
    if (!$Force) {
        $Confirm = Read-Host "Are you sure you want to stop the infrastructure? (Y/N)"
        if ($Confirm -ne 'Y') {
            Write-Info "Operation cancelled"
            return
        }
    }
    
    $VMs = Get-GitHubVMs
    $VMsToStop = @()
    
    # Determine which VMs to stop
    switch ($Component) {
        "All" {
            $VMsToStop = $VMs
        }
        "Enterprise" {
            $VMsToStop = $VMs | Where-Object { $_.Type -eq "Enterprise" }
        }
        "Runners" {
            $VMsToStop = $VMs | Where-Object { $_.Type -eq "Runner" }
        }
        default {
            $VMsToStop = $VMs | Where-Object { $_.Name -eq $Component }
        }
    }
    
    if ($VMsToStop.Count -eq 0) {
        Write-Warning "No VMs found matching component: $Component"
        return
    }
    
    # Stop in reverse order (runners first, then enterprise)
    if ($Component -eq "All") {
        $Enterprise = $VMsToStop | Where-Object { $_.Type -eq "Enterprise" }
        $Runners = $VMsToStop | Where-Object { $_.Type -eq "Runner" }
        
        # Stop runners first
        foreach ($Runner in $Runners) {
            Write-Info "Stopping $($Runner.Name)..."
            Stop-VM -VM $Runner.VM -Force -ErrorAction SilentlyContinue
            Write-Success "Stopped: $($Runner.Name)"
        }
        
        # Stop Enterprise last
        if ($Enterprise) {
            Write-Info "Stopping GitHub Enterprise Server..."
            Stop-VM -VM $Enterprise.VM -ErrorAction SilentlyContinue
            Write-Success "Stopped: $($Enterprise.Name)"
        }
    } else {
        # Stop specified VMs
        foreach ($VM in $VMsToStop) {
            Write-Info "Stopping $($VM.Name)..."
            Stop-VM -VM $VM.VM -Force:$Force -ErrorAction SilentlyContinue
            Write-Success "Stopped: $($VM.Name)"
        }
    }
    
    Write-Success "Infrastructure stop completed"
}

function Restart-Infrastructure {
    param([string]$Component)
    
    Write-StepHeader "Restarting GitHub Infrastructure"
    
    Stop-Infrastructure -Component $Component
    Write-Info "Waiting 30 seconds before restart..."
    Start-Sleep -Seconds 30
    Start-Infrastructure -Component $Component
}

function Test-Health {
    Write-StepHeader "GitHub Infrastructure Health Check"
    
    $VMs = Get-GitHubVMs
    $HealthResults = @()
    
    # Check Enterprise Server
    Write-Info "Checking GitHub Enterprise Server..."
    $Enterprise = $VMs | Where-Object { $_.Type -eq "Enterprise" } | Select-Object -First 1
    
    if ($Enterprise -and $Enterprise.VM.State -eq 'Running') {
        $Details = Get-VMDetails -VM $Enterprise.VM
        if ($Details.IPAddresses) {
            $IP = $Details.IPAddresses[0]
            
            # Test HTTPS connectivity
            try {
                $Response = Invoke-WebRequest -Uri "https://$IP" -SkipCertificateCheck -TimeoutSec 10 -UseBasicParsing
                $HealthResults += @{
                    Component = "GitHub Enterprise Web"
                    Status = "Healthy"
                    Message = "HTTPS responding"
                }
            } catch {
                $HealthResults += @{
                    Component = "GitHub Enterprise Web"
                    Status = "Warning"
                    Message = "HTTPS not responding (may still be starting)"
                }
            }
        }
    } else {
        $HealthResults += @{
            Component = "GitHub Enterprise Server"
            Status = "Critical"
            Message = "VM not running"
        }
    }
    
    # Check Runner VMs
    Write-Info "Checking GitHub Runners..."
    $RunnerVMs = $VMs | Where-Object { $_.Type -eq "Runner" }
    
    foreach ($RunnerVM in $RunnerVMs) {
        if ($RunnerVM.VM.State -eq 'Running') {
            $Details = Get-VMDetails -VM $RunnerVM.VM
            
            # Basic health based on resource usage
            $Health = "Healthy"
            $Message = "Running normally"
            
            if ($Details.CPUUsage -gt 90) {
                $Health = "Warning"
                $Message = "High CPU usage: $($Details.CPUUsage)%"
            }
            
            if ($Details.MemoryDemand -gt $Details.MemoryAssigned * 0.9) {
                $Health = "Warning"
                $Message = "Memory pressure detected"
            }
            
            $HealthResults += @{
                Component = $RunnerVM.Name
                Status = $Health
                Message = $Message
            }
        } else {
            $HealthResults += @{
                Component = $RunnerVM.Name
                Status = "Critical"
                Message = "VM not running"
            }
        }
    }
    
    # Display results
    Write-Host "`nHealth Check Results:" -ForegroundColor Cyan
    
    $Critical = $HealthResults | Where-Object { $_.Status -eq "Critical" }
    $Warning = $HealthResults | Where-Object { $_.Status -eq "Warning" }
    $Healthy = $HealthResults | Where-Object { $_.Status -eq "Healthy" }
    
    foreach ($Result in $HealthResults) {
        $Color = switch ($Result.Status) {
            "Healthy" { "Green" }
            "Warning" { "Yellow" }
            "Critical" { "Red" }
        }
        
        Write-Host "  $($Result.Component): $($Result.Status)" -ForegroundColor $Color
        Write-Host "    $($Result.Message)" -ForegroundColor Gray
    }
    
    # Summary
    Write-Host "`nSummary:" -ForegroundColor Cyan
    Write-Host "  Healthy: $($Healthy.Count)" -ForegroundColor Green
    Write-Host "  Warning: $($Warning.Count)" -ForegroundColor Yellow
    Write-Host "  Critical: $($Critical.Count)" -ForegroundColor Red
}

function Connect-ToVM {
    param([string]$Component)
    
    if ($Component -eq "All") {
        Write-Warning "Please specify a specific VM to connect to"
        $VMs = Get-GitHubVMs
        Write-Host "`nAvailable VMs:" -ForegroundColor Cyan
        foreach ($VM in $VMs) {
            Write-Host "  - $($VM.Name)"
        }
        return
    }
    
    Write-Info "Connecting to $Component..."
    
    # Check if it's the Enterprise server (might need special handling)
    if ($Component -eq "Enterprise" -or $Component -eq $script:Config.EnterpriseVMName) {
        $VMName = $script:Config.EnterpriseVMName
    } else {
        $VMName = $Component
    }
    
    # Launch VM connection
    Start-Process "vmconnect.exe" -ArgumentList "localhost", $VMName
    Write-Success "VM connection window opened"
}

function Backup-Infrastructure {
    Write-StepHeader "Backing Up GitHub Infrastructure"
    
    # Create backup directory
    $BackupDate = Get-Date -Format "yyyyMMdd-HHmmss"
    $BackupDir = Join-Path $script:Config.BackupPath $BackupDate
    
    if (!(Test-Path $BackupDir)) {
        New-Item -Path $BackupDir -ItemType Directory -Force | Out-Null
    }
    
    Write-Info "Backup directory: $BackupDir"
    
    # Export VM configurations
    $VMs = Get-GitHubVMs
    
    foreach ($VM in $VMs) {
        Write-Info "Backing up $($VM.Name) configuration..."
        
        $VMBackupPath = Join-Path $BackupDir $VM.Name
        New-Item -Path $VMBackupPath -ItemType Directory -Force | Out-Null
        
        # Export VM configuration
        Export-VM -Name $VM.Name -Path $VMBackupPath
        Write-Success "Exported: $($VM.Name)"
        
        # Save additional metadata
        $Metadata = @{
            ExportDate = Get-Date
            VMName = $VM.Name
            Type = $VM.Type
            State = $VM.VM.State
            Details = Get-VMDetails -VM $VM.VM
        }
        
        $Metadata | ConvertTo-Json | Out-File "$VMBackupPath\metadata.json"
    }
    
    Write-Success "Backup completed: $BackupDir"
    
    # Cleanup old backups (keep last 7)
    Write-Info "Cleaning up old backups..."
    $OldBackups = Get-ChildItem $script:Config.BackupPath | 
        Sort-Object Name -Descending | 
        Select-Object -Skip 7
    
    foreach ($OldBackup in $OldBackups) {
        Remove-Item $OldBackup.FullName -Recurse -Force
        Write-Info "Removed old backup: $($OldBackup.Name)"
    }
}

# Main execution
try {
    Write-Host @"
GitHub Infrastructure Management
================================
"@ -ForegroundColor Magenta

    # Execute action
    switch ($Action) {
        "Status" {
            Show-Status
        }
        "Start" {
            Start-Infrastructure -Component $Component
        }
        "Stop" {
            Stop-Infrastructure -Component $Component
        }
        "Restart" {
            Restart-Infrastructure -Component $Component
        }
        "Health" {
            Test-Health
        }
        "Connect" {
            Connect-ToVM -Component $Component
        }
        "Backup" {
            Backup-Infrastructure
        }
        "Update" {
            Write-Warning "Update functionality not yet implemented"
            Write-Info "For manual updates:"
            Write-Info "  - GitHub Enterprise: Use Management Console"
            Write-Info "  - Runners: SSH to VMs and run 'sudo update-runners'"
        }
    }
    
    Write-Host "`nOperation completed successfully" -ForegroundColor Green
    
} catch {
    Write-ErrorMessage $_.Exception.Message
    Write-Host "`nOperation failed. Please check the error message above." -ForegroundColor Red
    exit 1
}