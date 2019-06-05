Param(
    [Parameter(Mandatory = $false)][string]$templateLibraryName = (Split-Path (Resolve-Path "$PSScriptRoot\..") -Leaf),
    [string]$Location = "canadacentral",
    [string]$subscription = "",
    [switch]$devopsCICD = $false,
    [switch]$doNotCleanup = $false
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

function getBaseParametersURL {
    $remoteURL = git config --get remote.origin.url
    $currentBranch = git rev-parse --abbrev-ref HEAD
    $remoteURLnogit = $remoteURL -replace '\.git', ''
    $remoteURLRAW = $remoteURLnogit -replace 'github.com', 'raw.githubusercontent.com'
    $baseParametersURL = $remoteURLRAW + '/' + $currentBranch + '/test/parameters/'
    return $baseParametersURL
}

$currentBranch = "dev"
$validationURL = "https://raw.githubusercontent.com/canada-ca-azure-templates/$templateLibraryName/dev/template/azuredeploy.json"
$baseParametersURL = "https://raw.githubusercontent.com/canada-ca-azure-templates/$templateLibraryName/dev/test/"

if (-not $devopsCICD) {
    $currentBranch = git rev-parse --abbrev-ref HEAD

    if ($currentBranch -eq 'master') {
        Write-Host "You are working off the master branch... Validation will happen against the github master branch code and will not include any changes you may have made."
        Write-Host "If you want to walidate changes you have made make sure to create a new branch and push those to the remote github server with something like:"
        Write-Host ""
        Write-Host "git branch dev ; git add ..\. ; git commit -m "Update validation" ; git push -u origin dev"
    }
    else {
        # Make sure we update code to git
        # git branch dev ; git checkout dev ; git pull origin dev
        git add ..\. ; git commit -m "Update validation" ; git push -u origin $currentBranch
    }

    $validationURL = getValidationURL
    $baseParametersURL = getBaseParametersURL
}

if ($subscription -ne "") {
    Select-AzureRmSubscription -Subscription $subscription
}

# Cleanup validation resource content in case it did not properly completed and left over components are still lingeringcd
if (-not $doNotCleanup) {
    #check for existing resource group
    $resourceGroup = Get-AzureRmResourceGroup -Name PwS2-validate-$templateLibraryName-RG -ErrorAction SilentlyContinue

    if ($resourceGroup) {
        Write-Host "Cleanup old $templateLibraryName template validation resources if needed..."

        Remove-AzureRmResourceGroup -Name PwS2-validate-resourcegroups-1-RG -Verbose -Force -AsJob
        Remove-AzureRmResourceGroup -Name PwS2-validate-resourcegroups-2-RG -Verbose -Force -AsJob

        Write-Host "Waiting for parallel RG deletion jobs to finish..."
        Get-Job | Wait-Job
    }
}

# Validating server template
Write-Host "Starting $templateLibraryName validation deployment...";

New-AzureRmDeployment -Location canadacentral -Name "validate-$templateLibraryName-template" -TemplateUri $validationURL -TemplateParameterFile (Resolve-Path "$PSScriptRoot\parameters\validate.parameters.json") -Verbose

$provisionningState = (Get-AzureRmDeployment -Name "validate-$templateLibraryName-template").ProvisioningState

# Cleanup validation resource content
if (-not $doNotCleanup) {
    Write-Host "Cleanup $templateLibraryName template validation resources...";

    Remove-AzureRmResourceGroup -Name PwS2-validate-resourcegroups-1-RG -Verbose -Force -AsJob
    Remove-AzureRmResourceGroup -Name PwS2-validate-resourcegroups-2-RG -Verbose -Force -AsJob

    Write-Host "Waiting for parallel RG deletion jobs to finish..."
    Get-Job | Wait-Job
}

if ($provisionningState -eq "Failed") {
    throw  "Validation deployment failed..."
}