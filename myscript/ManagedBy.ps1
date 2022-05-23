#.SYNOPSIS
#***********************************************************************
# Copyright (C) 2012 VMware, Inc. All rights reserved.
# -- VMware Confidential
#***********************************************************************
# IMPORTANT!
# THIS SCRIPT IS PROVIDED “AS IS” WITHOUT WARRANTY OF ANY KIND.
# VMWARE FURTHER DISCLAIMS ALL IMPLIED WARRANTIES INCLUDING, WITHOUT
# LIMITATION, ANY IMPLIED WARRANTIES OF MERCHANTABILITY, NONINFRINGEMENT,
# OR OF FITNESS FOR A PARTICULAR PURPOSE. THE ENTIRE RISK ARISING OUT OF
# THE USE OR PERFORMANCE OF THIS SAMPLE SCRIPT REMAINS WITH YOU. IN NO
# EVENT SHALL VMWARE, ITS AUTHORS, OR ANYONE ELSE INVOLVED IN THE
# CREATION, PRODUCTION, OR DELIVERY OF THIS SCRIPT BE LIABLE FOR ANY
# DAMAGES WHATSOEVER (INCLUDING, WITHOUT LIMITATION, CONSEQUENTIAL
# DAMAGES, INDIRECT DAMAGES, DIRECT DAMAGES, INCIDENTAL DAMAGES, OR
# DAMAGES FOR LOSS OF BUSINESS PROFITS, BUSINESS INTERRUPTION, LOSS
# OF BUSINESS INFORMATION, OR OTHER PECUNIARY LOSS) ARISING OUT OF THE
# USE OF OR INABILITY TO USE THIS SCRIPT OR DOCUMENTATION, EVEN IF VMWARE
# HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGES.
#
# This script removes/adds the ManagedBy property for VM(s) registered in a vCenter inventory.
#
# If a VM has the ManagedBy property initialized, vSphere clients will show a warning when you edit the VM's
# settings and some the VM's features, like DRS, will be disabled. This script is intended to manage this
# property manually only in cases where Site Recovery Manager marked your protected VM with the ManagedBy
# property as the result of an error during reprotect/failback. Please, be very careful with your operations
# on VMs. The ManagedBy property is set intentionally for some VMs, like placeholders, VRMS, VRS, etc. Also,
# please make sure you do not change this flag for VMs that are critical to the operation of other extensions.
# Use it only for production VMs that you are 100% sure are not supposed to have the ManagedBy property set.
#
# This script is a workaround for an issue where VMware engineers have been unable to find a root cause at the
# time this script was created. Please search VMware KB articles and community forums by the keyword
# "Managed By" to check if problem is already resolved. If not, you can greatly help the community and VMware
# if you know a sequence of steps that reproduce this issue. Please share your knowledge about how to
# reproduce this issue and VMware engineers will fix it.
# Thank you for your help!
#
# Please pay attention to this help section and make sure you understand how this script works. If you need to
# test it, please use a test environment, not a production one. Although the script is not destructive, it is
# possible you could encounter some side-effects from changing the ManagedBy property.
#
#.DESCRIPTION
# This script can do the following operations:
# - Show a list of vCenter extensions (like Site Recovery Manager, vSphere Update Manager, vSphere Replication
#   Management Server, etc.) that are registered on a vCenter instance.
# - Traverse all VMs managed by a vCenter instance and show the extension key if VM is managed by an
#   extension.
# - Remove or set the ManagedBy property for a set of VMs.
#
#.PARAMETER Cmd
# Specifies the command that should be executed. The available commands are:
#   GetVMs  - returns array of VM objects which are managed by a specific extension and are of a certain type.
#   ScanVMs - traverses all VMs registered in the VC inventory and check their ManagedBy property, then
#             show a list of extension keys and VMs managed by extensions with those keys.
#   Clear   - removes the extension key from the ManagedBy property. The ManagedBy field will be set to
#             nothing (null).
#   Set     - sets the ManagedBy property and the Managed type value to the specified extension key and type.
#   Ver     - returns the versions of this script, of PowerShell and of PowerCLI.
#
# Commands require following additional parameters.
#   GetVMs:  -ExtKey  - optional if there is only one SRM extension registered on VC, otherwise required. If
#                       required, please specify the extension shown by command ScanVMs or by the warning
#                       message. If required but missing, a warning message will be generated and the script
#                       will show the SRM extensions registered on VC.
#            -VMType  - optionally specifies a filter for the managed VM type returned. The Default value
#                       is "placeholderVm".
#            -SkipDiskFilter
#                     - optional switch that, if set, will cause this command to ignore the number of
#                       disks added to a VM. Otherwise, the result list will contain only VMs with disks.
#                       Default parameter value is $false, i.e. only VMs with disk will be included in
#                       output by default. See details for the switch for more help.
#            -Verbose - optional switch. By default verbose information will not be shown. Setting this
#                       switch is useful when you need to know why each VM was included or skipped.
#   Clear:   -VMs     - required. Array of VM objects which should be processed. The ManagedBy Property will
#                       be deleted for these objects.  This command ignores -ExtKey and -VMType parameters
#                       because the ManagedBy property will be deleted from VM.
#   Set:     -ExtKey  - optional if there is only one SRM extension registered on VC, otherwise required the
#                       same as for GetVMs.
#                       This command will set the ManagedBy property to this value if it is an extension that
#                       is registered in VC. If it is not a registered extension, the VC task will fail.
#            -VMType  - optionally specifies the managed VM type to set. The Default value is "placeholderVm".
#   ScanVMs: -Verbose - optional switch. By default, verbose information will not be shown.
#
#.PARAMETER ExtKey
# Specifies the extension key to be set or cleared. Since this script is designed as workaround for an SRM
# issue, the default SRM extension key is "com.vmware.vcDr", but it is possible to set an extension key to a
# custom value. This is useful for N:1 scenarios. A Custom SRM extension key always starts with the prefix
# "com.vmware.vcDr-". This parameter can be set for the 'GetVMs' and 'Set' commands. Other commands ignore it.
#
#.PARAMETER VMType
# Managed VM type. The default value is "placeholderVm" which is type of placeholder VM for SRM.
#
#.PARAMETER VMs
# An array of VMs to be processed. The script is intended to be used in several steps. First users can
# find or create a set of VMs to be processed with the 'ScanVMs' and 'GetVMs' commands.  Then users should
# check the list of VMs returned, making sure that all of them should be processed in the next step. To remove
# a VM from array:
#   a) use the Where-Object cmdlet. (see Examples 3 and 4)
#   b) create new array which is a sub-array of result returned from the 'GetVMs' command. (see Example 5)
#   c) remove VMs from the result array. (see Example 6)
# After verifying that the array contains only those VMs that should have their ManagedBy property
# cleared/set, that array can then be used as a parameter for the corresponding 'Clear' or 'Set' command.
#
#.PARAMETER SkipDiskFilter
# Switch parameter. By default, the script outputs only those VMs which have disks.  If set, the
# script will ignore the disk criteria and output all VMs. This is designed for the typical SRM scenario
# where placeholder VMs don't have disks.
#
#.EXAMPLE
# .\ManagedBy.ps1 -Cmd ScanVMs
#
# Prints the extensions registered on VC along with the VMs managed by those extensions.
#
#.EXAMPLE
# .\ManagedBy.ps1 -Cmd GetVMs -Verbose
#
# Returns an array of VMs managed by the SRM extension (1:1 scenario) and prints the array on the screen.
#
#.EXAMPLE
# $myVMs = .\ManagedBy.ps1 -Cmd GetVMs -Verbose | Where-Object { $_.Host.Name -eq "MyHostName"}
# .\ManagedBy.ps1 -Cmd Clear -VMs $myVMs
#
# Returns an array of VMs managed by the SRM extension, filters them by host name (only VMs on host
# "MyHostName" will be in the array returned from the Where-Object cmdlet) and clears the ManagedBy property
# for the VMs in the filtered array.
#
#.EXAMPLE
# $vms = .\ManagedBy.ps1 -Cmd GetVMs -ExtKey "com.vmware.vcDr-myOldSrmExtension" -Verbose
# $myVMs = $vms | Where-Object { $_.Name.StartsWith("vm0") }
# .\ManagedBy.ps1 -Cmd Set -VMs $myVMs
#
# Let's suppose we had SRM extension with the key "com.vmware.vcDr-myOldSrmExtension".  The extension has
# been deleted now but the placeholder VMs are still registered with that extension key. We would like to
# register them with the new SRM extension key.
# The first line returns an array of VMs marked as managed by the SRM extension
# "com.vmware.vcDr-myOldSrmExtension".  The second line filters them by VM name prefix (only VMs with
# names starting with "vm0" will be in the array). The third line sets the ManagedBy property for the VMs in
# the filtered array to be managed by SRM with a VM type set to 'placeholderVm'.
# The extension key and VM type get their values from the defaults in the final Set command.
#
#.EXAMPLE
# $wholeResult = .\ManagedBy.ps1 -Cmd GetVMs -Verbose
# $myVMs = $wholeResult[0..2],[5]
# $myVMs += Get-VM -Name "MyProductionVm"
# .\ManagedBy.ps1 -Cmd Clear -VMs $myVMs
#
# The first line returns an array of VMs managed by the SRM extension. The second line creates another array
# that includes only parts of the origianl array: VMs with indexes 0, 1, 2 and 5 from the array $wholeResult.
# The third line adds a VM with the name "MyProductionVm" to the array.  The final line clears the ManagedBy
# property for those 5 VMs we assembled in the $myVMs array.
#
#.EXAMPLE
# $myVMs = .\ManagedBy.ps1 -Cmd GetVMs -Verbose
# $myVMs.RemoveAt(3)
# $myPlaceholder = $myVMs | Where-Object {$_.Name -eq "MyVM"}
# $myVMs.Remove($myPlaceholder)
# .\ManagedBy.ps1 -Cmd Clear -VMs $myVMs
#
# This first line returns an array of VMs managed by the SRM extension. The second line removes the VM
# at index 3 (remember that indexes start at 0!).  Next line initializes the $myPlaceholder variable to the VM
# object result array, which contains VMs named "MyVM". Line 4 removes the objects in $myPlaceholder from
# array $myVMs. The last step uses the script to clear the ManagedBy property for all the VMs returned in
# line 1, except for the 2 VMs that were excluded from the array in lines 2-4.
#
#.NOTES
# The key command for this script is GetVMs. It passes VMs through 3 filters: management extension, managed
# type and disk attached. If a VM has at least one disk and both the ManagedBy as well as the Managed type
# properties match the specified values, it is probably a VM that has been wrongly marked as managed by SRM.
# It will be included in the output VM array. The Filters for the VM managed type and disk can be disabled. To
# disable the managed type filter, set the $VMType parameter to an empty string, and to disable the disk
# filter use the SkipDiskFilter switch.
#
#.OUTPUTS
# The results depends on the command. No commands except GetVMs returns any object(s). The GetVMs command
# returns and array of VMs from the VC inventory which passed all the active filters. This array is of the
# type System.ArrayList and can be used for verifying that all the VMs in the array should be processed on the
# next step. Also, you can add or delete object from that array. These operations will not add or delete VMs
# from the VC inventory, they will just change the set of objects tp be used for the next operation (Clear or
# Set).
 param([string] $Cmd,
      [string]$ExtKey = "",
      [string]$VMType = "placeholderVm",
      $VMs,
      [switch]$SkipDiskFilter,
      [switch]$Verbose = $false)

