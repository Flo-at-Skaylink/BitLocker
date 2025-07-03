<#

.SYNOPSIS
	Detects if a Bitlocker startup PIN is set on the device.

	Use this script in Proactive Remediation to detect wether a Bitlocker startup PIN has been set to the device or not.
	If the OS-disk is encrypted but no startup PIN was found, remediation is needed.
	If the OS-disk is encrypted and a startup PIN was found, no need to remediate.
	If Bitlocker is not enabled on the device, exit with code 0.

.NOTES
	Author: Florian Aschbichler
	Date: 22.05.2025
	Version: 1.0
	Filename: Detect-Bitlocker-Startup-PIN.ps1

.DESCRIPTION
	Use this script in Proactive Remediation to detect wether a Bitlocker startup PIN has been set to the device or not.

.PARAMETER
	None
	This script does not take any parameters.

#>

# Make sure the BitLocker Startup PIN Tool is not already running (overlapPINg schedule)
$bitLockerToolProcess = Get-Process -Name Bitlocker-Startup-PIN-Tool -ErrorAction SilentlyContinue
if (! $bitLockerToolProcess) {
	
	# Get Bitlocker status
	$BitLocker = Get-BitLockerVolume -MountPoint $env:SystemDrive
	if ($BitLocker.VolumeStatus -ne 'FullyDecrypted') {
		if ($BitLocker.KeyProtector.KeyProtectorType -notcontains 'TPMPIN') {
			Write-Host "OS-disk is encrypted but startup PIN was not found. Remediation is needed"
			Exit 1
		}
		
		else {
			Write-Host "OS-disk is encrypted and startup PIN was found. No need to remediate"
			Exit 0
		}
		
	}
	
	else {
		Exit 0 # Exit if Bitlocker is not enabled on the device
	}
}

else {
	Exit 0 # Exit if the tool process is already running
}