terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.0.0"
    }

    azapi = {
      source  = "Azure/azapi"
      version = "~>0.5.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# creating resource group
resource "azurerm_resource_group" "devopsrg" {
  name     = "devopsrg"
  location = "East Asia"
}

# creating log analytics workspace
resource "azurerm_log_analytics_workspace" "devopslaw" {
  name                = "devopslaw"
  resource_group_name = azurerm_resource_group.devopsrg.name
  location            = azurerm_resource_group.devopsrg.location
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

# creating aca environment
resource "azapi_resource" "devopsaca" {
  type      = "Microsoft.App/managedEnvironments@2022-03-01"
  parent_id = azurerm_resource_group.devopsrg.id
  location  = azurerm_resource_group.devopsrg.location
  name      = "devopsaca"

  body = jsonencode({
    properties = {
      appLogsConfiguration = {
        destination = "log-analytics"
        logAnalyticsConfiguration = {
          customerId = azurerm_log_analytics_workspace.devopslaw.workspace_id
          sharedKey  = azurerm_log_analytics_workspace.devopslaw.primary_shared_key
        }
      }
    }
  })
}

# creating the aca
resource "azapi_resource" "aca" {
  type      = "Microsoft.App/containerApps@2022-03-01"
  parent_id = azurerm_resource_group.devopsrg.id
  location  = azurerm_resource_group.devopsrg.location
  name      = "webapp"

  body = jsonencode({
    properties : {
      managedEnvironmentId = azapi_resource.devopsaca.id
      configuration = {
        ingress = {
          external   = true
          targetPort = 80
        }
      }
      template = {
        containers = [
          {
            name  = "webcontainers"
            image = "nginx"
            resources = {
              cpu    = 0.25
              memory = "0.5Gi"
            }
          }
        ]
        scale = {
          minReplicas = 2
          maxReplicas = 10
        }
      }
    }
  })
}