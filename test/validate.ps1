Param(
    [Parameter(Mandatory = $false)][string]$templateLibraryName = "resourcegroups",
    [string]$templateName = "azuredeploy.json",
    [string]$Location = "canadacentral",
    [string]$subscription = "2de839a0-37f9-4163-a32a-e1bdb8d6eb7e"
)

#******************************************************************************
# Script body
# Execution begins here
#******************************************************************************

function getValidationURL {
    $remoteURL = git config --get remote.origin.url
    $currentBranch = git rev-parse --abbrev-ref HEAD
    $remoteURLnogit = $remoteURL -replace '\.git', ''
    $remoteURLRAW = $remoteURLnogit -replace 'github.com', 'raw.githubusercontent.com'
    $validateURL = $remoteURLRAW + '/' + $currentBranch + '/template/azuredeploy.json'
    return $validateURL
}

$currentBranch = git rev-parse --abbrev-ref HEAD

if ($currentBranch -eq 'master') {
    $confirmation = Read-Host "You are working off the master branch... are you sure you want to validate the template from here? Switch to the dev branch is recommended. Continue? (y/n)"
    if ($confirmation -ne 'y') {
        exit
    }
}

# Make sure we update code to git
# git branch dev ; git checkout dev ; git pull origin dev
git add . ; git commit -m "Update validation" ; git push origin $currentBranch

Select-AzureRmSubscription -Subscription $subscription

# Validating server template
Write-Host "Starting $templateLibraryName validation deployment...";

$validationURL = getValidationURL
New-AzureRmDeployment -Location canadacentral -Name "validate-$templateLibraryName-template" -TemplateUri $validationURL -TemplateParameterFile (Resolve-Path "$PSScriptRoot\parameters\validate.parameters.json") -Verbose

$provisionningState = (Get-AzureRmDeployment -Location canadacentral -Name "validate-$templateLibraryName-template").ProvisioningState

if ($provisionningState -eq "Failed") {
    Write-Host  "Test deployment failed..."
}