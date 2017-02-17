<#
Version 1.0
Jan 2016
Dave Coate

Constantly/periodically loads a web page.
#>
$WebMonitorLink = 'http://server2/LabServers.htm'

$ie = New-Object -com internetexplorer.application
$ie.Navigate($WebMonitorLink)
$ie.visible = $true

$ieSet = (New-Object -ComObject Shell.Application).Windows() |  ? {$_.LocationUrl -like "$WebMonitorLink"}

While ($true){$ieSet.Refresh(); Start-Sleep -Seconds 3}