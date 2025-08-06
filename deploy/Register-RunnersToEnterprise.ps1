<#
.SYNOPSIS
    Registers GitHub Actions runners with GitHub Enterprise Server
.DESCRIPTION
    This script automates the registration of runners on multiple VMs with GitHub Enterprise Server.
    It can handle repository, organization, or enterprise-level registrations.
.PARAMETER GitHubURL
    URL of your GitHub Enterprise Server instance
.PARAMETER Token
    Registration token from GitHub Enterprise
.PARAMETER VMNames
    Array of VM names to configure (defaults to all hsc-ctsc-github-runners-* VMs)
.PARAMETER Scope
    Registration scope: Repository, Organization, or Enterprise (default: Enterprise)
.PARAMETER Repository
    Repository path (required if Scope is Repository, format: org/repo)
.PARAMETER Organization
    Organization name (required if Scope is Organization)
.PARAMETER RunnerGroup
    Runner group to assign runners to (default: Default)
.PARAMETER Labels
    Additional labels to apply to runners
.PARAMETER SSHUser
    SSH username for connecting to VMs (default: sysadmin)
.PARAMETER SSHKeyPath
    Path to SSH private key (optional, will prompt for password if not provided)
.EXAMPLE
    .\Register-RunnersToEnterprise.ps1 -GitHubURL "https://github.company.com" -Token "ABCD1234"
.EXAMPLE
    .\Register-RunnersToEnterprise.ps1 -GitHubURL "https://github.company.com" -Token "ABCD1234" -Scope Organization -Organization "myorg"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$GitHubURL,
    
    [Parameter(Mandatory=$true)]
    [string]$Token,
    
    [Parameter()]
    [string[]]$VMNames,
    
    [Parameter()]
    [ValidateSet("Repository", "Organization", "Enterprise")]
    [string]$Scope = "Enterprise",
    
    [Parameter()]
    [string]$Repository,
    
    [Parameter()]
    [string]$Organization,
    
    [Parameter()]
    [string]$RunnerGroup = "Default",
    
    [Parameter()]
    [string[]]$Labels = @(),
    
    [Parameter()]
    [string]$SSHUser = "sysadmin",
    
    [Parameter()]
    [string]$SSHKeyPath
)

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

