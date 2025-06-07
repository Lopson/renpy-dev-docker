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

if (-not (Test-NullOrEmpty -String $Variables.volume)) {
    throw New-Object System.ArgumentException(
        "The value `"volume`" must be filled out in the variables file");
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

class ValidBuildGenerator : System.Management.Automation.IValidateSetValuesGenerator {
    [string[]] GetValidValues() {
        return [ValidContainerGenerator]::new().GetValidValues() | `
            Where-Object { $_ -ne "languagetool"};
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
        [Parameter(Mandatory = $true)]
        [ValidateSet([ValidBuildGenerator])]
        $Container,
        [Parameter(Mandatory = $true)]
        [ValidateSet([ValidLocaleGenerator])]
        [string]$Locale,
        [string]$Sublocale,
        [string]$RenpySdk,
        [string]$Volume
    )

    if (-not (Test-NullOrEmpty -String $Volume)) {
        $Volume = $Variables.volume;
    }
    if (-not (Test-NullOrEmpty -String $RenpySdk)) {
        $RenpySdk = $Variables.renpy_sdk_version;
    }

    [System.Text.StringBuilder]$EnvFile = [System.Text.StringBuilder]::new();
    $EnvFile.AppendLine("DOCKER_MOUNT=`"$Volume`"") > $null;
    $EnvFile.AppendLine("LOCALE=`"$Locale`"") > $null;
    $EnvFile.AppendLine("SUBLOCALE=`"$($Sublocale.ToUpper())`"") > $null;
    $EnvFile.AppendLine("RENPY_SDK_URL=`"$($RenpySdkBaseUrl -f $RenpySdk)`"") > $null;

    [string]$EnvFilePath = $(Get-EnvFilePath -Container $Container);
    Set-Content -NoNewline -Value $EnvFile.ToString() -Encoding "utf8BOM" -LiteralPath $EnvFilePath;
    return;
}

function Start-RenpyContainer {
    [OutputType([System.Void])]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet([ValidContainerGenerator])]
        [string]$Container
    )
    
    if ([ValidBuildGenerator]::new().GetValidValues() -contains $Container) {
        [string]$EnvFilePath = $(Get-EnvFilePath -Container $Container);
        if (-not $(Test-Path -LiteralPath $EnvFilePath)) {
            throw New-Object System.ArgumentException(
                "Couldn't find environment file $EnvFilePath, run Initialize-RenpyContainer"
            );
        }

        docker compose --file $(Get-ComposePath -Container $Container) `
            --env-file $EnvFilePath up --detach;    
    }
    else {
        docker compose --file $(Get-ComposePath -Container $Container) `
            up --detach;
    }
}

function Stop-RenpyContainer {
    [OutputType([System.Void])]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet([ValidContainerGenerator])]
        [string]$Container
    )

    if ([ValidBuildGenerator]::new().GetValidValues() -contains $Container) {
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
    else {
        docker compose --file $(Get-ComposePath -Container $Container) `
            down;
    }
}

function Build-RenpyImage {
    [OutputType([System.Void])]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet([ValidBuildGenerator])]
        [string]$Container,
        [Parameter(Mandatory = $true)]
        [ValidateSet([ValidLocaleGenerator])]
        [string]$Locale,
        [string]$Sublocale,
        [string]$RenpySdk,
        [string]$Volume
    )

    Initialize-RenpyContainer -Container $Container -Volume $Volume `
        -Locale $Locale -Sublocale $Sublocale -RenpySdk $RenpySdk;
    [string]$EnvFilePath = $(Get-EnvFilePath -Container $Container);

    docker compose --file $(Get-ComposePath -Container $Container) `
        --env-file $EnvFilePath build;
    # Remove-Item -LiteralPath $EnvFilePath;
}

function Connect-RenpyContainer {
    [OutputType([System.Void])]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet([ValidConnectGenerator])]
        [string]$Container
    )
    
    [string[]]$LoginContainers = "ubuntu", "manjaro";

    if ($LoginContainers -contains $Container) {
        docker exec -it "$ContainerPrefix$Container" login -f root;
    }
    else {
        docker exec -it "$ContainerPrefix$Container" bash;
    }
}
