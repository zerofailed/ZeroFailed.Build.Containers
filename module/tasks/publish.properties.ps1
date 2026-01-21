# <copyright file="publish.properties.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

# Publishing configuration

# Synopsis: When true, no container images will be published. Default is 'false'.
$SkipPublishContainerImages = [Convert]::ToBoolean((property ZF_BUILD_CONTAINER_SKIP_PUBLISH $false))

# Synopsis: The type of container registry where image are published. Supports 'docker' or 'acr'. Default is 'docker'.
$ContainerRegistryType = property ZF_BUILD_CONTAINER_REGISTRY_TYPE 'docker'

# Synopsis: The FQDN of the container registry where images will be published. Also required when 'UseAcrTasks' is enabled. Default is 'docker.io' (i.e. Docker Hub).
$ContainerRegistryFqdn = property ZF_BUILD_CONTAINER_REGISTRY_FQDN 'docker.io'

# Synopsis: An additional prefix added to the container image name when publishing to a container registry.
$ContainerRegistryPublishPrefix = property ZF_BUILD_CONTAINER_PUBLISH_PREFIX ''

# Synopsis: The path to a file where the build will write the generated image tag. Can be useful for passing the image version details to external processes (e.g. a CI/CD workflow). Default is './image-tag'.
$ContainerImageTagArtefactPath = property ZF_BUILD_CONTAINER_IMAGE_TAG_ARTEFACT_PATH (Join-Path $PWD "image-tag")


# Container Registry settings

# Synopsis: The username when publishing to a docker registry.
$DockerRegistryUsername = property ZF_BUILD_DOCKER_REGISTRY_USERNAME ''

# Synopsis: The password when publishing to a docker registry.
$DockerRegistryPassword = property ZF_BUILD_DOCKER_REGISTRY_PASSWORD ''

# Synopsis: The Azure subscription of the ACR when using one for building or publishing.
$AcrSubscription = property ZF_BUILD_CONTAINER_ACR_SUBSCRIPTION ''