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

//OPNsense Bootstrap parameters
param OPNsenseBootstrapURI string = ''  //TODO make a shell script wrapper & custom OPNsense config.xml file for the opnsense-boostrap.sh script
param OPNsenseBootstrapScriptName string = 'configure-opnsense.sh'
param OPNsenseVersion string = '25.1'
param WALinuxVersion string = '2.12.0.4'  //Azure Linux guest agent

//OPNsense Secret Parameters
param AdminUsername string = 'admin'
@secure()
param AdminPassword string
@secure()
param GithubRepoKey string

//Network Security Group parameters
param UntrustedNSGName string = 'untrusted-nsg'

////End Parameters
////Begin Resources

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
  name: UntrustedSubnetName
}
resource TrustedSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-05-01' existing = {
  name: TrustedSubnetName
}
resource ManagementSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-05-01' existing = {
  name: ManagementSubnetName
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

// untrusted NSG
module UntrustedNSG 'modules/vnet/nsg.bicep' = {
  name: UntrustedNSGName
  params: {
    nsgName: UntrustedNSGName
    Location: location
    securityRules: [
      {
        name: 'InboundSSH'
        properties: {
          description: 'Locks down inbound SSH access to the firewall from the Internet. SSH is configured to listen on a non-default port number.'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '58585'
          sourceAddressPrefix: '*' //TODO lock down allowed IP addresses
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 10
          direction: 'Inbound'
        }
      }
    ]
  }
}


// OPNsense VM
module OPNsense 'modules/VM/opnsense.bicep' = {
  name: OPNsenseVirtualMachineName
  params: {
    Location: location
    AdminPassword: AdminPassword
    GithubURIAccessKey: GithubRepoKey
    /*
     Script Params
     $1 = OPNScriptURI
     $2 = OpnVersion
     $3 = WALinuxVersion
     $4 = Trusted Nic subnet prefix - used to get the gateway for trusted subnet
     $5 = Management subnet prefix - used to route/nat allow internet access from Management VM
     $6 = the secret value to access the private github repo URI
    */
    ShellScriptParameters: {
      OpnScriptURI: OPNsenseBootstrapURI
      OpnVersion: OPNsenseVersion
      WALinuxVersion: WALinuxVersion
      TrustedSubnetName: TrustedSubnetName
      ManagementSubnetName: ManagementSubnetName
    }
    OPNScriptURI: OPNsenseBootstrapURI
    ShellScriptName: OPNsenseBootstrapScriptName
    multiNicSupport: true
    trustedSubnetId: TrustedSubnet.id
    untrustedSubnetId: UntrustedSubnet.id
    virtualMachineName: OPNsenseVirtualMachineName
    virtualMachineSize: OPNsenseVirtualMachineSize
    publicIPv4Id: PublicIPAddresses.outputs.publicIPv4Id
    publicIPv6Id: PublicIPAddresses.outputs.publicIPv6Id
    untrustedNsgId: UntrustedNSG.outputs.nsgID
  }
  dependsOn: [
    SkyVnet
    TrustedSubnet
    UntrustedSubnet
  ]
}

//TODO add the management VM
//TODO add a containerd host VM to the trusted subnet

