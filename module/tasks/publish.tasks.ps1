# <copyright file="publish.tasks.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

. $PSScriptRoot/publish.properties.ps1

# Synopsis: Publish Container Images to Docker Registry (Docker Hub)
task PublishContainerImagesToRegistry `
    -If {$ContainerRegistryType -eq "docker" -or $ContainerRegistryType -eq "acr"} `
    -Jobs GenerateContainerBuildTag,EnsureAzCliConnectionForACR,{

    # Validate we have a build tag
    if (!$script:containerBuildTag) {
        throw "Container build tag is not available. Ensure 'GenerateContainerBuildTag' task has run successfully."
    }

    # Validate required settings
    if (!$ContainerRegistryPublishPrefix -and !$DockerRegistryUsername) {
        throw "Either 'ContainerRegistryPublishPrefix' or 'DockerRegistryUsername' must be defined when publishing to a Docker Registry"
    }

    Write-Build White "Publishing container images to container registry: $ContainerRegistryFqdn"

    foreach ($buildInfo in $ContainersToBuild) {
        
        $config = _getContainerPublishConfiguration -Item $buildInfo -Tag $script:containerBuildTag
        Write-Build Green "Publishing container: $($config.buildTag) -> $($config.publishTag)"
        
        # Execute the commands included in the returned config
        foreach ($action in $config.publishActions) {
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
        Write-Build Green "Successfully published: $($config.publishTag)"
    }
}

# Synopsis: Create build artifact with container image tag
task OutputContainerImageTagArtefact `
    -If {$ContainersToBuild} `
    -Jobs GenerateContainerBuildTag,{

    if (!$script:containerBuildTag) {
        Write-Warning "No 'image-tag' artifact was created because containerBuildTag is not available"
        return
    }

    Write-Build White "Creating build artifact to record the container image tag"
    
    # Write tag to artifact file
    Set-Content -Path $ContainerImageTagArtefactPath -Value $script:containerBuildTag
    
    # Get full path for CI/CD systems
    $artefactFilePath = [IO.Path]::GetFullPath($ContainerImageTagArtefactPath)
    
    Write-Build Green "Container image tag: $script:containerBuildTag"
    Write-Build Green "Artifact path: $artefactFilePath"

    # Export to CI/CD platform
    if ($IsAzureDevOps) {
        Write-Build Magenta "Sending container image tag details to Azure Pipelines..."
        Write-Host "##vso[task.uploadsummary]$artefactFilePath"
        Write-Host "##vso[task.setvariable variable=ContainerImageTagArtefactPath]$artefactFilePath"
        Write-Host "##vso[task.setvariable variable=ContainerImageTag]$script:containerBuildTag"
    }
    elseif ($IsGitHubActions) {
        Write-Build Magenta "Sending container image tag details to GitHub Actions..."
        "ContainerImageTagArtefactPath=$artefactFilePath" | Out-File -Encoding utf8 -Append $env:GITHUB_OUTPUT
        "ContainerImageTag=$script:containerBuildTag" | Out-File -Encoding utf8 -Append $env:GITHUB_OUTPUT
    }
}

# Synopsis: Orchestrates container image publishing to configured registry
task PublishContainerImages `
    -If {!$SkipPublishContainerImages -and $ContainersToBuild} `
    -After PublishCore `
    -Jobs PublishContainerImagesToRegistry,OutputContainerImageTagArtefact
