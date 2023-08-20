# Get computer info
$computer = Get-WmiObject Win32_ComputerSystem
$computerName = $computer.Name
$branchNumber = $computerName.Split('-')[1]

Write-Host "Computer: $computerName"
Write-Host "Branch: $branchNumber"

# LDAP group search 
$ldapPath = "LDAP://OU=Branch Groups,OU=Group Objects,OU=OUs,DC=posprod,DC=supersol,DC=co,DC=il"
$groupCN = "Branch_$branchNumber"

Write-Host "Searching LDAP path: $ldapPath"  

$dirEntry = New-Object System.DirectoryServices.DirectoryEntry($ldapPath)
$search = New-Object System.DirectoryServices.DirectorySearcher($dirEntry)

$search.Filter = "(CN=$groupCN)"
$search.PropertiesToLoad.Add("memberOf")

$group = $search.FindOne() 

Write-Host "Number of group memberships found: $($group.Properties.memberof.Count)"
Write-Host "Found groups:"
foreach ($groupMembership in $group.Properties.memberof) {
  $groupName = ($groupMembership -split ',')[0].Split('=')[1]
  Write-Host "$groupName"
}

# Target groups
$targetGroups = @("Net_Supersol_New_Pharm", "Net_SuperSol_Good_Market", "Net_Supersol_Express", "Net_SuperSol_yesh", "Net_SuperSol_yesh_hessed")  

# Check if computer is in target group
$inTargetGroup = $false
foreach ($targetGroup in $targetGroups) {
  if ($group.Properties.memberof -like "*$targetGroup*") {
    $inTargetGroup = $true
    break
  }
}

Write-Host "In target group: $inTargetGroup"

# Determine config path
if ($computerName -like '*SCO*') {
  $configPath1 = 'c:\Program Files\Retalix\SCO.NET\App\sco.exe.config'
  $configPath2 = 'c:\Program Files (x86)\Retalix\SCO.NET\App\sco.exe.config'
  $configPath = if (Test-Path $configPath1) { $configPath1 } else { $configPath2 }
} elseif ($computerName -like '*CSS*') {
  $configPath = 'c:\Program Files (x86)\Retalix\SCO.NET\App\sco.exe.config'
} else {
  $configPath = 'c:\retalix\wingpos\GroceryWinPos.exe.config' 
}

# Update config
Write-Host "Updating config: $configPath"

if (Test-Path $configPath) {
  $text = Get-Content $configPath
  $newText = @()

  foreach ($line in $text) {
    if ($line -match '<URL>http://(posnlb|plpossrv)\w*') {
      if ($inTargetGroup) {
        $newValue = "http://plpossrv$branchNumber"
      } else {
        $newValue = "http://posnlb$branchNumber"
      }
      $newLine = $line -replace 'http://(posnlb|plpossrv)\w*', $newValue
      Write-Host "Replacing URL part with: $newValue"
    } else {
      $newLine = $line
    }
    $newText += $newLine
  }

  Set-Content $configPath -Value $newText

} else {
  Write-Warning "Config file not found: $configPath"
}

Write-Host "Script complete!"