#$ExtKey is intentionally set to be an empty string. If the user did not specify it we'll look for all SRM
# extensions. In the case of a single extension, we'll save it to a variable and continue work. Otherwise, if
# we have multiple SRM extensions (N:1 scenario), we'll ask for an extension key.
#$VMType is "placeholderVm" by default because this is the type of VM that most likely needs its ManagedBy
# property reset.

# Writes verbose messages to the screen. The Write-Verbose cmdlet doesn't have a -NoNewLine parameter, this
# method does have it.  The disadvantage is that this method doesn't behave the same as Write-Verbose for
# $VerbosePreference values "Inquire" and "Stop", but for our script it should be ok for most users.
Function LogVerbose($msg, [bool]$noNewLine=$false, $foreColor="Gray") {
   if ($Verbose -OR $VerbosePreference -ine "SilentlyContinue") {
      Write-Host $msg -NoNewLine:$noNewLine -ForegroundColor:$foreColor
   }
}

Function WriteErrorAboutMultipleVCConnections {
   $connectionsCount = $global:DefaultVIServers.Count
   $msg = "PowerCLI session is connected to more than one ($connectionsCount) VI servers:`r`n"
   $msg += "$DefaultVIServers `r`n"
   $msg += "This mode is not supported by the script. "
   $msg += "We recommend you to create new PowerCLI session and connect to only one Virtual Center,`r`n"
   $msg += "otherwise you can mix VMs on protected and recovery sites and do operation on wrong VMs"
   Write-Host $msg -ForegroundColor:"Red"
}

