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
param multiNicSupport bool
param Location string = resourceGroup().location

//Bootstrap shell script parameters
param OPNScriptURI string
param ShellScriptName string
param ShellScriptParameters object = {}

//Secrets
//TODO Azure Key Vault for secure storage and retrieval of secrets
param TempUsername string = 'tempAdmin'
#disable-next-line secure-secrets-in-params
param TempPassword string = 'Opnsense'

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
      adminUsername: TempUsername
      adminPassword: TempPassword
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
    /*
     Script Params
     $1 = OPNScriptURI
     $2 = OpnVersion
     $3 = WALinuxVersion
     $4 = Trusted Nic subnet prefix - used to get the gateway for trusted subnet
     $5 = Management subnet prefix - used to route/nat allow internet access from Management VM
    */
      commandToExecute: 'sh ${ShellScriptName} ${ShellScriptParameters.OpnScriptURI} ${ShellScriptParameters.OpnVersion} ${ShellScriptParameters.WALinuxVersion} ${ShellScriptParameters.TrustedSubnetName} ${ShellScriptParameters.ManagementSubnetName}'
    }
  }
}
output untrustedNicIP string = untrustedNic.outputs.nicIP
output trustedNicIP string = multiNicSupport == true ? trustedNic.outputs.nicIP : ''
output untrustedNicIPv4ProfileId string = untrustedNic.outputs.nicIPv4ConfigId
output untrustedNicIPv6ProfileId string = untrustedNic.outputs.nicIPv6ConfigId
