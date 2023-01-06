Function Disable-SSLCertificateValidation
{
<#
    .AUTOR
        Autor : Christian GRANDJEAN and anyone in internet
        Date : 2023-01-05 17:54:08
        Version : 1.0

    .SYNOPSIS
        This function allows to ignore SSL certificate validation and accept all certificates. It does this by creating an instance of the TrustAll class and attaching it to the ServicePointManager.
    
    .EXAMPLE
        Disable-SSLCertificateValidation
#>
    # Ignore SSL Certificate validsation and accept all
    $Provider = New-Object Microsoft.CSharp.CSharpCodeProvider
    $Compiler = $Provider.CreateCompiler()
    $Params = New-Object System.CodeDom.Compiler.CompilerParameters
    $Params.GenerateExecutable = $false
    $Params.GenerateInMemory = $true
    $Params.IncludeDebugInformation = $false
    $Params.ReferencedAssemblies.Add("System.DLL") > $null
    $TASource = @'
        namespace Local.ToolkitExtensions.Net.CertificatePolicy
        {
            public class TrustAll : System.Net.ICertificatePolicy
            {
                public bool CheckValidationResult(System.Net.ServicePoint sp,System.Security.Cryptography.X509Certificates.X509Certificate cert, System.Net.WebRequest req, int problem)
                {
                    return true;
                }
            }
        }
'@
    $TAResults = $Provider.CompileAssemblyFromSource($Params, $TASource)
    $TAAssembly = $TAResults.CompiledAssembly
    ## We create an instance of TrustAll and attach it to the ServicePointManager
    $TrustAll = $TAAssembly.CreateInstance("Local.ToolkitExtensions.Net.CertificatePolicy.TrustAll")
    [System.Net.ServicePointManager]::CertificatePolicy = $TrustAll
}

# Set global variable
$global:CrossvCenterURL = $null;
Function Set-XVCMConfiguration
{
<#
    .SYNOPSIS
        This function configure the global variable `CrossvCenterURL`, and calls the `Disable-SSLCertificateValidation` function to ignore SSL certificate validation.

    .EXAMPLE
        Set-XVCMConfiguration -CrossvCenterURL "https://localhost:8443" -DisableSSLCertificateValidation $true
    
    .NOTES
        You must use this function as first.
#>
    
    [OutputType([NullString])]
    Param
    (
        [Parameter(Mandatory = $true)]
        [String]$CrossvCenterURL,
        [Parameter(Mandatory = $true)]
        [boolean]$DisableSSLCertificateValidation
    )
    Write-Information "INFO   : Cross vcenter URL set to : $CrossvCenterURL"
    Set-Variable -Name "CrossvCenterURL" -Value $CrossvCenterURL -scope global -Option AllScope
    
    # Ignore certificate validation
    If ($DisableSSLCertificateValidation -eq $true)
    {
        Write-Information "INFO   : Ignore SSL Certificate Validation"
        Disable-SSLCertificateValidation
    }
}


Function Get-XVCMStatus
{
<#
    .NOTES
    ===========================================================================
     Created by:    William Lam
     Organization:  VMware
     Blog:          www.virtuallyghetto.com
     Twitter:       @lamw
    ===========================================================================
    .DESCRIPTION
        This function returns whether Cross vCenter Workload Migration Utility is running or not
    .EXAMPLE
        Get-XVCMStatus
#>

    $Uri = "$CrossvCenterURL/api/status" #Updated for 2.0, Old: "$CrossvCenterURL/api/ping"
    
    Try
    {
        $results = Invoke-WebRequest -Uri $Uri -Method GET -TimeoutSec 60 -ErrorAction SilentlyContinue -ErrorVariable oErr
    }
    Catch
    {
        $results = $null
    }
    
    If ($results.StatusCode -eq 200)
    {
        $Message = ("Server status: " + $results.Content.ToString())
        Write-Information ("INFO   : $Message")
        Return $Message
    }
    Else
    {
        $Message = ("Cross vCenter Workload Migration Utility is probably not running : " + $oErr.Message.Tostring())
        Write-Warning $Message
        Return $Message
    }
    
    
}

