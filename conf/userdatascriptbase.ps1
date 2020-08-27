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

function Install-CinegyPowershellModules(){
	#define Cinegy Install Modules version
	$installModulesVersion = "0.0.1"
    $rootPath = $env:TEMP 

	#download binaries and unzip
	$client = New-Object System.Net.WebClient
	$modulePackageUrl = "https://github.com/Cinegy/powershell-install-module/releases/download/v$installModulesVersion/cinegy-powershell-installmodule-v$installModulesVersion.zip"
	$downloadPath = "$rootPath\cinegy-powershell-installmodule.zip"
	Write-Output "Downloading Cinegy Installation Powershell Module from $modulePackageUrl to $downloadPath"
    	
	$client = new-object System.Net.WebClient
	$client.DownloadFile($modulePackageUrl, $downloadPath)
	
	$moduleInstallPath = "C:\Program Files\Cinegy\Installation Powershell Module"

	New-Item -Path $moduleInstallPath -ItemType Directory -ErrorAction SilentlyContinue
	[System.Environment]::SetEnvironmentVariable('CINEGY_INSTALL_MODULE_PATH', $moduleInstallPath, [System.EnvironmentVariableTarget]::Machine)
	$Env:CINEGY_INSTALL_MODULE_PATH = $moduleInstallPath

	Write-Output "Unpacking Cinegy Installation Powershell Module to $moduleInstallPath"
	
	Write-Host "Expanding bundle $downloadPath"
	Expand-Archive -Path $downloadPath -DestinationPath $moduleInstallPath
	
	#import the module, ready for use
	Import-Module $Env:CINEGY_INSTALL_MODULE_PATH\Cinegy.InstallModule.dll	
}

function Install-DefaultPackages(){
	Install-Product -PackageName Thirdparty-VCRuntimes-v150 -VersionTag prod
	Install-Product -PackageName Thirdparty-7Zip-Stable -VersionTag prod
	Install-Product -PackageName Thirdparty-MetricBeat-v6.x -VersionTag dev
	Install-Product -PackageName Thirdparty-NotepadPlusPlus-v7.x -VersionTag prod
	Install-Product -PackageName Thirdparty-Firefox-Stable -VersionTag prod
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