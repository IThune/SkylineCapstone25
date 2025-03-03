////Begin Parameters
//Subnets
param untrustedSubnetId string
param trustedSubnetId string

//Public IPs
param publicIPv4Id string = ''
param publicIPv6Id string = ''

//Network Security Groups
param untrustedNsgId string = ''
param trustedNsgId string = ''

//General parameters
param virtualMachineName string
param virtualMachineSize string
//param multiNicSupport bool
param Location string = resourceGroup().location

//Bootstrap shell script parameters
param ShellScriptName string

    /*
     Script Params
     $1 = OPNScriptURI - URI to the private github repo that contains config files and scripts, must end in '/'
     $2 = OpnVersion - The version of OPNsense to install to this system
     $3 = WALinuxVersion - The version of the Azure Linux Agent to install to this system
     $4 = Trusted Nic subnet prefix - used to get the gateway for trusted subnet
     $5 = Management subnet prefix - used to route/nat allow internet access from Management VM
     $6 = github token to download files from the private repo
     $7 = file name of the OPNsense config file, default config.xml
     $8 = file name of the python script to find gateway, default get_nic_gw.py
     $9 = file name of the waagent actions configuration file, default waagent_actions.conf
    */
param OPNVersion string
param OPNScriptURI string
param WALinuxVersion string
param TrustedSubnetName string
param ManagementSubnetName string
@secure()
param GithubPrivateToken string
param OPNsenseConfigXML string
param PythonGatewayScript string
param WAAgentActionsConfig string

var scriptParams = [ 
  OPNVersion
  OPNScriptURI
  WALinuxVersion
  TrustedSubnetName
  ManagementSubnetName
  GithubPrivateToken
  OPNsenseConfigXML
  PythonGatewayScript
  WAAgentActionsConfig
]

var runShellScriptCommand = 'sh ${ShellScriptName} ${join(scriptParams, ' ')}'

//Secrets
//TODO Azure Key Vault for secure storage and retrieval of secrets
param AdminUsername string
@secure() 
param AdminPassword string

//Network Interfaces
var untrustedNicName = '${virtualMachineName}-Untrusted-NIC'
var trustedNicName = '${virtualMachineName}-Trusted-NIC'

////End Parameters
////Begin Resources

//Network Interfaces
module untrustedNic '../vnet/nic.bicep' = {
  name: untrustedNicName
  params:{
    Location: Location
    nicName: untrustedNicName
    SubnetId: untrustedSubnetId
    publicIPv4Id: publicIPv4Id
    publicIPv6Id: publicIPv6Id
    enableIPForwarding: true
    nsgId: untrustedNsgId
  }
}

module trustedNic '../vnet/nic.bicep' = {
  name: trustedNicName
  params:{
    Location: Location
    nicName: trustedNicName
    SubnetId: trustedSubnetId
    enableIPForwarding: true
    nsgId: trustedNsgId
  }
}

//Virtual Machine
resource OPNsense 'Microsoft.Compute/virtualMachines@2023-07-01' = {
  name: virtualMachineName
  location: Location
  properties: {
    osProfile: {
      computerName: virtualMachineName
      adminUsername: AdminUsername 
      adminPassword: AdminPassword 
    }
    hardwareProfile: {
      vmSize: virtualMachineSize
    }
    storageProfile: {
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {storageAccountType:'StandardSSD_LRS'}
        caching:'ReadWrite'
      }
      imageReference: {
        publisher: 'thefreebsdfoundation'
        offer: 'freebsd-14_2'
        sku: '14_2-release-amd64-gen2-ufs'
        version: 'latest'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: untrustedNic.outputs.nicId
          properties:{
            primary: true
          }
        }
        {
          id: trustedNic.outputs.nicId
          properties:{
            primary: false
          }
        }
      ]
    }
  }
  plan: {
    name: '14_2-release-amd64-gen2-ufs'
    publisher: 'thefreebsdfoundation'
    product: 'freebsd-14_2'
  }
}

//Run custom shell script with image deployment
resource vmext 'Microsoft.Compute/virtualMachines/extensions@2023-07-01' = {
  parent: OPNsense
  name: 'CustomScript'
  location: Location
  properties: {
    publisher: 'Microsoft.OSTCExtensions'
    type: 'CustomScriptForLinux'
    typeHandlerVersion: '1.5'
    autoUpgradeMinorVersion: false
    settings:{
      fileUris: [
        '${OPNScriptURI}${ShellScriptName}'
      ]
    commandToExecute: runShellScriptCommand
    }
  }
}
output untrustedNicIP string = untrustedNic.outputs.nicIP
output trustedNicIP string = trustedNic.outputs.nicIP
output untrustedNicIPv4ProfileId string = untrustedNic.outputs.nicIPv4ConfigId
output untrustedNicIPv6ProfileId string = untrustedNic.outputs.nicIPv6ConfigId