# Function to test SSH connectivity
function Test-SSHConnection {
    param(
        [string]$IPAddress,
        [string]$User,
        [string]$KeyPath
    )
    
    $SSHCommand = "ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no"
    if ($KeyPath) {
        $SSHCommand += " -i `"$KeyPath`""
    }
    $SSHCommand += " $User@$IPAddress 'echo connected'"
    
    try {
        $Result = Invoke-Expression $SSHCommand 2>&1
        return $Result -match "connected"
    } catch {
        return $false
    }
}

# Function to execute remote command
function Invoke-SSHCommand {
    param(
        [string]$IPAddress,
        [string]$User,
        [string]$Command,
        [string]$KeyPath
    )
    
    $SSHCommand = "ssh -o StrictHostKeyChecking=no"
    if ($KeyPath) {
        $SSHCommand += " -i `"$KeyPath`""
    }
    $SSHCommand += " $User@$IPAddress `"$Command`""
    
    try {
        $Result = Invoke-Expression $SSHCommand 2>&1
        return @{
            Success = $LASTEXITCODE -eq 0
            Output = $Result
        }
    } catch {
        return @{
            Success = $false
            Output = $_.Exception.Message
        }
    }
}

# Main script
try {
    Write-Host @"
GitHub Enterprise Runner Registration Script
===========================================
This script will register runners with GitHub Enterprise Server
"@ -ForegroundColor Magenta

    # Validate parameters based on scope
    Write-StepHeader "Validating Parameters"
    
    $RegistrationURL = $GitHubURL
    switch ($Scope) {
        "Repository" {
            if (!$Repository) {
                throw "Repository parameter is required when Scope is Repository"
            }
            if ($Repository -notmatch "^[^/]+/[^/]+$") {
                throw "Repository must be in format: org/repo"
            }
            $RegistrationURL = "$GitHubURL/$Repository"
            Write-Success "Scope: Repository ($Repository)"
        }
        "Organization" {
            if (!$Organization) {
                throw "Organization parameter is required when Scope is Organization"
            }
            $RegistrationURL = "$GitHubURL/$Organization"
            Write-Success "Scope: Organization ($Organization)"
        }
        "Enterprise" {
            Write-Success "Scope: Enterprise"
        }
    }
    
    Write-Success "Registration URL: $RegistrationURL"
    
    # Find VMs if not specified
    if (!$VMNames) {
        Write-Info "No VMs specified, finding all GitHub runner VMs..."
        $VMNames = Get-VM | Where-Object { $_.Name -like "*github-runner*" } | Select-Object -ExpandProperty Name
        
        if (!$VMNames) {
            throw "No GitHub runner VMs found. Please specify VMs with -VMNames parameter."
        }
    }
    
    Write-Success "Found $($VMNames.Count) VM(s) to configure"
    
    # Test SSH connectivity if key provided
    if ($SSHKeyPath) {
        if (!(Test-Path $SSHKeyPath)) {
            throw "SSH key not found: $SSHKeyPath"
        }
        Write-Success "Using SSH key: $SSHKeyPath"
    } else {
        Write-Info "No SSH key provided. You may be prompted for passwords."
    }
    
    # Process each VM
    Write-StepHeader "Registering Runners"
    
    $SuccessCount = 0
    $FailureCount = 0
    $Results = @()
    
    foreach ($VMName in $VMNames) {
        Write-Info "`nProcessing VM: $VMName"
        
        # Get VM information
        $VM = Get-VM -Name $VMName -ErrorAction SilentlyContinue
        if (!$VM) {
            Write-ErrorMessage "VM not found: $VMName"
            $FailureCount++
            continue
        }
        
        if ($VM.State -ne 'Running') {
            Write-ErrorMessage "VM is not running: $VMName"
            $FailureCount++
            continue
        }
        
        # Get VM IP address
        $IPAddresses = $VM | Get-VMNetworkAdapter | Select-Object -ExpandProperty IPAddresses
        $IPAddress = $IPAddresses | Where-Object { $_ -match '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$' } | Select-Object -First 1
        
        if (!$IPAddress) {
            Write-ErrorMessage "Cannot get IP address for VM: $VMName"
            $FailureCount++
            continue
        }
        
        Write-Info "VM IP: $IPAddress"
        
        # Test connectivity
        Write-Info "Testing SSH connectivity..."
        if (!(Test-SSHConnection -IPAddress $IPAddress -User $SSHUser -KeyPath $SSHKeyPath)) {
            Write-ErrorMessage "Cannot connect to VM via SSH. Ensure VM setup is complete and SSH is enabled."
            $FailureCount++
            continue
        }
        
        Write-Success "SSH connection successful"
        
        # Create registration script
        $AdditionalLabels = $Labels -join ","
        if ($AdditionalLabels) {
            $AdditionalLabels = ",$AdditionalLabels"
        }
        
        $RegistrationScript = @"
#!/bin/bash
set -e

echo "Configuring GitHub Enterprise URL..."
sudo tee /etc/github-runner/enterprise.conf > /dev/null <<EOF
GITHUB_ENTERPRISE_URL=$GitHubURL
GITHUB_ENTERPRISE_API=$GitHubURL/api/v3
EOF

echo "Registering runners..."
for i in {1..4}; do
    echo "Registering runner \$i..."
    
    RUNNER_USER="runner"
    if [ \$i -gt 1 ]; then
        RUNNER_USER="runner\$i"
    fi
    
    RUNNER_HOME="/home/\$RUNNER_USER"
    
    # Skip if already configured
    if [ -f "\$RUNNER_HOME/actions-runner/.runner" ]; then
        echo "Runner \$i already configured, skipping..."
        continue
    fi
    
    # Configure runner
    cd "\$RUNNER_HOME/actions-runner"
    
    sudo -u "\$RUNNER_USER" ./config.sh \
        --unattended \
        --url "$RegistrationURL" \
        --token "$Token" \
        --name "$VMName-runner-\$i" \
        --work "\$RUNNER_HOME/work" \
        --labels "self-hosted,linux,x64,ubuntu-24.04,docker$AdditionalLabels" \
        --runnergroup "$RunnerGroup" \
        --ephemeral \
        --replace || {
            echo "Failed to configure runner \$i"
            continue
        }
    
    # Install and start service
    sudo ./svc.sh install "\$RUNNER_USER"
    sudo systemctl start github-runner@\$i
    sudo systemctl enable github-runner@\$i
    
    echo "Runner \$i registered and started"
done

echo "Checking runner status..."
sudo runner-status
"@
        
        # Execute registration script
        Write-Info "Registering runners on VM..."
        $Command = "echo '$RegistrationScript' | sudo bash"
        $Result = Invoke-SSHCommand -IPAddress $IPAddress -User $SSHUser -Command $Command -KeyPath $SSHKeyPath
        
        if ($Result.Success) {
            Write-Success "Successfully registered runners on $VMName"
            $SuccessCount++
            
            $Results += @{
                VM = $VMName
                IP = $IPAddress
                Status = "Success"
                Message = "Runners registered successfully"
            }
        } else {
            Write-ErrorMessage "Failed to register runners on $VMName"
            Write-ErrorMessage $Result.Output
            $FailureCount++
            
            $Results += @{
                VM = $VMName
                IP = $IPAddress
                Status = "Failed"
                Message = $Result.Output
            }
        }
    }
    
    # Display summary
    Write-StepHeader "Registration Summary"
    
    Write-Host @"
Results:
- Total VMs: $($VMNames.Count)
- Successful: $SuccessCount
- Failed: $FailureCount

"@ -ForegroundColor $(if ($FailureCount -eq 0) { "Green" } else { "Yellow" })
    
    # Detailed results
    Write-Host "Detailed Results:" -ForegroundColor Cyan
    foreach ($Result in $Results) {
        $Color = if ($Result.Status -eq "Success") { "Green" } else { "Red" }
        Write-Host "  $($Result.VM) ($($Result.IP)): $($Result.Status)" -ForegroundColor $Color
        if ($Result.Status -eq "Failed") {
            Write-Host "    Error: $($Result.Message)" -ForegroundColor Red
        }
    }
    
    # Next steps
    Write-StepHeader "Next Steps"
    
    Write-Host @"
1. Verify runners in GitHub Enterprise:
   $GitHubURL/settings/actions/runners

2. Check runner status on VMs:
   ssh $SSHUser@<VM_IP> 'sudo runner-status'

3. View runner logs:
   ssh $SSHUser@<VM_IP> 'sudo journalctl -u github-runner@1 -f'

4. Test with a workflow:
   Create a test workflow with: runs-on: self-hosted

"@ -ForegroundColor Cyan
    
    if ($FailureCount -gt 0) {
        Write-Host "`nNote: Some registrations failed. Check the errors above and try again." -ForegroundColor Yellow
        exit 1
    }
    
} catch {
    Write-ErrorMessage $_.Exception.Message
    Write-Host "`nRegistration failed. Please check the error message above." -ForegroundColor Red
    exit 1
}