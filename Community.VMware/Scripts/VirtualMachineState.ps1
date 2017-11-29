﻿param($vCenterServerName)

$ScriptName = 'Community.VMware.Probe.VirtualMachineState.ps1'
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
	LogScriptEvent -EventLevel 1 -Message ("$_`rType:$($_.Exception.GetType().FullName)`r$($_.InvocationInfo.PositionMessage)`rReceivedParam:`rsourceId:$sourceId`rvCenterServerName:$vCenterServerName")
}

Try {
	get-module -listavailable | ?{$_.name -match "vmware"} | %{import-module -Name $_.name}
	# $void = [System.Reflection.Assembly]::LoadFrom("C:\Program Files (x86)\VMware\Infrastructure\PowerCLI\Modules\VMware.VimAutomation.Sdk\VMware.VimAutomation.Logging.SoapInterceptor.dll")
} Catch {
	Start-Sleep -Seconds 10
	Try {
		get-module -listavailable | ?{$_.name -match "vmware"} | %{import-module -Name $_.name}
		# $void = [System.Reflection.Assembly]::LoadFrom("C:\Program Files (x86)\VMware\Infrastructure\PowerCLI\Modules\VMware.VimAutomation.Sdk\VMware.VimAutomation.Logging.SoapInterceptor.dll")
	} Catch {
		DefaultErrorLogging
		Exit
	}
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

Try {$VirtualMachines = Get-View -Server $connection -ViewType VirtualMachine -Property Summary | Select Summary,MoRef}
Catch {DefaultErrorLogging}

<#
If (!$VirtualMachines){
	LogScriptEvent 0 ("No virtual machines found in vCenter server " + $vCenterServerName)
	Try {Disconnect-VIServer -Server $connection -Confirm:$false}
	Catch {DefaultErrorLogging}
	exit
}
#>

ForEach ($VirtualMachine in $VirtualMachines){

	$bag = $api.CreatePropertyBag()
	$bag.AddValue('VirtualMachineId', [string]$VirtualMachine.MoRef)
	$bag.AddValue('vCenterServerName', $vCenterServerName)
	$bag.AddValue('PowerState',[string]$VirtualMachine.Summary.Runtime.PowerState)
	$bag
}
Try {Disconnect-VIServer -Server $connection -Confirm:$false}
Catch {DefaultErrorLogging}