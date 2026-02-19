# <copyright file="_getContainerBuildConfigurationAcrTasks.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

BeforeAll {
    # Load the function under test
    . $PSCommandPath.Replace('.Tests.ps1', '.ps1')

    # Load dependencies
    $here = Split-Path -Parent $PSCommandPath
    . (Join-Path $here _resolveContainerBuildArguments.ps1)

    # Mock verbose output to suppress during tests
    Mock Write-Verbose {}

    # Define cross-platform test paths using TestDrive
    $testPathDir = Join-Path 'TestDrive:' 'path' 'to'
    $testDockerfile = Join-Path $testPathDir 'Dockerfile'

    $testAppDockerDir = Join-Path 'TestDrive:' 'app' 'docker'
    $testAppDockerfile = Join-Path $testAppDockerDir 'Dockerfile'

    $testAppSrcDir = Join-Path 'TestDrive:' 'app' 'src'

    $testCustomDir = Join-Path 'TestDrive:' 'custom' 'path'
    $testCustomDockerfile = Join-Path $testCustomDir 'Dockerfile.prod'

    Mock Write-Host {}
}

Describe '_getContainerBuildConfigurationAcrTasksAcrTasks' {

    Context 'ACR Tasks build' {

        BeforeAll {
            # Configure for ACR Tasks builds
            $script:UseAcrTasks = $true
            $script:ContainerRegistryFqdn = 'myacr.azurecr.io'
            $script:ContainerRegistryPublishPrefix = $null
            $script:AcrSubscription = $null

            $imageName = 'testimage'
            $tag = 'v1.0.0'
            $buildTag = "{0}:{1}" -f $imageName.ToLower(), $tag
        }

        BeforeEach {
            $buildAction = @{
                command = ''
                args = [System.Collections.Generic.List[string]]::new()
                description = 'Building image'
            }

            $item = @{
                ImageName  = $imageName
                Dockerfile = $testDockerfile
                ContextDir = (Split-Path -Parent $testDockerfile)
            }

            $splat = @{
                BuildAction = $buildAction
                Item = $item
                BuildTag = $buildTag
                EnableCaching = $false
            }
        }

        It 'should set command to az with acr run arguments' {
            $result = _getContainerBuildConfigurationAcrTasks @splat

            $result.command | Should -Be 'az'
            $result.args[0] | Should -Be 'acr'
            $result.args[1] | Should -Be 'run'
        }

        It "should generate an ACT Tasks configuration file" {
            $result = _getContainerBuildConfigurationAcrTasks @splat

            $expectedConfigFilePath = Join-Path $item.ContextDir 'acr-tasks-config.g.yaml'
            $expectedConfigFilePath | Should -Exist
        }

        It 'should include --pre suffix on tag for ACR Tasks' {
            $result = _getContainerBuildConfigurationAcrTasks @splat

            $expectedConfigFilePath = Join-Path $item.ContextDir 'acr-tasks-config.g.yaml'
            $expectedConfigFilePath | Should -Exist
            $expectedConfigFilePath | Should -FileContentMatch "-t \{\{\.Run.Registry\}\}/$($imageName):$tag--pre"
        }

        It 'should include registry prefix in tag when set' {
            $script:ContainerRegistryPublishPrefix = 'myprefix'

            $result = _getContainerBuildConfigurationAcrTasks @splat

            $expectedConfigFilePath = Join-Path $item.ContextDir 'acr-tasks-config.g.yaml'
            $expectedConfigFilePath | Should -Exist
            $expectedConfigFilePath | Should -FileContentMatch "-t \{\{\.Run.Registry\}\}/myprefix/$($imageName):$tag--pre"

            # Reset for other tests
            $script:ContainerRegistryPublishPrefix = $null
        }

        It 'should include --subscription flag when AcrSubscription is set' {
            $script:AcrSubscription = 'my-subscription-id'

            $result = _getContainerBuildConfigurationAcrTasks @splat

            $args = $result.args
            $subIndex = $args.IndexOf('--subscription')
            $subIndex | Should -BeGreaterOrEqual 0
            $args[$subIndex + 1] | Should -Be 'my-subscription-id'

            # Reset for other tests
            $script:AcrSubscription = $null
        }

        It "should not configure caching, when caching is disabled" {
            $result = _getContainerBuildConfigurationAcrTasks @splat

            $expectedConfigFilePath = Join-Path $item.ContextDir 'acr-tasks-config.g.yaml'
            $expectedConfigFilePath | Should -Exist
            $expectedConfigFilePath | Should -Not -FileContentMatch "--cache-from"
            $expectedConfigFilePath | Should -Not -FileContentMatch "--cache-to"
        }

        It "should configure the caching, when caching is enabled" {
            $cachingSplat = $splat.Clone()
            $cachingSplat.EnableCaching = $true

            $result = _getContainerBuildConfigurationAcrTasks @cachingSplat

            $expectedConfigFilePath = Join-Path $item.ContextDir 'acr-tasks-config.g.yaml'
            $expectedConfigFilePath | Should -Exist
            $expectedConfigFilePath | Should -FileContentMatch "--cache-from=type=registry,ref=\{\{.Run.Registry\}\}/$($imageName):cache"
            $expectedConfigFilePath | Should -FileContentMatch "--cache-to=type=registry,ref=\{\{.Run.Registry\}\}/$($imageName):cache,mode=max"
        }

        It "should configure the caching correctly, when using a registry prefix" {
            $cachingSplat = $splat.Clone()
            $cachingSplat.EnableCaching = $true
            $script:ContainerRegistryPublishPrefix = 'myprefix'

            $result = _getContainerBuildConfigurationAcrTasks @cachingSplat

            $expectedConfigFilePath = Join-Path $item.ContextDir 'acr-tasks-config.g.yaml'
            $expectedConfigFilePath | Should -Exist
            $expectedConfigFilePath | Should -FileContentMatch "--cache-from=type=registry,ref=\{\{.Run.Registry\}\}/myprefix/$($imageName):cache"
            $expectedConfigFilePath | Should -FileContentMatch "--cache-to=type=registry,ref=\{\{.Run.Registry\}\}/myprefix/$($imageName):cache,mode=max"

            # Reset for other tests
            $script:ContainerRegistryPublishPrefix = $null
        }
    }

    Context 'Error handling' {

        BeforeAll {
            $script:UseAcrTasks = $true
            $script:ContainerRegistryFqdn = $null
            $script:ContainerRegistryPublishPrefix = $null
            $script:AcrSubscription = $null

            $imageName = 'testimage'
            $tag = 'v1.0.0'
            $buildTag = "{0}:{1}" -f $imageName.ToLower(), $tag
        }

        BeforeEach {
            $buildAction = @{
                command = ''
                args  [System.Collections.Generic.List[string]]::new()
                description = 'Building image'
            }
        }

        It 'should throw when ContainerRegistryFqdn is missing for ACR Tasks' {
            $item = @{
                ImageName  = $imageName
                Dockerfile = $testDockerfile
                ContextDir = (Split-Path -Parent $testDockerfile)
            }

            { _getContainerBuildConfigurationAcrTasks -BuildAction $buildAction -Item $item -BuildTag $buildTag -EnableCaching $false } |
            Should -Throw '*ContainerRegistryFqdn is required*'
        }
    }
}
