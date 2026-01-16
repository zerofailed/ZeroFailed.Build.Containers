# <copyright file="_getContainerBuildConfiguration.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>
function _getContainerBuildConfiguration {
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param (
        [Parameter(Mandatory)]
        [hashtable] $Item,

        [Parameter(Mandatory)]
        [string] $Tag
    )

    # Create empty configuration object that will be returned
    $config = @{
        buildTag = ''
        buildActions = [System.Collections.Generic.List[Object]]::new()
    }

    # Determine context directory (defaults to Dockerfile directory)
    $contextDir = $Item.ContainsKey("ContextDir") ? $Item.ContextDir : (Split-Path -Parent $Item.Dockerfile)

    # Generate build tag
    $config.buildTag = "{0}:{1}" -f $Item.ImageName.ToLower(), $Tag

    # Process build arguments with support for deferred evaluation (scriptblocks)
    $containerBuildArgs = [System.Collections.Generic.List[string]]::new()
    if ($Item.Arguments) {
        $Item.Arguments.Keys | ForEach-Object {
            # Support deferred evaluation via scriptblock
            $argValue = $Item.Arguments[$_] -is [scriptblock] ? $Item.Arguments[$_].Invoke() : $Item.Arguments[$_]
            
            # Construct command-line arguments for both 'docker build' and 'az acr build'
            $containerBuildArgs.AddRange(
                [string[]]@(
                    '--build-arg'
                    "$_=$argValue"
                )
            )
        }
    }

    # Setup an action to handle building the image
    $buildAction = @{
        command = ''
        args = [System.Collections.Generic.List[string]]::new()
        description = 'Building image'
    }

    # Build using ACR Tasks or Docker
    if ($UseAcrTasks) {
        # Validate required ACR settings
        if (!$ContainerRegistryFqdn) {
            throw "ContainerRegistryFqdn is required when using ACR Tasks"
        }

        # Tag with '--pre' suffix for ACR Tasks builds
        # This allows us to re-tag after tests pass
        $acrPublishTag = $ContainerRegistryPublishPrefix ? `
                            "$ContainerRegistryPublishPrefix/$($config.buildTag)" : `
                            $config.buildTag

        Write-Verbose "Building image with ACR Tasks: $acrPublishTag"

        # Setup command-line for bulilding via ACR Tasks
        $buildAction.command = 'az'
        $buildAction.args.AddRange(
            [string[]]@(
                'acr'
                'build'
            )
        )

        # Add ACR-specific parameters
        $buildAction.args.AddRange(
            [string[]]@(
                "-t"
                "$acrPublishTag--pre"
                "--registry"
                $ContainerRegistryFqdn
            )
        )

        # Support cross-subscription ACR access
        if ($AcrSubscription) {
            $buildAction.args.AddRange(
                [string[]]@(
                    "--subscription"
                    $AcrSubscription
                )
            )
            Write-Verbose "Using ACR subscription: $AcrSubscription"
        }
    }
    else {
        Write-Verbose "Building image with Docker: $($config.buildTag)"

        # Add Docker-specific parameters
        $buildAction.command = 'docker'
        $buildAction.args.AddRange(
            [string[]]@(
                'build'
                '-t'
                $config.buildTag
            )
        )
    }

    # Setup common build parameters
    $buildAction.args.AddRange(
        [string[]]@(
            '--file'
            $Item.Dockerfile
        )
    )
    
    # Add any specified Dockerfile arguments
    if ($containerBuildArgs) {
        $buildAction.args.AddRange($containerBuildArgs)
    }

    # Support building an explicit target in multi-stage builds
    if ($Item.Target) {
        $buildAction.args.AddRange(
            [string[]]@(
                '--target'
                $Item.Target
            )
        )
    }

    # Add the final positional argument (context directory)
    $buildAction.args.Add($contextDir)

    Write-Verbose "buildAction: $(ConvertTo-Json $buildAction -Depth 5)"

    # Save the configured action to the configuratin object
    $config.buildActions.Add($buildAction)

    return $config
}