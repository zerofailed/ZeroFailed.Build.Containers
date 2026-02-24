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
    $taskConfig = [ordered]@{
        version = 'v1.0.0'
        steps = @(
            [ordered]@{
                cmd = 'buildx create --use'
            }
            [ordered]@{
                # Setup placeholder we can update below
                cmd = ''
            }
        )
    }

    # Derive the ACR repository name by removing the tag from the name derived above
    $lastColonIndex = $acrPublishTag.LastIndexOf(':')
    if ($lastColonIndex -ge 0) {
        $acrRepositoryName = $acrPublishTag.Substring(0, $lastColonIndex)
    }
    else {
        $acrRepositoryName = $acrPublishTag
    }

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
    # NOTE: Use IO.Path.Combine() since it handles combining 2 absolute paths, whereas Join-Path does not
    $dockerFilePath = [IO.Path]::Combine($Item.ContextDir, $Item.Dockerfile)
    if (!(Test-Path $dockerFilePath)) {
        # Copy the Dockerfile into the context path
        Copy-Item -Path $Item.Dockerfile -Destination $Item.ContextDir -Force
        # Having copied the file to ContextDir, we need to reference it by its filename only
        # so we must strip any other path information included in the original config
        $dockerFile = Get-ChildItem $Item.Dockerfile
        $taskCmdArgs.Add("-f $($dockerFile.Name)")
    }
    else {
        $taskCmdArgs.Add("-f $($Item.Dockerfile)")
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
    
    # Generate the task configuration file in a path that will be available in the ACR Tasks context
    $taskConfigFilename = 'acr-tasks-config.g.yaml'
    $taskConfigPath = Join-Path $Item.ContextDir $taskConfigFilename
    $taskConfig | ConvertTo-Yaml | Out-File -FilePath $taskConfigPath -Force      
    Write-Host "Generated ACR Tasks config file: $taskConfigPath"
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