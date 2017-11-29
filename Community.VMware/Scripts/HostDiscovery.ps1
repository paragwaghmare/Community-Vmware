﻿param($sourceId,$managedEntityId,$vCenterServerName)

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

$ScriptName = 'Community.VMware.Discovery.Host.ps1'
$api = new-object -comObject 'MOM.ScriptAPI'
$discoveryData = $api.CreateDiscoveryData(0, $sourceId, $managedEntityId)

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
	}
}

If ($connection.IsConnected -ne $True){
	ExitPrematurely ("Unable to connect to vCenter server " + $vCenterServerName)
}

Try {$VMhosts = Get-View -Server $connection -ViewType HostSystem -Property Name,Parent | Select Name,Parent,MoRef}
Catch {DefaultErrorLogging}

If (!$VMhosts){
	Try {Disconnect-VIServer -Server $connection -Confirm:$false}
	Catch {DefaultErrorLogging}
	ExitPrematurely ("No Hosts found in vCenter " + $vCenterServerName)
}

ForEach ($VMhost in $VMhosts){

	If ($VMhost.Parent.Type -eq 'ClusterComputeResource'){
		$IsStandalone = 'False'
	}
	Else {$IsStandalone = 'True'}

	#Host Obj
	$VMhostObj = $discoveryData.CreateClassInstance("$MPElement[Name='Community.VMware.Class.Host']$")
	$VMhostObj.AddProperty("$MPElement[Name='Community.VMware.Class.Host']/HostName$", $VMhost.Name)
	$VMhostObj.AddProperty("$MPElement[Name='Community.VMware.Class.Host']/HostId$", [string]($VMhost.MoRef))
	$VMhostObj.AddProperty("$MPElement[Name='Community.VMware.Class.Host']/IsStandalone$", $IsStandalone)
	$VMhostObj.AddProperty("$MPElement[Name='Community.VMware.Class.vCenter']/vCenterServerName$", $vCenterServerName)
	$VMhostObj.AddProperty("$MPElement[Name='System!System.Entity']/DisplayName$", $VMhost.Name)
	$discoveryData.AddInstance($VMhostObj)
	
	#vCenter Obj (already discovered)
	$vCenterObj = $discoveryData.CreateClassInstance("$MPElement[Name='Community.VMware.Class.vCenter']$")
	$vCenterObj.AddProperty("$MPElement[Name='Community.VMware.Class.vCenter']/vCenterServerName$", $vCenterServerName )

	#vCenter Hosts Host
	$rel1 = $discoveryData.CreateRelationshipInstance("$MPElement[Name='Community.VMware.Relationship.vCenterHostsHost']$")
	$rel1.Source = $vCenterObj
	$rel1.Target = $VMhostObj
	$discoveryData.AddInstance($rel1)
}
Try {Disconnect-VIServer -Server $connection -Confirm:$false}
Catch {DefaultErrorLogging}
$discoveryData