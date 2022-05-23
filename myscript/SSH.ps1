$wokhosts = Get-VMHost
Get-VMHostService -VMHost wokhosts | ?{$_.Label -eq "SSH"} | Start-VMHostService