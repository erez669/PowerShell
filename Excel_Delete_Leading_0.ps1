Clear-Host

# Terminate any lingering Excel processes
Get-Process excel | Stop-Process -Force -Verbose

# Define the path to the Excel file
$excelFilePath = "C:\users\erezsc\Desktop\Tablets-Win10_Plus8.xlsx"

# Create an instance of Excel
$excel = New-Object -ComObject Excel.Application
$excel.Visible = $false
$excel.DisplayAlerts = $false

try {
    # Open the Excel file
    $workbook = $excel.Workbooks.Open($excelFilePath)

    # Iterate over each sheet in the workbook
    foreach ($sheet in $workbook.Sheets) {
        Write-Output "Processing sheet: $($sheet.Name)"
        
        # Get the range of used cells
        $usedRange = $sheet.UsedRange

        # Iterate over each row in the used range
        for ($row = 2; $row -le $usedRange.Rows.Count; $row++) {
            try {
                # Get the current IP address value from column D (4th column)
                $cell = $sheet.Cells.Item($row, 4)
                $ip = $cell.Text  # Use .Text to read displayed text

                # Check if the IP address is not empty and has the correct format
                if ($ip -ne $null -and $ip -match '^\d{1,3}(\.\d{1,3}){3}$') {
                    # Print the original IP address
                    Write-Output "Original IP at row $row on sheet $($sheet.Name): $ip"

                    # Remove leading zeros from the IP address
                    $ipParts = $ip -split '\.'
                    $newIpParts = @()
                    foreach ($part in $ipParts) {
                        $newIpParts += [string][int]$part
                    }
                    $newIp = $newIpParts -join '.'

                    # Print the new IP address
                    Write-Output "New IP at row $row on sheet $($sheet.Name): $newIp"

                    # Set the updated IP address back to the cell as a string
                    $cell.Value2 = [string]$newIp

                    # Verify that the cell was updated
                    $updatedIp = $sheet.Cells.Item($row, 4).Value2
                    if ($updatedIp -eq $newIp) {
                        Write-Output "Successfully updated IP at row $row on sheet $($sheet.Name): $updatedIp"
                    } else {
                        Write-Output "Failed to update IP at row $row on sheet $($sheet.Name). Expected: $newIp, but got: $updatedIp"
                    }
                } else {
                    Write-Output "Empty or invalid IP at row $row on sheet $($sheet.Name)"
                }
            } catch {
                Write-Output "Error processing row $row on sheet $($sheet.Name): $_"
            }
        }

        # Refresh the worksheet to ensure changes are committed
        $sheet.Calculate()
    }

    # Save and close the workbook
    $workbook.Save()
}
catch {
    Write-Output "An error occurred: $_"
}
finally {
    # Ensure the workbook and Excel are properly closed
    if ($workbook -ne $null) {
        $workbook.Close($false)
        [System.Runtime.Interopservices.Marshal]::ReleaseComObject($workbook) | Out-Null
    }
    if ($excel -ne $null) {
        $excel.Quit()
        [System.Runtime.Interopservices.Marshal]::ReleaseComObject($excel) | Out-Null
    }

    # Perform garbage collection to release COM objects
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()

    # Terminate any lingering Excel processes
    Get-Process excel | Stop-Process -Force -Verbose

    Write-Output "Processing complete. The file has been saved and Excel processes have been terminated."
}
