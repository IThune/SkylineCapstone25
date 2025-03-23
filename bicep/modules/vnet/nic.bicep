// This module will deploy a dual-stack NIC

//General Parameters
param Location string = resourceGroup().location
param nicName string
param nsgId string = ''
param enableIPForwarding bool = false

//IP Config Parameters
param SubnetId string
param publicIPv4Id string = ''
param publicIPv6Id string = ''

//TODO Load Balancer stuff?
//param loadBalancerBackendAddressPoolId string = ''
//param loadBalancerInboundNatRules string = ''

resource nic 'Microsoft.Network/networkInterfaces@2023-05-01' = {
  name: nicName
  location: Location
  properties: {
    enableIPForwarding: enableIPForwarding
    networkSecurityGroup:{id: nsgId}
    ipConfigurations: [
      {
        name: 'IPv4Config'
        properties: {
          subnet: {id: SubnetId}
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: first(publicIPv4Id) == '/' ? {id: publicIPv4Id}:null
          primary: true
          
          //loadBalancerBackendAddressPools: first(loadBalancerBackendAddressPoolId) == '/' ? [{id: loadBalancerBackendAddressPoolId}]:null
          //loadBalancerInboundNatRules: first(loadBalancerInboundNatRules) == '/' ? [{id: loadBalancerInboundNatRules}]:null
          
        }
      }
      
      {
        name: 'IPv6Config'
        properties: {
          privateIPAddressVersion: 'IPv6'
          subnet: {id: SubnetId}
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: first(publicIPv6Id) == '/' ? {id: publicIPv6Id}:null
        }
      }
      
    ]
  }
}
output nicName string = nic.name
output nicId string = nic.id
output nicIP string = nic.properties.ipConfigurations[0].properties.privateIPAddress
output nicIPv4ConfigId string = nic.properties.ipConfigurations[0].id
output nicIPv6ConfigId string = nic.properties.ipConfigurations[1].id
