param($sourceId,$managedEntityId,$vCenterServerName)

Function ExitPrematurely ($Message) {
	$discoveryData.IsSnapshot = $false
	$api.LogScriptEvent($ScriptName,1985,2,$Message)
	$discoveryData
	exit
}

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
	LogScriptEvent -EventLevel 1 -Message ("$_`rType:$($_.Exception.GetType().FullName)`r$($_.InvocationInfo.PositionMessage)`rReceivedParam:`rsourceId:$sourceId`rmanagedEntityId:$managedEntityId`rvCenterServerName:$vCenterServerName")
}

$ScriptName = 'Community.VMware.Discovery.VirtualMachineDatastoreReferenceRelationship.ps1'
$api = new-object -comObject 'MOM.ScriptAPI'
$discoveryData = $api.CreateDiscoveryData(0, $sourceId, $managedEntityId)

Try {Import-Module OperationsManager}
Catch {DefaultErrorLogging}

Try {New-SCOMManagementGroupConnection 'localhost'}
Catch {DefaultErrorLogging}

Try {$MGconn = Get-SCOMManagementGroupConnection | Where {$_.IsActive -eq $true}}
Catch {DefaultErrorLogging}

If(!$MGconn){
	ExitPrematurely ("Unable to connect to the local management group")
}

#Get Already Discovered Virtual Machines from SCOM
Try {$VMobjs = Get-SCOMClass -Name 'Community.VMware.Class.VirtualMachine' | Get-SCOMClassInstance | Where {$_.'[Community.VMware.Class.vCenter].vCenterServerName'.Value -eq $vCenterServerName}}
Catch {DefaultErrorLogging}

#Exit if no VMs are discovered, because there is no relationship to build
If (!$VMobjs){
	ExitPrematurely ("No VMs found discovered in SCOM for vCenter " + $vCenterServerName)
}

#Get Already Discovered Datastores from SCOM
Try {$VMdatastoreObjs = Get-SCOMClass -Name 'Community.VMware.Class.Datastore' | Get-SCOMClassInstance | Where {$_.'[Community.VMware.Class.vCenter].vCenterServerName'.Value -eq $vCenterServerName}}
Catch {DefaultErrorLogging}

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
	}
}

If ($connection.IsConnected -ne $True){
	ExitPrematurely ("Unable to connect to vCenter server " + $vCenterServerName)
}

Try {$VMwareVirtualMachines = (Get-View -Server $connection -ViewType VirtualMachine -Property Summary,Datastore -Filter @{"Config.Template"="false"}) | Select Summary,Datastore}
Catch {DefaultErrorLogging}

If (!$VMwareVirtualMachines){
	Try {Disconnect-VIServer -Server $connection -Confirm:$false}
	Catch {DefaultErrorLogging}
	ExitPrematurely ("No VMs found in vCenter " + $vCenterServerName)
}

ForEach ($VM in $VMwareVirtualMachines){

	If ($VMobjs | Where {$_.'[Community.VMware.Class.VirtualMachine].VirtualMachineId'.Value -eq [string]$VM.Summary.Vm}){

		#Virtual Machine Obj (already discovered)
		$VMInstance = $discoveryData.CreateClassInstance("$MPElement[Name='Community.VMware.Class.VirtualMachine']$")
		$VMInstance.AddProperty("$MPElement[Name='Community.VMware.Class.VirtualMachine']/VirtualMachineId$", [string]$VM.Summary.Vm )
		$VMInstance.AddProperty("$MPElement[Name='Community.VMware.Class.vCenter']/vCenterServerName$", $vCenterServerName )
		
		ForEach ($VMdatastore in $VM.Datastore){
		
			$MatchingDatastore = $VMdatastoreObjs | Where {$_.'[Community.VMware.Class.Datastore].DatastoreId'.Value -eq [string]$VMdatastore}
			If ($MatchingDatastore){
				
				#VMdatastore Obj (already discovered)
				$VMdatastoreInstance = $discoveryData.CreateClassInstance("$MPElement[Name='Community.VMware.Class.Datastore']$")
				$VMdatastoreInstance.AddProperty("$MPElement[Name='Community.VMware.Class.Datastore']/DatastoreId$", [string]$MatchingDatastore.'[Community.VMware.Class.Datastore].DatastoreId'.Value )
				$VMdatastoreInstance.AddProperty("$MPElement[Name='Community.VMware.Class.vCenter']/vCenterServerName$", $vCenterServerName )
				
				#VM reference Host
				$rel1 = $discoveryData.CreateRelationshipInstance("$MPElement[Name='Community.VMware.Relationship.VirtualMachineReferencesDatastore']$")
				$rel1.Source = $VMInstance
				$rel1.Target = $VMdatastoreInstance
				$discoveryData.AddInstance($rel1)
			}
		}
	}
}
Try {Disconnect-VIServer -Server $connection -Confirm:$false}
Catch {DefaultErrorLogging}
$discoveryData