var resourceNamePostfix = '-wn-nsp-session'
var storageBlobDataReaderRoleId = '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1' // Storage Blob Data Reader
var keyVaultSecretReaderRoleId = '4633458b-17de-408a-b874-0445c86b69e6' // Key Vault Secrets User

resource appServicePlan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: 'asp${resourceNamePostfix}'
  location: resourceGroup().location
  sku: {
    name: 'B1'
    tier: 'Basic'
  }
  kind: 'linux'
  properties: {
    reserved: true
  }
}
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: 'appi${resourceNamePostfix}'
  location: resourceGroup().location
  kind: 'web'
  properties: {
    Application_Type: 'web'
  }
}

resource appService 'Microsoft.Web/sites@2022-03-01' = {
  name: 'app${resourceNamePostfix}'
  location: resourceGroup().location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      appSettings: [
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appInsights.properties.InstrumentationKey
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsights.properties.ConnectionString
        }
      ]
    }
  }
}

resource appServiceAppSettings 'Microsoft.Web/sites/config@2022-03-01' = {
  parent: appService
  name: 'appsettings'
  properties: {
    Azure__BlobContainerUri: 'https://${storageAccount.name}.blob.${environment().suffixes.storage}'
    Azure__KeyVaultUri: 'https://${keyVault.name}${environment().suffixes.keyvaultDns}'
  }
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: replace('sa${resourceNamePostfix}', '-', '')
  location: resourceGroup().location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    minimumTlsVersion: 'TLS1_2'
  }

  resource blobContainer 'blobServices' = {
    name: 'default'

    resource nsp 'containers' = {
      name: 'nsp'
    }
  }
}

resource appServiceBlobReaderRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: storageAccount
  name: guid(storageAccount.id, storageBlobDataReaderRoleId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataReaderRoleId)
    principalId: appService.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' = {
  name: 'kv${resourceNamePostfix}'
  location: resourceGroup().location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    enableRbacAuthorization: true
  }

  resource secret 'secrets' = {
    name: 'verysecret'
    properties: {
      value: 'verysecretvalue'
    }
  }
}

resource appServiceSecretReaderRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: keyVault
  name: guid(storageAccount.id, keyVaultSecretReaderRoleId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', keyVaultSecretReaderRoleId)
    principalId: appService.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource nsp 'Microsoft.Network/networkSecurityPerimeters@2024-06-01-preview' = {
  name: 'nsp${resourceNamePostfix}'
  location: resourceGroup().location
  properties: {}

  resource defaultProfile 'profiles' = {
    name: 'defaultProfile'

    resource subscriptionAccessRule 'accessRules' = {
      name: 'subscriptionAccessRule'
      properties: {
        direction: 'Inbound'
        subscriptions: [
          {
            id: '/subscriptions/${subscription().subscriptionId}'
          }
        ]
      }
    }
  }

  resource keyVaultNspAssociation 'resourceAssociations' = {
    name: 'nsp-${keyVault.name}'
    properties: {
      accessMode: 'Learning'
      profile: {
        id: defaultProfile.id
      }
      privateLinkResource: {
        id: keyVault.id
      }
    }
  }

  resource storageAccountNspAssociation 'resourceAssociations' = {
    name: 'nsp-${storageAccount.name}'
    properties: {
      accessMode: 'Learning'
      profile: {
        id: defaultProfile.id
      }
      privateLinkResource: {
        id: storageAccount.id
      }
    }
  }
}

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2025-02-01' = {
  name: 'law${resourceNamePostfix}'
  location: resourceGroup().location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}
