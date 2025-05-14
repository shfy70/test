Param (

	[Parameter(Mandatory=$true,Position=1,HelpMessage="vCenter's VM Name")]
		[Alias("vCenter")]
	[System.String]$VC
	,
	[Parameter(Mandatory=$true,Position=2,HelpMessage="ESXi Hosts' common suffix")]
		[Alias("VMHostSuffix","ESXiSuffix")]
	[System.String]$HostSuffix
	,
	[Parameter(Mandatory=$false,Position=3,HelpMessage="ESXi Hosts' postfix number start")]
		[ValidateRange(1,98)]
		[Alias("PostfixFirst","Start")]
	[Int]$PostfixStart = 1
	,
	[Parameter(Mandatory=$false,Position=4,HelpMessage="ESXi Hosts' postfix number end")]
		[ValidateRange(2,99)]
		[Alias("PostfixLast","End")]
	[Int]$PostfixEnd = 9
	,
	[Parameter(Mandatory=$false,Position=5,HelpMessage="Add ESXi Hosts' postfix leading zero")]
	[Switch]$AddZero = $false
)

Begin {

	Set-PowerCLIConfiguration -DefaultVIServerMode Multiple -Scope Session -Confirm:$false |Out-Null
	If ($PostfixEnd -le $PostfixStart) {Throw "PostfixEnd must be greater than PostfixStart"}
}

Process {

	$VMHostName = ''
	$cred = Get-Credential -UserName root -Message "Common VMHost Credentials"
	If ($cred) {
		$hosts = @()
		
		For ($i=$PostfixStart; $i -le $PostfixEnd; $i++) {
			If ($AddZero -and $i -match '^\d{1}$') {
				$hosts += $HostSuffix + '0' + $i
			} Else {
				$hosts += $HostSuffix + $i
			}
		}
		Connect-VIServer $hosts -WarningAction SilentlyContinue -ErrorAction SilentlyContinue -Credential $cred |select Name,IsConnected |ft -AutoSize
		If ($global:DefaultVIServers.Length -ne 0) {
			$VMHostName = (Get-VM -ErrorAction SilentlyContinue |? {$_.Name -eq $VC} |select -ExpandProperty VMHost).Name
			Disconnect-VIServer -Server '*' -Force -Confirm:$false
		}
	}
}

End {

	If ($VMHostName)	{
		$Properties = [ordered]@{
			VC     = $VC
			VMHost = $VMHostName
		}
		$Object = New-Object PSObject -Property $Properties
		return $Object
	}
	Else {return $null}
}
