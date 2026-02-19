# <copyright file="_resolveContainerBuildArguments.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

function _resolveContainerBuildArguments {

    [CmdletBinding()]
    [OutputType([string[]])]
    param (
        [Parameter(Mandatory)]
        [hashtable] $Item
    )

    # Process build arguments with support for deferred evaluation (scriptblocks)
    $containerBuildArgs = [System.Collections.Generic.List[string]]::new()
    if ($Item.Arguments) {
        $Item.Arguments.Keys | ForEach-Object {
            # Support deferred evaluation via scriptblock usign helper from ZeroFailed.DevOps.Common
            $argValue = Resolve-Value $Item.Arguments[$_]
            
            # Construct command-line arguments for both 'docker build' and 'az acr build'
            $containerBuildArgs.AddRange(
                [string[]]@(
                    '--build-arg'
                    "$_=$argValue"
                )
            )
        }
    }

    return $containerBuildArgs
}