Function Get-XVCMSite
{
<#
    .NOTES
    ===========================================================================
     Created by:    William Lam
     Organization:  VMware
     Blog:          www.virtuallyghetto.com
     Twitter:       @lamw
    ===========================================================================
    .DESCRIPTION
        This function returns all registered vCenter Servers
    .EXAMPLE
        Get-XVCMSite
#>
    $Uri = "$CrossvCenterURL/api/sites"
    
    Try
    {
        $results = Invoke-WebRequest -Uri $Uri -Method GET -ErrorVariable oErr
    }
    Catch
    {
        $results = $null
    }
    
    
    If ($results.StatusCode -eq 200)
    {
        $json = $results.Content.ToString()
        $json = $json.Replace("[", "'[").Replace("]", "]'").ToString().Trim()
        $Message = ConvertFrom-Json $json | Select-Object sitename, hostname, username
        return $results.Content.ToString()
    }
    Else { Write-Warning "Failed to retrieve VC Site Registration details" }
}
 
Function New-XVCMSite
{
<#
    .NOTES
    ===========================================================================
     Created by:    William Lam
     Organization:  VMware
     Blog:          www.virtuallyghetto.com
     Twitter:       @lamw
    ===========================================================================
    .DESCRIPTION
        This function registers a new vCenter Server endpoint
    .PARAMETER SiteName
        The display name for the particular vCenter Server to be registered
    .PARAMETER VCHostname
        The Hostname/IP Address of vCenter Server
    .PARAMETER VCUsername
        The VC Username of vCenter Server
    .PARAMETER VCPassword
        The VC Password of vCenter Server
    .PARAMETER Insecure
        Flag to disable SSL Verification checking, useful for lab environments
    .EXAMPLE
        New-XVCMSite -SiteName "SiteA" -VCHostname "vcenter65-1.primp-industries.com" -VCUsername "administrator@vsphere.local" -VCPassword "VMware1!" -Insecure
#>
    Param (
        [Parameter(Mandatory = $true)]
        [String]$SiteName,
        [Parameter(Mandatory = $true)]
        [String]$VCHostname,
        [Parameter(Mandatory = $true)]
        [String]$VCUsername,
        [Parameter(Mandatory = $true)]
        [String]$VCPassword,
        [Parameter(Mandatory = $false)]
        [Switch]$Insecure
    )
    
    $Uri = "$CrossvCenterURL/api/sites"
    
    $insecureFlag = $false
    If ($Insecure)
    {
        $insecureFlag = $true
    }
    
    $body = @{
        "sitename" = $SiteName;
        "hostname" = $VCHostname;
        "username" = $VCUsername;
        "password" = $VCPassword;
        "insecure" = $insecureFlag;
    }
    
    $body = $body | ConvertTo-Json
    
    Write-Host -ForegroundColor Cyan "Registering vCenter Server $VCHostname as $SiteName ..."
    $results = Invoke-WebRequest -Uri $Uri -Method POST -Body $body -ContentType "application/json"
    
    If ($results.StatusCode -eq 200)
    {
        Write-Host -ForegroundColor Green "Successfully registered $SiteName"
    }
    Else { Write-Host -ForegroundColor Red "Failed to register $SiteName" }
}

