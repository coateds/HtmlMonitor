<#
Branch Feature1:

New Function to add a column for WatchedServices.
The Function will accept as input an array (list) of services to be watched.
The output string will include substitutable strings for color coding the html


Version 1.0
Jan 2016
Dave Coate

This is now a 2 part solution. Part 1, this file, builds a collection of objects with ComputerName,
Ping and other server health columns. This output is converted to html and copied to a web server.

Part 2 apparently needs to be run on another server/computer. This constantly/periodically loads the
web page from the web server copied to in part 1.
#>

<# 
.Synopsis 
   Gets a (filtered) list of servers from a CSV File 
.DESCRIPTION 
   The parameters are both optional. 
   Leaving one blank applies no filter for that parameter. 
.EXAMPLE 
   Get-MyServerCollection 
   Returns everything 
.EXAMPLE 
   Get-MyServerCollection -Role Web 
   Returns all of the Web Servers 
.EXAMPLE 
   Get-MyServerCollection -Role SQL -Location WA 
   Returns the SQL Servers in Washington 
#>
Function Get-MyServerCollection  
    { 
    Param 
        ( 
        [ValidateSet("Web", "SQL", "DC")] 
        [string]$Role, 
         
        [ValidateSet("AZ", "WA")] 
        [string]$Location 
        ) 

    # $ScriptPath = 'C:\Scripts\Book\Chap2' 
    $ScriptPath = $PSScriptRoot
    $ComputerNames = 'Servers.csv' 

    If ($Role -ne "")  {$ModRole = $Role} 
        Else {$ModRole = "*"} 
    If ($Location -ne "")  {$ModLocation = $Location} 
        Else {$ModLocation = "*"} 

    Import-Csv -Path "$ScriptPath\$ComputerNames"  | 
        Where {($_.Role -like $ModRole) -and ($_.Location -like $ModLocation)} 
    }

<# 
.Synopsis 
    Converts a collection of Server Name Strings into a Colection of objects
.DESCRIPTION 
    This function will take a random list of servers, such as an array or txt file
    and convert it on the pipeline to a collection of PSObjects. This collection 
    will function exactly like an imported CSV with ComputerName as the column heading.
.EXAMPLE 
    ('Server2','Server4') | Get-ServerObjectCollection | Test-ServerConnectionOnPipeline | ft
.EXAMPLE 
    Get-Content -Path .\RndListOfServers.txt | Get-ServerObjectCollection | Test-ServerConnectionOnPipeline | ft
.EXAMPLE 
    (Get-ADComputer -Filter *).Name | Get-ServerObjectCollection | Test-ServerConnectionOnPipeline | ft
    Active Directory!! (All Computers)
.EXAMPLE
    (Get-ADComputer -SearchBase "OU=Domain Controllers,DC=coatelab,DC=com" -Filter *).Name | Get-ServerObjectCollection | Test-ServerConnectionOnPipeline | ft
    Active Directory!! (Just Domain Controllers)
#>
Function Get-ServerObjectCollection
    {
    [CmdletBinding()]
    Param(
        [parameter(
        Mandatory=$true,
        ValueFromPipeline= $true)]
        [string]
        $ComputerName
    )

    Begin
        {}
    Process
        {
        New-Object PSObject -Property @{'ComputerName' = $_}
        }
    }

<#
Simple Function to test WMI connectivity on a remote machine 
moving the Try...Catch block into isolation helps prevent any errors on the console
Return is the WMI OS object when sucessfully connects, Null when it does not
#>
Function Get-WMI_OS ($ComputerName)
    {
    Try {Get-Wmiobject -ComputerName $ComputerName -Class Win32_OperatingSystem -ErrorAction Stop}
    Catch {}
    }

<#
Simple Function to test PS Remote connectivity on a remote machine 
moving the Try...Catch block into isolation helps prevent any errors on the console
Return is the the remote computer's name when sucessfully connects, Null when it does not
#>
Function Get-PSRemoteComputerName  ($ComputerName)
    {
    Try {Invoke-Command -ComputerName $ComputerName -ScriptBlock {1} -ErrorAction Stop}
    Catch {} 
    }

<# 
.Synopsis 
    Runs availability checks on servers
.DESCRIPTION 
    This typically takes an imported csv file with a ComputerName Column as an imput object
    but just about any collection of objects that exposes .ComputerName should work
    The output is the same type of object as the input (hopefully) so that it can be piped 
    to the next function to add another column.

    Makes both a WMI and PS Remote call
.EXAMPLE 
    Get-MyServerCollection | Test-ServerConnectionOnPipeline | ft
.EXAMPLE
    $a = Foreach ($s in ('Server1','Server2','Server3')) {New-Object PSObject -Property @{'ComputerName' = $s}}
    $a | Test-ServerConnectionOnPipeline | ft
    Another Ad Hoc way to build an object for the pipeline. These two lines cannot