# Looks for all extension keys currently registered in VC. The result returned by this function is not the
# same as the result returned by inspecting all VMs and fetching their 'ManagedBy' property. E.g if
# an extension "XYZ" has already been deleted or unregistered, this function will not return "XYZ". On the
# other hand, some VMs can still have "XYZ" in their ManagedBy property. Call the function GetAllVmExtensions
# to get all extensions persisted in all VMs.
Function GetRegisteredExtensions {
   # if PowerCLI session is not connected to VC, Get-View will generate an error and return $null
   $si = Get-View serviceInstance
   if ($null -eq $si) {
      Write-Host "PowerCLI is not connected to VC. Please run Connect-VIServer cmdlet" -ForegroundColor:"Red"
      exit 1
   }
   if ($si.Count -gt 1) {
      WriteErrorAboutMultipleVCConnections
      exit 2
   }
   $eman = Get-View $si.Content.ExtensionManager
   return $eman.ExtensionList
}

# Returns all registered SRM extensions.
# Note:
# Default SRM extension is "com.vmware.vcDr", custom extension always starts with prefix "com.vmware.vcDr-".
# This prefix is added to custom keys by the SRM installer and is not visible to the user in most cases
# (except for MOB and raw objects).  The SRM plugin for the vSphere Client removes this prefix before showing
# it in a special SRM dialog.  The vSphere Client shows the extension name (like "vCenter Site Recovery
# Manager") if an extension is registered. So, do not be confused if you see extension name for SRM without
# this prefix. When you specify parameter -ExtKey for the script (see list of params on top of script),
# you should specify the whole parameter, i.e. with prefix.
Function FindDrExtensions ([string]$ExtKeyPrefix = "com.vmware.vcDr") {
   $filteredExt = GetRegisteredExtensions | Where-Object { $_.Key.StartsWith($ExtKeyPrefix) }
   return $filteredExt
}

