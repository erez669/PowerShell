Clear-Host
function Test-DotNetVersion {
    $minVersion = "4.6"
    $result = @{
        IsInstalled = $false
        Version = $null
        Message = ""
    }
    $netVersions = Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP' -Recurse |
        Get-ItemProperty -Name Version -ErrorAction SilentlyContinue |
        Where-Object { $_.Version -match '^\d+\.\d+\.\d+' } |
        ForEach-Object { $_.Version }
    
    if ($netVersions) {
        $maxVersion = $netVersions | Sort-Object {[version]$_} -Descending | Select-Object -First 1
        $result.Version = $maxVersion
        
        if ([version]$maxVersion -ge [version]$minVersion) {
            $result.IsInstalled = $true
            $result.StatusCode = 0  # Success
            # Only show version found if it's compatible
            Write-Host ".NET Framework version $maxVersion found"
        } else {
            $result.StatusCode = 1  # Version too low
            # Show required version only if current version is insufficient
            Write-Host ".NET Framework version $maxVersion found. Required version $minVersion or higher"
        }
    } else {
        $result.StatusCode = 2  # Not found
        Write-Host "No .NET Framework 4.x versions found. Required version $minVersion or higher"
        Write-Host "[$(Get-Date -Format 'dd-MM-yyyy HH:mm:ss')] Error - No compatible .NET Framework version found."
    }
    return $result
}

# Get the result
$dotNetCheck = Test-DotNetVersion

# Exit with the status code
exit $dotNetCheck.StatusCode