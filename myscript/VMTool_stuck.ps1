#  Created by Norman Yang
# This short script trying to list all the VMs (currently installing VMware tools) and associated host
$StuckVM = Get-View -ViewType VirtualMachine -Property 'name' -Filter @{'RunTime.ToolsInstallerMounted'='True'}
$vmlist = $StuckVM.Name
$n = $StuckVM.Count
Write-Host "There are a total of $n Virtual Machines currently in the process of installing VMware Tools `n`n`n`n"
Write-Host "VM Name                               Host Name `n`n`n"
foreach ( $vm in $vmlist)
   {  
    $vmdetail = Get-VM $vm                  # Get detailed virtual machine name
    $hstdetail = $vmdetail | Get-VMHost     # Get host name for the targeting virtual machine  
    $name = $hstdetail.Name                 # Get brief host name for output
      Write-Host "$vm  `t is stuck on host:  $name     `n"
   }
   