# Returns an array of objects made out of input object.
# When script or cmdlet returns array of objects as result, PowerShell by default analyzes output, and can
# convert it to single object, if array contains only one object, or change it to $null, if array is empty.
# This function converts objects to array.
Function ConvertToArray($obj) {
   if ($obj -is [array]) {
      return $obj
   } elseif ($null -ne $obj) {
      return ,@($obj)
   } else {
      return ,@()
   }
}

# Returns an array of VMs filtered by name.
# Note: Get-VM cmdlet returns:
#  - array of VMs - if multiple VMs were found,
#  - single VM object, not an array of one object - if only one VM was found
#  - $null - if no VM was found at all. It also prints an error. We do not suppress the error text in
#            this function.
# This function will always return array, so it is safe to call the Count method on the result, and use
# the result in foreach loop.
# The following is the number of elements in the array that will be returned:
#  - same number of VMs as Get-VM returned - if multiple VMs were found,
#  - single element array with one VM object - if only one VM was found by Get-VM
#  - zero-size array - if no VM was found at all by Get-VM cmdlet.
Function GetVmArray([string[]]$names = $null) {
   if ($null -ne $names) {
      $vms = Get-VM -Name $names
   } else {
      $vms = Get-VM
   }
   return ,(ConvertToArray($vms))
}

