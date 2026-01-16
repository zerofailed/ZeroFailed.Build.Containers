# <copyright file="build.properties.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

# Container build configuration
# Must be an array of hashtables with the following structure:
#   @(
#     @{
#       Dockerfile = "<path-to-dockerfile>"
#       ImageName = "<container-image-name-without-tag>"
#       ContextDir = "<path-to-docker-build-context-dir>"  # Optional
#       Target = "<build-stage-name>"  # Optional
#       Arguments = @{ Name = "Value" }  # Optional, supports scriptblocks for deferred evaluation
#     }
#   )
$ContainersToBuild = @()

# Build method configuration
$UseAcrTasks = $false
$SkipContainerImages = $false

# Version configuration
$ContainerImageVersionOverride = $null

# ACR-specific settings
$AcrSubscription = ""

$ContainerRegistryPublishPrefix = ""
$ContainerRegistryFqdn = ""

# Internal state
$script:containerBuildTag = $null

