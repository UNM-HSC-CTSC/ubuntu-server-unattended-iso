<#
.SYNOPSIS
    Download the latest ISO from the repository server

.DESCRIPTION
    Downloads ISOs from the HSC-CTSC repository server. Can list available ISOs
    or download specific versions.

.PARAMETER Role
    The role to download (e.g., github, tools, artifacts)

.PARAMETER Version
    Specific version to download (default: latest)

.PARAMETER OutputPath
    Where to save the ISO (default: current directory)

.PARAMETER ListOnly
    Just list available ISOs without downloading

.PARAMETER RepositoryServer
    Repository server URL (default: hsc-ctsc-repository.health.unm.edu)

.EXAMPLE
    .\Get-LatestISO.ps1 -Role github

.EXAMPLE
    .\Get-LatestISO.ps1 -ListOnly

.EXAMPLE
    .\Get-LatestISO.ps1 -Role tools -Version 1.2.3 -OutputPath C:\ISOs
#>

[CmdletBinding()]
param(
    [string]$Role = "",
    
    [string]$Version = "latest",
    
    [string]$OutputPath = $PWD,
    
    [switch]$ListOnly,
    
    [string]$RepositoryServer = "hsc-ctsc-repository.health.unm.edu"
)

$ErrorActionPreference = "Stop"

# Colors
$Green = @{ForegroundColor = 'Green'}
$Yellow = @{ForegroundColor = 'Yellow'}
$Red = @{ForegroundColor = 'Red'}
$Cyan = @{ForegroundColor = 'Cyan'}

function Write-Status {
    param([string]$Message)
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $Message" @Green
}

function Write-Info {
    param([string]$Message)
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $Message" @Cyan
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] WARNING: $Message" @Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] ERROR: $Message" @Red
}

function Format-FileSize {
    param([int64]$Size)
    
    if ($Size -gt 1GB) {
        return "{0:N2} GB" -f ($Size / 1GB)
    } elseif ($Size -gt 1MB) {
        return "{0:N2} MB" -f ($Size / 1MB)
    } elseif ($Size -gt 1KB) {
        return "{0:N2} KB" -f ($Size / 1KB)
    } else {
        return "$Size bytes"
    }
}

try {
    # Base URL for repository
    $BaseURL = "http://$RepositoryServer"
    
    if ($ListOnly) {
        Write-Status "Listing available ISOs from $RepositoryServer"
        
        # Get list of ISOs
        try {
            $Response = Invoke-RestMethod -Uri "$BaseURL/api/isos" -Method Get
            
            if ($Response.Count -eq 0) {
                Write-Warning "No ISOs found on repository server"
                exit 0
            }
            
            Write-Host "`n=== Available ISOs ===" @Green
            Write-Host "Role          Version         Size        Uploaded" @Yellow
            Write-Host "----          -------         ----        --------" @Yellow
            
            foreach ($ISO in $Response | Sort-Object role, version) {
                $Size = Format-FileSize $ISO.size
                $Uploaded = [DateTime]::Parse($ISO.uploaded).ToString("yyyy-MM-dd HH:mm")
                
                Write-Host ("{0,-13} {1,-15} {2,-11} {3}" -f $ISO.role, $ISO.version, $Size, $Uploaded)
            }
            
            Write-Host "`nTotal ISOs: $($Response.Count)" @Green
            
        } catch {
            throw "Failed to list ISOs: $_"
        }
        
    } else {
        # Download ISO
        if ([string]::IsNullOrEmpty($Role)) {
            throw "Role parameter is required for download. Use -ListOnly to see available ISOs."
        }
        
        Write-Status "Downloading $Role ISO (version: $Version) from $RepositoryServer"
        
        # Create output directory if needed
        if (-not (Test-Path $OutputPath)) {
            New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
        }
        
        # Determine filename
        $Filename = "$Role-$Version.iso"
        $LocalPath = Join-Path $OutputPath $Filename
        
        # Build download URL
        $DownloadURL = "$BaseURL/isos/$Role/$Filename"
        
        Write-Info "Download URL: $DownloadURL"
        Write-Info "Saving to: $LocalPath"
        
        # Check if file already exists
        if (Test-Path $LocalPath) {
            Write-Warning "File already exists: $LocalPath"
            $Overwrite = Read-Host "Overwrite? (Y/N)"
            if ($Overwrite -ne 'Y' -and $Overwrite -ne 'y') {
                Write-Status "Download cancelled"
                exit 0
            }
        }
        
        # Download with progress
        Write-Status "Starting download..."
        
        try {
            $ProgressPreference = 'Continue'
            
            # Use Invoke-WebRequest with progress
            $Response = Invoke-WebRequest -Uri $DownloadURL -OutFile $LocalPath -PassThru
            
            # Verify download
            if (Test-Path $LocalPath) {
                $FileInfo = Get-Item $LocalPath
                Write-Status "Download complete!"
                Write-Info "File: $LocalPath"
                Write-Info "Size: $(Format-FileSize $FileInfo.Length)"
                
                # Get metadata if available
                try {
                    $MetadataURL = "$DownloadURL.json"
                    $Metadata = Invoke-RestMethod -Uri $MetadataURL -Method Get
                    
                    if ($Metadata.checksum) {
                        Write-Info "Expected checksum: $($Metadata.checksum)"
                        Write-Status "Calculating checksum..."
                        
                        $Hash = Get-FileHash -Path $LocalPath -Algorithm SHA256
                        if ($Hash.Hash -eq $Metadata.checksum) {
                            Write-Status "Checksum verified successfully"
                        } else {
                            Write-Warning "Checksum mismatch!"
                            Write-Warning "Expected: $($Metadata.checksum)"
                            Write-Warning "Actual:   $($Hash.Hash)"
                        }
                    }
                } catch {
                    # Metadata not available, skip verification
                }
                
                # Offer to deploy
                Write-Host "`n=== Download Complete ===" @Green
                Write-Host "ISO downloaded successfully to:" @Green
                Write-Host $LocalPath @Yellow
                
                $Deploy = Read-Host "`nWould you like to deploy this ISO to a VM? (Y/N)"
                if ($Deploy -eq 'Y' -or $Deploy -eq 'y') {
                    $VMName = Read-Host "Enter VM name (e.g., hsc-ctsc-$Role-01)"
                    
                    $DeployScript = Join-Path $PSScriptRoot "Deploy-VM.ps1"
                    if (Test-Path $DeployScript) {
                        Write-Status "Deploying VM..."
                        & $DeployScript -Name $VMName -ISOPath $LocalPath
                    } else {
                        Write-Warning "Deploy-VM.ps1 not found"
                    }
                }
                
            } else {
                throw "Download failed - file not created"
            }
            
        } catch {
            # Clean up partial download
            if (Test-Path $LocalPath) {
                Remove-Item $LocalPath -Force
            }
            throw "Download failed: $_"
        }
    }
    
} catch {
    Write-Error $_.Exception.Message
    
    # Provide helpful error messages
    if ($_.Exception.Message -like "*404*") {
        Write-Error "ISO not found on repository server"
        Write-Info "Use -ListOnly to see available ISOs"
    } elseif ($_.Exception.Message -like "*Unable to connect*") {
        Write-Error "Cannot connect to repository server: $RepositoryServer"
        Write-Info "Check that the server is accessible and the URL is correct"
    }
    
    exit 1
}