# Visit all VMs for getting the ManagedBy property value and add it to the result hashtable variable
# The key of the hashtable is a extensionKey as a string.  The value is an array of strings which are
# VM names
Function GetAllVmExtensions {
   $extensions = @{}
   $vms = GetVmArray
   $vmsCount = $vms.Count
   LogVerbose "Found $vmsCount VMs total" -foreColor:"Yellow"
   $vmIdx = 0
   foreach ($vm in $vms) {
      if ($vmsCount -ge 10) {
         ++$vmIdx
         $act = "Scanning all VMs"
         $percent = $vmIdx/$vmsCount*100
         Write-Progress -Activity $act -Status "In Progress" -PercentComplete $percent
      }

      LogVerbose "VM '$vm': is " -noNewLine:$true
      $vmVw = $vm | Get-View -Verbose:$false
      if ($null -ne $vmVw.Config.ManagedBy) {
         $extensionKey = $vmVw.Config.ManagedBy.ExtensionKey
         if ([string]::IsNullOrEmpty($extensionKey)) {
            LogVerbose "NOT" -noNewLine:$true -foreColor:"Yellow"
            LogVerbose " managed by any extension"
         } else {
            $type = $vmVw.Config.ManagedBy.Type
            LogVerbose "managed" -noNewLine:$true -foreColor:"Yellow"
            LogVerbose " by '$extensionKey', type='$type'" -noNewLine:$false
            $extensions[$extensionKey] += @($vm.Name)
         }
      } else {
         LogVerbose "NOT" -noNewLine:$true -foreColor:"Yellow"
         LogVerbose " managed by any extension" -NoNewLine:$false
      }
   }
   return $extensions
}

