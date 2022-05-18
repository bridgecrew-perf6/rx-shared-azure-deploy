<#
    .SYNOPSIS
        Script for deploying Bicep Templates to Azure.
    .DESCRIPTION
        This script make it possible to deploy a Bicep Template to Azure.
        It can be used to override or pass parameters to the deployment.
        Reason behind this script is that there is no builtin Azure Devops Task to deploy Bicep Files.
        The script will transform bicep code to ARM json if needed.
    .PARAMETER ManagementGroupId
        Optional. Management Group Id used when deploying to Manage Group Level.
    .PARAMETER SubscriptionId
        Mandatory. Subscription ID of the Subscription where to deploy to. Used for setting the right Az Context.
    .PARAMETER ResourceGroupName
        Optional. Resource Group Name of the Resource Group where to deploy to. Used when deploying to Resource Group Level.
    .PARAMETER Location
        Optional. Location where to deploy to. like "eastus". Used when deploying to Tenant, ManagementGroup or Subscription Level.
    .PARAMETER StepName
        Mandatory. StepName for Azure Devops Pipeline. Used for deployment name in Azure.
    .PARAMETER TemplateFile
        Mandatory. Path of Bicep Template file.
    .PARAMETER TemplateParameterFile
        Optional. Path of Bicep Parameter Template file.
    .PARAMETER OverrideParameters
        Optional. String of key value pair to override or set parameters during deployment.
        example: -param1 "value1" -param2 "value2"
    .INPUTS
        none
    .OUTPUTS
        none
    .EXAMPLE
        New-Deploy.ps1 -SubscriptionId "$SubscriptionId" -ResourceGroupName "$ResourceGroupName" -Location "$Location" -StepName "$StepName" -TemplateFile "$TemplateFile" -TemplateParameterFile "$TemplateParameterFile" -OverrideParameters "$OverrideParameters"
    .LINK
        https://github.com/gjlabus/rx-shared-azure-deploy
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [String] $ManagementGroupId,
    [Parameter(Mandatory = $true)]
    [String] $SubscriptionId,
    [Parameter(Mandatory = $false)]
    [String] $ResourceGroupName,
    [Parameter(Mandatory = $false)]
    [String] $Location,
    [Parameter(Mandatory = $true)]
    [String] $StepName,
    [Parameter(Mandatory = $true)]
    [String] $TemplateFile,
    [Parameter(Mandatory = $false)]
    [String] $TemplateParameterFile,
    [Parameter(Mandatory = $false)]
    [String] $OverrideParameters
)

function MergeHashtable($HT, $HTtoMerge) {
    foreach ($key in $HTtoMerge.keys) {
        if ($HT.containskey($key)) {
            $HT.remove($key)
        }
    }
    return $HT + $HTtoMerge
}

function Install-BicepModule {
    $Modules = @(
        @{
            name = 'bicep'
        }
    )
    foreach ($Module in $Modules) {
        if (Get-InstalledModule -Name $($Module.name) -ErrorAction SilentlyContinue) {
            Write-Information "Module Already Installed: $($Module.name)"
        }
        else {
            try {
                Write-Information "Installing Module: $($Module.name)"
                Install-Module -Name $($Module.name) -Confirm:$False -Force -AllowClobber
                Write-Information "Done: $($Module.name)"
            }
            catch [Exception] {
                $_.message
                exit
            }
        }
    }
}

$InformationPreference = "Continue"

# Template File TargetScope
if ($TemplateFile -like "*.bicep") {
    $TargetScope = Get-Content -Path $TemplateFile | Where-Object { $_.Contains("targetScope") }
    if (!($TargetScope)) {
        $TargetScope = 'Default'
    }
}
else {
    $htTemplateFile = (ConvertFrom-Json (Get-Content -Raw -Path $TemplateFile) -AsHashtable)
    $TargetScope = $htTemplateFile.'$schema'
}

# Set Correct Subscription
if ( (Get-AzContext).Subscription.Id -ne "$SubscriptionId" ) {
    Set-AzContext "$SubscriptionId"
}

# DeploymentInput Hashtable
$DeploymentInputs = @{
    Name         = "$StepName-$(-join (Get-Date -Format yyyyMMddTHHMMssffffZ)[0..63])"
    TemplateFile = "$TemplateFile"
    Verbose      = $true
    ErrorAction  = "Stop"
}

# Set Parameters
$ParameterObjectArm = @{}
if ($TemplateParameterFile -ne "$null") {
    if (Test-Path -Path $TemplateParameterFile) {
        Write-Information "Got Parameter File: $TemplateParameterFile"
        if ($TemplateParameterFile -like "*.bicep") {
            Install-BicepModule
            New-BicepParameterFile -Path "$TemplateParameterFile" -Parameters All
            $TemplateParameterFile = $($TemplateParameterFile.Split(".bicep")[0] + ".parameters.json")
        }
        $ht = (ConvertFrom-Json (Get-Content -Raw -Path $TemplateParameterFile) -AsHashtable)
        foreach ($i in $ht.parameters.GetEnumerator()) {
            $ParameterObjectArm."$($i.key)" = ($i.value).value
        }
    }
    else {
        Write-Error -Message "Could not find TemplateParameterFile: $($TemplateParameterFile)"
    }
}

# Set Override Parameters
$ParameterObjectOverride = @{}
if ($OverrideParameters -ne "$null") {
    Write-Information "Got override parameters: $OverrideParameters"
    ($OverrideParameters.Trim() -replace ('\s+', ' ')).Substring(1) -split '\s+-' | ForEach-Object {
        $key = ($_.Split(' ')[0]).Trim()
        $inputValue = ($_.Split(' ')[1..($_.Split(' ').Length)] -join ' ' )
        try {
            $jsonAsObject = ConvertFrom-Json $inputValue -AsHashtable
            $value = $jsonAsObject
        }
        catch {
            $value = $inputValue
        }
        $ParameterObjectOverride.Add($key, $value)
    }
    $ParameterObjectOverride
}

# Merge parameters and override parameters
$TemplateParameterObject = MergeHashtable $ParameterObjectArm $ParameterObjectOverride
$DeploymentInputs += @{
    TemplateParameterObject = $TemplateParameterObject
}

# deploy to correct TargetScope
Switch -regex ($TargetScope) {
    'deploymentTemplate' {
        Write-Information 'Handling resource group level deployment'
        $DeploymentInputs += @{
            ResourceGroupName = $ResourceGroupName
        }
        New-AzResourceGroupDeployment @DeploymentInputs
        break
    }
    'subscription' {
        Write-Information 'Handling subscription level deployment'
        $DeploymentInputs += @{
            Location = $Location
        }
        New-AzSubscriptionDeployment @DeploymentInputs
        break
    }
    'managementGroup' {
        Write-Information 'Handling management group level deployment'
        $DeploymentInputs += @{
            ManagementGroupId = $ManagementGroupId
            Location          = $Location
        }
        New-AzManagementGroupDeployment @DeploymentInputs
        break
    }
    'tenant' {
        Write-Information 'Handling tenant level deployment'
        $DeploymentInputs += @{
            Location = $Location
        }
        New-AzTenantDeployment @DeploymentInputs
        break
    }
    default {
        Write-Information 'Handling resource group level deployment'
        $DeploymentInputs += @{
            ResourceGroupName = $ResourceGroupName
        }
        New-AzResourceGroupDeployment @DeploymentInputs
    }
}
