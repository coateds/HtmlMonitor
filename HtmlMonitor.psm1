<#
Branch Feature1:

New Function to add a column for WatchedServices.
The Function will accept as input an array (list) of services to be watched.
The output string will include substitutable strings for color coding the html

------

Version 2.0

Back to a 1 part solution. As long as the web browser and web server are not running on the same 
servers as this script, the auto refreshing web page set in the header of the page works fine.

In addition to a column for watched services, an improvement was made to ensure only one PS Remote
session is opened for each server and closed again when all information has been gathered.

------

Version 1.0
Jan 2016
Dave Coate

This is now a 2 part solution. Part 1, this file, builds a collection of objects with ComputerName,
Ping and other server health columns. This output is converted to html and copied to a web server.

Part 2 apparently needs to be run on another server/computer. This constantly/periodically loads the
web page from the web server copied to in part 1.
#>

$CSVPath = 'C:\Scripts\CSVs'
$TempPath = 'C:\Scripts\TempData'
$ServersCSV = 'Servers.csv'


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

    If ($Role -ne "")  {$ModRole = $Role} 
        Else {$ModRole = "*"} 
    If ($Location -ne "")  {$ModLocation = $Location} 
        Else {$ModLocation = "*"} 

    Import-Csv -Path "$CSVPath\$ServersCSV"  | 
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
.Synopsis 
    Runs availability checks on servers
.DESCRIPTION 
    This typically takes an imported csv file with a ComputerName Column as an imput object
    but just about any collection of objects that exposes .ComputerName should work
    The output is the same type of object as the input (hopefully) so that it can be piped 
    to the next function to add another column.

    Makes both a WMI and PS Remote call

    If successful, the PS Remote call opens a session to stay open for use on the pipeline until all tests
    and information is gathered. The session is closed in the Cleanup-PSSession function

    The result of each test is stored in the object collection (table) to be used in subsequent functions on the 
    pipeline. There is no point in trying to gather more information from a server that will not ping or more
    WMI information if that service is not responding
.EXAMPLE 
    Get-MyServerCollection | Test-ServerConnectionOnPipeline | ft
