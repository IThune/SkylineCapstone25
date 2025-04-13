////Begin Parameters
//General Parameters
param virtualMachineName string
param virtualMachineSize string
param Location string = resourceGroup().location

//Networking Parameters
param trustedSubnetId string
param trustedNsgId string = ''
param nicStaticIPv4 string
var nicName = '${virtualMachineName}-NIC'

//Secret Parameters
//TODO Azure Key Vault for secure storage and retrieval of secrets
// System Administrator
param AdminUsername string
@secure()
param AdminPassword string
// Database Administrator
param MySQLUsername string = 'zmuser'
@secure()
param MySQLPassword string

////End Parameters
////Begin Resources

//Network Interfaces
module nic '../vnet/nic.bicep' = {
  name:nicName
  params: {
    Location: Location
    nicName: nicName
    SubnetId: trustedSubnetId
    enableIPForwarding: false
    nsgId: trustedNsgId
    privateIPAllocMethod: 'Static'
    privateStaticIPv4: nicStaticIPv4
  }
}

//Virtual Machine
resource Zoneminder 'Microsoft.Compute/virtualMachines@2023-07-01' = {
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
        publisher: 'debian'
        offer: ''
      }
    }
  }
}
