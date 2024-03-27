param(
    [Parameter(Mandatory=$false, ValueFromPipeline=$true)]
    [bool]$DownloadArtifacts=$true
)


# default script values 
$taskName = "task6"

$artifactsConfigPath = "$PWD/artifacts.json"
$tempFolderPath = "$PWD/temp"

$worksheetName = "Your Estimate"
$spreadsheetName = "ExportedEstimate.xlsx"

if ($DownloadArtifacts) { 
    Write-Output "Reading config" 
    $artifactsConfig = Get-Content -Path $artifactsConfigPath | ConvertFrom-Json 

    Write-Output "Checking if temp folder exists"
    if (-not (Test-Path "$tempFolderPath")) { 
        Write-Output "Temp folder does not exist, creating..."
        New-Item -ItemType Directory -Path $tempFolderPath
    }

    Write-Output "Downloading artifacts"

    if (-not $artifactsConfig.pricingCalculationsURL) { 
        throw "Artifact config value 'pricingCalculationsURL' is empty! Please make sure that you executed the script 'scripts/generate-artifacts.ps1', and commited your changes"
    } 
    Invoke-WebRequest -Uri $artifactsConfig.pricingCalculationsURL -OutFile "$tempFolderPath/$spreadsheetName" -UseBasicParsing

}

Write-Output "Installing pre-requirements"
Install-Module ImportExcel 
Import-Module -Name ImportExcel


Write-Output "Validating artifacts"

$data = Import-Excel -StartRow 3 -Path "$tempFolderPath/$spreadsheetName" -WorksheetName $worksheetName

$computeEstimate = $data | Where-Object {$_.'Service Category' -eq 'Compute'}
if ($computeEstimate) { 
    if ($computeEstimate.'Service Category'.Count -eq 1) { 
        if ($computeEstimate.'Region' -ne 'UK West') { 
            throw "Unable to verify the VM region - please make sure it set to UK West and try again."
        } 

        if (-not $computeEstimate.Description.Contains("B1s")) { 
            throw "Unable to verify VM size in calulations - please make sure that VM size is set to B1s in the calculations and try again. "
        } 
        
        if (-not $computeEstimate.Description.Contains("Linux")) { 
            throw "Unable to verify VM OS type in calulations - please make sure that VM OS tyoe is set to Linux in the calculations and try again. "
        } 

        if (-not $computeEstimate.Description.Contains("1 managed disk – P4")) { 
            throw "Unable to verify that you included OS disk to the calulations - please check and try again. "
        } 
        
        Write-Output "`u{2705} Checked calculations for the Virtual Machine - OK."

    } else { 
        throw "Unable to verify estimates for the category 'Compute' - more than one VM found. Please make sure that you have only one VM in your calculations and try again."
    }

} else { 
    throw "Unable to find estimates for the category 'Compute'. Please make sure that you added your Virtual Machine to the pricing calculation."
}

$storageEstimate = $data | Where-Object {$_.'Service Category' -eq 'Storage'}
if ($storageEstimate) { 
    if ($storageEstimate.'Service Category'.Count -eq 1) { 
        if ($storageEstimate.'Region' -ne 'UK West') { 
            throw "Unable to verify the VM region - please make sure it set to UK West and try again."
        } 

        if (-not $storageEstimate.Description.Contains("Managed Disks, Premium SSD, LRS Redundancy")) { 
            throw "Unable to verify disk type - please make sure that you added a mannaded disk with proper disk type (Premium SSD) and replication type (LRS) to the calculations and try again."
        } 
        
        if (-not $storageEstimate.Description.Contains("P6")) { 
            throw "Unable to verify data disk size - please make sure that disk size for data disk is set to 64GB and try again. "
        } 

        Write-Output "`u{2705} Checked calculations for the data disk (mannaged disk) - OK."

    } else { 
        throw "Unable to verify estimates for the category 'Storage' - more than one item found. Please make sure that you have only one separate storage resource (for your data disk) in your calculations and try again."
    }

} else { 
    throw "Unable to find estimates for the category 'Storage. Please make sure that you added your data disk to the pricing calculation."
}

$networkingEstimate = $data | Where-Object {$_.'Service Category' -eq 'Networking'}
if ($networkingEstimate) { 
    if ($networkingEstimate.'Service Category'.Count -eq 1) { 
        
        if ($networkingEstimate.'Service type' -ne 'IP Addresses') { 
            throw "Unable to verify Public IP resource - please make sure that you added it to the calculations and try again."
        }
        
        if ($networkingEstimate.'Region' -ne 'UK West') { 
            throw "Unable to verify the Public IP region - please make sure it set to UK West and try again."
        } 

        Write-Output "`u{2705} Checked calculations for the Public IP address - OK."

    } else { 
        throw "Unable to verify estimates for the category 'Networking' - more than one item found. Please make sure that you have only one separate storage resource (for your data disk) in your calculations and try again."
    }

} else { 
    throw "Unable to find estimates for the category 'Networking. Please make sure that you added your Public IP address to the pricing calculation."
}

Write-Output ""
Write-Output "`u{1F973} Congratulations! All tests passed!"