#>
Function Test-ServerConnectionOnPipeline
    {
    [CmdletBinding()]

    Param
        (
        [parameter(
        Mandatory=$true, 
        ValueFromPipeline= $true)]
        $ComputerProperties
        )
    
    Begin
        {}
    Process
        {
        $ComputerProperties | Select *, Ping, WMI, PSRemote, BootTime | %{
            # Test Ping
            $_.Ping = Test-Connection -ComputerName $ComputerProperties.ComputerName -Quiet -Count 1

            If ($_.Ping)
                {
                
                # Calling WMI in a wrapper in order to isolate the error condition if it occurs
                $os = Get-WMI_OS -ComputerName $ComputerProperties.ComputerName
                # $os = Get-Wmiobject -ComputerName $ComputerProperties.ComputerName -Class Win32_OperatingSystem -ErrorAction Stop

                If ($os -ne $null) 
                    {
                    $_.BootTime = [Management.ManagementDateTimeConverter]::ToDateTime($os.LastBootUpTime) 
                    $_.WMI = $true
                    }
                Else
                    {
                    $_.WMI = $false
                    $_.BootTime = 'No Try'
                    }

                # Test PS Remoting
                $ps = Get-PSRemoteComputerName -ComputerName $ComputerProperties.ComputerName
                # $Result = Invoke-Command -ComputerName $ComputerProperties.ComputerName -ScriptBlock {$env:COMPUTERNAME} -ErrorAction Stop

                If ($ps -ne $null) 
                    {$_.PSRemote = $true}
                Else
                    {$_.PSRemote = $false}
                }
            $_
            }
        }
    }

<#
Script Block to return Service Status
#>
$GetWatchedServicesScriptBlock = 
    {
    Param($WatchedServiceNames)

    $arrWatchedSvcs = $WatchedServiceNames.Split(',')
    $SvcString = ""
    Foreach ($Svc in Get-Service | Where {$_.Name -in $arrWatchedSvcs}) 
        {
        If ($Svc.Status -eq "Stopped")
            {$ServiceName = 'StatusStopped' + $Svc.Name + 'Fnt'}
        ElseIf ($Svc.Status -eq "Running")
            {$ServiceName = 'StatusRunning' + $Svc.Name + 'Fnt'}
        Else
            {$ServiceName = 'StatusOther' + $Svc.Name + 'Fnt'}
        $SvcString += $ServiceName + " "
        }
    $SvcString
    }

<#
.Synopsis 
    Returns the Status on Watched Services
.DESCRIPTION 
    Feature1

    Gets the status of a list of services on a remote server (PSRemote)
    The returned string is designed to be substituted for color coded html

        (Get-Content $LocalHtmlFile).replace('Red', '<font color="DarkRed">') | Set-Content $LocalHtmlFile
        (Get-Content $LocalHtmlFile).replace('Grn', '<font color="DarkGreen">') | Set-Content $LocalHtmlFile
        (Get-Content $LocalHtmlFile).replace('Yel', '<font color="Gold">') | Set-Content $LocalHtmlFile
        (Get-Content $LocalHtmlFile).replace('Fnt', '</font>') | Set-Content $LocalHtmlFile

.EXAMPLE 
#>
Function Get-SelectedServiceStatusString
    {
    [CmdletBinding()]

    Param
        (
        [parameter(
        Mandatory=$true, 
        ValueFromPipeline= $true)]
        $ComputerProperties,

        
        $WatchedServiceNames
        )
    
    Begin
        {}
    Process
        {
        $ComputerProperties | Select *, WatchedServices | %{
            
            If (($_.Ping) -and ($_.PSRemote))
                {
                $_.WatchedServices = Invoke-Command -ComputerName $_.ComputerName -ScriptBlock $GetWatchedServicesScriptBlock -ArgumentList $WatchedServiceNames
                }
            Else
                {$_.WatchedServices = 'No Try'}
            $_
            }
        }
    }

<#
.Synopsis
    Build an HTML page for a constantly refreshing Web Page

.DESCRIPTION
    This is how to build a PowerShell generated, dynamically refreshing Web Page
    to display server connection status.

    The process starts by defining two file paths
    1) Local for building the web page
    2) In folder that is accessible on a web server (wwwroot for instance)

    Start the (infinite) Loop

        Build and write the local html page
            This may have multiple steps
        Copy the local file over the Web Server file

.EXAMPLE
    
#>
Function Start-HtmlMonitor
    {
    [CmdletBinding()]

    Param
        (
        $WebServer
        )

    $HtmlHeader = "<style>BODY{background-color:#737CA1;}</style>"

    # $WebServer = 'Server2'
    $WebServerFileName = "LabServers.htm"
    $WebServerFilePath = "\\$WebServer\C$\inetpub\wwwroot\$WebServerFileName"
    $LocalHtmlFile = "$PSScriptRoot\$WebServerFileName"
 
    # Write the initial file out to the web server
    $null | ConvertTo-HTML -head $HtmlHeader | Out-File $WebServerFilePath

    While($True)
        {
        # Debug: Is this line necessary?
        # $null | ConvertTo-HTML -head $HtmlHeader | Out-File $LocalHtmlFile

        $Servers = Get-MyServerCollection | Test-ServerConnectionOnPipeline | Get-SelectedServiceStatusString -WatchedServiceNames 'bits,spooler' | Sort-Object 'Ping','ComputerName'
        $Servers | ConvertTo-HTML -head $HtmlHeader | Out-File $LocalHtmlFile
        (Get-Content $LocalHtmlFile).replace('False', '<font color="DarkRed"> False </font>') | Set-Content $LocalHtmlFile
        (Get-Content $LocalHtmlFile).replace('StatusStopped', '<font color="DarkRed">') | Set-Content $LocalHtmlFile
        (Get-Content $LocalHtmlFile).replace('StatusRunning', '<font color="DarkGreen">') | Set-Content $LocalHtmlFile
        (Get-Content $LocalHtmlFile).replace('StatusOther', '<font color="Gold">') | Set-Content $LocalHtmlFile
        (Get-Content $LocalHtmlFile).replace('Fnt', '</font>') | Set-Content $LocalHtmlFile

        Copy-Item -Path $LocalHtmlFile -Destination $WebServerFilePath
        }

    }


# Start the process
Start-HtmlMonitor 'Server2'


