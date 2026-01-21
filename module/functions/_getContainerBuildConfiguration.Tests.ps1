# <copyright file="_getContainerBuildConfiguration.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

BeforeAll {
    # Load the function under test
    . $PSCommandPath.Replace('.Tests.ps1', '.ps1')

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
}

Describe '_getContainerBuildConfiguration' {

    Context 'Docker build without ACR Tasks' {

        BeforeAll {
            # Configure for Docker builds
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

            $result = _getContainerBuildConfiguration -Item $item -Tag '1.0.0'

            $result.buildActions[0].args[-1] | Should -Be $testAppSrcDir
        }

        It 'should include static build arguments' {
            $item = @{
                ImageName  = 'testimage'
                Dockerfile = $testDockerfile
                Arguments  = @{
                    BUILD_VERSION = '1.0.0'
                    ENV_TYPE      = 'production'
                }
            }

            $result = _getContainerBuildConfiguration -Item $item -Tag '1.0.0'

            $args = $result.buildActions[0].args
            $args | Should -Contain '--build-arg'
            $args | Should -Contain 'BUILD_VERSION=1.0.0'
            $args | Should -Contain 'ENV_TYPE=production'
        }

        It 'should support deferred evaluation for dockerfile arguments' {
            $counter = 0
            $item = @{
                ImageName  = 'testimage'
                Dockerfile = $testDockerfile
                Arguments  = @{
                    DYNAMIC_VALUE = { $script:counter++; "value-$script:counter" }
                }
            }

            $result = _getContainerBuildConfiguration -Item $item -Tag '1.0.0'

            $args = $result.buildActions[0].args
            $args | Should -Contain 'DYNAMIC_VALUE=value-1'
        }

        It 'should include target when specified' {
            $item = @{
                ImageName  = 'testimage'
                Dockerfile = $testDockerfile
                Target     = 'runtime'
            }

            $result = _getContainerBuildConfiguration -Item $item -Tag '1.0.0'

            $args = $result.buildActions[0].args
            $targetIndex = $args.IndexOf('--target')
            $targetIndex | Should -BeGreaterOrEqual 0
            $args[$targetIndex + 1] | Should -Be 'runtime'
        }

        It 'should support deferred evaluation for container build target' {
            $isReleaseMode = $true
            $item = @{
                ImageName  = 'testimage'
                Dockerfile = $testDockerfile
                Target     = { $isReleaseMode ? 'runtime' : 'debug' }
            }
            $isReleaseMode = $false

            $result = _getContainerBuildConfiguration -Item $item -Tag '1.0.0'

            $args = $result.buildActions[0].args
            $targetIndex = $args.IndexOf('--target')
            $targetIndex | Should -BeGreaterOrEqual 0
            $args[$targetIndex + 1] | Should -Be 'debug'
        }

        It 'should set command to docker with build argument' {
            $item = @{
                ImageName  = 'testimage'
                Dockerfile = $testDockerfile
            }

            $result = _getContainerBuildConfiguration -Item $item -Tag '1.0.0'

            $result.buildActions[0].command | Should -Be 'docker'
            $result.buildActions[0].args[0] | Should -Be 'build'
        }

        It 'should include -t flag with buildTag for Docker' {
            $item = @{
                ImageName  = 'testimage'
                Dockerfile = $testDockerfile
            }

            $result = _getContainerBuildConfiguration -Item $item -Tag '1.0.0'

            $args = $result.buildActions[0].args
            $tagIndex = $args.IndexOf('-t')
            $tagIndex | Should -BeGreaterOrEqual 0
            $args[$tagIndex + 1] | Should -Be 'testimage:1.0.0'
        }

        It 'should include --file flag with Dockerfile path' {
            $item = @{
                ImageName  = 'testimage'
                Dockerfile = $testCustomDockerfile
            }

            $result = _getContainerBuildConfiguration -Item $item -Tag '1.0.0'

            $args = $result.buildActions[0].args
            $fileIndex = $args.IndexOf('--file')
            $fileIndex | Should -BeGreaterOrEqual 0
            $args[$fileIndex + 1] | Should -Be $testCustomDockerfile
        }
    }

    Context 'ACR Tasks build' {

        BeforeAll {
            # Configure for ACR Tasks builds
            $script:UseAcrTasks = $true
            $script:ContainerRegistryFqdn = 'myacr.azurecr.io'
            $script:ContainerRegistryPublishPrefix = $null
            $script:AcrSubscription = $null
        }

        It 'should set command to az with acr build arguments' {
            $item = @{
                ImageName  = 'testimage'
                Dockerfile = $testDockerfile
            }

            $result = _getContainerBuildConfiguration -Item $item -Tag '1.0.0'

            $result.buildActions[0].command | Should -Be 'az'
            $result.buildActions[0].args[0] | Should -Be 'acr'
            $result.buildActions[0].args[1] | Should -Be 'build'
        }

        It 'should include --pre suffix on tag for ACR Tasks' {
            $item = @{
                ImageName  = 'testimage'
                Dockerfile = $testDockerfile
            }

            $result = _getContainerBuildConfiguration -Item $item -Tag '1.0.0'

            $args = $result.buildActions[0].args
            $tagIndex = $args.IndexOf('-t')
            $tagIndex | Should -BeGreaterOrEqual 0
            $args[$tagIndex + 1] | Should -BeLike '*--pre'
        }

        It 'should include --registry flag with ACR FQDN' {
            $item = @{
                ImageName  = 'testimage'
                Dockerfile = $testDockerfile
            }

            $result = _getContainerBuildConfiguration -Item $item -Tag '1.0.0'

            $args = $result.buildActions[0].args
            $registryIndex = $args.IndexOf('--registry')
            $registryIndex | Should -BeGreaterOrEqual 0
            $args[$registryIndex + 1] | Should -Be 'myacr.azurecr.io'
        }

        It 'should include registry prefix in tag when set' {
            $script:ContainerRegistryPublishPrefix = 'myprefix'

            $item = @{
                ImageName  = 'testimage'
                Dockerfile = $testDockerfile
            }

            $result = _getContainerBuildConfiguration -Item $item -Tag '1.0.0'

            $args = $result.buildActions[0].args
            $tagIndex = $args.IndexOf('-t')
            $args[$tagIndex + 1] | Should -Be 'myprefix/testimage:1.0.0--pre'

            # Reset for other tests
            $script:ContainerRegistryPublishPrefix = $null
        }

        It 'should include --subscription flag when AcrSubscription is set' {
            $script:AcrSubscription = 'my-subscription-id'

            $item = @{
                ImageName  = 'testimage'
                Dockerfile = $testDockerfile
            }

            $result = _getContainerBuildConfiguration -Item $item -Tag '1.0.0'

            $args = $result.buildActions[0].args
            $subIndex = $args.IndexOf('--subscription')
            $subIndex | Should -BeGreaterOrEqual 0
            $args[$subIndex + 1] | Should -Be 'my-subscription-id'

            # Reset for other tests
            $script:AcrSubscription = $null
        }
    }

    Context 'Error handling' {

        BeforeAll {
            $script:UseAcrTasks = $true
            $script:ContainerRegistryFqdn = $null
            $script:ContainerRegistryPublishPrefix = $null
            $script:AcrSubscription = $null
        }

        It 'should throw when ContainerRegistryFqdn is missing for ACR Tasks' {
            $item = @{
                ImageName  = 'testimage'
                Dockerfile = $testDockerfile
            }

            { _getContainerBuildConfiguration -Item $item -Tag '1.0.0' } |
                Should -Throw '*ContainerRegistryFqdn is required*'
        }
    }

    Context 'Return structure' {

        BeforeAll {
            $script:UseAcrTasks = $false
            $script:ContainerRegistryFqdn = $null
            $script:ContainerRegistryPublishPrefix = $null
            $script:AcrSubscription = $null
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
    }
}
