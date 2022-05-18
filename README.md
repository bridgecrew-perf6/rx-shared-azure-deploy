# rx-shared-azure-deploy

This shared module can be used to deploy Bicep templates to Azure.
It is also used by other shared modules as a nested template.

## Azure Devops Resource Repository

If a shared module or your pipeline is using the 'rx-shared-azure-deploy' resository you should add this as an Azure Devops Resource in your pipeline.
Check the latest release for specifing the latest version.

'''yml
resources:
  repositories:
    - repository: rx-shared-azure-deploy
      name: gjlabus/rx-shared-azure-deploy
      endpoint: gjlabus
      type: github
      ref: release/1.0
...
steps:
  - checkout: self
  - checkout: rx-shared-azure-deploy
  - checkout: <othersharedmodule>
```

## Parameters

| Parameter Name          | Type   | Description                                                                                                                        |
| :---------------------- | :----- | :--------------------------------------------------------------------------------------------------------------------------------- |
| 'displayName'           | string | Required. DisplayName of the Task. So that it is easy to identify in Azure Devops Pipeline |
| 'location'              | string | Required. Location where to deploy |
| 'overrideParameters'    | string | Optional. Override parameters for the deployment. You can also only use a TemplateParameterFile.|
| 'resourceGroupName'     | string | Optional. Depending on the location level of deployment the resourceGroupName should be specified.|
| 'serviceConnection'     | string | Required. The name of the Azure Devops Service Connection |
| 'stepName'              | string | Required. Name of task in Azure Devops Pipeline |
| 'subscriptionId'        | string | Required. The Subscription ID where to deploy |
| 'templateFile'          | string | Required. The TemplateFile which needs to be deployed. Bicep |
| 'templateParameterFile' | string | Optional. The Template Parameter File which containing the parameters for the deployment. You can also only use overrideparameters |

### Parameter Usage: 'displayName'

'''yml
displayName: 'Deploy XXXX'
'''

### Parameter Usage: 'location'

'''yml
location: 'eastus'
'''

### Parameter Usage: 'overrideParameters'

This is an optional parameter. You can use 'overrideParameters' and/or 'templateParameterFile'\
You can use it to specify parameters or to override parameters from a template parameter file.

Override parameters only work for simple 'key, value' pairs. For complex parameters use a 'templateParameterFile'.

'''yml
overrideParameters:
  '-parameterA valueA
  -parameterB valueB
  -parameterC valueC'
'''

### Parameter Usage: 'resourceGroupName'

Optional parameter only required when deploying to Resource Group Level.

'''yml
resourceGroupName: rg-xxxxx
'''

### Parameter Usage: 'serviceConnection'

'''yml
serviceConnection: serviceConnectionNameInAzureDevops
'''

### Parameter Usage: 'stepName'

Identifier in Azure Devops Pipeline. No spaces or special characters.

'''yml
stepName: deployresourcea
'''

### Parameter Usage: 'subscriptionId'

'''yml
subscriptionId: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
'''

### Parameter Usage: 'templateFile'

This is a required parameter.

Bicep Template

'''yml
templateFile: $(System.DefaultWorkingDirectory)/templates/deploy.bicep
'''

### Parameter Usage: 'templateParameterFile'

This is optional parameter. You can use 'overrideParameters' and/or 'templateParameterFile'
You can use the 'overrideParameters' to override template parameters.

Bicep Parameters Template

'''yml
templateFile: $(System.DefaultWorkingDirectory)/parameters/deploy.parameters.bicep
'''

## Example Steps Pipeline

below some examples

### Subscription Level Deployment

'resourceGroupName' parameter is not specified

'''yml
steps:
  - template: pipelines/steps.pipeline.yml@rx-shared-azure-deploy
    parameters:
      stepName: XXXX
      displayName: 'Deploy XXXX'
      subscriptionId: ${{ parameters.subscriptionId }}
      location: ${{ parameters.location }}
      serviceConnection: ${{ parameters.serviceConnection }}
      templateFile: $(System.DefaultWorkingDirectory)/templates/deploy.bicep
      templateParameterFile: $(System.DefaultWorkingDirectory)/parameters/deploy.parameters.bicep
'''

### Resoure Group Level Deployment (only overrideParameters)

'templateParameterFile' parameter is not specified

'''yml
steps:
  - template: pipelines/steps.pipeline.yml@rx-shared-azure-deploy
    parameters:
      stepName: XXXX
      displayName: 'Deploy XXXX'
      subscriptionId: ${{ parameters.subscriptionId }}
      resourceGroupName: ${{ parameters.resourceGroupName }}
      location: ${{ parameters.location }}
      serviceConnection: ${{ parameters.serviceConnection }}
      templateFile: '$(System.DefaultWorkingDirectory)/templates/deploy.bicep'
      overrideParameters: 
        '-parameterA valueA
        -parameterB valueB
        -parameterC valueC'
'''

### Resoure Group Level Deployment (templateParameterFile and overrideParameters)

'templateParameterFile'  and 'overrideParameters' parameters are specified

'''yml
steps:
  - template: pipelines/steps.pipeline.yml@rx-shared-azure-deploy
    parameters:
      stepName: XXXX
      displayName: 'Deploy XXXX'
      subscriptionId: ${{ parameters.subscriptionId }}
      resourceGroupName: ${{ parameters.resourceGroupName }}
      location: ${{ parameters.location }}
      serviceConnection: ${{ parameters.serviceConnection }}
      templateFile: '$(System.DefaultWorkingDirectory)/templates/deploy.bicep'
      templateParameterFile: $(System.DefaultWorkingDirectory)/parameters/deploy.parameters.bicep
      overrideParameters: 
        '-parameterA valueA'
'''