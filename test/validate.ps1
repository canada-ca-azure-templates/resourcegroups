Param(
    [Parameter(Mandatory = $false)][string]$templateLibraryName = "asg",
    [string]$templateName = "azuredeploy.json",
    [string]$Location = "canadacentral",
    [string]$subscription = "2de839a0-37f9-4163-a32a-e1bdb8d6eb7e"
)

#******************************************************************************
# Script body
# Execution begins here
#******************************************************************************

Select-AzureRmSubscription -Subscription $subscription

# Start the deployment
Write-Host "Starting validation deployment...";

New-AzureRmDeployment -Location $Location -Name "Validate-RG" -TemplateUri "https://raw.githubusercontent.com/canada-ca/accelerators_accelerateurs-azure/master/Templates/arm/masterdeploy/20190319.1/masterdeploysub.json" -TemplateParameterFile (Resolve-Path -Path "$PSScriptRoot\parameters\masterdeploysub.parameters.json") -Verbose;

$provisionningState = (Get-AzureRmDeployment -Name "Validate-RG").ProvisioningState

if ($provisionningState -eq "Failed") {
    Write-Host "One of the jobs was not successfully created... exiting..."
    exit
}
