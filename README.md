This repository contains resource for a Azure Network Security Perimeter session. This repository has the following resources:
- Azure DevOps pipeline which deploys the following:
  - A resource group with app service and sql database with VNET
  - A resource group with app service, storage account and keyvault with NSP
- Powerpoint presentation

To be able to deploy the code you should first adjust the variables in [azure-pipelines.yml](./azuredevops/azure-pipelines.yml)