<#
.Synopsis
    Compares the PCI devices pNICs and HBAs for all hosts within each cluster
 
.DESCRIPTION
    Compares the PCI devices pNICs and HBAs for all hosts within each cluster
.EXAMPLE  
    Example with all parameters
    .\Esx_PCI.ps1 -vcenter "vcenter.acme.com" -WorkingDirectory "C:\TEMP" -logfile "Esx_PCI_date.log"
 
.INPUTS
    None

.OUTPUTS
    Full log file, default name is "Esx_PCI_date.log", can be overridden with parameter -logfile

.NOTES
    DISCLAIMER:
 
.COMPONENT
  
.ROLE
  
.FUNCTIONALITY
    Compares the PCI devices pNICs and HBAs for all hosts within each cluster
#>
 
Param (
        # The FQDN or IP of the vCenter Server
        [string]$vcenter = "vcenter.acme.com",
        # The path to the folder for output files
        [string]$WorkingDirectory = ".",
        #file with extended logging
        [string]$logfile=""
)
#
# logit function to log output to the logfile AND screen
# 1st parameter = message written to logfile
# 2nd parameter = 1 - log to output and screen
# 2nd parameter, value other than 1 changes foreground color: 2=green, 3=blue, 4=red, 5=purple etc
function logit($message , $toscreen)
{
   Write-Output $message | Out-File -FilePath $logfile -Encoding "utf8"  -Append   #avoid UTF-16 output
   IF(-NOT [string]::IsNullOrWhiteSpace($toscreen)) 
   {
      if($toscreen -eq "1")
      { Write-Host $message}
      else
      { Write-Host -ForegroundColor $toscreen  $message}
   }
}
#
# Loop through all hosts and process.
#           
function loop_through_all_hosts()
{
# Get Clusters
$clusters=@()  
foreach($i in Get-Cluster )
{
    # Fill Cluster
    $clusters += $i.Name
    logit "Cluster:  $($i.Name)" 1
    # For each Cluster fill VMhosts
    $vmhosts=@()
    $refp=@()
    $refh=@()
    # $i is Cluster name and $j is VMHost
    foreach($j in Get-Cluster -Name $i | Get-VMHost)
    {
        $pnics=@()
        $storage=@()
        # Hostname
        $vmhosts += $j.Name
        logit "Host   : $($j.Name)" 1
        # Collect Pnics
        $pnics = Get-View -ViewType HostSystem -Filter @{"Name" = $j.Name} | %{$_.Config.Network.Pnic | Select Pci, Device, Driver}
        logit "pNICS go here..." 1
        # foreach loop to transfer output to logfile
        foreach($line in $pnics) { logit "$($line)" 1 }
        # First host in cluster is reference for other hosts
        if($vmhosts.Count -eq 1)
        {
            $refp=$pnics
        }
        else
        {
            # Following hosts are compared against the reference host"
            # Check number of devices
            if($refp.Count -ne $pnics.Count)
            {
                logit "ERROR Number of pNICs is not equal. Reference host has $($refp.Count) and host $($j.Name) has $($pnics.Count)" 1
            }
            # Compare pNICs against reference
            # $k is counter $line is not used
            $k=0;
            foreach($line in $pnics)
            {
                if($pnics[$k].Pci -ne $refp[$k].Pci)
                {
                    logit "ERROR Pci is not equal. Pci: $($pnics[$k].Pci) , Device: $($pnics[$k].Device)" 1
                }
                if($pnics[$k].Device -ne $refp[$k].Device)
                {
                    logit "ERROR Device is not equal: $($pnics[$k].Device)" 1
                }
                if($pnics[$k].driver -ne $refp[$k].driver)
                {
                    logit "ERROR Driver is not equal: $($pnics[$k].driver) , Device: $($pnics[$k].Device)" 1
                }
                $k++
            }
        }
        # Collect HBAs
        $storage = Get-View -ViewType HostSystem -Filter @{"Name" = $j.Name} | %{$_.Config.StorageDevice.HostBusAdapter | Select Pci, Device, Driver, Model}
        logit "$storage" 1
        logit "HBAs go here..." 1
        # foreach loop to transfer output to logfile       
        foreach($line in $storage) { logit "$($line)" 1 }
        # First host in cluster is reference for other hosts
        if($vmhosts.Count -eq 1)
        {
            logit "#### Host $($j.Name) is reference host for this cluster ####" 1
            $refh=$storage
        }
        else
        {
            # Following hosts are compared against the reference host"
            # Check number of devices
            if($refh.Count -ne $storage.Count)
            {
                logit "ERROR Number of HBAs is not equal. Reference host has $($refh.Count) and host $($j.Name) has $($storage.Count)" 1
            }
            # Compare HBAs against reference
            # $k is counter $line is not used
            $k=0;
            foreach($line in $storage)
            {
                if($storage[$k].Pci -ne $refh[$k].Pci)
                {
                    logit "ERROR Pci is not equal. Pci: $($storage[$k].Pci) , Device: $($storage[$k].Device)" 1
                }
                if($storage[$k].Device -ne $refh[$k].Device)
                {
                    logit "ERROR Device is not equal: $($storage[$k].Device)" 1
                }
                if($storage[$k].driver -ne $refh[$k].driver)
                {
                    logit "ERROR Driver is not equal: $($storage[$k].driver) , Device: $($storage[$k].Device)" 1
                }
                $k++
            }
        }
        logit "Next Host..." 1
    }
    logit "Total Number of Hosts in Cluster $($i.Name) is: $($vmhosts.Count )." 1
    logit "Next Cluster"
}
logit "Total Number of Clusters is: $($clusters.Count)." 1
}
#
#
#
# MAIN starts here
#
$currentLocation = Get-Location
$today = date -Format yyyyMMdd_hhmm
if($logfile -eq "") {$logfile="$WorkingDirectory\Esx_PCI_$today.log";}
Write-Host "Logfile: $logfile"
Write-Output "ESX_PCI script version: 1.0 " | Out-File -FilePath $logfile -Encoding "utf8"
logit "Date: $today"
#login vCenter Server
logit "vCenter Server is: $vcenter" 1
Write-Host "Provide Credentials for the vCenter Server"
try{$cred=Get-Credential
}
catch{ Write-Host -ForegroundColor Red "reading credentials failed - abort"
    exit
}
Connect-VIServer -Server $vcenter -Credential $cred
# Start loop
logit "##########################################################" 1
logit "##################### Start ##############################" 1
logit "##########################################################" 1
loop_through_all_hosts
logit "##########################################################" 1
logit "##################### End ################################" 1
logit "##########################################################" 1
#eof
 
