Clear-Host

$scriptBlock = {
    param($CN)

    Write-Host "Computer Name: $CN"  # Outputs the computer name

    $root = [ADSI]''
    $searcher = New-Object System.DirectoryServices.DirectorySearcher($root)
    $searcher.filter = "(&(objectclass=computer)(cn=$CN))"

    $name = $searcher.findall()

    if ($name -eq $null) {
        Write-Host "No matches found"  # If no matches are found, print a message and exit
        return
    }
    else {
        Write-Host "Matches found: $($name.Count)"  # Outputs the number of matches found
    }

    # Get the DN of the object
    $computerDN = $name[0].Properties.Item("DistinguishedName")
    Write-Host "Distinguished Name: $computerDN"  # Outputs the Distinguished Name

    # Connect to the computer object
    $Object = [ADSI]"LDAP://$ComputerDN"

    # Specify the target OU
    $TargetOU = "OU=Servers_2019,OU=Branches,OU=OUs,DC=posprod,DC=supersol,DC=co,DC=il"
    $TargetOU="LDAP://$TargetOU"

    # Move the object to the target OU
    try {
        $Object.psbase.MoveTo($TargetOU)
        Write-Host "Object moved successfully"
    }
    catch {
        Write-Host "Error moving object: $_"  # Outputs the error message if moving the object fails
    }
}

# Execute the script block locally
& $scriptBlock -CN $env:COMPUTERNAME

# Generate the "SL" hostname
$SL_Hostname = "SL" + $env:COMPUTERNAME.Substring(2)

# Execute the script block locally with "SL" hostname
& $scriptBlock -CN $SL_Hostname
