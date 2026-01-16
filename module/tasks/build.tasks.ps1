# <copyright file="build.tasks.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

. $PSScriptRoot/build.properties.ps1

$sbInvokeCommandWrapper = {
    param (
        [string] $command,
        [System.Collections.Generic.List[string]] $additionalArguments
    )
    Write-Verbose "command: $command"
    Write-Verbose "additionalArguments: $(ConvertTo-Json $additionalArguments)"
    & $command @additionalArguments
}

# Synopsis: Generate container build tag from GitVersion or override
task GenerateContainerBuildTag -If {$ContainersToBuild} Version,{
    
    if ($ContainerImageVersionOverride) {
        Write-Build White "Using container image version override: $ContainerImageVersionOverride"
        $script:containerBuildTag = $ContainerImageVersionOverride
    }
    elseif ($script:GitVersion) {
        $script:containerBuildTag = ($script:GitVersion).SemVer
        Write-Build Green "Generated container build tag from GitVersion: $script:containerBuildTag"
    }
    else {
        throw "Unable to generate container build tag. GitVersion is not available and no override was specified."
    }
}

# Synopsis: When building images locally, check whether a Docker daemon is available
task EnsureLocalDockerDaemon -If { !$UseAcrTasks } {
    Write-Build White "Verifying Docker daemon availability..."
    try {
        exec { docker ps } | Out-Null
        Write-Build Green "Docker daemon is available"
    }
    catch {
        throw "Unable to build container images - Docker is not installed or not running"
    }
}

# Synopsis: When building images via ACR Tasks, verify an authenticated Azure CLI connection
task EnsureAzCliConnectionForACR -If { $UseAcrTasks } {
    Write-Build White "Building using ACR Tasks - Docker daemon check skipped"
    if (!(Test-AzCliConnection)) {
        throw "You must be logged in to Azure CLI to build using ACR Tasks"
    }
}

# Synopsis: Build Container Images using Docker or ACR Tasks
task BuildContainerImages `
    -If {!$SkipContainerImages -and $ContainersToBuild} `
    -After PackageCore `
    -Jobs GenerateContainerBuildTag,EnsureLocalDockerDaemon,EnsureAzCliConnectionForACR,{

    # Validate we have a build tag
    if (!$script:containerBuildTag) {
        throw "Container build tag is not available. Ensure 'GenerateContainerBuildTag' task has run successfully."
    }

    # Build each container image
    foreach ($buildInfo in $ContainersToBuild) {
        
        $config = _getContainerBuildConfiguration -Item $buildInfo -Tag $script:containerBuildTag
        Write-Build Green "Building container: $($config.buildTag)"
        Write-Verbose "buildConfig: $(ConvertTo-Json $config -Depth 10)"

        # Execute the commands included in the returned config
        foreach ($action in $config.buildActions) {
            Write-Build White "Executing action: $($action.description)"
            exec {
                Invoke-Command -ScriptBlock $sbInvokeCommandWrapper `
                               -ArgumentList @(
                                                $action.command
                                                # Workaround issue with Invoke-Command 'unwrapping' collection-based arguments
                                                ,@($action.args)
                                            )
            }
        }
        
        Write-Build Green "Successfully built: $($config.buildTag)"
    }
}
