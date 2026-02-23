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

    # Ensure Determine Dockerfile (applying defaults as necessary)
    if (!$Item.ContainsKey("Dockerfile")) {
        throw "Missing required 'Dockerfile' configuration property"
    }
    elseif (!(Test-Path $Item.Dockerfile)) {
        throw "Dockerfile could not be found: $($Item.Dockerfile)"
    }
    
    # Determine context directory (defaults to same directory as the Dockerfile)
    if (!$Item.ContainsKey("ContextDir")) {
        $Item.Add("ContextDir", (Split-Path -Parent $Item.Dockerfile))
    }

    # Generate build tag
    $config.buildTag = "{0}:{1}" -f $Item.ImageName.ToLower(), $Tag

    # Setup an action to handle building the image
    $buildAction = @{
        command = ''
        args = [System.Collections.Generic.List[string]]::new()
        description = 'Building image'
    }

    # Build using ACR Tasks or Docker
    $getBuildActionsSplat = @{
        BuildAction = $buildAction
        Item = $Item
        BuildTag = $config.buildTag
    }
    if ($UseAcrTasks) {
        $buildAction = _getContainerBuildConfigurationAcrTasks @getBuildActionsSplat -EnableCaching $EnableAcrTasksBuildCache
    }
    else {
        Write-Verbose "Building image with Docker: $($config.buildTag)"
        $buildAction = _getContainerBuildConfigurationDocker @getBuildActionsSplat
    }

    Write-Verbose "buildAction: $(ConvertTo-Json $buildAction -Depth 5)"

    # Save the configured action to the configuration object
    $config.buildActions.Add($buildAction)

    return $config
}