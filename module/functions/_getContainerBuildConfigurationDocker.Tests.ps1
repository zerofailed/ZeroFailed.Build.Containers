# <copyright file="_getContainerBuildConfigurationDocker.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

BeforeAll {
    # Load the function under test
    . $PSCommandPath.Replace('.Tests.ps1', '.ps1')

    # Load dependencies
    $here = Split-Path -Parent $PSCommandPath
    . (Join-Path $here '_resolveContainerBuildArguments.ps1')

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

Describe '_getContainerBuildConfigurationDocker' {

    Context 'Docker build without ACR Tasks' {

        BeforeAll {
            # Configure for Docker builds
            $script:UseAcrTasks = $false
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
                args = [System.Collections.Generic.List[string]]::new()
                description = 'Building image'
            }
        }

        It 'should include static build arguments' {
            $item = @{
                ImageName  = $imageName
                Dockerfile = $testDockerfile
                Arguments  = @{
                    BUILD_VERSION = '1.0.0'
                    ENV_TYPE      = 'production'
                }
                ContextDir = (Split-Path -Parent $testDockerfile)
            }

            $result = _getContainerBuildConfigurationDocker -BuildAction $buildAction -Item $item -BuildTag $buildTag

            $result.args | Should -Contain '--build-arg'
            $result.args | Should -Contain 'BUILD_VERSION=1.0.0'
            $result.args | Should -Contain 'ENV_TYPE=production'
        }

        It 'should support deferred evaluation for dockerfile arguments' {
            $counter = 0
            $item = @{
                ImageName  = $imageName
                Dockerfile = $testDockerfile
                Arguments  = @{
                    DYNAMIC_VALUE = { $script:counter++; "value-$script:counter" }
                }
                ContextDir = (Split-Path -Parent $testDockerfile)
            }

            $result = _getContainerBuildConfigurationDocker -BuildAction $buildAction -Item $item -BuildTag $buildTag

            $result.args | Should -Contain 'DYNAMIC_VALUE=value-1'
        }

        It 'should include target when specified' {
            $item = @{
                ImageName  = $imageName
                Dockerfile = $testDockerfile
                Target     = 'runtime'
                ContextDir = (Split-Path -Parent $testDockerfile)
            }

            $result = _getContainerBuildConfigurationDocker -BuildAction $buildAction -Item $item -BuildTag $buildTag

            $targetIndex = $result.args.IndexOf('--target')
            $targetIndex | Should -BeGreaterOrEqual 0
            $result.args[$targetIndex + 1] | Should -Be 'runtime'
        }

        It 'should support deferred evaluation for container build target' {
            $isReleaseMode = $true
            $item = @{
                ImageName  = $imageName
                Dockerfile = $testDockerfile
                Target     = { $isReleaseMode ? 'runtime' : 'debug' }
                ContextDir = (Split-Path -Parent $testDockerfile)
            }
            $isReleaseMode = $false

            $result = _getContainerBuildConfigurationDocker -BuildAction $buildAction -Item $item -BuildTag $buildTag

            $targetIndex = $result.args.IndexOf('--target')
            $targetIndex | Should -BeGreaterOrEqual 0
            $result.args[$targetIndex + 1] | Should -Be 'debug'
        }

        It 'should set command to docker with build argument' {
            $item = @{
                ImageName  = $imageName
                Dockerfile = $testDockerfile
                ContextDir = (Split-Path -Parent $testDockerfile)
            }

            $result = _getContainerBuildConfigurationDocker -BuildAction $buildAction -Item $item -BuildTag $buildTag

            $result.command | Should -Be 'docker'
            $result.args[0] | Should -Be 'build'
        }

        It 'should include -t flag with buildTag for Docker' {
            $item = @{
                ImageName  = $imageName
                Dockerfile = $testDockerfile
                ContextDir = (Split-Path -Parent $testDockerfile)
            }

            $result = _getContainerBuildConfigurationDocker -BuildAction $buildAction -Item $item -BuildTag $buildTag

            $tagIndex = $result.args.IndexOf('-t')
            $tagIndex | Should -BeGreaterOrEqual 0
            $result.args[$tagIndex + 1] | Should -Be 'testimage:v1.0.0'
        }

        It 'should include --file flag with Dockerfile path' {
            $item = @{
                ImageName  = $imageName
                Dockerfile = $testCustomDockerfile
                ContextDir = (Split-Path -Parent $testCustomDockerfile)
            }

            $result = _getContainerBuildConfigurationDocker -BuildAction $buildAction -Item $item -BuildTag $buildTag

            $fileIndex = $result.args.IndexOf('--file')
            $fileIndex | Should -BeGreaterOrEqual 0
            $result.args[$fileIndex + 1] | Should -Be $testCustomDockerfile
        }
    }
}