.EXAMPLE
    $a = Foreach ($s in ('Server1','Server2','Server3')) {New-Object PSObject -Property @{'ComputerName' = $s}}
    $a | Test-ServerConnectionOnPipeline | ft
    Another Ad Hoc way to build an object for the pipeline.
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
        $ComputerProperties | Select *, Ping, WMI, PSRemote, PSSession, BootTime | %{
            # Test Ping
            $_.Ping = Test-Connection -ComputerName $_.ComputerName -Quiet -Count 1

            If ($_.Ping)
                {
                # Calling WMI in a wrapper in order to isolate the error condition if it occurs
                $os = Get-WMI_OS -ComputerName $_.ComputerName

                # Test WMI
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
                $Session = New-PSSession -ComputerName $_.ComputerName -ErrorAction SilentlyContinue #[-Credential $c]

                If ($Session -ne $null) 
                    {$_.PSRemote = $true; $_.PSSession = $Session}
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
    Param($ServerType,$arrWatchedSvcs)

    $SvcString = ""
    Foreach ($ws in $arrWatchedSvcs) 
        {
        $svc = Get-Service -Name $ws -ErrorAction SilentlyContinue
        If ($Svc.Status -eq "Stopped")
            {$ServiceName = 'StatusStopped' + $Svc.Name + 'Fnt'}
        ElseIf ($Svc.Status -eq "Running")
            {$ServiceName = 'StatusRunning' + $Svc.Name + 'Fnt'}
        Else
            {$ServiceName = 'StatusOther' + $Svc.Name + 'Fnt'}

        $SvcString += "$ServiceName "
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

    In this example, each server role has its own csv file to define which services to watch

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
        $ComputerProperties
        )
    
    Begin
        {}
    Process
        {
        $ComputerProperties | Select *, WatchedServices | %{
            
            # Only attempt this if the server pings and a PSRemote session has been opened.
            If (($_.Ping) -and ($_.PSRemote))
                {
                # Read in a csv file customized for the role
                $ServerRole = $_.Role
                $arrWatchedSvcs = (Import-Csv -Path "$CSVPath\$ServerRole`LabServices.csv").Service

                # Make a PSRemote call to get the status of each service
                # The returned string contains substrings that can be replaced with html tags later
                $_.WatchedServices = Invoke-Command -Session $_.PSSession -ScriptBlock $GetWatchedServicesScriptBlock -ArgumentList $_.Role,$arrWatchedSvcs
                }
            Else
                # No Try means the test server connections function failed to establish a connection
                {$_.WatchedServices = 'No Try'}
            $_
            }
        }
    }

<# 
.Synopsis 
    Shuts down the PS Remote session as stored in the 'PSSession' column of the object
.DESCRIPTION 
    Test-ServerConnectionOnPipeline opens a PSSession and stores the reference in the collection: $ComputerProperties
    This session is re-used as needed by any data gathering function that uses PSRemote
    Cleanup-PSSession closes that session after all data is gathered
.EXAMPLE 
   [Import-Csv] | Test-ServerConnectionOnPipeline | [Get-OtherData] | Cleanup-PSSession
#>
Function Cleanup-PSSession
    {
    [CmdletBinding()]

    Param
        (
        [parameter(
        Mandatory=$true, 
        ValueFromPipeline= $true)]
        $ComputerProperties,

        [switch]
        $NoErrorCheck
        )
    
    Begin
        {}
    Process
        {
        If ($_.PSSession -ne $null)  {Remove-PSSession -Session $_.PSSession}
        
        $_
        }
    }

<# 
.Synopsis 
    Specialized helper file to customize the output html file
.DESCRIPTION 
    Provides color coding to the output table

    A header has been started at the beginning of the <body> 
    Currently it shows the date and time at the end of the last data gathering pass
.EXAMPLE 
    Process-HtmlFile $LocalHtmlFile
#>
Function Process-HtmlFile
    {
    Param($HtmlFilePath)
        (Get-Content $HtmlFilePath).replace('False', '<b><font color=#8B0000> False </font>') | Set-Content $HtmlFilePath
        (Get-Content $HtmlFilePath).replace('StatusStopped', '<b><font color=#8B0000>') | Set-Content $HtmlFilePath
        (Get-Content $HtmlFilePath).replace('StatusRunning', '<font color=#006400>') | Set-Content $HtmlFilePath
        (Get-Content $HtmlFilePath).replace('StatusOther', '<b><font color=#DDA000>') | Set-Content $HtmlFilePath
        (Get-Content $HtmlFilePath).replace('Fnt', '</font></b>') | Set-Content $HtmlFilePath

        # Write a header
        $dt = (Get-Date).tostring()
        (Get-Content $HtmlFilePath).replace('<body>',"<body>Last Update: $dt<br><br><hr><br>") | Set-Content $HtmlFilePath
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
    start-job -name HtmlMonitor -ScriptBlock {Start-HtmlMonitor}

    Run as a job
#>
Function Start-HtmlMonitor
    {
    [CmdletBinding()]

    # Sets the web page to refresh
    $HtmlHeader = "<meta http-equiv=`"refresh`" content=`"5`" >"

    $WebServer = 'Server2'
    $WebServerFileName = "LabServers.htm"
    $WebServerFilePath = "\\$WebServer\C$\inetpub\wwwroot\$WebServerFileName"
    $LocalHtmlFile = "$TempPath\$WebServerFileName"

    While($True)
        {
        # Gather data into a collection of objects (Table)
        # Convert it to to html and output to a local file
        Get-MyServerCollection | 
            Test-ServerConnectionOnPipeline | 
            Get-SelectedServiceStatusString | 
            Cleanup-PSSession | 
            Select-Object ComputerName,Role,Location,Ping,WMI,PSRemote,BootTime,WatchedServices |
            Sort-Object 'Ping','Farm','Type','ComputerName' | 
            ConvertTo-HTML -head $HtmlHeader | 
            Out-File $LocalHtmlFile
        Process-HtmlFile $LocalHtmlFile
        
        # copy the local html file to the web server
        Copy-Item -Path $LocalHtmlFile -Destination $WebServerFilePath

        Start-Sleep -Seconds 3
        }
    
    }

<#
For future use, some variant of the following can be used to start this as a job at startup

$Trigger = New-JobTrigger -AtStartup
Register-ScheduledJob -Name Monitor -InitializationScript {Import-Module C:\Scripts\HtmlMonitor\HtmlMonitor.ps1} -ScriptBlock {Start-HtmlMonitor 'Server2'} -Trigger $Trigger

Use Unregister-ScheduledJob to make it go away

#>