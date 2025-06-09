function Test-Wsl2DockerDesktopRunning {
    [OutputType([bool])]
    param()

    if ($(Get-ChildItem "\\.\pipe\dockerDesktopLinuxEngine" `
        -ErrorAction "SilentlyContinue")) {
        return $true;
    }

    return $false;
}

function Assert-Wsl2DockerDesktopRunning {
    if (-not $(Test-Wsl2DockerDesktopRunning)) {
        throw New-Object System.IO.IOException(
            "Docker Desktop is not running"
        );
    }
}

function Test-NullOrEmpty {
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$String
    )
    
    if ([string]::IsNullOrWhiteSpace($String)) {
        return $false;
    }
    return $true;
}

[string]$VariablesPath = "$PSScriptRoot$([IO.Path]::DirectorySeparatorChar)variables.json";
$Variables = Get-Content -LiteralPath $VariablesPath | ConvertFrom-Json;
[string]$ContainerPrefix = $Variables.prefix;
[string]$RenpySdkBaseUrl = "https://renpy.org/dl/{0}/renpy-{0}-sdk.tar.bz2";

if (-not (Test-NullOrEmpty -String $Variables.renpy_volume)) {
    throw New-Object System.ArgumentException(
        "The value `"renpy_volume`" must be filled out in the variables file");
}
if (-not (Test-NullOrEmpty -String $Variables.renpy_sdk_version)) {
    throw New-Object System.ArgumentException(
        "The value `"renpy_sdk_version`" must be filled out in the variables file");
}

class ValidContainerGenerator : System.Management.Automation.IValidateSetValuesGenerator {
    [string[]] GetValidValues() {
        return $Script:Variables.images;
    }
}

class ValidConnectGenerator : System.Management.Automation.IValidateSetValuesGenerator {
    [string[]] GetValidValues() {
        return [ValidContainerGenerator]::new().GetValidValues() | `
            Where-Object { $_ -ne "languagetool"};
    }
}

class ValidLocaleGenerator : System.Management.Automation.IValidateSetValuesGenerator {
    # NOTE: Testing the locale + sublocale combo is up to the container.
    # There's no way for us to determine that at this level.

    [string[]] GetValidValues() {
        return $Script:Variables.locales;
    }
}

function Get-ComposePath {
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet([ValidContainerGenerator])]
        [string]$Container
    )
    
    return "$PSScriptRoot$([IO.Path]::DirectorySeparatorChar)$Container$([IO.Path]::DirectorySeparatorChar)compose.yml";
}

function Get-DockerfilePath {
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet([ValidContainerGenerator])]
        [string]$Container
    )
    
    return "$PSScriptRoot$([IO.Path]::DirectorySeparatorChar)$Container$([IO.Path]::DirectorySeparatorChar)Dockerfile";
}

function Get-EnvFilePath {
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet([ValidContainerGenerator])]
        [string]$Container
    )

    return "$([System.IO.Path]::GetTempPath())$Container.env";
}

