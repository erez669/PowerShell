# SQL Server Express instance on localhost
$localInstance = "localhost\SQLEXPRESS"

# Define log file path
$logFilePath = "C:\Install\Witness_Alter_Mirror.log"

# Clear the log file at the beginning of the script
"" | Out-File -FilePath $logFilePath

# SQL Commands to run and verify
$sqlCommands = @(
    @{
        Command = "ALTER ENDPOINT MIRRORING STATE=STOPPED";
        Verify = "SELECT state_desc FROM sys.endpoints WHERE name = 'Mirroring'"
    },
    @{
        Command = "ALTER ENDPOINT MIRRORING STATE=STARTED";
        Verify = "SELECT state_desc FROM sys.endpoints WHERE name = 'Mirroring'"
    }
)

foreach ($sqlCommand in $sqlCommands) {
    try {
        # Running the ALTER command
        $alterCommand = "sqlcmd -S {0} -Q ""{1}""" -f $localInstance, $sqlCommand.Command
        Invoke-Expression $alterCommand 2>&1

        # Running the verification command
        $verifyCommand = "sqlcmd -S {0} -Q ""{1}""" -f $localInstance, $sqlCommand.Verify
        $verificationOutput = Invoke-Expression $verifyCommand 2>&1

        # Log the output
        "Verification Output for $($sqlCommand.Command): $verificationOutput" | Out-File -FilePath $logFilePath -Append
    } catch {
        # Log the exception
        "Exception caught: $_" | Out-File -FilePath $logFilePath -Append
    }
}