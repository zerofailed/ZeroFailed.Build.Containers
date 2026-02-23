# <copyright file="_getContainerBuildConfiguration.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

BeforeAll {
    # Load the function under test
    . $PSCommandPath.Replace('.Tests.ps1', '.ps1')

    # Load dependencies
    $here = Split-Path -Parent $PSCommandPath
    . (Join-Path $here '_getContainerBuildConfigurationAcrTasks.ps1')
    . (Join-Path $here '_getContainerBuildConfigurationDocker.ps1')
    . (Join-Path $here '_resolveContainerBuildArguments.ps1')

    # Mock verbose output to suppress during tests
    Mock Write-Verbose {}

    # Define cross-platform test paths using TestDrive
    $testPathDir = Join-Path 'TestDrive:' 'path' 'to'
    $testDockerfile = Join-Path $testPathDir 'Dockerfile'
    New-Item $testDockerfile -ItemType File -Force

    $testAppDockerDir = Join-Path 'TestDrive:' 'app' 'docker'
    $testAppDockerfile = Join-Path $testAppDockerDir 'Dockerfile'
    New-Item $testAppDockerfile -ItemType File -Force

    $testAppSrcDir = Join-Path 'TestDrive:' 'app' 'src'

    $testCustomDir = Join-Path 'TestDrive:' 'custom' 'path'
    $testCustomDockerfile = Join-Path $testCustomDir 'Dockerfile.prod'
    New-Item $testCustomDockerfile -ItemType File -Force
}

Describe '_getContainerBuildConfiguration' {

    Context 'Return structure' {

        BeforeAll {
            $script:UseAcrTasks = $false
            $script:ContainerRegistryFqdn = $null
            $script:ContainerRegistryPublishPrefix = $null
            $script:AcrSubscription = $null
        }

        It 'should return correct buildTag in lowercase' {
            $item = @{
                ImageName  = 'MyImage'
                Dockerfile = $testDockerfile
            }

            $result = _getContainerBuildConfiguration -Item $item -Tag 'v1.0.0'

            $result.buildTag | Should -Be 'myimage:v1.0.0'
        }

        It 'should return hashtable with buildTag and buildActions' {
            $item = @{
                ImageName  = 'testimage'
                Dockerfile = $testDockerfile
            }

            $result = _getContainerBuildConfiguration -Item $item -Tag '1.0.0'

            $result | Should -BeOfType [hashtable]
            $result.Keys | Should -Contain 'buildTag'
            $result.Keys | Should -Contain 'buildActions'
        }

        It 'should return buildActions as a list with one action' {
            $item = @{
                ImageName  = 'testimage'
                Dockerfile = $testDockerfile
            }

            $result = _getContainerBuildConfiguration -Item $item -Tag '1.0.0'

            $result.buildActions | Should -HaveCount 1
            $result.buildActions[0].Keys | Should -Contain 'command'
            $result.buildActions[0].Keys | Should -Contain 'args'
            $result.buildActions[0].Keys | Should -Contain 'description'
        }

        It 'should use Dockerfile parent directory as ContextDir when not specified' {
            $item = @{
                ImageName  = 'testimage'
                Dockerfile = $testAppDockerfile
            }
            
            $result = _getContainerBuildConfiguration -Item $item -Tag '1.0.0'

            # The last argument should be the context directory
            $result.buildActions[0].args[-1] | Should -Be $testAppDockerDir
        }

        It 'should use explicit ContextDir when provided' {
            $item = @{
                ImageName  = 'testimage'
                Dockerfile = $testAppDockerfile
                ContextDir = $testAppSrcDir
            }

            $result =_getContainerBuildConfiguration -Item $item -Tag '1.0.0'

            $result.buildActions[0].args[-1] | Should -Be $testAppSrcDir
        }
    }
}
