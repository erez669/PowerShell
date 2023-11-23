$scriptPath = $MyInvocation.MyCommand.Path
$scriptRoot = Split-Path -Path $scriptPath -Parent

# Define the paths for the .ps1 and .xml files relative to the script's location
$ps1Source = Join-Path -Path $scriptRoot -ChildPath "Alter_Mirror.ps1"
$xmlSource = Join-Path -Path $scriptRoot -ChildPath "Alter_Mirror.xml"

# Define the destination folder
$destinationFolder = "C:\Install"

# Create the destination folder if it doesn't exist
if (-not (Test-Path $destinationFolder)) {
    New-Item -Path $destinationFolder -ItemType Directory -Verbose | Out-Null
}

# Copy the .ps1 and .xml files to the destination folder
Copy-Item -Path $ps1Source -Destination $destinationFolder -Force -Verbose
Copy-Item -Path $xmlSource -Destination $destinationFolder -Force -Verbose

# Import the .xml file to create a scheduled task
$xmlDestination = Join-Path -Path $destinationFolder -ChildPath (Get-Item $xmlSource).Name
$taskName = "Alter_Mirror_Witness"

# Specify the credentials
$user = "posprod\retalix_sqlinstall"

# Define the paths for the key and encrypted password relative to the script's location
$KeyPath = Join-Path -Path $scriptRoot -ChildPath "key.txt"
$EncryptedPasswordPath = Join-Path -Path $scriptRoot -ChildPath "EncryptedPassword.txt"

# Load the key and encrypted password
$Key = Get-Content $KeyPath -Encoding Byte
$EncryptedPassword = Get-Content $EncryptedPasswordPath

# Decrypt the password
$Password = ConvertTo-SecureString -String $EncryptedPassword -Key $Key

# Convert the decrypted SecureString password to plaintext
$plaintextPassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password))

# Import the scheduled task
schtasks /create /xml $xmlDestination /tn $taskName /ru $user /rp $plaintextPassword /F