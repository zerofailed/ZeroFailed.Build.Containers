# <copyright file="_getContainerPublishConfiguration.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

function _getContainerPublishConfiguration {
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
        buildTag = "{0}:{1}" -f $Item.ImageName.ToLower(), $Tag
        publishTag = ''
        publishActions = [System.Collections.Generic.List[Object]]::new()
    }

    if ($UseAcrTasks) {
        # When building with ACR Tasks, images are published automatically as part of the build process. In order to preserve our
        # preferred approach of not publishing images until the end of the overall build process, we use a tag with a '--pre'
        # suffix during the build. The suffix is then removed as part of the publish process to make the final version available.

        # Derive the different tags we need to work with
        $publishTag = $ContainerRegistryPublishPrefix ? `
                            "$ContainerRegistryFqdn/$ContainerRegistryPublishPrefix/$($config.buildTag)" : `
                            "$ContainerRegistryFqdn/$($config.buildTag)"
        $sourceTag = "$publishTag--pre"
        $sourceTagToRemove = $sourceTag.Replace("$ContainerRegistryFqdn/", "")
        $targetTag = $publishTag.Replace("$ContainerRegistryFqdn/", "")
        
        # Configure task to create the non '--pre' image tag
        $createFinalPublishTagTask = @{
            command = 'az'
            args = [System.Collections.Generic.List[string]]::new()
            description = "Promoting 'pre' tag in ACR: $sourceTag -> $targetTag"
        }
        $createFinalPublishTagTask.args.AddRange(
            [string[]]@(
                'acr'
                'import'
                '--name'
                $ContainerRegistryFqdn
                '--source'
                $sourceTag
                '--image'
                $targetTag
                '--force'
            )
        )

        # Configure task to remove the '--pre' tag
        $removePreTagTask = @{
            command = 'az'
            args = [System.Collections.Generic.List[string]]::new()
            description = "Removing 'pre' tag from ACR"
        }
        $removePreTagTask.args.AddRange(
            [string[]]@(
                'acr'
                'repository'
                'untag'
                '--name'
                $ContainerRegistryFqdn
                '--image'
                $sourceTagToRemove
            )
        )
        # Ensure the tasks are configured to use the correct subscription
        if ($AcrSubscription) {
            $createFinalPublishTagTask.args.AddRange(
                [string[]]@(
                    '--subscription'
                    $AcrSubscription
                )
            )
            $removePreTagTask.args.AddRange(
                [string[]]@(
                    '--subscription'
                    $AcrSubscription
                )
            )
        }

        $config.publishActions.Add($createFinalPublishTagTask)
        $config.publishActions.Add($removePreTagTask)
    }
    else {
        switch ($ContainerRegistryType) {
            "docker" {
                # Construct publish tag with registry prefix
                $config.publishTag = $ContainerRegistryPublishPrefix ? `
                                        "$ContainerRegistryFqdn/$ContainerRegistryPublishPrefix/$($config.buildTag)" : `
                                        "$ContainerRegistryFqdn/$DockerRegistryUsername/$($config.buildTag)"
    
                # Handle Docker registry authentication
                if ($DockerRegistryPassword) {
                    $dockerLoginTask = @{
                        command = 'docker'
                        args = [System.Collections.Generic.List[string]]::new()
                        description = 'Logging-in to Docker registry'
                    }
                    $dockerLoginTask.args.AddRange(
                        [string[]]@(
                            'login'
                            '-u'
                            $DockerRegistryUsername
                            '-p'
                            $DockerRegistryPassword
                        )
                    )
                    $config.publishActions.Add($dockerLoginTask)
                }
                else {
                    Write-Warning "No Docker registry password was provided, publishing may fail. Use the 'ZF_BUILD_DOCKER_REGISTRY_PASSWORD' environment variable to provide a password."
                }
            }
            "acr" {
                # Construct publish tag
                $config.publishTag = $ContainerRegistryPublishPrefix ? `
                                        "$ContainerRegistryFqdn/$ContainerRegistryPublishPrefix/$($config.buildTag)" : `
                                        "$ContainerRegistryFqdn/$($config.buildTag)"
            }
        }
    
        if ($config.buildTag -ne $config.publishTag) {
            # Setup the command to re-tag the image prior to publishing
            $reTagTask = @{
                command = 'docker'
                args = [System.Collections.Generic.List[string]]::new()
                description = 'Re-tagging image'
            }
            $reTagTask.args.AddRange(
                [string[]]@(
                    'tag'
                    $config.buildTag
                    $config.publishTag
                )
            )
            $config.publishActions.Add($reTagTask)
        }
    
        # Setup the publish command
        $pushTask = @{
            command = 'docker'
            args = [System.Collections.Generic.List[string]]::new()
            description = 'Pushing image'
        }
        $pushTask.args.AddRange(
            [string[]]@(
                'push'
                $config.publishTag
            )
        )
        $config.publishActions.Add($pushTask)
    }

    return $config
}