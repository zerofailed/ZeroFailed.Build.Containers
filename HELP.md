# ZeroFailed.Build.Containers - Reference Sheet


<!-- START_GENERATED_HELP -->

## Build

### Properties

| Name                            | Default Value | ENV Override                                | Description                                                                                         |
| ------------------------------- | ------------- | ------------------------------------------- | --------------------------------------------------------------------------------------------------- |
| `ContainerImageVersionOverride` | ''            | `ZF_BUILD_CONTAINER_IMAGE_VERSION_OVERRIDE` | When set, will override the image version otherwise generated via GitVersion. Undefined by default. |
| `ContainersToBuild`             | @()           |                                             | The configuration for each container image the build will process.                                  |
| `SkipBuildContainerImages`      | $false        | `ZF_BUILD_CONTAINER_SKIP_BUILD`             | When true, no container images will be built. Default is 'false'.                                   |
| `UseAcrTasks`                   | $false        | `ZF_BUILD_CONTAINER_USE_ACR_TASKS`          | When true, the container images will be built using ACR Tasks. Default is 'false'.                  |

### Tasks

| Name                          | Description                                                                                                                                                  |
| ----------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `BuildContainerImages`        | Builds container images locally (via 'docker build') or remotely using ACR Tasks.                                                                            |
| `EnsureAzCliConnectionForACR` | When building images via ACR Tasks, verifies an authenticated Azure CLI connection. If not, throws an error.                                                 |
| `EnsureLocalDockerDaemon`     | When building images locally, ensures a Docker daemon is available. If not, throws an error.                                                                 |
| `GenerateContainerBuildTag`   | Generates the container image tag used for all containers, based on a GitVersion version number or an overriden provided by 'ContainerImageVersionOverride'. |

## Publish

### Properties

| Name                             | Default Value | ENV Override                                 | Description                                                                                                                                                                                         |
| -------------------------------- | ------------- | -------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `AcrSubscription`                | ''            | `ZF_BUILD_CONTAINER_ACR_SUBSCRIPTION`        | The Azure subscription of the ACR when using one for building or publishing.                                                                                                                        |
| `ContainerImageTagArtefactPath`  | "image-tag"   | `ZF_BUILD_CONTAINER_IMAGE_TAG_ARTEFACT_PATH` | The path to a file where the build will write the generated image tag. Can be useful for passing the image version details to external processes (e.g. a CI/CD workflow). Default is './image-tag'. |
| `ContainerRegistryFqdn`          | 'docker.io'   | `ZF_BUILD_CONTAINER_REGISTRY_FQDN`           | The FQDN of the container registry where images will be published. Also required when 'UseAcrTasks' is enabled. Default is 'docker.io' (i.e. Docker Hub).                                           |
| `ContainerRegistryPublishPrefix` | ''            | `ZF_BUILD_CONTAINER_PUBLISH_PREFIX`          | An additional prefix added to the container image name when publishing to a container registry.                                                                                                     |
| `ContainerRegistryType`          | 'docker'      | `ZF_BUILD_CONTAINER_REGISTRY_TYPE`           | The type of container registry where image are published. Supports 'docker' or 'acr'. Default is 'docker'.                                                                                          |
| `DockerRegistryPassword`         | ''            | `ZF_BUILD_DOCKER_REGISTRY_PASSWORD`          | The password when publishing to a docker registry.                                                                                                                                                  |
| `DockerRegistryUsername`         | ''            | `ZF_BUILD_DOCKER_REGISTRY_USERNAME`          | The username when publishing to a docker registry.                                                                                                                                                  |
| `SkipPublishContainerImages`     | $false        | `ZF_BUILD_CONTAINER_SKIP_PUBLISH`            | When true, no container images will be published. Default is 'false'.                                                                                                                               |

### Tasks

| Name                               | Description                                                           |
| ---------------------------------- | --------------------------------------------------------------------- |
| `OutputContainerImageTagArtefact`  | Stores the generated container image tag used by the build in a file. |
| `PublishContainerImages`           | Orchestrates container image publishing.                              |
| `PublishContainerImagesToRegistry` | Publish container images to a container registry.                     |


<!-- END_GENERATED_HELP -->
