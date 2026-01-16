# <copyright file="_getContainerPublishConfiguration.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

BeforeAll {
    # Load the function under test
    . $PSCommandPath.Replace('.Tests.ps1', '.ps1')

    # Mock output cmdlets to suppress during tests
    Mock Write-Verbose {}
    Mock Write-Warning {}
}

Describe '_getContainerPublishConfiguration' {

    Context 'Docker registry with prefix' {

        BeforeAll {
            $script:UseAcrTasks = $false
            $script:ContainerRegistryType = 'docker'
            $script:ContainerRegistryPublishPrefix = 'myorg'
            $script:ContainerRegistryFqdn = 'docker.io'
            $script:DockerRegistryUsername = 'testuser'
            $script:DockerRegistryPassword = 'testpassword'
        }

        It 'should return correct buildTag in lowercase' {
            $item = @{
                ImageName = 'MyImage'
            }

            $result = _getContainerPublishConfiguration -Item $item -Tag 'v1.0.0'

            $result.buildTag | Should -Be 'myimage:v1.0.0'
        }

        It 'should use prefix in publishTag when set' {
            $item = @{
                ImageName = 'testimage'
            }

            $result = _getContainerPublishConfiguration -Item $item -Tag '1.0.0'

            $result.publishTag | Should -Be 'docker.io/myorg/testimage:1.0.0'
        }

        It 'should add login action when password provided' {
            $item = @{
                ImageName = 'testimage'
            }

            $result = _getContainerPublishConfiguration -Item $item -Tag '1.0.0'

            $loginAction = $result.publishActions | Where-Object { $_.description -eq 'Logging-in to Docker registry' }
            $loginAction | Should -Not -BeNullOrEmpty
            $loginAction.command | Should -Be 'docker'
            $loginAction.args | Should -Contain 'login'
            $loginAction.args | Should -Contain '-u'
            $loginAction.args | Should -Contain 'testuser'
            $loginAction.args | Should -Contain '-p'
            $loginAction.args | Should -Contain 'testpassword'
        }
    }

    Context 'Docker registry without prefix' {

        BeforeAll {
            $script:UseAcrTasks = $false
            $script:ContainerRegistryType = 'docker'
            $script:ContainerRegistryPublishPrefix = $null
            $script:ContainerRegistryFqdn = 'docker.io'
            $script:DockerRegistryUsername = 'myuser'
            $script:DockerRegistryPassword = 'testpassword'
        }

        It 'should use username in publishTag when no prefix' {
            $item = @{
                ImageName = 'testimage'
            }

            $result = _getContainerPublishConfiguration -Item $item -Tag '1.0.0'

            $result.publishTag | Should -Be 'docker.io/myuser/testimage:1.0.0'
        }
    }

    Context 'Docker registry without password' {

        BeforeAll {
            $script:UseAcrTasks = $false
            $script:ContainerRegistryType = 'docker'
            $script:ContainerRegistryPublishPrefix = $null
            $script:ContainerRegistryFqdn = 'docker.io'
            $script:DockerRegistryUsername = 'testuser'
            $script:DockerRegistryPassword = $null
        }

        It 'should emit warning when no password provided' {
            $item = @{
                ImageName = 'testimage'
            }

            _getContainerPublishConfiguration -Item $item -Tag '1.0.0'

            Should -Invoke Write-Warning -Times 1 -ParameterFilter {
                $Message -like '*Docker registry password*'
            }
        }

        It 'should not add login action when no password' {
            $item = @{
                ImageName = 'testimage'
            }

            $result = _getContainerPublishConfiguration -Item $item -Tag '1.0.0'

            $loginAction = $result.publishActions | Where-Object { $_.description -eq 'Logging-in to Docker registry' }
            $loginAction | Should -BeNullOrEmpty
        }
    }

    Context 'ACR registry with prefix' {

        BeforeAll {
            $script:UseAcrTasks = $false
            $script:ContainerRegistryType = 'acr'
            $script:ContainerRegistryPublishPrefix = 'myprefix'
            $script:ContainerRegistryFqdn = 'myacr.azurecr.io'
            $script:DockerRegistryUsername = $null
            $script:DockerRegistryPassword = $null
        }

        It 'should use prefix in publishTag when set' {
            $item = @{
                ImageName = 'testimage'
            }

            $result = _getContainerPublishConfiguration -Item $item -Tag '1.0.0'

            $result.publishTag | Should -Be 'myacr.azurecr.io/myprefix/testimage:1.0.0'
        }
    }

    Context 'ACR registry without prefix' {

        BeforeAll {
            $script:UseAcrTasks = $false
            $script:ContainerRegistryType = 'acr'
            $script:ContainerRegistryPublishPrefix = $null
            $script:ContainerRegistryFqdn = 'myacr.azurecr.io'
            $script:DockerRegistryUsername = $null
            $script:DockerRegistryPassword = $null
        }

        It 'should not include prefix in publishTag when not set' {
            $item = @{
                ImageName = 'testimage'
            }

            $result = _getContainerPublishConfiguration -Item $item -Tag '1.0.0'

            $result.publishTag | Should -Be 'myacr.azurecr.io/testimage:1.0.0'
        }
    }

    Context 'Re-tagging logic' {

        BeforeAll {
            $script:UseAcrTasks = $false
            $script:ContainerRegistryType = 'acr'
            $script:ContainerRegistryPublishPrefix = $null
            $script:ContainerRegistryFqdn = 'myacr.azurecr.io'
            $script:DockerRegistryUsername = $null
            $script:DockerRegistryPassword = $null
        }

        It 'should add re-tag action when buildTag differs from publishTag' {
            $item = @{
                ImageName = 'testimage'
            }

            $result = _getContainerPublishConfiguration -Item $item -Tag '1.0.0'

            # buildTag is 'testimage:1.0.0', publishTag is 'myacr.azurecr.io/testimage:1.0.0'
            # They differ, so re-tag action should be added
            $retagAction = $result.publishActions | Where-Object { $_.description -eq 'Re-tagging image' }
            $retagAction | Should -Not -BeNullOrEmpty
            $retagAction.command | Should -Be 'docker'
            $retagAction.args | Should -Contain 'tag'
            $retagAction.args | Should -Contain 'testimage:1.0.0'
            $retagAction.args | Should -Contain 'myacr.azurecr.io/testimage:1.0.0'
        }
    }

    Context 'Push action' {

        BeforeAll {
            $script:UseAcrTasks = $false
            $script:ContainerRegistryType = 'acr'
            $script:ContainerRegistryPublishPrefix = $null
            $script:ContainerRegistryFqdn = 'myacr.azurecr.io'
            $script:DockerRegistryUsername = $null
            $script:DockerRegistryPassword = $null
        }

        It 'should always add push action with correct publishTag' {
            $item = @{
                ImageName = 'testimage'
            }

            $result = _getContainerPublishConfiguration -Item $item -Tag '1.0.0'

            $pushAction = $result.publishActions | Where-Object { $_.description -eq 'Pushing image' }
            $pushAction | Should -Not -BeNullOrEmpty
            $pushAction.command | Should -Be 'docker'
            $pushAction.args | Should -Contain 'push'
            $pushAction.args | Should -Contain 'myacr.azurecr.io/testimage:1.0.0'
        }

        It 'should have push action as the last action' {
            $item = @{
                ImageName = 'testimage'
            }

            $result = _getContainerPublishConfiguration -Item $item -Tag '1.0.0'

            $lastAction = $result.publishActions[-1]
            $lastAction.description | Should -Be 'Pushing image'
        }
    }

    Context 'ACR Tasks publish with prefix' {

        BeforeAll {
            $script:UseAcrTasks = $true
            $script:ContainerRegistryType = $null
            $script:ContainerRegistryPublishPrefix = 'myprefix'
            $script:ContainerRegistryFqdn = 'myacr.azurecr.io'
            $script:AcrSubscription = $null
            $script:DockerRegistryUsername = $null
            $script:DockerRegistryPassword = $null
        }

        It 'should create az acr import action for promoting pre tag' {
            $item = @{
                ImageName = 'testimage'
            }

            $result = _getContainerPublishConfiguration -Item $item -Tag '1.0.0'

            $importAction = $result.publishActions | Where-Object { $_.description -like "*Promoting 'pre' tag*" }
            $importAction | Should -Not -BeNullOrEmpty
            $importAction.command | Should -Be 'az'
            $importAction.args | Should -Contain 'acr'
            $importAction.args | Should -Contain 'import'
            $importAction.args | Should -Contain '--name'
            $importAction.args | Should -Contain 'myacr.azurecr.io'
            $importAction.args | Should -Contain '--force'
        }

        It 'should include prefix in source and target tags' {
            $item = @{
                ImageName = 'testimage'
            }

            $result = _getContainerPublishConfiguration -Item $item -Tag '1.0.0'

            $importAction = $result.publishActions | Where-Object { $_.description -like "*Promoting 'pre' tag*" }
            $importAction.args | Should -Contain 'myacr.azurecr.io/myprefix/testimage:1.0.0--pre'
            $importAction.args | Should -Contain 'myprefix/testimage:1.0.0'
        }
    }

    Context 'ACR Tasks publish without prefix' {

        BeforeAll {
            $script:UseAcrTasks = $true
            $script:ContainerRegistryType = $null
            $script:ContainerRegistryPublishPrefix = $null
            $script:ContainerRegistryFqdn = 'myacr.azurecr.io'
            $script:AcrSubscription = $null
            $script:DockerRegistryUsername = $null
            $script:DockerRegistryPassword = $null
        }

        It 'should not include prefix in tags when not set' {
            $item = @{
                ImageName = 'testimage'
            }

            $result = _getContainerPublishConfiguration -Item $item -Tag '1.0.0'

            $importAction = $result.publishActions | Where-Object { $_.description -like "*Promoting 'pre' tag*" }
            $importAction.args | Should -Contain 'myacr.azurecr.io/testimage:1.0.0--pre'
            $importAction.args | Should -Contain 'testimage:1.0.0'
        }
    }

    Context 'ACR Tasks publish with subscription' {

        BeforeAll {
            $script:UseAcrTasks = $true
            $script:ContainerRegistryType = $null
            $script:ContainerRegistryPublishPrefix = $null
            $script:ContainerRegistryFqdn = 'myacr.azurecr.io'
            $script:AcrSubscription = 'my-subscription-id'
            $script:DockerRegistryUsername = $null
            $script:DockerRegistryPassword = $null
        }

        It 'should include subscription in import action' {
            $item = @{
                ImageName = 'testimage'
            }

            $result = _getContainerPublishConfiguration -Item $item -Tag '1.0.0'

            $importAction = $result.publishActions | Where-Object { $_.description -like "*Promoting 'pre' tag*" }
            $importAction.args | Should -Contain '--subscription'
            $importAction.args | Should -Contain 'my-subscription-id'
        }
    }

    Context 'Return structure' {

        BeforeAll {
            $script:UseAcrTasks = $false
            $script:ContainerRegistryType = 'acr'
            $script:ContainerRegistryPublishPrefix = $null
            $script:ContainerRegistryFqdn = 'myacr.azurecr.io'
            $script:DockerRegistryUsername = $null
            $script:DockerRegistryPassword = $null
        }

        It 'should return hashtable with buildTag, publishTag and publishActions' {
            $item = @{
                ImageName = 'testimage'
            }

            $result = _getContainerPublishConfiguration -Item $item -Tag '1.0.0'

            $result | Should -BeOfType [hashtable]
            $result.Keys | Should -Contain 'buildTag'
            $result.Keys | Should -Contain 'publishTag'
            $result.Keys | Should -Contain 'publishActions'
        }

        It 'should return publishActions as a list' {
            $item = @{
                ImageName = 'testimage'
            }

            $result = _getContainerPublishConfiguration -Item $item -Tag '1.0.0'

            $result.publishActions.Count | Should -BeGreaterOrEqual 1
            $result.publishActions[0].Keys | Should -Contain 'command'
            $result.publishActions[0].Keys | Should -Contain 'args'
            $result.publishActions[0].Keys | Should -Contain 'description'
        }
    }
}