# Returns an array of VMs managed by a specific extension and having a matching 'ManagedBy.TypeName' field
Function GetManagedVMs([string]$extName, [string]$typeName, [bool]$SkipDiskFilter=$false) {
   # instead of .Net internal arrays, we'll use the ArrayList class which has Remove* methods to give the user
   # more flexibility to remove VMs from the result list without recreating it by filtering. Users can still
   # recreate the array, but RemoveAt() and Remove() will just add a small bit of flexibility.
   # Please pay attention to the fact that returning an ArrayList should be done with comma before the
   # variable to skip some processing and prevent the conversion of the ArrayList to a System.Array
   $vmsCandidates = New-Object System.Collections.ArrayList
   $vms = GetVmArray
   $vmsCount = $vms.Count
   LogVerbose "Found $vmsCount VMs" -foreColor:"Yellow"
   # Go though all VMs and check the extension to be matched, and some other criterias
   # We have tested the performance of both this loop in the script and filtering through the Where-Object
   # cmdlet. We did not find statistical significant difference between the script and the Where-object cmdlet
   # with script block based on an environment of 700+ VMs.
   # Just in case, the following line is how Where-Object cmdlet filtering would be done:
   # Get-VM | Where-Object -FilterScript { $vmVw = Get-View $_; $vmVw.Config.ManagedBy -ne $null -AND ^
   #  $vmVw.Config.ManagedBy.ExtensionKey -eq $extName }
   # Since we will write more diagnostic messages, and show a progress bar, and also do some additional
   # checks, we still need to have $vmView.  So, it is simpler to do this inside a script loop.
   $vmIdx = 0
   foreach($vm in $vms) {
      if ($vmsCount -ge 10) {
         ++$vmIdx
         $act = "Looking for VMs"
         $percent = $vmIdx/$vmsCount*100
         Write-Progress -Activity $act -Status "In Progress" -PercentComplete $percent
      }

      LogVerbose "VM '$vm' is " -noNewLine:$true
      $vmVw = $vm | Get-View -Verbose:$false
      if ($vmVw.Config.ManagedBy -ne $null -AND $vmVw.Config.ManagedBy.ExtensionKey -eq $extName) {
         LogVerbose "managed" -NoNewLine:$true -foreColor:"Yellow"
         LogVerbose " by '$extName'" -NoNewLine:$true

         # Extension matches. Now check for managed type, and then disks
         $vmManagedType = $vmVw.Config.ManagedBy.Type
         if ("" -eq $typeName -OR $typeName -ieq $vmManagedType) {
            if ("" -ne $vmManagedType) {
               LogVerbose " and managed type" -noNewLine:$true -foreColor:"Yellow"
               LogVerbose " is '$vmManagedType'" -noNewLine:$true
            }
            if ("" -eq $typeName) {
               $msg = ". Skipping ManagedType filter due to specified options"
               LogVerbose $msg -noNewLine:$true -foreColor:"Yellow"
            }
            #magic comma
            $vmDisks = ,($vmVw.Config.Hardware.Device | Where-Object { $_.GetType().Name -ieq "VirtualDisk" })
            if (($vmDisks -ne $null) -And ($vmDisks.Count -ge 0)) {
               $dsCnt = $vmDisks.Count
            } else {
               $dsCnt = 0
            }
            LogVerbose ". Has $dsCnt disk(s)" -noNewLine:$true -foreColor:"Yellow"
            if ($SkipDiskFilter) {
               LogVerbose ". Skipping filter by disk" -noNewLine:$true -foreColor:"Yellow"
               LogVerbose " due to specified options" -noNewLine:$true
            }
            if ($SkipDiskFilter -OR $dsCnt -gt 0) {
               LogVerbose ". VM possible has wrong 'managed by' property." -noNewLine:$true
               LogVerbose " Adding" -foreColor:"Yellow"
               # 'Add' method returns index of object inserted. We need to swallow its output and do not mess
               # with result array of VMs
               $objIdx = $vmsCandidates.Add($vm)
            } else {
               LogVerbose ". Disk count filter didn't pass. " -noNewLine:$true
               LogVerbose "Skipping" -foreColor:"Yellow"
            }
         } else {
            LogVerbose ". ManagedType doesn't match to '$typeName'. " -noNewLine:$true
            LogVerbose "Skipping" -foreColor:"Yellow"
         }
      } else {
         LogVerbose "NOT" -NoNewLine:$true -foreColor:"Yellow"
         LogVerbose " managed by $extName"
      }
   }
   # don't forget about magic comma
   return ,$vmsCandidates
}

#returns VMSpec object which is used to set or reset "ManagedBy" VM property
Function GetSpec_ManagedBy($extensionKey, $managedType) {
   $spec = New-Object VMware.Vim.VirtualMachineConfigSpec
   $manBy = New-Object VMware.Vim.ManagedByInfo
   $spec.ManagedBy = $manBy
   $manBy.Type = $managedType
   $manBy.ExtensionKey = $extensionKey
   return $spec
}

