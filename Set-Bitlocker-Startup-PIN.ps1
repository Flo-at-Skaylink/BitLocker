<#

.SYNOPSIS
    This script sets up BitLocker with a user-defined PIN on the operating system volume.

.DESCRIPTION
    The script creates a directory for BitLocker logs, prompts the user to set a BitLocker startup PIN through a GUI form, and configures BitLocker with the specified PIN. It ensures the PIN meets complexity requirements and logs the process.
    A company logo is displayed on the PIN input form. The logo file should be named "Company_logo.png" and placed in the same directory as the script. If the logo file is not found, a warning will be displayed, but the script will continue to execute.
    The script also checks for existing BitLocker settings and handles errors gracefully, logging them to a specified log file.

.PARAMETER None
    This script does not take any parameters.

.EXAMPLE
    Run the script without any parameters:
    .\Set-BitlockerStartupPIN.ps1

.NOTES
    Author: Florian Aschbichler
    Date: 22.05.2025
    Version: 1.1
    This script requires administrative privileges to run.
    Ensure that "Company_logo.png" is available in the script's directory for the logo to be displayed on the form.

#>

#Log folder
$logfolder = "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs"

# Registry Path for BitLocker minimum PIN length
$Bitlockersettings = "HKLM:\SOFTWARE\Policies\Microsoft\FVE"

# Create log file name
$logFile = Join-Path $logfolder "Bitlocker-Set-Startup-PIN.log"

# Function to write logs
# This function logs messages to a specified log file with a timestamp.
Function Write-Log {
	param (
		$message
	)

	$TimeStamp = "[{0:MM/dd/yy} {0:HH:mm:ss}]" -f (Get-Date)
	Add-Content $LogFile  "$TimeStamp - $message"
}

# Function to test PIN complexity
# This function checks if the provided PIN meets complexity requirements.
# It checks for sequential numbers, repeated characters, common patterns, and other criteria based on the specified pinComplexity.
# Returns $true if the PIN is complex enough, otherwise returns $false
function Test-PinComplex {
    param(
        [string]$pin,
        [int]$pinComplexity
    )

    # Check for sequential numbers (including partial sequences)
    if ($pinComplexity -eq 0 -and $pin -match '01234|12345|23456|34567|45678|56789|67890') { return $false }
    
    # Check for reverse sequential numbers
    if ($pinComplexity -eq 0 -and $pin -match '98765|87654|76543|65432|54321|43210') { return $false }

    # Check for repeated characters (6 or more repetitions)
    if ($pin -match '(.)\1{5,}') { return $false }

    # Check for common patterns (repeating sequences)
    if ($pin -match '(.{3,})\1') { return $false }

    # Check for patterns with more than 3 repeating characters
    if ($pin -match '(.)\1{2,}') { return $false }
    
    # Check if all digits are the same
    if ($pin -match '^(.)\1*$') { return $false }
    
    # Check for repeating pairs
    if ($pin -match '(.{2})\1+') { return $false }

    # Check for common keyboard patterns
    if ($pinComplexity -eq 1 -and $pin -match 'qwerty|asdfgh|zxcvbn') { return $false }

    # Check for spaces or control characters
    if ($pinComplexity -eq 1 -and $pin -match '\s') { return $false }

    # Check for Username patterns, e.g., first 4 characters of the username
    if ($pinComplexity -eq 1 -and ($pin.ToLower().Contains($env:USERNAME.ToLower().Substring(0,4)))) { return $false }

    # Check for pinComplexity. Uppercase, lowercase, numbers and special characters
    if ($pinComplexity -eq 1 -and $pin -notmatch '^(?=.*?[A-Z])(?=.*?[a-z])(?=.*?[0-9])(?=.*?[^\w\d\s])') { return $false }

    return $true
}

