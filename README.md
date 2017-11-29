

Community developed Operations Manager monitoring for VMware developed by Mitch Luedy. I have just made changes to the powershell snapin part.
Its highly recommended to tune this management pack according to your requirements. The discoveries and monitors will take up considerable processor time.


## Known Issues as is from Mitch ##

* **Event 300 PowerShell Warning Exception** - Provider Health: Attempting to perform the NewDrive operation on the 'VimInventory' provider failed for the drive with root '\'. The specified mount name 'vis' is already in use.. 

	Multiple monitoring scripts running to collect and monitor using the VMware PowerCLI providers causes this contention. This can lead to MonitoringHost.exe crashes and memory leakage. **I don't have the time to address this issue**



