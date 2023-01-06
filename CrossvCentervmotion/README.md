This XVM.psm1 is only an update of Bulk VM Migration using new Cross vCenter vMotion Utility Fling created by William Lam
https://williamlam.com/2017/12/bulk-vm-migration-using-new-cross-vcenter-vmotion-utility-fling.html
https://github.com/lamw/PowerCLI-Example-Scripts/tree/master/Modules/CrossvCentervmotion

My contribution is to adapt code for working with version 3.1 of Cross Vcenter Workload Migration Utility from VMware Flings
https://flings.vmware.com/cross-vcenter-workload-migration-utility

Changes :
  Set-XVCMConfiguration
    This function configure the global variable `CrossvCenterURL`, and calls the `Disable-SSLCertificateValidation` function to ignore SSL certificate validation.
    Disable-SSLCertificateValidation
    Add new function to ignore SSL certificate validation with Powershell 5.1
New-XVCMRequest
    diskFormatConversion
    [ValidateSet('Same Format as Source', 'Thick Provision Lazy Zeroed', 'Thick Provision Eager Zeroed', 'Thin Provision')]
VMNamePattern
    Used to define VM paterns. Set to null if you dont use
Some other minor changes...

How to use :
    Import-Module XVM.psm1
    # Cross vCenter URL
    $CrossvCenterURL = "https://crossvcenterworkloadutility:8443"

    # Configure XVCM
    Set-XVCMConfiguration -CrossvCenterURL $CrossvCenterURL -DisableSSLCertificateValidation $true

    # Get sites informations (not required to initiate migration just for identify Cross Vcenter Workload Migration Utility informations)
    Get-XVCMSite

    # Get Cross vCenter connectivity status
    Get-XVCMStatus

    # Initiate migration
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
