# HtmlMonitor
A constantly refeshing html page created from ConvertTo-HTML cmdlet in PoweShell.

This builds on the 'BigPipelineSolution' repository/project I have presented here. Any collection of objects that can be presented in a table, like that created by importing a CSV file, can be converted to HTML. The output of the BigPipelineSolution can be converted in just such a manner. If the information gathered is at least somewhat dynamic then the webpage created could be constantly (periodically) written and refreshed to give near real time feedback creating a really simple monitor page. The working example presented here runs a ping test as well as verify WMI and PowerShell Remoting can be accessed. The BigPipelineSolution provides a framework for adding other columns as needed.

Currently, this process can only be run in the foreground from the ISE. Furthermore, it seems that I can only get the constant (periodic) webpage refresh to run in the same process that is constantly (periodically) writing new information to web page itself. The negative effect of this is that only one computer can be running this 'dashboard' at a time. I would like to 'de-couple' the two processes. One process to ConvertTo-HTML my collection of objects and one (that can be run by many people on multiple computers) to open and periodically refresh the web page produced.

# Update 1 -

The combined process of gathering information into an object collection and outputting it to HTML cannot be run on the same computer that is loading and constantly refreshing the web page. It seems that after some period of time, the two processes would collide, IE would freeze and the entore process would stop without exiting. The only recourse was to kill IE from task manager.

This actually provided me with the de-coupling I was looking for, but that means 2 scripts instead of one. HtmlMonitor.ps1 has had a lot of its original Start-HtmlMonitor Function moved to "detritus" at the bottom of the script along with some functions I experimented on to try can close and release com objects. The new script, StartAndRefreshWebPage.ps1 now contains just the bits needed to open IE and refresh it every three seconds.

The current experiment is to try running both scripts from PS Console instead of the ISE. It appears to be Working.