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

////Public IP parameters
param PublicIPDeploymentName string = 'SkylinePublicIP'
param PublicIPv4AddressName string = 'skyline-public-ipv4'
param PublicIPv6AddressName string = 'skyline-public-ipv6'
param PublicIPv4DNSLabel string = 'skylinetest' //skyline.eastus.cloudapp.azure.com will resolve to this public IPv4 address
param PublicIPv6DNSLabel string = 'skyline6test'  //skyline6.eastus.cloudapp.azure.com will resolve to this public IPv6 address

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
param AzureAgentActionsConfig string = 'actions_waagent.conf'

//OPNsense Secret Parameters
param AdminUsername string
@secure()
param AdminPassword string
@secure()
param GithubPrivateToken string


////Zoneminder VM Parameters
//General VM Parameters
param ZoneminderVirtualMachineSize string = 'Standard_B1s'
param ZoneminderVirtualMachineName string = 'skyline-nvr'

//Zoneminder Networking Parameters
param ZoneminderTrustedNicPrivateIPv4Address string = '10.0.0.5'

//Zoneminder deployment script parameters
param ZoneminderShellScriptName string = 'configurezoneminder.sh'
param ZoneminderScriptURI string = 'https://api.github.com/repos/IThune/SkylineCapstone25/contents/scripts/'

//Zoneminder secret parameters
param ZoneminderMySQLUsername string = 'zmuser'
@secure()
param ZoneminderMySQLPassword string
param ZoneminderAdminUsername string
@secure()
param ZoneminderAdminPassword string

//Network Security Group parameters
param UntrustedNSGName string = 'untrusted-nsg'
param TrustedNSGName string = 'trusted-nsg'

//Route table parameters - allows traffic behind opnsense gateway to reach the internet
param rtName string = 'skyline-default-route'
param rtEntryName string = 'default-route'
param rtDestinationAddressPrefix string = '0.0.0.0/0'
// next hop ip address is the trusted NIC ip for opnsense (OPNsenseTrustedNicPrivateIPv4Address)
param nextHopType string = 'VirtualAppliance'

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

// Network Security Group definitions
// rules are stateful so no need to replicate them for both inbound/outbound
module UntrustedNSG 'modules/vnet/nsg.bicep' = {
  name: UntrustedNSGName
  params: {
    nsgName: UntrustedNSGName
    Location: location
    securityRules: [
      // Inbound Rules
      // Allow inbound wireguard traffic (51820 udp)
      {
        name: 'Allow-WG-In-IPv4'
        properties: {
          priority: 4095
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          protocol: 'udp'
          destinationPortRange: '51820'
          access: 'Allow'
          direction: 'Inbound'
          destinationAddressPrefix: UntrustedIPv4Subnet
        }
      }
      {
        name: 'Allow-WG-In-IPv6'
        properties: {
          priority: 4096
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          protocol: 'udp'
          destinationPortRange: '51820'
          access: 'Allow'
          direction: 'Inbound'
          destinationAddressPrefix: UntrustedIPv6Subnet
        }
      }
      // Outbound Rules
      // Allow https and http outbound for package updates
      {
        name: 'Allow-HttpOut-Any'
        properties: {
          priority: 4094
          sourceAddressPrefix: UntrustedIPv4Subnet
          sourcePortRange: '*'
          protocol: 'tcp'
          destinationPortRange: '80'
          access: 'Allow'
          direction: 'Outbound'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'Allow-HttpsOut-Any'
        properties: {
          priority: 4095
          sourceAddressPrefix: UntrustedIPv4Subnet
          sourcePortRange: '*'
          protocol: 'tcp'
          destinationPortRange: '443'
          access: 'Allow'
          direction: 'Outbound'
          destinationAddressPrefix: '*'
        }
      }
      //deny-any outbound rule
      {
        
        name: 'Deny-InternetOut-Any'
        properties: {
          priority: 4096
          sourceAddressPrefix: '*'
          protocol: '*'
          destinationPortRange: '*'
          access: 'Deny'
          direction: 'Outbound'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

module TrustedNSG 'modules/vnet/nsg.bicep' = {
  name: TrustedNSGName
  params: {
    nsgName: TrustedNSGName
    Location: location
    securityRules: [
      // Inbound rules
      //Default Inbound rules apply

      //Outbound rules
      //deny-any outbound rule
      {
        name: 'Deny-InternetOut-Any'
        properties: {
          priority: 4096
          sourceAddressPrefix: '*'
          protocol: '*'
          destinationPortRange: '*'
          access: 'Deny'
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
     $4 = github token to download files from the private repo
     $5 = file name of the OPNsense config file, default config.xml
     $6 = waagent actions config file
    */
    
    OPNScriptURI: OPNsenseBootstrapURI
    OPNVersion: OPNsenseVersion
    WALinuxVersion: WALinuxVersion
    GithubPrivateToken: GithubPrivateToken 
    OPNsenseConfigXML: OPNsenseConfigXMLName
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

// Zoneminder VM
module Zoneminder 'modules/VM/zoneminder-host.bicep' = {
  name: ZoneminderVirtualMachineName
  params:{
    Location: location
    virtualMachineName: ZoneminderVirtualMachineName
    virtualMachineSize: ZoneminderVirtualMachineSize
    AdminUsername: ZoneminderAdminUsername
    AdminPassword: ZoneminderAdminPassword
    ZMScriptURI: ZoneminderScriptURI
    ShellScriptName: ZoneminderShellScriptName
    MySQLUsername: ZoneminderMySQLUsername
    MySQLPassword: ZoneminderMySQLPassword
    GithubPrivateToken: GithubPrivateToken
    WAAgentActionsConfig: AzureAgentActionsConfig
    nicStaticIPv4: ZoneminderTrustedNicPrivateIPv4Address
    WALinuxVersion: WALinuxVersion
    trustedSubnetId: TrustedSubnet.id
    trustedNsgId: TrustedNSG.outputs.nsgID
  }
}
