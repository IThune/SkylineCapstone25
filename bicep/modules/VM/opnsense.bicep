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
param Location string = resourceGroup().location

//Bootstrap shell script parameters

param ShellScriptName string

/*
# Script Params
# $1 = OPNScriptURI - path to the github repo which contains the config files and scripts - needs to end with '/'
# $2 = OpnVersion
# $3 = WALinuxVersion
# $4 = github token to download files from the private repo
# $5 = file name of the OPNsense config file, default config.xml
# $6 = file name of the waagent actions configuration file, default waagent_actions.conf
*/

param OPNScriptURI string
param OPNVersion string
param WALinuxVersion string
/*
@secure()
param GithubPrivateToken string
*/
param OPNsenseConfigXML string
param WAAgentActionsConfig string

var scriptParams = [ 
  OPNScriptURI
  OPNVersion
  WALinuxVersion
  //GithubPrivateToken
  OPNsenseConfigXML
  WAAgentActionsConfig
]
// Installs curl package, uses curl to securely download the bootstrap script, runs the bootstrap script with the required params
//var runShellScriptCommand = '/bin/sh -c "pkg update && pkg install -y curl && curl -H \\"Authorization: Bearer ${GithubPrivateToken}\\" -H \\"Accept: application/vnd.github.v3.raw\\" -O -L \\"${OPNScriptURI}${ShellScriptName}\\" && chmod +x \\"${ShellScriptName}\\" && sh \\"${ShellScriptName}\\" ${join(scriptParams, ' ')}"'
var runShellScriptCommand = '/bin/sh -c "pkg update && pkg install -y curl && curl ${OPNScriptURI}${ShellScriptName}\\" && chmod +x \\"${ShellScriptName}\\" && sh \\"${ShellScriptName}\\" ${join(scriptParams, ' ')}"'
//Secrets
//TODO Azure Key Vault for secure storage and retrieval of secrets
param AdminUsername string
@secure() 
param AdminPassword string

//Network Interfaces
param trustedNicStaticIPv4 string
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
    enableIPForwarding: false
    nsgId: untrustedNsgId
    privateIPAllocMethod: 'Dynamic'
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
    privateIPAllocMethod: 'Static'
    privateStaticIPv4: trustedNicStaticIPv4
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
      //fileUris: ['${OPNScriptURI}${ShellScriptName}']
      commandToExecute: runShellScriptCommand
    }
  }
}

output untrustedNicIP string = untrustedNic.outputs.nicIP
output trustedNicIP string = trustedNic.outputs.nicIP
output untrustedNicIPv4ProfileId string = untrustedNic.outputs.nicIPv4ConfigId
output untrustedNicIPv6ProfileId string = untrustedNic.outputs.nicIPv6ConfigId
