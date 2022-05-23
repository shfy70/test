$wokhosts = Get-VMHost  #This is from OpenText
Get-VMHostService -VMHost wokhosts | ?{$_.Label -eq "SSH"} | Start-VMHostService