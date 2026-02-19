# <copyright file="_getContainerBuildConfigurationAcrTasks.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>
function _getContainerBuildConfigurationAcrTasks {
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param(
        [Parameter(Mandatory)]
        [hashtable] $Item,

        [Parameter(Mandatory)]
        [string] $BuildTag,

        [Parameter(Mandatory)]
        [bool] $EnableCaching,

        [Parameter(Mandatory)]
        [hashtable] $BuildAction
    )

    # Validate required ACR settings
    if (!$ContainerRegistryFqdn) {
        throw "ContainerRegistryFqdn is required when using ACR Tasks"
    }

    # Tag with '--pre' suffix for ACR Tasks builds
    # This allows us to re-tag after tests pass
    $acrPublishTag = $ContainerRegistryPublishPrefix ? `
                        "$ContainerRegistryPublishPrefix/$BuildTag" : `
                $BuildTag
    Write-Verbose "Building image with ACR Tasks: $acrPublishTag"

    # Setup command-line for building via ACR Tasks
    $BuildAction.command = 'az'
    $BuildAction.args.AddRange(
        [string[]]@(
            'acr'
            'run'
        )
    )

    # Generate ACR Tasks build configuration file
    $taskConfig = @{
        version = 'v1.0.0'
        steps = @(
            @{
                cmd = 'buildx create --use'
            }
            @{
                cmd = ''
            }
        )
    }

    # Derive the ACR repository name by removing the tag from the name derived above
    $acrRepositoryName = $acrPublishTag.Replace(":$Tag", '')

    # Start constructing the command-line that ACR Tasks will use to build the container image
    $taskCmdArgs = [System.Collections.Generic.List[string]]::new()

    # Add the static command arguments
    $taskCmdArgs.AddRange(
        [string[]]@(
            'buildx build --push'
            # Tag with '--pre' suffix for ACR Tasks builds (since the images are published as part of building them),
            # we will then re-tag to the final version as part of the publish phase (i.e. after tests pass etc.)
            "-t {{.Run.Registry}}/$acrPublishTag--pre"
        )
    )

    if ($EnableCaching) {
        $taskCmdArgs.AddRange(
            [string[]]@(
                "--cache-from=type=registry,ref={{.Run.Registry}}/$($acrRepositoryName):cache"
                "--cache-to=type=registry,ref={{.Run.Registry}}/$($acrRepositoryName):cache,mode=max"
            )
        )
    }
    
    # Ensure the Dockerfile will be available in the context uploaded to the ACR Tasks
    if (!(Test-Path (Join-Path $Item.ContextDir $buildInfo.Dockerfile))) {
        Copy-Item (Join-Path $here $buildInfo.Dockerfile) $Item.ContextDir
        $dockerFile = Get-ChildItem $buildInfo.Dockerfile
        $taskCmdArgs.Add("-f $($dockerFile.BaseName)")
    }
    else {
        $taskCmdArgs.Add("-f $($buildInfo.Dockerfile)")
    }
    
    # Add any dynamic build arguments
    # Add any specified Dockerfile arguments
    [System.Collections.Generic.List[string]]$containerBuildArgs = _resolveContainerBuildArguments $Item
    if ($containerBuildArgs) {
        $taskCmdArgs.AddRange($containerBuildArgs)
    }
    # Add the positional build context argument
    $taskCmdArgs.Add('.')

    # Add the cmd args into the task configuration for the main build step
    $taskConfig.steps[1].cmd = $taskCmdArgs -join " "
    
    # Generate the task configuration file
    $taskConfigFilename = 'acr-tasks-config.g.yaml'
    $taskConfigPath = Join-Path $Item.ContextDir $taskConfigFilename
    $taskConfig | ConvertTo-Yaml | Out-File -Path $taskConfigPath -Force      
    Write-Host "Generated ACR Tasks config file: $taskConfigFilename"
    Write-Verbose "ACR Tasks config:`n$(Get-Content -Raw $taskConfigPath)"

    # Add other az-cli command-lin arguments
    $BuildAction.args.AddRange(
        [string[]]@(
            '-f'
            $taskConfigFilename
            "--registry"
            $ContainerRegistryFqdn
            $Item.ContextDir
        )
    )

    # Support cross-subscription ACR access
    if ($AcrSubscription) {
        $BuildAction.args.AddRange(
            [string[]]@(
                "--subscription"
                $AcrSubscription
            )
        )
        Write-Verbose "Using ACR subscription: $AcrSubscription"
    }

    return $BuildAction
}