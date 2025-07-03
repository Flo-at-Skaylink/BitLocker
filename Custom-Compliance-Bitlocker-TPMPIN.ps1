<#	

.SYNOPSIS
    This script checks if BitLocker is enabled on the OS drive and if a TPM+PIN key protector is present.

.NOTES
	Author: Florian Aschbichler
	Date: 22.05.2025
	Version: 1.0
	Filename: Custom-Compliance-Bitlocker-TPMPIN.ps1

.DESCRIPTION
    This script checks if BitLocker is enabled on the OS drive and if a TPM+PIN key protector is present.
    It logs the results to a file and returns a JSON object indicating compliance status.
    The script is intended to be used as a custom compliance script in Microsoft Intune.

.PARAMETER
		None
		This script does not take any parameters.

#>

# Identify OS drive
$osDrive = $env:SystemDrive 
Write-Host "OS drive detected: $osDrive"

# Create log directory, file and function
$logFolderLocation = 'C:\ProgramData\Microsoft\IntuneManagementExtension\Logs'
if (!(Test-Path $logFolderLocation) -eq $true) {
    New-Item -Path $logFolderLocation -ItemType Dir -ErrorAction Ignore
}
$LogFile = "$logFolderLocation\Bitlocker-CustomCompliance-PIN-State.log"

# Function to write logs
# This function logs messages to a specified log file with a timestamp.
Function Write-Log {
	param (
		$Log
	)
	
	$TimeStamp = "[{0:MM/dd/yy} {0:HH:mm:ss}]" -f (Get-Date)
	Add-Content $LogFile  "$TimeStamp - $Log"
}

Write-Log -Log "Custom compliance script started"

try {
    # Get BitLocker info for OS drive
    $bitlocker = Get-BitLockerVolume -MountPoint $osDrive -ErrorAction Stop
    Write-Host "BitLocker ProtectionStatus: $($bitlocker.ProtectionStatus); VolumeStatus: $($bitlocker.VolumeStatus)"
    Write-Log -Log "BitLocker ProtectionStatus: $($bitlocker.ProtectionStatus); VolumeStatus: $($bitlocker.VolumeStatus)"

    # Check if BitLocker is fully enabled on the OS volume
    if ($bitlocker.ProtectionStatus -eq 'On' -and $bitlocker.VolumeStatus -eq 'FullyEncrypted') {
        Write-Host "BitLocker is enabled and volume is fully encrypted."
        Write-Log -Log "BitLocker is enabled and volume is fully encrypted."
        
        # Gather all KeyProtector types on this volume
        $protectorTypes = $bitlocker.KeyProtector | Select-Object -ExpandProperty KeyProtectorType
        Write-Host "KeyProtector types on OS drive: $($protectorTypes -join ', ')"
        Write-Log -Log "KeyProtector types on OS drive: $($protectorTypes -join ', ')"

        # Check for a TPM+PIN protector
        if ($protectorTypes -contains 'TpmPin') {
            Write-Host "TPM+PIN key protector is present."
            Write-Log -Log "TPM+PIN key protector is present."
            $isCompliant = "TpmPin"
        } else {
            Write-Host "TPM+PIN key protector not found."
            Write-Log -Log "TPM+PIN key protector not found."
            $isCompliant = "NoPin"
        }
    } else {
        Write-Host "BitLocker is not fully enabled/encrypted on the OS drive."
        Write-Log -Log "BitLocker is not fully enabled/encrypted on the OS drive."
        $isCompliant = "NoPin"
    }
}
catch {
    Write-Host "Error retrieving BitLocker status: $($_.Exception.Message)"
    Write-Log -Log "Error retrieving BitLocker status: $($_.Exception.Message)"
    $isCompliant = "NoPin"
}

# Construct result JSON using the official schema

$result = @{ CheckBitLockerPIN = $isCompliant }

Write-Host "Compliance result JSON: $($result | ConvertTo-Json -Compress)"
Write-Log -Log "Compliance result JSON: $($result | ConvertTo-Json -Compress)"

# Return JSON (must be a single-line JSON)
return $result | ConvertTo-Json -Compress

# End of script