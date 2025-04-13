param location string = resourceGroup().location

////vnet parameters

//Address Space
param SkynetVirtualNetworkName string = 'SKYNET'
param SkynetIPv4AddressPrefix string = '10.0.0.0/16'
param SkynetIPv6AddressPrefix string = 'fd00:6f08:7be9::/48'
param SkynetAddressSpace array = [
  SkynetIPv4AddressPrefix
  SkynetIPv6AddressPrefix
]

//Trusted Subnet
param TrustedIPv4Subnet string = '10.0.0.0/24'
param TrustedIPv6Subnet string = 'fd00:6f08:7be9::/64'
param TrustedSubnetName string = 'trusted'

//Untrusted Subnet
param UntrustedIPv4Subnet string = '10.0.255.224/27'
param UntrustedIPv6Subnet string = 'fd00:6f08:7be9:ffff::/64'
param UntrustedSubnetName string = 'untrusted'

//Management Subnet
param ManagementIPv4Subnet string = '10.0.100.0/27'
param ManagementIPv6Subnet string = 'fd00:6f08:7be9:ff::/64'
param ManagementSubnetName string = 'management'

////Public IP parameters
param PublicIPDeploymentName string = 'SkylinePublicIP'
param PublicIPv4AddressName string = 'skyline-public-ipv4'
param PublicIPv6AddressName string = 'skyline-public-ipv6'
param PublicIPv4DNSLabel string = 'skyline' //skyline.eastus.cloudapp.azure.com will resolve to this public IPv4 address
param PublicIPv6DNSLabel string = 'skyline6'  //skyline6.eastus.cloudapp.azure.com will resolve to this public IPv6 address

////OPNsense VM Parameters
//General VM Parameters
param OPNsenseVirtualMachineSize string = 'Standard_B1s'  //Smallest size VM, free for student subscription
param OPNsenseVirtualMachineName string = 'skyline-gateway'

//OPNsense Networking parameters
param OPNsenseTrustedNicPrivateIPv4Address string = '10.0.0.4'

//OPNsense Bootstrap parameters
param OPNsenseBootstrapURI string = 'https://api.github.com/repos/IThune/SkylineCapstone25/contents/scripts/'
param OPNsenseBootstrapScriptName string = 'configureopnsense.sh'
param OPNsenseVersion string = '25.1'
param WALinuxVersion string = '2.12.0.4'  //Azure Linux guest agent
param OPNsenseConfigXMLName string = 'config.xml'
param PythonGatewayScript string = 'get_nic_gw.py'
param AzureAgentActionsConfig string = 'actions_waagent.conf'

//OPNsense Secret Parameters
param AdminUsername string = 'ian-administrator'
@secure()
param AdminPassword string
@secure()
param GithubPrivateToken string

//Network Security Group parameters
param UntrustedNSGName string = 'untrusted-nsg'

//Route table parameters - allows traffic behind opnsense gateway to reach the internet
param rtName string = 'skyline-default-route'
param rtEntryName string = 'default-route'
param rtDestinationAddressPrefix string = '0.0.0.0/0'
// next hop ip address is the trusted NIC ip for opnsense (OPNsenseTrustedNicPrivateIPv4Address)
param nextHopType string = 'Virtual Appliance'

var rtEntries = [
  {
    name: rtEntryName
    properties: {
      addressPrefix: rtDestinationAddressPrefix
      nextHopType: nextHopType
      nextHopIpAddress: OPNsenseTrustedNicPrivateIPv4Address
    }
  }
]
////End Parameters
////Begin Resources