Function Remove-XVCMSite
{
<#
    .NOTES
    ===========================================================================
     Created by:    William Lam
     Organization:  VMware
     Blog:          www.virtuallyghetto.com
     Twitter:       @lamw
    ===========================================================================
    .DESCRIPTION
        This function removes vCenter Server endpoint
    .PARAMETER SiteName
        The name of the registered vCenter Server to remove
    .EXAMPLE
        Remove-XVCMSite -SiteName "SiteA"
#>
    Param (
        [Parameter(Mandatory = $true)]
        [String]$SiteName
    )
    
    $Uri = "$CrossvCenterURL/api/sites/$SiteName"
    
    Write-Host -ForegroundColor Cyan  "Deleting vCenter Server Site Registerion $SiteName ..."
    $results = Invoke-WebRequest -Uri $Uri -Method DELETE
    
    If ($results.StatusCode -eq 200)
    {
        Write-Host -ForegroundColor Green "Successfully deleted $SiteName"
    }
    Else { Write-Host -ForegroundColor Red "Failed to deleted $SiteName" }
}

Function New-XVCMRequest
{
<#
    .AUTOR
        ===========================================================================
        Created by:    William Lam
        Organization:  VMware
        Blog:          www.virtuallyghetto.com
        Twitter:       @lamw
        Adaptations    Christian GRANDJEAN
        Version        2.0
        ===========================================================================

    .SYNOPSIS
        This function initiates a migration request
        https://williamlam.com/2017/12/bulk-vm-migration-using-new-cross-vcenter-vmotion-utility-fling.html
        https://github.com/lamw/PowerCLI-Example-Scripts/tree/master/Modules/CrossvCentervmotion
    
    .DESCRIPTION
        A detailed description of the New-XVCMRequest function.
    
    .PARAMETER opType
        The type of task, "relocate" or "clone"
    
    .PARAMETER SrcSite
        The name of the source vCenter Server, knowed with Get-XVCMSite function and select "sitename" value
    
    .PARAMETER DstSite
        The name of the destination vCenter Server, knowed with Get-XVCMSite function and select "sitename" value
    
    .PARAMETER SrcDatacenter
        The name of the source vSphere Datacenter
    
    .PARAMETER DstDatacenter
        The name of the destination vSphere Datacenter
    
    .PARAMETER DstCluster
        The name of the destination vSphere Cluster, set to null if DstHost is defined
    
    .PARAMETER DstPool
        The name of the destination vSphere Resource Pool
    
    .PARAMETER DstFolder
        The name of the destination vSphere Folder
    
    .PARAMETER DstDatastore
        The name of the destination Datastore
    
    .PARAMETER diskFormatConversion
        Conversion of disk format during migration
        Values :
        Same Format as Source
        Thick Provision Lazy Zeroed
        Thick Provision Eager Zeroed
        Thin Provision
    
    .PARAMETER DstHost
        The name of the destination host. Set to null if DstCluster is defined
    
    .PARAMETER srcVMs
        List of VMs to migrate
    
    .PARAMETER VMNamePattern
        Used to define VM paterns. Set to null if you dont use
    
    .PARAMETER NetworkMapping
        Hash table of the VM network mappings between your source and destination vCenter Server
    
        You must format switchs names like this :
            Add " (Network)" for "vmNetwork"
            Add " (DistributedVirtualPortgroup)" for "Distributed Port Group"
            Sample : 
                "VM Network (Network)"
                "DPG125 (DistributedVirtualPortgroup)"

            $networkMap = @{
                "VM Network 12 (Network)"="DPG-DIST-DVS1 (DistributedVirtualPortgroup)"
                "VM Network 15 (Network)"="VMN34 (Network)"
                "SRTZ-DVS9 (DistributedVirtualPortgroup)"="DPGDVS-SURTE-123 (DistributedVirtualPortgroup)"
            }
    
    .EXAMPLE
        $networkMap = @{
            "SRTZ-DVS9 (DistributedVirtualPortgroup)"="DPGDVS-SURTE-123 (DistributedVirtualPortgroup)"
        }
        New-XVCMRequest -opType "relocate" `
        -SrcSite "sitenameOfSourceSite" `
        -DstSite sitenameOfDestinationSite `
        -SrcDatacenter "VMDatacenter1" `
        -DstDatacenter "VMDatacenter3" `
        -DstCluster "Dest-CLUSTER1" `
        -DstDatastore "TARGETDatastore12" `
        -NetworkMapping $networkMap `
        -srcVMs @("PhotonOS-01","PhotonOS-02","PhotonOS-03","PhotonOS-04") `
        -DstHost $null `
        -DstPool "TheSwimmingPool" `
        -DstFolder "TheVMFolder" `
        -diskFormatConversion 'Same Format as Source' `
        -VMNamePattern $null `
    
    .EXAMPLE
        $networkMap = @{
            "VM Network 15 (Network)"="VMN34 (Network)"
        }
        New-XVCMRequest -opType "relocate" `
        -SrcSite "sitenameOfSourceSite" `
        -DstSite sitenameOfDestinationSite `
        -SrcDatacenter "VMDatacenter1" `
        -DstDatacenter "VMDatacenter3" `
        -DstCluster $null `
        -DstDatastore "TARGETDatastore12" `
        -NetworkMapping $networkMap `
        -srcVMs @("VM2") `
        -DstHost "esxiserver.lab.int" `
        -DstPool "TheSwimmingPool" `
        -DstFolder "TheVMFolder" `
        -diskFormatConversion 'Thin Provision' `
        -VMNamePattern $null `
#>
    
    Param
    (
        [Parameter(Mandatory = $true)]
        [String]$opType,
        [Parameter(Mandatory = $true)]
        [String]$SrcSite,
        [Parameter(Mandatory = $true)]
        [String]$DstSite,
        [Parameter(Mandatory = $true)]
        [String]$SrcDatacenter,
        [Parameter(Mandatory = $true)]
        [String]$DstDatacenter,
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        $DstCluster,
        [Parameter(Mandatory = $true)]
        [String]$DstPool,
        [Parameter(Mandatory = $true)]
        [String]$DstFolder,
        [Parameter(Mandatory = $true)]
        [String]$DstDatastore,
        [Parameter(Mandatory = $true)]
        [ValidateSet('Same Format as Source', 'Thick Provision Lazy Zeroed', 'Thick Provision Eager Zeroed', 'Thin Provision')]
        [string[]]$diskFormatConversion,
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        $DstHost,
        [Parameter(Mandatory = $true)]
        [String[]]$srcVMs,
        [Parameter(Mandatory = $false)]
        [AllowNull()]
        $VMNamePattern = $null,
        [Parameter(Mandatory = $true)]
        [Hashtable]$NetworkMapping
    )
    
    $Uri = "$CrossvCenterURL/api/tasks"
    
    # Set disk format
    Switch ($diskFormatConversion)
    {
        'Thick Provision Lazy Zeroed' {
            $diskFormatC = "Thick Provision Lazy Zeroed"
        }
        'Thick Provision Eager Zeroed' {
            $diskFormatC = "Thick Provision Eager Zeroed"
        }
        'Thin Provision' {
            $diskFormatC = "Thin Provision"
        }
        default {
            $diskFormatC = "Same Format as Source"
        }
    }
    
    <# {
    "operationType":"relocate",
    "sourceSite":"vc-source",
    "targetSite":"vc-destination",
    "sourceDatacenter":"DTCNAME",
    "vmList":["migrate_cross"],
    "vmNamePattern":null,
    "targetDatacenter":"DTCDESTNAME",
    "targetCluster":null,
    "targetHost":"esxname.domain.lab",
    "targetDatastore":"DATASTORENAME7",
    "networkMap":{"VM Network 1 (Network)":"Distributed Port Group 2 (DistributedVirtualPortgroup)"},
    "targetPool":"RessourcePool1",
    "targetFolder":"Folder4",
    "diskFormatConversion":"Thin Provision"}
    #>
    $body = [ORDERED]@{
        "operationType"        = $opType;
        "sourceSite"           = $SrcSite;
        "targetSite"           = $DstSite;
        "sourceDatacenter"     = $SrcDatacenter;
        "vmList"               = $srcVMs;
        "vmNamePattern"        = $VMNamePattern;
        "targetDatacenter"     = $dstDatacenter;
        "targetCluster"        = $DstCluster;
        "targetHost"           = $DstHost;
        "targetDatastore"      = $DstDatastore;
        "networkMap"           = $NetworkMapping;
        "targetPool"           = $DstPool;
        "targetFolder"         = $DstFolder;
        "diskFormatConversion" = $diskFormatC
    }
    
    $body = $body | ConvertTo-Json
    Write-Debug "JSON Value : $body"
    Write-Information "INFO   : Initiating migration request ..."
    
    Try
    {
        $results = Invoke-WebRequest -Uri $Uri -Method POST -Body $body -ContentType "application/json" -ErrorVariable oErr
    }
    Catch
    {
        $results = $null
    }
    
    If ($results.StatusCode -eq 200)
    {
        $Message = ("Successfully issued migration with requestId:" + $results.Content.ToString())
        Write-Information ("INFO   : $Message")
        Return "Success"
    }
    Else
    {
        $Message = ("Failed to initiate migration request" + $oErr.Message.Tostring())
        Write-Warning $Message
        Return $Message
    }
}