function Initialize-RenpyContainer {
    [OutputType([System.Void])]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = "GameContainer", Position = 0)]
        [Parameter(Mandatory = $true, ParameterSetName = "LTContainer", Position = 0)]
        [ValidateSet([ValidContainerGenerator])]
        $Container,

        [Parameter(Mandatory = $true, ParameterSetName = "GameContainer")]
        [ValidateSet([ValidLocaleGenerator])]
        [string]$Locale,
        [Parameter(ParameterSetName = "GameContainer")]
        [string]$Sublocale,
        [Parameter(ParameterSetName = "GameContainer")]
        [string]$RenpySdk,
        [Parameter(ParameterSetName = "GameContainer")]
        [string]$RenpyVolume,

        [Parameter(ParameterSetName = "LTContainer")]
        [string]$NGramVolume,
        [Parameter(ParameterSetName = "LTContainer")]
        [int]$LTPort
    )
    Assert-Wsl2DockerDesktopRunning;

    [System.Text.StringBuilder]$EnvFile = [System.Text.StringBuilder]::new();

    switch ($PSCmdlet.ParameterSetName) {
        "GameContainer" {
            if (-not (Test-NullOrEmpty -String $RenpyVolume)) {
                $RenpyVolume = $Variables.renpy_volume;
            }
            if (-not (Test-NullOrEmpty -String $RenpySdk)) {
                $RenpySdk = $Variables.renpy_sdk_version;
            }
        
            $EnvFile.AppendLine("DOCKER_MOUNT=`"$RenpyVolume`"") > $null;
            $EnvFile.AppendLine("LOCALE=`"$Locale`"") > $null;
            $EnvFile.AppendLine("SUBLOCALE=`"$($Sublocale.ToUpper())`"") > $null;
            $EnvFile.AppendLine("RENPY_SDK_URL=`"$($RenpySdkBaseUrl -f $RenpySdk)`"") > $null;
        }
        "LTContainer" {
            if (-not (Test-NullOrEmpty -String $NGramVolume)) {
                $NGramVolume = $Variables.lt_ngrams_volume;
            }
            if ($null -eq $LTPort -or 0 -eq $LTPort) {
                $LTPort = $Variables.lt_port;
            }

            $EnvFile.AppendLine("DOCKER_MOUNT=`"$NGramVolume`"") > $null;
            $EnvFile.AppendLine("MAPPED_PORT=$LTPort") > $null;
        }
    }

    [string]$EnvFilePath = $(Get-EnvFilePath -Container $Container);
    Set-Content -NoNewline -Value $EnvFile.ToString() -Encoding "utf8BOM" `
        -LiteralPath $EnvFilePath;
    return;
}

function Start-RenpyContainer {
    [OutputType([System.Void])]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet([ValidContainerGenerator])]
        [string]$Container
    )
    Assert-Wsl2DockerDesktopRunning;
    
    [string]$EnvFilePath = $(Get-EnvFilePath -Container $Container);
    if (-not $(Test-Path -LiteralPath $EnvFilePath)) {
        throw New-Object System.ArgumentException(
            "Couldn't find environment file $EnvFilePath, run Initialize-RenpyContainer"
        );
    }

    docker compose --file $(Get-ComposePath -Container $Container) `
        --env-file $EnvFilePath up --detach;
}

function Stop-RenpyContainer {
    [OutputType([System.Void])]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet([ValidContainerGenerator])]
        [string]$Container
    )
    Assert-Wsl2DockerDesktopRunning;

    [string]$EnvFilePath = $(Get-EnvFilePath -Container $Container);
    if (-not $(Test-Path -LiteralPath $EnvFilePath)) {
        throw New-Object System.ArgumentException(
            "Couldn't find environment file $EnvFilePath, run Initialize-RenpyContainer"
        );
    }

    docker compose --file $(Get-ComposePath -Container $Container) `
        --env-file $EnvFilePath down;
    # Remove-Item -LiteralPath $EnvFilePath;
}

function Build-RenpyImage {
    [OutputType([System.Void])]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = "GameContainer", Position = 0)]
        [Parameter(Mandatory = $true, ParameterSetName = "LTContainer", Position = 0)]
        [ValidateSet([ValidContainerGenerator])]
        [string]$Container,
        [Parameter(ParameterSetName = "GameContainer")]
        [Parameter(ParameterSetName = "LTContainer")]
        [bool]$NoCache = $false,

        [Parameter(Mandatory = $true, ParameterSetName = "GameContainer")]
        [ValidateSet([ValidLocaleGenerator])]
        [string]$Locale,
        [Parameter(ParameterSetName = "GameContainer")]
        [string]$Sublocale,
        [Parameter(ParameterSetName = "GameContainer")]
        [string]$RenpySdk,
        [Parameter(ParameterSetName = "GameContainer")]
        [string]$RenpyVolume,

        [Parameter(ParameterSetName = "LTContainer")]
        [string]$NGramVolume,
        [Parameter(ParameterSetName = "LTContainer")]
        [int]$LTPort
    )
    Assert-Wsl2DockerDesktopRunning;

    switch ($Container) {
        "languagetool" {
            Initialize-RenpyContainer -Container $Container -NGramVolume $NGramVolume `
                -LTPort $LTPort;
        }
        default {
            Initialize-RenpyContainer -Container $Container -RenpyVolume $RenpyVolume `
                -Locale $Locale -Sublocale $Sublocale -RenpySdk $RenpySdk;
        }
    }

    [string]$EnvFilePath = $(Get-EnvFilePath -Container $Container);

    if ($NoCache) {
        docker compose --file $(Get-ComposePath -Container $Container) `
        --env-file $EnvFilePath build --no-cache;
    }
    else {
        docker compose --file $(Get-ComposePath -Container $Container) `
        --env-file $EnvFilePath build;
    }
    # Remove-Item -LiteralPath $EnvFilePath;
}

function Connect-RenpyContainer {
    [OutputType([System.Void])]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet([ValidConnectGenerator])]
        [string]$Container
    )
    Assert-Wsl2DockerDesktopRunning;
    
    [string[]]$LoginContainers = "ubuntu", "manjaro";

    if ($LoginContainers -contains $Container) {
        docker exec -it "$ContainerPrefix$Container" login -f root;
    }
    else {
        docker exec -it "$ContainerPrefix$Container" bash;
    }
}
