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

# Synopsis: The configuration for each container image the build will process.
$ContainersToBuild = @()


# Build method configuration

# Synopsis: When true, the container images will be built using ACR Tasks. Default is 'false'.
$UseAcrTasks = [Convert]::ToBoolean((property ZF_BUILD_CONTAINER_USE_ACR_TASKS $false))

# Synopsis: When true, no container images will be built. Default is 'false'.
$SkipBuildContainerImages =  [Convert]::ToBoolean((property ZF_BUILD_CONTAINER_SKIP_BUILD $false))


# Version configuration

# Synopsis: When set, will override the image version otherwise generated via GitVersion. Undefined by default.
$ContainerImageVersionOverride = $null


# Internal state
$script:containerBuildTag = $null

