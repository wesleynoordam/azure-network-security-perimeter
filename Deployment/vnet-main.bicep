param location string = resourceGroup().location

var context = '-wn-nsp-session'

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2021-05-01' = {
  name: 'vnet${context}'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/26'
      ]
    }
    subnets: [
      {
        name: 'ple-subnet'
        properties: {
          addressPrefix: '10.0.0.0/27'
        }
      }
      {
        name: 'asp-subnet'
        properties: {
          addressPrefix: '10.0.0.32/27'
          delegations: [
            {
              name: 'Microsoft.Web/serverFarms'
              properties: {
                serviceName: 'Microsoft.Web/serverfarms'
              }
            }
          ]
        }
      }
    ]
  }
}

resource appServicePlan 'Microsoft.Web/serverfarms@2021-02-01' = {
  name: 'asp${context}'
  location: location
  sku: {
    name: 'B1'
    tier: 'Basic'
  }
  kind: 'linux'
  properties: {
    reserved: true
  }
}
resource userAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'uami${context}'
  location: location
}

resource sqlServer 'Microsoft.Sql/servers@2023-08-01-preview' = {
  name: 'sql${context}'
  location: location
  properties: {
    version: '12.0'
    administrators: {
      administratorType: 'ActiveDirectory'
      azureADOnlyAuthentication: true
      login: userAssignedIdentity.name
      sid: userAssignedIdentity.properties.principalId
      tenantId: tenant().tenantId
      principalType: 'Application'
    }
  }

  resource sqlDatabase 'databases' = {
    name: 'sqldb${context}'
    location: location
    properties: {
      collation: 'SQL_Latin1_General_CP1_CI_AS'
      maxSizeBytes: 1073741824
    }
    sku: {
      name: 'Basic'
      tier: 'Basic'
    }
  }
}

resource sqlPrivateEndpoint 'Microsoft.Network/privateEndpoints@2021-05-01' = {
  name: 'pe-sql${context}'
  location: location
  properties: {
    subnet: {
      id: virtualNetwork.properties.subnets[0].id
    }
    privateLinkServiceConnections: [
      {
        name: 'sqlServerConnection'
        properties: {
          privateLinkServiceId: sqlServer.id
          groupIds: [
            'sqlServer'
          ]
        }
      }
    ]
  }
}

resource sqlPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink${environment().suffixes.sqlServerHostname}'
  location: 'global'
}

resource sqlDnsZoneVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: sqlPrivateDnsZone
  name: 'vnetlink-sql${context}'
  location: 'global'
  properties: {
    virtualNetwork: {
      id: virtualNetwork.id
    }
    registrationEnabled: false
  }
}

resource sqlPrivateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2021-05-01' = {
  parent: sqlPrivateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'sqlDnsZoneConfig'
        properties: {
          privateDnsZoneId: sqlPrivateDnsZone.id
        }
      }
    ]
  }
}
resource webApp 'Microsoft.Web/sites@2021-02-01' = {
  name: 'app-vnet${context}'
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentity.id}': {}
    }
  }
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      appSettings: [
        {
          name: 'ASPNETCORE_ENVIRONMENT'
          value: 'Production'
        }
      ]
      connectionStrings: [
        {
          name: 'sqlServer'
          type: 'SQLServer'
          connectionString: 'Server=tcp:${sqlServer.name}${environment().suffixes.sqlServerHostname};Database=${sqlServer::sqlDatabase.name};Authentication=Active Directory Managed Identity;User ID=${userAssignedIdentity.properties.clientId};Encrypt=true;Connection Timeout=30;'
        }
      ]
      vnetRouteAllEnabled: true
    }
    virtualNetworkSubnetId: virtualNetwork.properties.subnets[1].id
  }
}
