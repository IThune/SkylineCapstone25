////Begin Parameters
//General Parameters
param virtualMachineName string
param virtualMachineSize string
param Location string = resourceGroup().location
param footageDiskName string

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
param MySQLUsername string = 'zmuser' // $1 - This username will be configured as the zoneminder database user
@secure()
param MySQLPassword string // $2 - Password for the db user above. TODO password policy for this user?

// Deploy configuration parameters
param ShellScriptName string //The filename of the shell script as it appears on Github
param ZMScriptURI string //URI to the private github repo that contains config files & scripts. Must end in '/'
param WALinuxVersion string // $3 - The version of the Azure Linux Agent to install
@secure()
param GithubPrivateToken string // $4 - github token passed into gh api request headers to download files from the private repo
param WAAgentActionsConfig string // $5 - file name of the waagent actions config file, default waagent_actions.conf

var scriptParams = [
  MySQLUsername
  MySQLPassword
  WALinuxVersion
  GithubPrivateToken
  WAAgentActionsConfig
]

var runShellScriptCommand = '/bin/sh -c "apt update && apt install curl -y && curl -H \\"Authorization: Bearer ${GithubPrivateToken}\\" -H \\"Accept: application/vnd.github.v3.raw\\" -O -L \\"${ZMScriptURI}${ShellScriptName}\\" chmod +x \\"${ShellScriptName}\\" && sh \\"${ShellScriptName}\\" ${join(scriptParams, ' ')}"'


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
      imageReference: {
        publisher: 'Debian'
        offer: 'debian'
        sku: '12'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {storageAccountType:'StandardSSD_LRS'}
        caching:'ReadWrite'
      }
      dataDisks: [  // stores NVR footage
        {
          name: footageDiskName
          lun: 0
          createOption: 'Empty'
          diskSizeGB: 64
          managedDisk: {storageAccountType: 'PremiumSSD_LRS'}
        }
      ]
    }
  }
}