# Function to show the PIN input form
# This function creates a Windows Forms GUI for the user to input their BitLocker startup PIN.
# It includes fields for entering and confirming the PIN, and checks the PIN against complexity requirements.
# If the PIN is valid, it returns the entered PIN; otherwise, it displays an error message.
# The form is maximized and has no borders, with a company logo displayed at the top.
# The logo file should be named "Company_logo.png" and placed in the same directory as the script.
# If the logo file is not found, a warning will be displayed, but the script will continue to execute.
function Show-PinInputForm {
    param(
        [int]$pinComplexity,
        [int]$minPinLength
    )

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
    $instructionLabel.Location = New-Object System.Drawing.Point(20, 180)

    # PIN Input
    $pinInput = New-Object System.Windows.Forms.TextBox
    $pinInput.PasswordChar = "*"
    $pinInput.Font = New-Object System.Drawing.Font("Segoe UI", 12)
    $pinInput.Size = New-Object System.Drawing.Size(300, 25)
    $pinInput.Location = New-Object System.Drawing.Point(20, 210)

    # PIN Confirmation Input
    $pinConfirmInput = New-Object System.Windows.Forms.TextBox
    $pinConfirmInput.PasswordChar = "*"
    $pinConfirmInput.Font = New-Object System.Drawing.Font("Segoe UI", 12)
    $pinConfirmInput.Size = New-Object System.Drawing.Size(300, 25)
    $pinConfirmInput.Location = New-Object System.Drawing.Point(20, 240)

    # Set PIN Button
    $submitButton = New-Object System.Windows.Forms.Button
    $submitButton.Text = "Set PIN"
    $submitButton.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 12, [System.Drawing.FontStyle]::Regular)
    $submitButton.Size = New-Object System.Drawing.Size(100, 30)
    $submitButton.Location = New-Object System.Drawing.Point(20, 280)

    #Cancel Button
    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Text = "Cancel"
    $cancelButton.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 12, [System.Drawing.FontStyle]::Regular)
    $cancelButton.Size = New-Object System.Drawing.Size(100, 30)
    $cancelButton.Location = New-Object System.Drawing.Point(140, 280)

    # Error Label
    $errorLabel = New-Object System.Windows.Forms.Label
    $errorLabel.ForeColor = [System.Drawing.Color]::Red
    $errorLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $errorLabel.AutoSize = $true
    $errorLabel.Location = New-Object System.Drawing.Point(20, 340)

    # Add controls to the form
    $form.Controls.AddRange(@($logoBox, $label, $instructionLabel, $pinInput, $pinConfirmInput, $submitButton, $cancelButton, $errorLabel))

    # Set form properties
    $script:pin = $null

    # Event handlers for Submit and Cancel buttons
    $submitButton.Add_Click({
        $enteredPin = $pinInput.Text
        $confirmedPin = $pinConfirmInput.Text
        if ($enteredPin.Length -ge $minPinLength -and $enteredPin -match '^\d+$' -and $enteredPin -eq $confirmedPin) {
            if (Test-PinComplex -pin $enteredPin -pinComplexity $pinComplexity) {
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

    Write-Log "Starting BitLocker PIN setup script..."

    # Create Company\BitLocker folder if it doesn't exist
    if (-not (Test-Path $logfolder)) {
        New-Item -Path $logfolder -ItemType Directory -Force | Out-Null
    }

    # Check or Create a script running flag, if it exists, exit the script
    # This prevents multiple instances of the script from running simultaneously
    # If the run flag is older than 1 day, delete it
    $scriptRunningFlag = Join-Path $logfolder "BitLocker-Set-Bitlocker-Startup-PIN.running"
    if (Test-Path $scriptRunningFlag) {
        $flagCreationTime = (Get-Item $scriptRunningFlag).CreationTime
        if ($flagCreationTime -lt (Get-Date).AddDays(-1)) {
            Remove-Item $scriptRunningFlag -Force | Out-Null
            Write-Log "Old script running flag deleted. Older than 1 day."
        } else {
            Write-Log "Script is already running. Exiting to prevent multiple instances."
            Exit 1
        }
    }

    # Create the script running flag
    New-Item -Path $scriptRunningFlag -ItemType File -Force | Out-Null
    Write-Log "Script running flag created."

    # Read the current minimum PIN length from the registry
    $minPinLength = if (Test-Path $Bitlockersettings) {
        Get-ItemProperty -Path $Bitlockersettings -Name "MinimumPIN" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty MinimumPIN
        Write-Log "Minimum PIN length found in registry"
    } else {
        8  # Default minimum PIN length if not set
        Write-Log "Registry path for BitLocker settings not found. Using default minimum PIN length: 8"
    }

    # Read the current Bitlocker PIN complexity settings
    $pinComplexity = if (Test-Path $Bitlockersettings) {
        Get-ItemProperty -Path $Bitlockersettings -Name "UseEnhancedPIN" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty UseEnhancedPIN
        Write-Log "PIN complexity settings found in registry"
    } else {
        0  # Default complexity if not set
        Write-Log "Registry path for BitLocker settings not found. Using default PIN complexity: 0"
    }

    # Read the current BitLocker status
    Write-Log "Checking BitLocker status..."
    $osVolume = Get-BitLockerVolume | Where-Object { $_.VolumeType -eq 'OperatingSystem' }

    # Show PIN input form and get PIN from user
    $userPIN = Show-PinInputForm -minPinLength $minPinLength -pinComplexity $pinComplexity
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

    # Delete the script running flag if an error occurs
    if (Test-Path $scriptRunningFlag) {
        Remove-Item $scriptRunningFlag -Force | Out-Null
        Write-Log "Script running flag deleted due to error."
    }

    # Log the error and display a warning
    $ErrorMessage = $_.Exception.Message
    Write-Log "Error: $ErrorMessage"
    Write-Warning $ErrorMessage
    Exit 1
}

Finally {

    # Clean up: Delete the script running flag
    if (Test-Path $scriptRunningFlag) {
        Remove-Item $scriptRunningFlag -Force | Out-Null
        Write-Log "Script running flag deleted successfully."
    }

    # Script is completed
    Write-Log "BitLocker setup script completed."
}