# Starts VMReconfigure task on VC, and waits for its completion
Function ReconfigureVm($vm, $configSpec) {
   $vmView = Get-View $vm -Verbose:$false
   if ($null -eq $vmView) {
      return $false
   }

   $taskMoRef = $vmView.ReconfigVM_Task($configSpec)
   $task = Get-View $taskMoRef -Verbose:$false
   while("running","queued" -contains $task.Info.State) {
      $task.UpdateViewData("Info")
   }
   if ("error" -eq $task.Info.State) {
      Write-Error "ReconfigVm task failed"
      return $false
   }
   return $true
}

Function WriteMessagePowerCliInstallUrl {
   $msg = "Recommended PowerCLI version is 5.0.1. Please download PowerCLI 5.0.1 from "
   $msg += "http://communities.vmware.com/community/vmtn/server/vsphere/automationtools/powercli"
   Write-Host $msg -ForegroundColor:"Yellow"
}

Function VerifyScriptParams($scriptName) {
    $msg = ""
    if ("" -eq $Cmd) {
      $msg = "Parameter -Cmd and command expected."
   } elseif ("GetVMs","ScanVMs","Clear","Clean","Set","Ver","Version" -iNotContains $Cmd) {
      $msg = "Command '$Cmd' is not supported."
   }
   if ("" -ne $msg) {
      $msg += " Please read help about script: get-help .\$scriptName -detailed"
      Write-Host $msg -ForegroundColor:"Red"
      exit 4
   }
   if ("ScanVMs","Ver","Version" -iContains $Cmd) {
      return
   } elseif ("Clear","Clean","Set" -iContains $Cmd) {
      # array of VMs is required
      if ($null -eq $VMs) {
         Write-Error "Please specify VM object(s) you want to set/clear ManagedBy property"
         exit 5
      }
   }
   if (("GetVMs","Set" -iContains $Cmd) -AND ($ExtKey -eq "")) {
      $extKeys = FindDrExtensions
      if ($extKeys.Count -eq 1) {
         $ExtKey = $extKeys[0]
      } else {
         if ($extKeys.Count -gt 1) {
            $extCount = $extKeys.Count
            $msg = "Found multiple SRM extensions ($extCount) registered in VC. Please specify one"
            $msg += " (key) from the following list:"
            Write-Warning $msg
            $extKeys | Select-Object "Key","Version",@{Name="Extension Name"; Expression={$_.Description.Label}}
         } else {
            Write-Warning "There is no any extension registered in VC"
         }
         $msg = "Sometimes some VMs are still registered in VC inventory but extension is already deleted. "
         $msg += "To inspect all VMs and get their extension, please execute script with -Cmd ScanVMs"
         Write-Warning $msg
         exit 6
      }
   }
}

Function VerifyConnection {
   if ($null -eq $global:DefaultVIServers -OR $global:DefaultVIServers.Count -eq 0) {
      Write-Host "PowerCLI is not connected to VC. Please run Connect-VIServer cmdlet" -ForegroundColor:"Red"
      exit 1
   }
   if ($global:DefaultVIServers.Count -gt 1) {
      WriteErrorAboutMultipleVCConnections
      exit 2
   }
   $productType = $global:DefaultVIServer.ProductLine
   if ($productType -ine "vpx") {
      $msg = "PowerCLI connected to VI server but it is not a Virtual Center. Probably it is ESX(i) server."
      $msg += " Please run Connect-VIServer cmdlet in other PowerCLI session and connect to Virtual Center"
      Write-Host $msg -ForegroundColor:"Red"
      exit 3
   }
}

####################
# MAIN
####################

#First check that script is started in PowerCLI environment
if(-not (Get-Command Get-PowerCLIVersion -errorAction SilentlyContinue)){
   $msg = "Script should be executed in PowerCLI environment. If PowerCLI is installed please start "
   $msg += "PowerCLI console: Start/Programs/VMware/VMware vSphere PowerCLI/..."
   Write-Host $msg -ForegroundColor:"Red"
   Write-Host "If PowerCLI is not installed, please install it" -ForegroundColor:"Red"
   WriteMessagePowerCliInstallUrl
   exit 7
}

VerifyScriptParams
VerifyConnection

