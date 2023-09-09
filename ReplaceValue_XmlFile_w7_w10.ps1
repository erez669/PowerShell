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
  $xmlDoc = New-Object System.Xml.XmlDocument
  $xmlDoc.Load($configPath)
  
  $urlNode = $xmlDoc.SelectSingleNode('//URL')
  
  if ($urlNode -ne $null) {
    if ($inTargetGroup) {
      $newValue = "http://plpossrv$branchNumber"
    } else {
      $newValue = "http://posnlb$branchNumber"
    }
    $staticPart = ".posprod.supersol.co.il:4444/wsgpos/Service.asmx"
    $newUrl = "${newValue}${staticPart}"
    $urlNode.InnerText = $newUrl
    Write-Host "New URL: $newUrl"
  }
  
  $settings = New-Object System.Xml.XmlWriterSettings
  $settings.Indent = $true
  $writer = [System.Xml.XmlTextWriter]::Create($configPath, $settings)
  $xmlDoc.Save($writer)
  $writer.Close()
} else {
  Write-Warning "Config file not found: $configPath"
}

Write-Host "Script complete!"
