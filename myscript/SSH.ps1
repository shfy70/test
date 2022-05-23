$wokhosts = Get-VMHost  #Edit this in branch
Get-VMHostService -VMHost wokhosts | ?{$_.Label -eq "SSH"} | Start-VMHostService