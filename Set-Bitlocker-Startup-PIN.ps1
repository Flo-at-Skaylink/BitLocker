<#

.SYNOPSIS
    This script sets up BitLocker with a user-defined PIN on the operating system volume.

.DESCRIPTION
    The script creates a directory for BitLocker logs, prompts the user to set a BitLocker startup PIN through a GUI form, and configures BitLocker with the specified PIN. It ensures the PIN meets complexity requirements and logs the process.
    A company logo is displayed on the PIN input form. The logo file should be named "Company_logo.png" and placed in the same directory as the script. If the logo file is not found, a warning will be displayed, but the script will continue to execute.

.PARAMETER None
    This script does not take any parameters.

.EXAMPLE
    Run the script without any parameters:
    .\Set-BitlockerStartupPIN.ps1

.NOTES
    Author: Florian Aschbichler
    Date: 22.05.2025
    Version: 1.0
    This script requires administrative privileges to run.
    Ensure that "Company_logo.png" is available in the script's directory for the logo to be displayed on the form.

#>

# Create Company\BitLocker folder if it doesn't exist
$bitlockerFolder = "C:\Windows\Temp\BitLocker-Startup-PIN-Tool"
if (-not (Test-Path $bitlockerFolder)) {
    New-Item -Path $bitlockerFolder -ItemType Directory -Force | Out-Null
}

#Log folder
$logfolder = "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs"

# Registry Path for BitLocker minimum PIN length
$Bitlockersettings = "HKLM:\SOFTWARE\Policies\Microsoft\FVE"

# Create log file name with timestamp
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$logFile = Join-Path $logfolder "Bitlocker-Setup-PIN_$timestamp.log"

Function Write-Log {
	param (
		$message
	)
	$TimeStamp = "[{0:MM/dd/yy} {0:HH:mm:ss}]" -f (Get-Date)
	Add-Content $LogFile  "$TimeStamp - $message"
}

function Test-PinComplex {
    param([string]$pin)
    
    # Check for sequential numbers (including partial sequences)
    if ($pin -match '01234|12345|23456|34567|45678|56789|67890') { return $false }
    
    # Check for reverse sequential numbers
    if ($pin -match '98765|87654|76543|65432|54321|43210') { return $false }
    
    # Check for repeated digits (6 or more repetitions)
    if ($pin -match '(\d)\1{5,}') { return $false }
    
    # Check for common patterns (repeating sequences)
    if ($pin -match '(\d{3,})\1') { return $false }
    
    # Check if all digits are the same
    if ($pin -match '^(\d)\1*$') { return $false }
    
    # Check for repeating pairs
    if ($pin -match '(\d{2})\1+') { return $false }

    return $true
}

