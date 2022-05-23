$vCenter = Read-Host "Enter the vCenter server name"
Connect-VIServer $vCenter

$vmhosts = get-vmhost * 
$vmhosts | Sort Name -Descending | % { $server = $_ |get-view; `
    $server.Config.Product | select `
    @{ Name = "Server Name"; Expression ={ $server.Name }}, `
    Name, Version, Build, FullName, ApiVersion }
