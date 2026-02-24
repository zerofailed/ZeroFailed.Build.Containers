# <copyright file="_getContainerBuildConfigurationDocker.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>
function _getContainerBuildConfigurationDocker {
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param(
        [Parameter(Mandatory)]
        [hashtable] $Item,

        [Parameter(Mandatory)]
        [string] $BuildTag,

        [Parameter(Mandatory)]
        [hashtable] $BuildAction
    )

    # Add Docker-specific parameters
    $BuildAction.command = 'docker'
    $BuildAction.args.AddRange(
        [string[]]@(
            'build'
            '-t'
            $BuildTag
        )
    )

    # Setup common build parameters
    $BuildAction.args.AddRange(
        [string[]]@(
            '--file'
            $Item.Dockerfile
        )
    )
    
    # Add any specified Dockerfile arguments
    [System.Collections.Generic.List[string]]$containerBuildArgs = _resolveContainerBuildArguments $Item
    if ($containerBuildArgs) {
        $BuildAction.args.AddRange($containerBuildArgs)
    }

    # Support building an explicit target in multi-stage builds
    if ($Item.Target) {
        $BuildAction.args.AddRange(
            [string[]]@(
                '--target'
                # Support deferred evaluation via scriptblock using helper from ZeroFailed.DevOps.Common
                Resolve-Value $Item.Target
            )
        )
    }

    # Add the final positional argument (context directory)
    $BuildAction.args.Add($Item.ContextDir)

    return $BuildAction
}