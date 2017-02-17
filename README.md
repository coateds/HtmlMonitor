# HtmlMonitor
A constantly refeshing html page created from ConvertTo-HTML cmdlet in PoweShell.

This builds on the 'BigPipelineSolution' repository/project I have presented here. Any collection of objects that can be presented in a table, like that created by importing a CSV file, can be converted to HTML. The output of the BigPipelineSolution can be converted in just such a manner. If the information gathered is at least somewhat dynamic then the webpage created could be constantly (periodically) written and refreshed to give near real time feedback creating a really simple monitor page. The working example presented here runs a ping test as well as verify WMI and PowerShell Remoting can be accessed. The BigPipelineSolution provides a framework for adding other columns as needed.

I have determined that the constantly refreshing web page must run on another computer than the PowerShell process. This version converts the data gathering script to a module and therefore be run as a PowerShell Job. There appears to be a bug in Server 2008 R2. The target of repeated PSRemote calls occasionally sees the profile of the authenticating user put into a 'backup' mode in the registry. The only solution is to reset the profile via WMI call. With this work-around in place, I have run this process for days at a time with out issue

---

## Feature 1 Branch - Version 2.0
Completes the Get-SelectedServiceStatusString Function by allowing each computer to have a customized csv file of relevent services. In this example, there are specifc services for the Web and DC (Domain Controller) Roles.

This version only opens one PS Remote session per pass on a target system. All calls to the system reuse the session before closing it at the end of each pass.

All functionality has been implemented in HtmlMonitor.psm1.

---

## Feature 1 Branch - Version 1.0
This adds the Get-SelectedServiceStatusString Function to get the status of a particular set of services and return it all on one line. Currently the process replaces substrings within the string to build html tags that result in a color coded output: Green for Running, Red for Stopped and Yellow for other (typically starting).