if ($Cmd -ieq "ScanVMs") {
   $extVmHash = GetAllVmExtensions

   # to return object from script just uncomment the following line
   #return $extVmHash

   # for most users it is good enough to just print values to the screen
   # if they do not want to post-process values into pipe or other cmdlets/scripts, just print it nicely
   # unfortunately I did not find way to print it as a nice table without truncation for large list of VMs.
   $backupOFS = $OFS
   $OFS = ", "
   foreach($extKey in $extVmHash.Keys) {
      Write-Host "Extension " -NoNewLine
      Write-Host $extKey -NoNewLine -ForegroundColor:"Yellow"
      Write-Host " manages the following VMs:"
      $eVm = $extVmHash[$extKey]
      Write-Host "$eVm"
   }
   $OFS = $backupOFS
   exit 0
} elseif ($Cmd -ieq "Ver" -OR $Cmd -ieq "Version") {
   Write-Host "Script version: 1.0.0."
   $PsVersion = $Host.Version
   Write-Host "PowerShell version: '$PSVersion'."
   if ($PsVersion.Major -lt 2) {
      $msg = "Recommended PowerShell version is 2.0. Please download powershell 2.0 from "
      $msg += "http://support.microsoft.com/kb/968929"
      Write-Host $msg -ForegroundColor:"Yellow"
   }
   $CliVer = Get-PowerCLIVersion
   $PcliTxtVer = $CliVer.UserFriendlyVersion
   Write-Host "PowerCLI version: '$PcliTxtVer'."

   # Compare PowerCli version to the recommended one. Please note, the third part of standard version numbers
   # is 'Build', but the third component of PowerCLI version is 'Revision'.
   $PowerCliVer = New-Object System.Version -ArgumentList $CliVer.Major,$CliVer.Minor,$CliVer.Revision,0
   $PCliRecommendedVer = [Version]"5.0.1.0"
   if ($PCliRecommendedVer -gt $PowerCliVer) {
      WriteMessagePowerCliInstallUrl
   }
   exit 0
}

if ($Cmd -ieq "GetVMs") {
   # comma makes the magic and ArrayList is not converted by PowerShell to an internal array
   return ,(GetManagedVMs -extName:$ExtKey -typeName:$VMType -SkipDiskFilter:$SkipDiskFilter)
} else {
   if ($Cmd -ieq "Clear" -OR $Cmd -ieq "Clean") {
      $newKey = ""
      $newType = ""
      $cmdTextProgress = "Cleaning"
   } elseif ($Cmd -ieq "Set") {
      $newKey = $ExtKey
      $newType = $VMType
      $cmdTextProgress = "Setting"
   } else {
      $scriptName = $Myinvocation.MyCommand.Name
      $msg = "Not supported command '$Cmd'. Please read help about script: get-help .\$scriptName -detailed"
      Write-Error $msg
      exit 8
   }

   $specManagedBy = GetSpec_ManagedBy $newKey $newType
   $vmObjects = GetVmArray -names:$VMs
   $vmsCount = $vmObjects.Count

   LogVerbose "Found $vmsCount VMs"
   $vmItemIdx = 0
   $act = "$cmdTextProgress property 'Managed By' for VMs"
   Write-Progress -Activity $act -Status "In Progress" -PercentComplete (0)
   foreach ($vmObj in $vmObjects) {
      $vmName = $vmObj.Name
      LogVerbose "Processing VM '$vmName'" -NoNewLine:$true
      $ok = ReconfigureVm $vmObj $specManagedBy
      LogVerbose " - Done " -NoNewLine:$true
      if ($ok) {
         $resText = "successfully"
      } else {
         $resText = "with error"
      }
      LogVerbose $resText -foreColor:"Yellow"
      ++$vmItemIdx
      Write-Progress -Activity $act -Status "In Progress" -PercentComplete ($vmItemIdx/$vmsCount*100)
   }
}
