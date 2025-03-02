//This module will deploy 2 public IP addresses: an IPv4 and an IPv6

//General parameters
param location string = resourceGroup().location
param DNSname string
param DNSname6 string

param publicIPv4Name string
param publicIPv6Name string


resource publicIPv4Address 'Microsoft.Network/publicIPAddresses@2023-05-01' = {
  name: publicIPv4Name
  location: location
  sku: {name: 'Standard'}
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: DNSname
    }
  }
}
resource publicIPv6Address 'Microsoft.Network/publicIPAddresses@2023-05-01' = {
  name: publicIPv6Name
  location: location
  sku: {name:'Standard'}
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv6'
    dnsSettings: {
      domainNameLabel: DNSname6
    }
  }
}
output publicIPv4Id string = publicIPv4Address.id
output publicIPv4Address string = publicIPv4Address.properties.ipAddress
output publicIPv6Id string = publicIPv6Address.id
output publicIPv6Address string = publicIPv6Address.properties.ipAddress

