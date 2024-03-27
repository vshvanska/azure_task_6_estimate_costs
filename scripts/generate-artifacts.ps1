param(
    [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
    [string]$ArtifactsStorageAccountName='matestorage123'
)

# default script values
$taskName = "task6"

$containerName = "task-artifacts"
$artifactsConfigPath = "$PWD/artifacts.json"

$spreadsheetName = "ExportedEstimate.xlsx"

# initial validation
Write-Output "Running initial validation"
$context = Get-AzContext  
if ($context)   
{  
    Write-Output "Azure Powershell module is installed, account is connected."  
} else {  
    throw "Please log in to Azure using Azure Powershell module (run Connect-AzAccount)"
}  

Write-Output "Checking if storage account exists"
$storageAccount = (Get-AzStorageAccount -ErrorAction SilentlyContinue | Where-Object -Property 'StorageAccountName' -EQ -Value $ArtifactsStorageAccountName )
if ($storageAccount) {
    Write-Output "Storage account found"
} else { 
    throw "Unable to find storage account $ArtifactsStorageAccountName. Please make sure, that you specified the correct name of the storage account for the artifacts and that it is present in your Azure subscription"
}

Write-Output "Checking if artifacts storage container exists" 
$artifactContainer = Get-AzStorageContainer -Name $containerName -Context $storageAccount.Context -ErrorAction SilentlyContinue
if ($artifactContainer) { 
    Write-Output "Storage container for artifacts found!" 
} else { 
    throw "Unable to find a storage container $containerName in the storage account $ArtifactsStorageAccountName, please make sure that it's created"
}

# generation of artifacts
Write-Output "Generating artifacts..."

if (Test-Path -Path "$PWD/$spreadsheetName" -ErrorAction SilentlyContinue) { 
    Write-Output "Pricing calculations found - OK"
} else { 
    throw "Unable to find exported pricing calculations file ($spreadsheetName). Please make sure that you copied the file to the repository folder."
}

Write-Output "Uploading spreadsheet"
$ResourcesTemplateBlob = @{
    File             = "$PWD/$spreadsheetName"
    Container        = $containerName
    Blob             = "$taskName/$spreadsheetName"
    Context          = $storageAccount.Context
    StandardBlobTier = 'Hot'
}
$blob = Set-AzStorageBlobContent @ResourcesTemplateBlob -Force

Write-Output "Generating a SAS token for the artifact"
$date = Get-Date
$date = $date.AddDays(30) 
$resourcesTemplateSaSToken = New-AzStorageBlobSASToken -Container $containerName -Blob "$taskName/$spreadsheetName" -Permission r -ExpiryTime $date -Context $storageAccount.Context
$pricingCalculationsURL = "$($blob.ICloudBlob.uri.AbsoluteUri)?$resourcesTemplateSaSToken"


# updating artifacts config
Write-Output "Updating artifacts config"
$artifactsConfig = @{
    pricingCalculationsURL = "$pricingCalculationsURL"
}
$artifactsConfig | ConvertTo-Json | Out-File -FilePath $artifactsConfigPath -Force