Function Get-XVCMTask
{
<#
    .NOTES
    ===========================================================================
     Created by:    William Lam
     Organization:  VMware
     Blog:          www.virtuallyghetto.com
     Twitter:       @lamw
    ===========================================================================
    .DESCRIPTION
        This function retrieves either all migration tasks and/or a specific migration task
    .PARAMETER Id
        The task ID returned from initiating a migration
    .EXAMPLE
        Get-XVCMTask -Id <Task ID>
#>
    Param (
        [Parameter(Mandatory = $false)]
        [String]$Id
    )
    
    $Uri = "$CrossvCenterURL/api/tasks"
    
    If ($Id)
    {
        $body = @{ "requestId" = $Id }
        
        $results = Invoke-WebRequest -Uri $Uri -Method GET -Body $body -ContentType "application/json"
    }
    Else
    {
        $results = Invoke-WebRequest -Uri $Uri -Method GET
    }
    
    If ($results.StatusCode -eq 200)
    {
        $results.Content | ConvertFrom-Json
    }
    Else { Write-Host -ForegroundColor Red "Failed to retrieve tasks" }
}

Function Get-VMNetwork
{
<#
    .NOTES
    ===========================================================================
     Created by:    William Lam
     Organization:  VMware
     Blog:          www.virtuallyghetto.com
     Twitter:       @lamw
    ===========================================================================
    .DESCRIPTION
        This function returns the list of all VM Networks attached to
        given VMs to help with initiating migration
    .PARAMETER srcVMs
        List of VMs to query their current VM Networks
    .EXAMPLE
        Get-VMNetwork -srcVMs @("PhotonOS-01","PhotonOS-02","PhotonOS-03","PhotonOS-04")
#>
    Param (
        [Parameter(Mandatory = $false)]
        [String[]]$srcVMs
    )
    
    If (-not $global:DefaultVIServers) { Write-Host -ForegroundColor red "No vCenter Server Connection found, please connect to your source vCenter Server using Connect-VIServer"; Break }
    
    $results = @()
    If ($srcVMs)
    {
        ForEach ($srcVM In $srcVMs)
        {
            $vm = Get-VM -Name $srcVM
            $networkDetails = $vm | Get-NetworkAdapter
            $tmp = [pscustomobject] @{
                Name    = $srcVM;
                Adapter = $networkDetails.name;
                Network = $networkDetails.NetworkName;
            }
            $results += $tmp
        }
    }
    Else
    {
        ForEach ($vm In Get-VM)
        {
            $networkDetails = $vm | Get-NetworkAdapter
            $tmp = [pscustomobject] @{
                Name    = $vm.Name;
                Adapter = $networkDetails.name;
                Network = $networkDetails.NetworkName;
            }
            $results += $tmp
        }
    }
    $results
}
