<#	

.SYNOPSIS
	This script sets a Bitlocker startup PIN on the device.
	It downloads the Bitlocker Startup PIN Tool from a GitHub repository, extracts it, and executes it to set the startup PIN.
	The script logs its actions to a log file located in the Intune Management Extension logs directory.

.NOTES
	Author: Florian Aschbichler
	Date: 22.05.2025
	Version: 1.0
	Filename: Set-BitlockerStartupPIN.ps1

.DESCRIPTION
	This script sets a Bitlocker startup PIN on the device.
	It downloads the Bitlocker Startup PIN Tool from a GitHub repository, extracts it, and executes it to set the startup PIN.
	The script logs its actions to a log file located in the Intune Management Extension logs directory.

.PARAMETER
		None
		This script does not take any parameters.

#>

# Create log directory, file and function
$logFolderLocation = 'C:\ProgramData\Microsoft\IntuneManagementExtension\Logs'
if (!(Test-Path $logFolderLocation) -eq $true) { New-Item -Path $logFolderLocation -ItemType Dir -ErrorAction Ignore }
$LogFile = "$logFolderLocation\Bitlocker-Remediate-PIN.log"

# Function to write logs
# This function logs messages to a specified log file with a timestamp.
Function Write-Log {
	param (
		$Log
	)
	
	$TimeStamp = "[{0:MM/dd/yy} {0:HH:mm:ss}]" -f (Get-Date)
	Add-Content $LogFile  "$TimeStamp - $Log"
}

Write-Log -Log "Remediation script started"

Try {
	# Declare variables
	$DownloadURL = "https://github.com/Flo-at-Skaylink/Powershell/raw/refs/heads/main/Bitlocker-Startup-PIN-Tool.zip"
	$ZIP_File = "C:\Windows\temp\Bitlocker-Startup-PIN-Tool.zip" # ZIP-file download location
	$ExtractedFolder = 'C:\Windows\Temp\Bitlocker-Startup-PIN-Tool' # Location to the extraced ZIP-file
	
	# Download the .ZIP-file from storeage account
	Invoke-WebRequest -Uri $DownloadURL -OutFile $ZIP_File
	
	# Extract the .ZIP-file
	Expand-Archive -Path $ZIP_File -DestinationPath $ExtractedFolder -Force
	
	# Execute 
	Try {
		Start-Process -FilePath "$ExtractedFolder\ServiceUI.exe" -ArgumentList "-process:explorer.exe C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -NoProfile -WindowStyle Hidden -NonInteractive -ExecutionPolicy Bypass -File $ExtractedFolder\Set-Bitlocker-Startup-PIN.ps1" -WindowStyle Hidden
		Write-Log -Log "Bitlocker Startup PIN Tool has been started successfully"
	}
	
	Catch {
		Write-Log -Log "Something went wrong"; Write-Log -Log "$_.Exception.Message"; Exit 1
	}
	Finally {
		Write-Log -Log "Remediation script has completed successfully"; Exit 0
	}
}

catch {
	Write-Log -Log "Something went wrong"; Write-Log -Log "$_.Exception.Message"; Exit 1
}