// Custom routing table
module SkylineRoutingTable 'modules/vnet/route-table.bicep' = {
  name: rtName
  params: {
    rtName: rtName
    routes: rtEntries
  }
}
// main vnet
module SkyVnet 'modules/vnet/vnet.bicep' = {
  name: SkynetVirtualNetworkName
  params: {
    vnetAddressSpace: SkynetAddressSpace
    vnetName: SkynetVirtualNetworkName
    subnets: [
      {
        name: TrustedSubnetName
        properties: {
          addressPrefixes:[
            TrustedIPv4Subnet
            TrustedIPv6Subnet
          ]
          routeTable: { id: SkylineRoutingTable.outputs.rtID }
        }
      }     
      {
        name: UntrustedSubnetName
        properties: {
          addressPrefixes: [
            UntrustedIPv4Subnet
            UntrustedIPv6Subnet
          ]
        }
      }
      {
        name: ManagementSubnetName
        properties: {
          addressPrefixes:[
              ManagementIPv4Subnet
              ManagementIPv6Subnet
          ]
        }
      }
    ]
  }
}

// register existing subnets for use in this file

resource UntrustedSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-05-01' existing = {
  name: '${SkynetVirtualNetworkName}/${UntrustedSubnetName}'
}

resource TrustedSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-05-01' existing = {
  name: '${SkynetVirtualNetworkName}/${TrustedSubnetName}'
}
/*
resource ManagementSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-05-01' existing = {
  name: ManagementSubnetName
}
*/
// Public IPs
module PublicIPAddresses 'modules/vnet/publicip.bicep' = {
  name: PublicIPDeploymentName
  params:{
    publicIPv4Name: PublicIPv4AddressName
    publicIPv6Name: PublicIPv6AddressName
    DNSname: PublicIPv4DNSLabel
    DNSname6: PublicIPv6DNSLabel
  }
}

// untrusted NSG
// TODO tighten up these rules, these are test only!
module UntrustedNSG 'modules/vnet/nsg.bicep' = {
  name: UntrustedNSGName
  params: {
    nsgName: UntrustedNSGName
    Location: location
    securityRules: [
      {
        name: 'In-Any'
        properties: {
          priority: 4096
          sourceAddressPrefix: '*'
          protocol: '*'
          destinationPortRange: '*'
          access: 'Allow'
          direction: 'Inbound'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'Out-Any'
        properties: {
          priority: 4096
          sourceAddressPrefix: '*'
          protocol: '*'
          destinationPortRange: '*'
          access: 'Allow'
          direction: 'Outbound'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}


// OPNsense VM
module OPNsense 'modules/VM/opnsense.bicep' = {
  name: OPNsenseVirtualMachineName
  params: {
    //General Parameters
    Location: location
    AdminUsername: AdminUsername
    AdminPassword: AdminPassword

    //Shell script Parameters
    ShellScriptName: OPNsenseBootstrapScriptName
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
     $9 = waagent actions config file
    */
    
    OPNScriptURI: OPNsenseBootstrapURI
    OPNVersion: OPNsenseVersion
    WALinuxVersion: WALinuxVersion
    TrustedSubnetIPv4Prefix: TrustedIPv4Subnet
    ManagementSubnetIPv4Prefix: ManagementIPv4Subnet
    GithubPrivateToken: GithubPrivateToken 
    OPNsenseConfigXML: OPNsenseConfigXMLName
    PythonGatewayScript: PythonGatewayScript
    WAAgentActionsConfig: AzureAgentActionsConfig
    
    //Networking parameters
    trustedSubnetId: TrustedSubnet.id
    untrustedSubnetId: UntrustedSubnet.id
    virtualMachineName: OPNsenseVirtualMachineName
    virtualMachineSize: OPNsenseVirtualMachineSize
    publicIPv4Id: PublicIPAddresses.outputs.publicIPv4Id
    publicIPv6Id: PublicIPAddresses.outputs.publicIPv6Id
    untrustedNsgId: UntrustedNSG.outputs.nsgID
    trustedNsgId: UntrustedNSG.outputs.nsgID  // TODO make a trusted NSG, management NSG
    trustedNicStaticIPv4: OPNsenseTrustedNicPrivateIPv4Address
  }
}

//TODO add the management VM
//TODO add a containerd host VM to the trusted subnet

