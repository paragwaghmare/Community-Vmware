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

$ScriptName = 'Community.VMware.Discovery.Cluster.ps1'
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

Try {$VMclusters = Get-Cluster -Server $connection | Select Name,Id,HAEnabled}
Catch {DefaultErrorLogging}

If (!$VMclusters){
	Try {Disconnect-VIServer -Server $connection -Confirm:$false	}
	Catch {DefaultErrorLogging}
	ExitPrematurely ("No clusters found in vCenter " + $vCenterServerName)
}

ForEach ($Cluster in $VMclusters){

	#Cluster Obj
	$ClusterObj = $discoveryData.CreateClassInstance("$MPElement[Name='Community.VMware.Class.Cluster']$")
	$ClusterObj.AddProperty("$MPElement[Name='Community.VMware.Class.Cluster']/ClusterName$", $Cluster.Name )
	$ClusterObj.AddProperty("$MPElement[Name='Community.VMware.Class.Cluster']/ClusterId$", $Cluster.Id )
	$ClusterObj.AddProperty("$MPElement[Name='Community.VMware.Class.Cluster']/HAEnabled$", [string]($Cluster.HAEnabled))
	$ClusterObj.AddProperty("$MPElement[Name='Community.VMware.Class.vCenter']/vCenterServerName$", $vCenterServerName)
	$ClusterObj.AddProperty("$MPElement[Name='System!System.Entity']/DisplayName$", $Cluster.Name )
	$discoveryData.AddInstance($ClusterObj)
	
	#vCenter Obj (already discovered)
	$vCenterObj = $discoveryData.CreateClassInstance("$MPElement[Name='Community.VMware.Class.vCenter']$")
	$vCenterObj.AddProperty("$MPElement[Name='Community.VMware.Class.vCenter']/vCenterServerName$", $vCenterServerName )

	#vCenter Hosts Cluster
	$rel1 = $discoveryData.CreateRelationshipInstance("$MPElement[Name='Community.VMware.Relationship.vCenterHostsCluster']$")
	$rel1.Source = $vCenterObj
	$rel1.Target = $ClusterObj
	$discoveryData.AddInstance($rel1)
}
Try {Disconnect-VIServer -Server $connection -Confirm:$false}
Catch {DefaultErrorLogging}
$discoveryData