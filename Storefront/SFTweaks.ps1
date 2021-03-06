#Speeds up storefront by adding some tweaks
#
#What it does?
##Disables signature checking in .NET
##Enables pool sockets in storefront
##Disables Netbios
#
#How to run?
#Run from Storefront server and as Administrator 
#
#Ryan Butler 10-03-2014

Clear-Host
#Imports modules needed
& 'C:\Program Files\Citrix\Receiver StoreFront\Scripts\importModules.ps1'



######################DON'T EDIT BELOW LINE
$servers = (Get-DSClusterMembersName).hostnames

$storenames = (get-dsstores).FriendlyName

foreach ($server in $servers)
{
	Write-Host Checking $server
	$flag = 0
	$serverpath = "\\" + $server + "\c$\"
	Write-Host "Checking for .NET Signature tweak..." -ForegroundColor Magenta
	$locations = (Get-ChildItem -Path ($serverpath + "Windows\Microsoft.NET\Framework64\") | Where-Object { $_.PSIsContainer -eq $true }) + (Get-ChildItem -Path ($serverpath + "Windows\Microsoft.NET\Framework\") | Where-Object { $_.PSIsContainer -eq $true })

	foreach ($location in $locations)
	{
		Write-Host "Checking: " $location.FullName
		$xmlpath = $location.FullName + "\Aspnet.config"
		if (Test-Path $xmlpath)
		{
			Write-Host "Found config and checking..." -ForegroundColor yellow
			#Loads XML
			$config = New-Object System.Xml.XmlDocument
			$config.Load($xmlpath)

			#Has it been changed already?
			if ($config.configuration.runtime.generatePublisherEvidence.enabled -eq $false)
			{
				Write-Host "Already changed" -ForegroundColor Green
			}
			else
			{
				Write-Host "Changing and backing up file..." -ForegroundColor Red
				#backs up file
				Rename-Item -Path $xmlpath -NewName "Aspnet.config.old"

				#Creates new element for edit
				$add = $config.CreateElement('generatePublisherEvidence')
				$add.SetAttribute('enabled','false')

				#edits and saves XML
				$runs = $config.configuration.runtime
				$runs.AppendChild($add) | Out-Null
				$config.Save($xmlpath)

				#sets restart IIS flag only if change was completed
				$flag = 1

			}

		}
		else
		{
			Write-Host ".NET Config file not found" -ForegroundColor Gray
		}



	}

	Write-Host "Checking for pooled sockets..." -ForegroundColor Magenta

	foreach ($storename in $storenames)
	{
		Write-Host $storename
		#Config file path
		$config = $serverpath + "inetpub\wwwroot\Citrix\" + $storename + "\web.config"

		if (Test-Path $config)
		{
			Write-Host "File found and checking for pooled sockets..." -ForegroundColor Yellow
			$xml = New-Object System.Xml.XmlDocument
			$xml.Load($config)
			$farmset = $xml.configuration. 'citrix.deliveryservices'.wing.farmsets.farmset
			if ($farmset.pooledSockets -eq "off")
			{
				Write-Host "Pooled sockets disabled.. Now Enabling.." -ForegroundColor Red
				Rename-Item -Path $config -NewName "web.config.old"
				$farmset.pooledSockets = "on"
				$xml.Save($config)
				#setting IIS reset flag
				$flag = 1
			}
			else
			{
				Write-Host "Pooled sockets already enabled.." -ForegroundColor Green
			}
		}
		else
		{
			Write-Host "Webconfig file not found..." -ForegroundColor Red
		}
	}




	#resets IIS if config has changed
	if ($flag -eq 1)
	{
		Write-Host "Restarting IIS..."
		iisreset $server
	}

	#disables NETBIOS
	#uses WMI which sometimes is broken
	Write-Host "Disabling NETBIOS" -ForegroundColor Magenta
	$nics = Get-WmiObject Win32_NetworkAdapterConfiguration -Filter "ipenabled = 'true'" -ComputerName $server -ErrorAction Continue
	foreach ($nic in $nics)
	{
		Write-Host $nic.servicename
		$nic.SetTcpipNetbios(2) | Out-Null -ErrorAction Continue
	}


}
