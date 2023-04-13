@description('Name for the SQL Server')
param serverName string
@description('AD Group Object ID for the SQL Admins')
param sqlAdminGroupObjectId string
@description('AD Group Name for the SQL Admins')
param sqlAdminGroupName string
@description('Location for all resources.')
param location string = resourceGroup().location
@description('Email address to send vulnerability scan results to')
param vulnerabilityScanEmails string = 'SQLAdmin@TEST.COM'
@description('Log Analytics Workspace ID to send SQL Diagnostics to')
param logAnalyticsWorkspaceID string
@description('Storage Account Endpoint for Vulnerability Assessment')
param storageAccountVulnerabilityEndpoint string
@description('Storage Account Name for Vulnerability Assessment')
param storageAccountName string

var blobContributorRoleId = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
/*
resource vulnerabilityStorageAccount 'Microsoft.Storage/storageAccounts@2021-06-01' existing = {
  name: storageAccountName
}
*/
resource sqlServerAdvancedSecurityAssessment 'Microsoft.Sql/servers/securityAlertPolicies@2022-08-01-preview' = {
  name: 'advancedSecurityAssessment'
  parent: sqlServer
  properties:{
    state: 'Enabled'
  }
}
resource sqlServer 'Microsoft.Sql/servers@2022-08-01-preview' = {
  name: toLower('sql-${serverName}')
  location: location
  properties: {
    version: '12.0'
    minimalTlsVersion: '1.2'
    publicNetworkAccess: 'Enabled'
    restrictOutboundNetworkAccess: 'Disabled'
    administrators: {
      administratorType: 'ActiveDirectory'
      tenantId: subscription().tenantId
      principalType: 'Group'
      azureADOnlyAuthentication: true
      login: sqlAdminGroupName
      sid: sqlAdminGroupObjectId
    }
  }
  identity:{
    type: 'SystemAssigned'
  }
}


resource sqlVulnerability 'Microsoft.Sql/servers/vulnerabilityAssessments@2022-08-01-preview' = {
  name: 'default'
  parent: sqlServer
  properties: {
    recurringScans:{
      emails: [
        vulnerabilityScanEmails
      ]
      isEnabled: true
    }
    storageContainerPath: storageAccountVulnerabilityEndpoint
  }
  
}



 resource SqlDbDiagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' ={
  name: 'logAnalyticsDiagnosticSettings'
  scope: masterDb
  properties: {
    workspaceId: logAnalyticsWorkspaceID
    logs:[
      {
        category: 'SQLSecurityAuditEvents'
        enabled: true
      }
    ]
  }
  }
 resource sqlAudit 'Microsoft.Sql/servers/auditingSettings@2022-05-01-preview'={
   name: 'default'
   parent: sqlServer
   properties:{
     auditActionsAndGroups:[
      'BATCH_COMPLETED_GROUP'
      'SUCCESSFUL_DATABASE_AUTHENTICATION_GROUP'
      'FAILED_DATABASE_AUTHENTICATION_GROUP'
     ]
     isAzureMonitorTargetEnabled: true
     state:'Enabled'
   }
 }
 resource masterDb 'Microsoft.Sql/servers/databases@2022-08-01-preview' = {
  parent: sqlServer
  location: location
  name: 'master'
  properties: {}
  }
/*
  resource sqlStorageAccountRBAC 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
    name: guid(vulnerabilityStorageAccount.id,sqlServer.id, blobContributorRoleId )
    scope: vulnerabilityStorageAccount
    properties:{
      roleDefinitionId: blobContributorRoleId
      principalId: sqlServer.identity.principalId
      principalType: 'ServicePrincipal'
    }
  }
*/
  resource advancedThreatProtection 'Microsoft.Sql/servers/advancedThreatProtectionSettings@2022-08-01-preview' = {
    name: 'Default'
    parent: sqlServer
    properties: {
      state: 'Enabled'
    }
  }
 output sqlServerName string = sqlServer.name
