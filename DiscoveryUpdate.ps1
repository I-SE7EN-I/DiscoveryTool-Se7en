# Set the GitHub URLs for the script and the updater itself
$repoBaseUrl = "https://raw.githubusercontent.com/I-SE7EN-I/DiscoveryTool-Se7en/main"
$mainScriptName = "DiscoveryTool-Se7en.ps1"
$updaterScriptName = "DiscoveryUpdate.ps1"
$presetsScriptName = "IpPresets.psd1"

# Define file paths
$scriptPath = "$PSScriptRoot\$mainScriptName"
$updaterPath = "$PSScriptRoot\$updaterScriptName"
$presetsPath = "$PSScriptRoot\$presetsScriptName"
$oldUpdatesFolder = "$PSScriptRoot\Old Updates"

# Function to check internet connectivity
function Test-Internet {
    try {
        $response = Invoke-WebRequest -Uri "https://1.1.1.1" -UseBasicParsing -TimeoutSec 3
        return $true
    } catch {
        return $false
    }

}

# Exit if no internet
if (-not (Test-Internet)) {
    Write-Host "No internet connection detected. Skipping update check."
    Start-Sleep -Seconds 2
    & "$scriptPath"
    exit
}

# Define the raw URLs directly
$mainScriptUrl = "$repoBaseUrl/$mainScriptName"
$updaterScriptUrl = "$repoBaseUrl/$updaterScriptName"
$PresetDataUrl = "$repoBaseUrl/$presetsScriptName"

# Function to calculate file hash
function Get-FileHash {
    param ($filePath)
    if (Test-Path $filePath) {
        $fileContent = Get-Content -Path $filePath -Raw
        return [BitConverter]::ToString([System.Security.Cryptography.SHA256]::Create().ComputeHash([Text.Encoding]::UTF8.GetBytes($fileContent))).Replace("-", "")
    }
    return $null
}

# Get hashes of local scripts
$localMainHash = Get-FileHash -filePath $scriptPath
$localUpdaterHash = Get-FileHash -filePath $updaterPath

# Get hashes of remote scripts
try {
    $remoteMainContent = Invoke-RestMethod -Uri $mainScriptUrl
    $remoteUpdaterContent = Invoke-RestMethod -Uri $updaterScriptUrl
    $remoteMainHash = [BitConverter]::ToString([System.Security.Cryptography.SHA256]::Create().ComputeHash([Text.Encoding]::UTF8.GetBytes($remoteMainContent))).Replace("-", "")
    $remoteUpdaterHash = [BitConverter]::ToString([System.Security.Cryptography.SHA256]::Create().ComputeHash([Text.Encoding]::UTF8.GetBytes($remoteUpdaterContent))).Replace("-", "")
} catch {
    Write-Error "Failed to download remote script contents."
    Start-Sleep -Seconds 2
    & "$scriptPath"
    exit
}

# Function to back up and update a script
function Update-Script {
    param ($scriptPath, $scriptUrl, $scriptName)

    # Ensure backup folder exists
    if (-not (Test-Path $oldUpdatesFolder)) {
        New-Item -ItemType Directory -Path $oldUpdatesFolder
    }

    # Backup previous version if it exists
    if (Test-Path $scriptPath) {
        $timestamp = (Get-Date).ToString("yyyyMMdd-HHmmss")
        Copy-Item -Path $scriptPath -Destination "$oldUpdatesFolder\$scriptName-$timestamp.ps1"
    }

    # Limit backups to the last 5
    $oldFiles = Get-ChildItem -Path $oldUpdatesFolder -File | Sort-Object LastWriteTime
    if ($oldFiles.Count -gt 5) {
        $oldFiles | Select-Object -First ($oldFiles.Count - 5) | ForEach-Object { Remove-Item -Path $_.FullName -Force }
    }

    # Download the new version
    Invoke-RestMethod -Uri $scriptUrl -OutFile $scriptPath
}

# Check for updates to the updater script
$updatetrue = $false
if ($localUpdaterHash -ne $remoteUpdaterHash) {
	Write-Host "An update/repair for the Updater is available. Would you like to update? (Y/N)"
	$response = Read-Host
	
	if ($response -eq 'Y' -or $response -eq '') {
    Update-Script -scriptPath $updaterPath -scriptUrl $updaterScriptUrl -scriptName $updaterScriptName
    Write-Host "Update successful."
	#Rerun the update file because of update
	Clear-Host
	& "$updaterPath"
	} else {
		Write-Host "Update Skipped."
		$updatetrue = $false
	}
} else {
    Write-Host "You are using the latest Update Script version."
	Start-Sleep -Seconds 1
}

# Check for updates to the main script
if ($localMainHash -ne $remoteMainHash) {
    Write-Host "An update/repair for the Discovery Tool is available. Would you like to update? (Y/N)"
	$response = Read-Host
	
	if ($response -eq 'Y' -or $response -eq '') {
    Update-Script -scriptPath $scriptPath -scriptUrl $mainScriptUrl -scriptName $mainScriptName
    Write-Host "Update successful."
	} else {
		Write-Host "Update Skipped."
	}
} else {
    Write-Host "You are using the latest Main Script version."
	Start-Sleep -Seconds 1
}

if (-not (Test-Path $presetsPath)) {
    Write-Host "IpPresets.psd1 not found. Downloading..."
    Start-Sleep -Seconds 3
    Invoke-RestMethod -Uri $PresetDataUrl -OutFile $presetsPath
    Write-Host "Download complete."
}

# Run the updated main script
& "$scriptPath"
