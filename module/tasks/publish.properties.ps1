# <copyright file="publish.properties.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

# Publishing configuration
$SkipPublishContainerImages = $false
$ContainerRegistryType = "acr"  # Options: "acr", "docker", "ghcr"
$ContainerRegistryFqdn = "docker.io"
$ContainerRegistryPublishPrefix = $null

# Docker Registry settings
$DockerRegistryUsername = property ZF_BUILD_DOCKER_REGISTRY_USERNAME ''
$DockerRegistryPassword = property ZF_BUILD_DOCKER_REGISTRY_PASSWORD ''

$ContainerImageTagArtefactPath = Join-Path $PWD "image-tag"
# $ContainerImageVersionOverride = $null