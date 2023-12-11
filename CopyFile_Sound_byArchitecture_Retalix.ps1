# Check if running as Administrator
If (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {   
    Write-Host "Not running as Administrator. Attempting to restart with elevated privileges."
    $arguments = "& '" + $myinvocation.mycommand.definition + "'"
    Start-Process powershell -Verb runAs -ArgumentList $arguments
    exit
}

Write-Host "Running as Administrator."

# Initialize 'System.DirectoryServices.AccountManagement'
Add-Type -AssemblyName System.DirectoryServices.AccountManagement

# Function to check if the computer is in the specified AD group
Function IsInAdGroup($groupName) {

    # Get the current user's identity
    $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent()

    # Create a PrincipalContext for domain
    $contextType = [System.DirectoryServices.AccountManagement.ContextType]::Domain
    $principalContext = New-Object System.DirectoryServices.AccountManagement.PrincipalContext $contextType

    # Create a UserPrincipal for the current user
    $userPrincipal = [System.DirectoryServices.AccountManagement.UserPrincipal]::FindByIdentity($principalContext, $currentUser.Name)

    if ($userPrincipal -ne $null) {
        # Check if the user is a member of the specified group
        $groupFound = $userPrincipal.IsMemberOf($principalContext, [System.DirectoryServices.AccountManagement.GroupPrincipal]::FindByIdentity($principalContext, $groupName))
        return $groupFound
    } else {
        return $false
    }
}

# Get the branch number from the computer's hostname
$computerName = $env:COMPUTERNAME
$branchNumber = ($computerName -split '-')[1]

Write-Host "Branch number is: $branchNumber"

# Define the function to check and display AD groups related to the branch
Function GetAdGroupsForBranch($branchNumber) {
    Write-Host "Getting AD groups that the branch group is a member of for branch: $branchNumber"

    # Define the search base for the branch groups in Active Directory
    $searchBase = "OU=branchgroups,ou=groupobjects,ou=ous,dc=posprod,dc=supersol,dc=co,dc=il"

    # Create a PrincipalContext for domain
    $contextType = [System.DirectoryServices.AccountManagement.ContextType]::Domain
    $principalContext = New-Object System.DirectoryServices.AccountManagement.PrincipalContext $contextType

    # Create a Principal object for the branch group
    $branchGroupPrincipal = [System.DirectoryServices.AccountManagement.GroupPrincipal]::FindByIdentity($principalContext, "branch_$branchNumber")

    if ($branchGroupPrincipal -ne $null) {
        Write-Host "Found branch group: $($branchGroupPrincipal.Name)"

        # Get all the groups that the branch group is a member of
        $memberOf = $branchGroupPrincipal.GetGroups()

        # Filter and display "Net_SuperSol" or "Net_Bela" groups if found
        $foundNetGroups = $memberOf | Where-Object { $_.Name -like "Net_SuperSol*" -or $_.Name -like "Net_Bela*" }

        foreach ($group in $foundNetGroups) {
            Write-Host "Branch group is a member of: $($group.Name)"
        }
        
        # Check if the branch group is a member of the requested group
        $groupFound = $foundNetGroups | Where-Object { $_.Name -eq "Net_SuperSol_Good_Market" }
        
        if ($groupFound -ne $null) {
            Write-Host "The requested group 'Net_SuperSol_Good_Market' found. Proceeding with file copy."
            $source = "\\10.250.236.25\IvantiShare\Packages\-RETALIX-\-POS-VERSIONS-\ScoOnly\AllPaidScreen_PrintReceipt.mp3"
            $destination_x86 = "C:\Program Files\Retalix\SCO.NET\App\Shufersal\PPL\IMAGES\SOUNDS"
            $destination_x64 = "C:\Program Files (x86)\Retalix\SCO.NET\App\Shufersal\PPL\IMAGES\SOUNDS"

            # Get architecture of the local host
            $architecture = (Get-WmiObject -Class Win32_Processor).AddressWidth
            $destination = if ($architecture -eq 64) { $destination_x64 } else { $destination_x86 }

            Write-Host "Architecture: $architecture-bit. Destination set to $destination"

            if (Test-Path -Path $destination) {
                Write-Host "Destination path exists. Copying file..."
                Copy-Item $source -Destination $destination -Recurse -Verbose -Force
            } else {
                Write-Host "Destination path does not exist. Exiting with code 4."
                exit 3
            }
        }
        else {
            Write-Host "The requested group 'Net_SuperSol_Good_Market' not found. Exiting with code 4."
            exit 3
        }
    } else {
        Write-Host "Branch group not found."
    }
}

# Call the function to get and display AD groups for the branch
GetAdGroupsForBranch $branchNumber
