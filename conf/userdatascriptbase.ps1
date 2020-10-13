#Requires -RunAsAdministrator

$licenseserverurl = "https://central.cinegy.com/api_awsmrkt/v1/license"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$telemetryServerUrl = "https://telemetry.cinegy.com"

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
	$installModulesVersion = "0.0.3"
    $rootPath = $env:TEMP 

	#download binaries and unzip
	$client = New-Object System.Net.WebClient
	$modulePackageUrl = "https://github.com/Cinegy/powershell-install-module/releases/download/v$installModulesVersion/cinegy-powershell-installmodule.zip"
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
	Expand-Archive -Path $downloadPath -DestinationPath $moduleInstallPath -Force
	
	#import the module, ready for use
	Import-Module $Env:CINEGY_INSTALL_MODULE_PATH\Cinegy.InstallModule.dll	
}

function Install-DefaultPackages(){
	Install-Product -PackageName Thirdparty-VCRuntimes-v150 -VersionTag prod
	Install-Product -PackageName Thirdparty-7Zip-Stable -VersionTag prod
	Install-Product -PackageName Thirdparty-NotepadPlusPlus-v7.x -VersionTag prod
	Install-Product -PackageName Thirdparty-Firefox-Stable -VersionTag prod
}

function Send-TelemetryMessage([string] $Message, [string] $IndexName, [string] $OrganizationName="cinegy", [string] $Level="Info" ,[string] $tags="aws,production")
{
	#create an object of correct structure to steer the log record in ElasticSearch (this will be first line sent to server)
	$index = [PSCustomObject]@{
		index = [PSCustomObject]@{
			_index = "$IndexName-$OrganizationName-$([System.DateTime]::UtcNow.Year).$([System.DateTime]::UtcNow.Month.ToString("00")).$([System.DateTime]::UtcNow.Day.ToString("00"))"
			_type = "logevent"
			}
	}

	#create an object of minimum structure to send to ElasticSearch (this will be the second line sent to server)
	$log = [PSCustomObject]@{
		Level = $Level
		Time = Get-Date -format o
		Tags = $tags
		Host = [system.environment]::MachineName
		Logger = "PowershellTelemetryScript"
		Key = "Message"
		Message = $Message
	}

	#convert the custom objects to JSON format, with each object on a single line
	$body = (ConvertTo-Json -InputObject $index -Compress) + "`n" + (ConvertTo-Json -InputObject $log -Compress)

	#print resulting string to console
	Write-Host $body

	#create webclient object, add JSON content-type header, and POST to telemetry server
	$web = new-object net.webclient
	$web.Headers.add("Content-Type", "application/json")
	$web.UploadString("$telemetryServerUrl/_bulk",$body)
}

function Get-StringHash([string] $String,[string]$HashName="MD5")
{
    $StringBuilder=New-Object System.Text.StringBuilder
    [System.Security.Cryptography.HashAlgorithm]::Create($HashName).ComputeHash([System.Text.Encoding]::UTF8.GetBytes($String)) |
		ForEach-Object { [Void]$StringBuilder.Append($_.ToString("x2"))}
    return $StringBuilder.ToString()
}

function Get-CinegyMachineFingerprint($UseTaggedHostname = $true)
{
    $fingerprintVersion = "01"
    $cpuKey = Get-ItemProperty "HKLM:\HARDWARE\DESCRIPTION\System\CentralProcessor\0"
    $biosKey = Get-ItemProperty "HKLM:\HARDWARE\DESCRIPTION\System\BIOS"

	$computerName = $env:computername
	if($UseTaggedHostname) { $computerName = Get-LocalInstanceTagValue("Hostname") }

    $fingerprintRaw = "$($computerName)-#-$($cpuKey.Identifier)-#-$($biosKey.BaseBoardProduct)-#-$($biosKey.BaseBoardManufacturer)-#-$($biosKey.BIOSVendor)".Replace(" ","").ToLowerInvariant();

    $hashedPrint = Get-StringHash($fingerprintRaw) 
    return "$($hashedPrint)$fingerprintVersion"
}

function Get-AwsSignedMetadata()
{
  try #read AWS metadata from instance
  {
      $metadataUrl = "http://169.254.169.254/latest/dynamic/instance-identity/pkcs7"
      $signedMetadata = Invoke-RestMethod -UseBasicParsing  -Method Get -Uri $metadataUrl  
      return $signedMetadata
  }
  catch
  {
      Write-Output "Problem getting AWS Instance Metadata: $PSItem"
	  Send-TelemetryMessage -Message "Problem getting AWS Instance Metadata: $PSItem" -IndexName "awsmarketplace" -Level "Error"
  }
}

function Get-AwsLicense($UseTaggedHostname = $false)
{
  # note - this will only work if the account ID or instance ID has a back-end record, 
  # or if there is a valid Cinegy marketplace code embedded in the signedmetadata - otherwise this will fail

  try{   	  
	  Write-Output "Getting license file from server URL: $licenseserverurl"
      $headers = @{'accept'="application/xml";'content-type'="application/json"}
	  $signedMetadata = Get-AwsSignedMetadata 
	  Add-Type -AssemblyName System.Web
	  $encodedSignedMetadata = [System.Web.HttpUtility]::UrlEncode($signedMetadata)
      $fingerprint = Get-CinegyMachineFingerprint -UseTaggedHostname $UseTaggedHostname
	  $encodedfingerprint = [System.Web.HttpUtility]::UrlEncode($fingerprint)
	  $uri = "$licenseserverurl/negotiate?MachineId=$encodedfingerprint&AwsInstanceMetadata=$encodedSignedMetadata"
	  
	  New-Item -ItemType Directory -Path "C:\ProgramData\Cinegy\Software Licenses\" -Force -ErrorAction SilentlyContinue | Out-Null

      Invoke-RestMethod -UseBasicParsing -Method Post -Uri $uri -Headers $headers -OutFile "C:\ProgramData\Cinegy\Software Licenses\aws-instance-license.cinelic"   
  }
  catch
  {
      Write-Output "Problem negotiating license from license server: $PSItem"
	  Send-TelemetryMessage -Message "Problem getting license key from license server: $PSItem" -IndexName "awsmarketplace" -Level "Error"
  }
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