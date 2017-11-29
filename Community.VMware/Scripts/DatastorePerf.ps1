param($vCenterServerName)

$ScriptName = 'Community.VMware.Probe.DatastorePerf.ps1'
$api = new-object -comObject 'MOM.ScriptAPI'


Function LogScriptEvent {
	Param (
		
		#0 = Informational
		#1 = Error
		#2 = Warning
		[parameter(Mandatory=$true)]
		[ValidateRange(0,2)]
		[int]$EventLevel
		,
		
		[parameter(Mandatory=$true)]
		[string]$Message
	)

	$api.LogScriptEvent($ScriptName,1985,$EventLevel,$Message)
}

Function DefaultErrorLogging {
	LogScriptEvent -EventLevel 1 -Message ("$_`rType:$($_.Exception.GetType().FullName)`r$($_.InvocationInfo.PositionMessage)`rReceivedParam:`rvCenterServerName:$vCenterServerName")
}

Try {
	
get-module -listavailable | ?{$_.name -match "vmware"} | %{import-module -Name $_.name}
	
# $void = [System.Reflection.Assembly]::LoadFrom("C:\Program Files (x86)\VMware\Infrastructure\PowerCLI\Modules\VMware.VimAutomation.Sdk\VMware.VimAutomation.Logging.SoapInterceptor.dll")
    } 
Catch 
    {  

	Start-Sleep -Seconds 10
	
   	DefaultErrorLogging
		
        Exit
	
    }

Try {
	$connection = Connect-VIServer -Server $vCenterServerName -Force:$true -NotDefault
} Catch {
	Start-Sleep -Seconds 10
	Try {
		$connection = Connect-VIServer -Server $vCenterServerName -Force:$true -NotDefault
	} Catch {
		DefaultErrorLogging
		Exit
	}
}

Try {$VMdatastores = Get-View -Server $connection -ViewType Datastore -Property Summary | Select Summary}
Catch {DefaultErrorLogging}

If (!$VMdatastores){
	LogScriptEvent 0 ("No datastores found in vCenter server " + $vCenterServerName)
	Try {Disconnect-VIServer -Server $connection -Confirm:$false}
	Catch {DefaultErrorLogging}
	exit
}

ForEach ($VMdatastore in $VMdatastores){

	$CAPACITY_GB	= [math]::Round($VMdatastore.Summary.Capacity * (9.31323e-10), 2)
	$FREE_GB		= [math]::Round($VMdatastore.Summary.FreeSpace * (9.31323e-10), 2)
	$USED_GB		= [math]::Round(($VMdatastore.Summary.Capacity - $VMdatastore.Summary.FreeSpace)*(9.31323e-10) , 2)
	$FREE_Percent	= [math]::Round(($VMdatastore.Summary.FreeSpace * 100)/$VMdatastore.Summary.Capacity, 2)
	$USED_Percent	= [math]::Round(($VMdatastore.Summary.Capacity - $VMdatastore.Summary.FreeSpace)*100/$VMdatastore.Summary.Capacity, 2)

	$bag = $api.CreatePropertyBag()
	$bag.AddValue('DatastoreId', [string]$VMdatastore.Summary.Datastore)
	$bag.AddValue('vCenterServerName',$vCenterServerName)
	$bag.AddValue('CAPACITY_GB',$CAPACITY_GB)
	$bag.AddValue('FREE_GB',$FREE_GB)
	$bag.AddValue('USED_GB',$USED_GB)
	$bag.AddValue('FREE_Percent',$FREE_Percent)
	$bag.AddValue('USED_Percent',$USED_Percent)
	$bag
}
Try {Disconnect-VIServer -Server $connection -Confirm:$false}
Catch {DefaultErrorLogging}