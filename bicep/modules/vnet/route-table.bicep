// route
param rtName string
param location string = resourceGroup().location

// route table list
param routes array

resource rt 'Microsoft.Network/routeTables@2023-05-01' = {
  name: rtName
  location: location
  properties: {
    disableBgpRoutePropagation: true
    routes: routes
  }
}

output rtID string = rt.id
