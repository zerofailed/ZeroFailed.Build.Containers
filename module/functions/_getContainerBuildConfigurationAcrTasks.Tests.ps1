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
    # NOTE: Use $TestDrive instead of TestDrive: for compat with .NET APIs
    $testPathDir = Join-Path $TestDrive 'path' 'to'
    $testDockerfile = Join-Path $testPathDir 'Dockerfile'
    New-Item $testDockerfile -ItemType File -Force

    $testAppDockerDir = Join-Path $TestDrive 'app' 'docker'
    $testAppDockerfile = Join-Path $testAppDockerDir 'Dockerfile'
    New-Item $testAppDockerfile -ItemType File -Force

    $testAppSrcDir = Join-Path $TestDrive 'app' 'src'

    $testCustomDir = Join-Path $TestDrive 'custom' 'path'
    $testCustomDockerfile = Join-Path $testCustomDir 'Dockerfile.prod'
    New-Item $testCustomDockerfile -ItemType File -Force

    Mock Write-Host {}
    Mock Out-File {}
}

Describe '_getContainerBuildConfigurationAcrTasks' {

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

        It "should generate an ACR Tasks configuration file" {
            $result = _getContainerBuildConfigurationAcrTasks @splat

            Should -Invoke Out-File -ParameterFilter { $FilePath -ne $null }
        }

        It 'should include --pre suffix on tag for ACR Tasks' {
            $result = _getContainerBuildConfigurationAcrTasks @splat

            Should -Invoke Out-File -ParameterFilter { $FilePath -ne $null }
            Should -Invoke Out-File -ParameterFilter { $InputObject -Match "-t \{\{\.Run.Registry\}\}/$($imageName):$tag--pre" }
        }

        It 'should include registry prefix in tag when set' {
            $script:ContainerRegistryPublishPrefix = 'myprefix'

            $result = _getContainerBuildConfigurationAcrTasks @splat

            Should -Invoke Out-File -ParameterFilter { $FilePath -ne $null }
            Should -Invoke Out-File -ParameterFilter { $InputObject -Match "-t \{\{\.Run.Registry\}\}/myprefix/$($imageName):$tag--pre" }

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

            Should -Invoke Out-File -ParameterFilter { $FilePath -ne $null }
            Should -Invoke Out-File -ParameterFilter { $InputObject -NotMatch "--cache-from" }
            Should -Invoke Out-File -ParameterFilter { $InputObject -NotMatch "--cache-to" }
        }

        It "should configure the caching, when caching is enabled" {
            $cachingSplat = $splat.Clone()
            $cachingSplat.EnableCaching = $true

            $result = _getContainerBuildConfigurationAcrTasks @cachingSplat

            Should -Invoke Out-File -ParameterFilter { $FilePath -ne $null }
            Should -Invoke Out-File -ParameterFilter { $InputObject -Match "--cache-from=type=registry,ref=\{\{.Run.Registry\}\}/$($imageName):cache" }
            Should -Invoke Out-File -ParameterFilter { $InputObject -Match "--cache-to=type=registry,ref=\{\{.Run.Registry\}\}/$($imageName):cache,mode=max" }
        }

        It "should configure the caching correctly, when using a registry prefix" {
            $cachingSplat = $splat.Clone()
            $cachingSplat.EnableCaching = $true
            $script:ContainerRegistryPublishPrefix = 'myprefix'

            $result = _getContainerBuildConfigurationAcrTasks @cachingSplat

            Should -Invoke Out-File -ParameterFilter { $FilePath -ne $null }
            Should -Invoke Out-File -ParameterFilter { $InputObject -Match "--cache-from=type=registry,ref=\{\{.Run.Registry\}\}/myprefix/$($imageName):cache" }
            Should -Invoke Out-File -ParameterFilter { $InputObject -Match "--cache-to=type=registry,ref=\{\{.Run.Registry\}\}/myprefix/$($imageName):cache,mode=max" }

            # Reset for other tests
            $script:ContainerRegistryPublishPrefix = $null
        }
    }

    Context 'Dockerfile path handling' {

        BeforeAll {
            $script:UseAcrTasks = $true
            $script:ContainerRegistryFqdn = 'myacr.azurecr.io'
            $script:ContainerRegistryPublishPrefix = $null
            $script:AcrSubscription = $null

            $imageName = 'pathimage'
            $tag = 'v1.0.0'
            $buildTag = "{0}:{1}" -f $imageName.ToLower(), $tag
        }

        BeforeEach {
            $buildAction = @{
                command = ''
                args = [System.Collections.Generic.List[string]]::new()
                description = 'Building image'
            }
            Mock Copy-Item {}
        }

        It 'should not copy Dockerfile when it is already in ContextDir' {
            $item = @{
                ImageName  = $imageName
                Dockerfile = $testDockerfile
                ContextDir = (Split-Path -Parent $testDockerfile)
            }

            _getContainerBuildConfigurationAcrTasks -BuildAction $buildAction -Item $item -BuildTag $buildTag -EnableCaching $false

            Should -Invoke Copy-Item -Times 0 -Exactly
        }

        It 'should use the Dockerfile value directly in the -f flag when Dockerfile is already in ContextDir' {
            $item = @{
                ImageName  = $imageName
                Dockerfile = $testDockerfile
                ContextDir = (Split-Path -Parent $testDockerfile)
            }

            _getContainerBuildConfigurationAcrTasks -BuildAction $buildAction -Item $item -BuildTag $buildTag -EnableCaching $false

            Should -Invoke Out-File -ParameterFilter { $InputObject -Match "-f $([regex]::Escape($testDockerfile))" }
        }

        It 'should copy Dockerfile to ContextDir when it is not already there' {
            Mock Test-Path { $false } -ParameterFilter { $Path -eq $testAppDockerfile }

            $item = @{
                ImageName  = $imageName
                Dockerfile = $testAppDockerfile
                ContextDir = $testAppSrcDir
            }

            _getContainerBuildConfigurationAcrTasks -BuildAction $buildAction -Item $item -BuildTag $buildTag -EnableCaching $false

            Should -Invoke Copy-Item -Times 1 -Exactly -ParameterFilter { $Path -eq $testAppDockerfile -and $Destination -eq $testAppSrcDir }
        }

        It 'should use filename only in the -f flag when Dockerfile is copied to ContextDir' {
            Mock Test-Path { $false } -ParameterFilter { $Path -eq $testAppDockerfile }

            $item = @{
                ImageName  = $imageName
                Dockerfile = $testAppDockerfile
                ContextDir = $testAppSrcDir
            }

            _getContainerBuildConfigurationAcrTasks -BuildAction $buildAction -Item $item -BuildTag $buildTag -EnableCaching $false

            Should -Invoke Out-File -ParameterFilter { $InputObject -Match "-f Dockerfile\b" }
        }

        It 'should preserve the file extension in the -f flag when a custom Dockerfile name is copied' {
            Mock Test-Path { $false } -ParameterFilter { $Path -eq $testCustomDockerfile }

            $item = @{
                ImageName  = $imageName
                Dockerfile = $testCustomDockerfile
                ContextDir = $testAppSrcDir
            }

            _getContainerBuildConfigurationAcrTasks -BuildAction $buildAction -Item $item -BuildTag $buildTag -EnableCaching $false

            Should -Invoke Out-File -ParameterFilter { $InputObject -Match "-f Dockerfile\.prod" }
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
                args = [System.Collections.Generic.List[string]]::new()
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
