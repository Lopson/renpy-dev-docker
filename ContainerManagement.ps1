[string]$VariablesPath = "$PSScriptRoot$([IO.Path]::DirectorySeparatorChar)variables.json";
$Variables = Get-Content -LiteralPath $VariablesPath | ConvertFrom-Json;
[string]$ContainerPrefix = $Variables.prefix;

function Test-ContainerName {
    [OutputType([bool])]
    param([Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$Container)
    
    if (-not ($Variables.images -contains $Container)) {
        return $false;
    }

    return $true;
}

function Test-VolumePath {
    [OutputType([bool])]
    param([Parameter(Mandatory = $true)][AllowNull()][AllowEmptyString()][string]$Volume)
    
    if ([string]::IsNullOrWhiteSpace($Volume)) {
        return $false;
    }
    return $true;
}

function Get-ComposePath {
    [OutputType([string])]
    param([Parameter(Mandatory = $true)][ValidateScript({Test-ContainerName -Container $_})][string]$Container)
    
    return "$PSScriptRoot$([IO.Path]::DirectorySeparatorChar)$Container$([IO.Path]::DirectorySeparatorChar)compose.yml";
}

function Get-DockerfilePath {
    [OutputType([string])]
    param([Parameter(Mandatory = $true)][ValidateScript({Test-ContainerName -Container $_})][string]$Container)
    
    return "$PSScriptRoot$([IO.Path]::DirectorySeparatorChar)$Container$([IO.Path]::DirectorySeparatorChar)Dockerfile";
}

function Get-EnvFilePath {
    [OutputType([string])]
    param([Parameter(Mandatory = $true)][ValidateScript({Test-ContainerName -Container $_})][string]$Container)

    return "$([System.IO.Path]::GetTempPath())$Container.env";
}

function Initialize-RenpyContainer {
    [OutputType([System.Void])]
    param (
        [Parameter(Mandatory = $true)][ValidateScript({Test-ContainerName -Container $_})][string]$Container,
        [string]$Volume
    )

    if (-not (Test-VolumePath -Volume $Volume)) {
        $Volume = $Variables.volume;
    }

    [System.Text.StringBuilder]$EnvFile = [System.Text.StringBuilder]::new();
    $EnvFile.Append("DOCKER_MOUNT=`"$Volume`"") > $null;

    [string]$EnvFilePath = $(Get-EnvFilePath -Container $Container);
    Set-Content -Value $EnvFile.ToString() -Encoding "utf8BOM" -LiteralPath $EnvFilePath;
    return;
}

function Start-RenpyContainer {
    [OutputType([System.Void])]
    param (
        [Parameter(Mandatory = $true)][ValidateScript({Test-ContainerName -Container $_})][string]$Container,
        [string]$Volume
    )
    
    Initialize-RenpyContainer -Container $Container -Volume $Volume;
    [string]$EnvFilePath = $(Get-EnvFilePath -Container $Container);

    docker compose --file $(Get-ComposePath -Container $Container) --env-file $EnvFilePath up --detach;
}

function Stop-RenpyContainer {
    [OutputType([System.Void])]
    param ([Parameter(Mandatory = $true)][ValidateScript({Test-ContainerName -Container $_})][string]$Container)

    [string]$EnvFilePath = $(Get-EnvFilePath -Container $Container);
    if (-not $(Test-Path -LiteralPath $EnvFilePath)) {
        throw New-Object System.ArgumentException(
            "Couldn't find environment file $EnvFilePath, run Initialize-RenpyContainer"
        );
    }

    docker compose --file $(Get-ComposePath -Container $Container) --env-file $EnvFilePath down;
    Remove-Item -LiteralPath $EnvFilePath;
}

function Build-RenpyImage {
    [OutputType([System.Void])]
    param (
        [Parameter(Mandatory = $true)][ValidateScript({Test-ContainerName -Container $_})][string]$Container,
        [string]$Volume
    )

    Initialize-RenpyContainer -Container $Container -Volume $Volume;
    [string]$EnvFilePath = $(Get-EnvFilePath -Container $Container);

    docker compose --file $(Get-ComposePath -Container $Container) --env-file $EnvFilePath build;
    Remove-Item -LiteralPath $EnvFilePath;
}

function Connect-RenpyContainer {
    [OutputType([System.Void])]
    param ([Parameter(Mandatory = $true)][ValidateScript({Test-ContainerName -Container $_})][string]$Container)

    docker exec -it "$ContainerPrefix$Container" bash;
}
