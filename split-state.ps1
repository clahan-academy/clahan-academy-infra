# split-state.ps1
# PowerShell script to split combined production state into persistent and transient states

$stateFile = "prod-state-backup.json"
if (-not (Test-Path $stateFile)) {
    throw "State backup file $stateFile not found!"
}

Write-Host "Loading combined state file..." -ForegroundColor Cyan
$state = Get-Content $stateFile -Raw | ConvertFrom-Json

# Define persistent modules and resources
$persistentModules = @(
    "module.networking",
    "module.monitoring",
    "module.acr",
    "module.storage",
    "module.postgres",
    "module.keyvault"
)

$persistentResources = @()
$transientResources = @()

foreach ($res in $state.resources) {
    $moduleName = $res.module
    
    # Root level resources (no module) are persistent private endpoints and dependencies
    if ([string]::IsNullOrEmpty($moduleName)) {
        Write-Host "Root resource found: $($res.type).$($res.name) -> Persistent" -ForegroundColor Yellow
        $persistentResources += $res
    }
    # Check if resource belongs to persistent modules
    elseif ($persistentModules -contains $moduleName.Split('[')[0]) {
        Write-Host "Module resource found: $moduleName.$($res.type).$($res.name) -> Persistent" -ForegroundColor Green
        $persistentResources += $res
    }
    # Otherwise it belongs to transient (AKS, VM, AppGW, Workload Identity)
    else {
        Write-Host "Module resource found: $moduleName.$($res.type).$($res.name) -> Transient" -ForegroundColor Magenta
        $transientResources += $res
    }
}

# Create persistent state object
$persistentState = [PSCustomObject]@{
    version           = $state.version
    terraform_version = $state.terraform_version
    serial            = $state.serial + 1
    lineage           = $state.lineage
    outputs           = [PSCustomObject]@{}
    resources         = $persistentResources
    check_results     = $state.check_results
}

# Create transient state object
$transientState = [PSCustomObject]@{
    version           = $state.version
    terraform_version = $state.terraform_version
    serial            = $state.serial + 1
    lineage           = [Guid]::NewGuid().ToString()  # Give transient state its own unique lineage
    outputs           = [PSCustomObject]@{}
    resources         = $transientResources
    check_results     = $state.check_results
}

Write-Host "`nSaving split state files (UTF-8 without BOM)..." -ForegroundColor Cyan

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText("$(Get-Location)\persistent-prod.tfstate", ($persistentState | ConvertTo-Json -Depth 100), $utf8NoBom)
[System.IO.File]::WriteAllText("$(Get-Location)\transient-prod.tfstate", ($transientState | ConvertTo-Json -Depth 100), $utf8NoBom)

Write-Host "`nSuccess! split states saved to persistent-prod.tfstate and transient-prod.tfstate" -ForegroundColor Green
