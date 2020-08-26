#Requires -RunAsAdministrator

function RenameHost(){
	
	#Perform rename using 'hostname' tag from AWS metadat
	$taggedName = Get-LocalInstanceTagValue("Hostname")

	if($null -ne $taggedName)
	{
		if($taggedName -ne "")
		{
			Rename-Computer -NewName $taggedName -Force 
		}
	}

    return
}

function InstallPowershellModules(){
    
}

function Get-LocalInstanceTagValue([string] $tagName)
{
	$result = Invoke-WebRequest -Uri http://169.254.169.254/latest/dynamic/instance-identity/document -UseBasicParsing
	$meta = ConvertFrom-Json($result.Content)
	$instanceId = $meta.instanceId
	
	if($null -eq $instanceId) 
	{
		Write-Host "Cannot access and / or parse AWS metadata - are you really running in AWS?"
		exit
	}
	
	$localtags = get-ec2tag  -Filter @{ Name="resource-id"; Values=$instanceId }

	return $localTags.Where({$_.Key -eq "Hostname"}).Value
}

function Set-LicenseServerSettings([string] $RemoteLicenseAddress, [string] $ServiceUrl = "", [bool] $AllowSharing = $false)
{
	Write-Output "Setting license server settings:" `
		"`tUse Remote Server ($RemoteLicenseAddress)" `
		"`tAlternative Renewal Service URL: ($ServiceUrl)" `
		"`tAllow Remote Sharing: ($AllowSharing)" 

	if(!(Test-Path -Path 'HKLM:\SOFTWARE\WOW6432Node\Cinegy LLC\Cinegy\License')) {
		New-Item -Path 'HKLM:\SOFTWARE\WOW6432Node\Cinegy LLC\Cinegy\License' -Force -ErrorAction SilentlyContinue | Out-Null
	}

	#$serviceUrl = "https://api.central.cinegy.com/awsmrkt/v1/license/renew?serialId="
	if ($ServiceUrl) {
		Set-ItemProperty -path 'HKLM:\SOFTWARE\WOW6432Node\Cinegy LLC\Cinegy\License' -Name 'LicenseRenewalUrl' -Value $ServiceUrl | Out-Null
	}
	else {
		Remove-ItemProperty -path 'HKLM:\SOFTWARE\WOW6432Node\Cinegy LLC\Cinegy\License' -Name 'LicenseRenewalUrl' -ErrorAction SilentlyContinue | Out-Null
	}

	if(!(Test-Path -Path 'HKLM:\SOFTWARE\Cinegy LLC\Cinegy\License')) {
		New-Item -Path 'HKLM:\SOFTWARE\Cinegy LLC\Cinegy\License' -Force -ErrorAction SilentlyContinue | Out-Null
	}

	#$RemoteLicenseAddress = "10.10.10.1"
	if ($RemoteLicenseAddress) {
		Set-ItemProperty -path 'HKLM:\SOFTWARE\Cinegy LLC\Cinegy\License' -Name 'LicenseServerAddress' -Value $RemoteLicenseAddress | Out-Null
	}
	else {
		Remove-ItemProperty -path 'HKLM:\SOFTWARE\Cinegy LLC\Cinegy\License' -Name 'LicenseServerAddress' -ErrorAction SilentlyContinue | Out-Null
	}
	
	if($AllowSharing) {
		Set-ItemProperty -path 'HKLM:\SOFTWARE\WOW6432Node\Cinegy LLC\Cinegy\License' -Name 'AllowRemoteConnections' -Value 1 | Out-Null
	}
	else {		
		Set-ItemProperty -path 'HKLM:\SOFTWARE\WOW6432Node\Cinegy LLC\Cinegy\License' -Name 'AllowRemoteConnections' -Value 0 | Out-Null
	}
}

${injected_content}