function Show-PinInputForm {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $form = New-Object System.Windows.Forms.Form
    $form.WindowState = [System.Windows.Forms.FormWindowState]::Maximized
    $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
    $form.BackColor = [System.Drawing.Color]::White
    $form.TopMost = $true

    # Logo
    $logoBox = New-Object System.Windows.Forms.PictureBox
    $logoBox.Size = New-Object System.Drawing.Size(200, 100)
    $logoBox.Location = New-Object System.Drawing.Point(20, 20)
    $logoBox.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::Zoom
    $logoPath = Join-Path $PSScriptRoot "Company_logo.png"
    if (Test-Path $logoPath) {
        $logoBox.Image = [System.Drawing.Image]::FromFile($logoPath)
    } else {
        Write-Warning "Logo file not found: $logoPath"
    }

    # Title
    $label = New-Object System.Windows.Forms.Label
    $label.Text = "Set BitLocker Startup PIN"
    $label.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 20, [System.Drawing.FontStyle]::Regular)
    $label.AutoSize = $true
    $label.Location = New-Object System.Drawing.Point(20, 130)

    # Instructions
    $instructionLabel = New-Object System.Windows.Forms.Label
    $instructionLabel.Text = "PIN must be at least $minPinLength digits long and not use simple patterns."
    $instructionLabel.Font = New-Object System.Drawing.Font("Segoe UI", 13)
    $instructionLabel.AutoSize = $true
    $instructionLabel.Location = New-Object System.Drawing.Point(20, 160)

    # PIN Input
    $pinInput = New-Object System.Windows.Forms.TextBox
    $pinInput.PasswordChar = "*"
    $pinInput.Font = New-Object System.Drawing.Font("Segoe UI", 12)
    $pinInput.Size = New-Object System.Drawing.Size(300, 25)
    $pinInput.Location = New-Object System.Drawing.Point(20, 190)

    # PIN Confirmation Input
    $pinConfirmInput = New-Object System.Windows.Forms.TextBox
    $pinConfirmInput.PasswordChar = "*"
    $pinConfirmInput.Font = New-Object System.Drawing.Font("Segoe UI", 12)
    $pinConfirmInput.Size = New-Object System.Drawing.Size(300, 25)
    $pinConfirmInput.Location = New-Object System.Drawing.Point(20, 230)

    # Set PIN Button
    $submitButton = New-Object System.Windows.Forms.Button
    $submitButton.Text = "Set PIN"
    $submitButton.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 12, [System.Drawing.FontStyle]::Regular)
    $submitButton.Size = New-Object System.Drawing.Size(100, 30)
    $submitButton.Location = New-Object System.Drawing.Point(20, 260)

    #Cancel Button
    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Text = "Cancel"
    $cancelButton.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 12, [System.Drawing.FontStyle]::Regular)
    $cancelButton.Size = New-Object System.Drawing.Size(100, 30)
    $cancelButton.Location = New-Object System.Drawing.Point(140, 260)

    # Error Label
    $errorLabel = New-Object System.Windows.Forms.Label
    $errorLabel.ForeColor = [System.Drawing.Color]::Red
    $errorLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $errorLabel.AutoSize = $true
    $errorLabel.Location = New-Object System.Drawing.Point(20, 300)

    # Add controls to the form
    $form.Controls.AddRange(@($logoBox, $label, $instructionLabel, $pinInput, $pinConfirmInput, $submitButton, $cancelButton, $errorLabel))

    # Set form properties
    $script:pin = $null

    # Event handlers for Submit and Cancel buttons
    $submitButton.Add_Click({
        $enteredPin = $pinInput.Text
        $confirmedPin = $pinConfirmInput.Text
        if ($enteredPin.Length -ge $minPinLength -and $enteredPin -match '^\d+$' -and $enteredPin -eq $confirmedPin) {
            if (Test-PinComplex $enteredPin) {
                $script:pin = $enteredPin
                Write-Log "PIN set successfully"
                $form.Close()
            } else {
                $errorLabel.Text = "PIN is too simple. Please avoid sequential numbers, repeating patterns, or easily guessable combinations."
            }
        } elseif ($enteredPin -ne $confirmedPin) {
            $errorLabel.Text = "PINs do not match. Please try again."
        } else {
            $errorLabel.Text = "PIN must be at least $minPinLength digits long. Please try again."
        }
    })

    $cancelButton.Add_Click({
        Write-Log "User cancelled the PIN setup."
        $form.Close()
    })

    $form.Add_Shown({$form.Activate()})
    [void]$form.ShowDialog()

    # Return the entered PIN
    return $script:pin
}

Try {

    # Read the current minimum PIN length from the registry
    $minPinLength = if (Test-Path $Bitlockersettings) {
        Get-ItemProperty -Path $Bitlockersettings -Name "MinimumPIN" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty MinimumPIN
        Write-Log "Minimum PIN length read from registry: $minPinLength"
    } else {
        8  # Default minimum PIN length if not set
        Write-Log "Registry path for BitLocker settings not found. Using default minimum PIN length: $minPinLength"
    }

    # Read the current BitLocker status
    Write-Log "Checking BitLocker status..."
    $osVolume = Get-BitLockerVolume | Where-Object { $_.VolumeType -eq 'OperatingSystem' }

    # Show PIN input form and get PIN from user
    $userPIN = Show-PinInputForm
    Write-Log "User PIN after form: $($userPIN -replace '.', '*')"  # Log masked PIN for security

    # Validate the user input
    if (-not $userPIN) {
        Write-Log "PIN input seems to be empty or invalid."
        throw "PIN input cancelled or invalid. BitLocker not enabled."
    }

    # Convert the user PIN to a SecureString
    Write-Log "Attempting to convert PIN to SecureString"
    $devicePIN = ConvertTo-SecureString $userPIN -AsPlainText -Force

    # Add BitLocker key protector with the provided PIN
    Write-Log "Adding BitLocker with the provided PIN"
    Add-BitlockerKeyProtector -MountPoint $osVolume.MountPoint -TpmAndPinProtector -Pin $devicePIN -ErrorAction Stop

    Exit 0
}
Catch {
    # Log the error and display a warning
    $ErrorMessage = $_.Exception.Message
    Write-Log "Error: $ErrorMessage"
    Write-Warning $ErrorMessage
    Exit 1
}

Finally {
    # Script is completed
    Write-Log "BitLocker setup script completed."
}