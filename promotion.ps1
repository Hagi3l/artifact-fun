# Function to load .env file
function Load-EnvFile {
    param (
        [string]$filePath
    )

    if (Test-Path $filePath) {
        Get-Content -Path $filePath | ForEach-Object {
            if ($_ -match "^\s*([^#\s]+)\s*=\s*(.+?)\s*$") {
                $name = $matches[1]
                $value = $matches[2]
                [System.Environment]::SetEnvironmentVariable($name, $value)
            }
        }
        Write-Host "Environment variables loaded from $filePath"
    } else {
        Write-Host "Error: .env file not found at $filePath"
        exit
    }
}

# Load environment variables from .env file
$envFilePath = ".env"
Load-EnvFile -filePath $envFilePath

# Variables
$artifactoryUrl = "https://kangaroo.jfrog.io/artifactory"
$accessToken = $env:ACCESS_TOKEN
$sourceRepo = "devtest"
$targetRepo = "preprod"
$buildsFolderPath = "builds"

# Debug output to verify variables
Write-Host "Artifactory URL: $artifactoryUrl"
Write-Host "Source Repo: $sourceRepo"
Write-Host "Target Repo: $targetRepo"
Write-Host "Builds Folder Path: $buildsFolderPath"

# Function to validate access token
function Validate-AccessToken {
    $uri = "$artifactoryUrl/api/system/ping"
    $headers = @{
        "Authorization" = "Bearer $accessToken"
    }

    try {
        Write-Host "Validating access token..."
        $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get
        if ($response -eq "OK") {
            Write-Host "Access token is valid."
        } else {
            Write-Host "Failed to validate access token."
            exit
        }
    } catch {
        Write-Host "Error: Failed to validate access token. Status Code: $($_.Exception.Response.StatusCode)"
        Write-Host "Error Message: $($_.Exception.Message)"
        exit
    }
}

# Function to list artifacts in a folder
function List-Artifacts {
    param (
        [string]$repo,
        [string]$folderPath
    )

    $uri = "$artifactoryUrl/$repo/$folderPath?list&deep=1"
    $headers = @{
        "Authorization" = "Bearer $accessToken"
    }

    try {
        Write-Host "Requesting artifacts list from $uri"
        $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get
        Write-Host "Response: $($response | ConvertTo-Json -Depth 5)" # Debug output
        if ($response.files) {
            Write-Host "Artifacts found in $repo/$folderPath -"
            $response.files | ForEach-Object { Write-Host $_.uri }
        } else {
            Write-Host "No artifacts found in $repo/$folderPath."
        }
        return $response.files
    } catch {
        Write-Host "Error: Failed to list artifacts. Status Code: $($_.Exception.Response.StatusCode)"
        Write-Host "Error Message: $($_.Exception.Message)"
        return $null
    }
}

# Function to get artifact details
function Get-ArtifactDetails {
    param (
        [string]$repo,
        [string]$artifactPath
    )

    $uri = "$artifactoryUrl/$repo/$artifactPath"
    $headers = @{
        "Authorization" = "Bearer $accessToken"
    }

    try {
        Write-Host "Requesting artifact details from $uri"
        $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get
        return $response
    } catch {
        Write-Host "Error: Failed to get artifact details. Status Code: $($_.Exception.Response.StatusCode)"
        Write-Host "Error Message: $($_.Exception.Message)"
        return $null
    }
}

# Function to copy artifact to the target repository
function Copy-Artifact {
    param (
        [string]$sourceRepo,
        [string]$targetRepo,
        [string]$artifactPath
    )

    $uri = "$artifactoryUrl/api/copy/$sourceRepo/$artifactPath?to=/$targetRepo/$artifactPath"
    $headers = @{
        "Authorization" = "Bearer $accessToken"
    }

    try {
        Write-Host "Copying artifact from $sourceRepo/$artifactPath to $targetRepo/$artifactPath"
        $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Post
        return $response
    } catch {
        Write-Host "Error: Failed to copy artifact. Status Code: $($_.Exception.Response.StatusCode)"
        Write-Host "Error Message: $($_.Exception.Message)"
        return $null
    }
}

# Main Script
Write-Host "Finding the latest artifact in $sourceRepo/$buildsFolderPath..."

# Validate access token
Validate-AccessToken

# List artifacts in the builds folder
$artifacts = List-Artifacts -repo $sourceRepo -folderPath $buildsFolderPath

if ($artifacts) {
    # Initialize variable to hold the latest artifact details
    $latestArtifact = $null
    $latestModifiedTime = [datetime]::MinValue

    # Loop through artifacts to find the latest one
    foreach ($artifact in $artifacts) {
        if ($artifact.uri) {
            $artifactDetails = Get-ArtifactDetails -repo $sourceRepo -artifactPath ($buildsFolderPath + $artifact.uri)
            if ($artifactDetails) {
                $modifiedTime = [datetime]$artifactDetails.lastModified
                if ($modifiedTime -gt $latestModifiedTime) {
                    $latestModifiedTime = $modifiedTime
                    $latestArtifact = $artifact.uri
                }
            }
        }
    }

    if ($latestArtifact) {
        $latestArtifactPath = $latestArtifact.TrimStart('/')
        Write-Host "Latest artifact found: $latestArtifactPath"

        # Copy the latest artifact to the target repository
        $copyResult = Copy-Artifact -sourceRepo $sourceRepo -targetRepo $targetRepo -artifactPath $latestArtifactPath

        if ($copyResult) {
            Write-Host "Artifact successfully promoted from $sourceRepo to $targetRepo"
        } else {
            Write-Host "Failed to promote artifact from $sourceRepo to $targetRepo"
        }
    } else {
        Write-Host "No artifacts found in $sourceRepo/$buildsFolderPath"
    }
} else {
    Write-Host "Failed to list artifacts in $sourceRepo/$buildsFolderPath"
}

Write-Host "Artifact promotion script completed."
