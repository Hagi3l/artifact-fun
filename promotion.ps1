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
$artifactoryUrl = "https://kangaroo1.jfrog.io/artifactory"
$accessToken = $env:ACCESS_TOKEN
$sourceRepo = "7-year-archive"
#$sourceRepo = "preprod"
#$targetRepo = "preprod"
#$targetRepo = "7-year-archive"
$targetRepo = "devtest"
$filePath = "builds/m2m-1.37.7z"

# Debug output to verify variables
Write-Host "Artifactory URL: $artifactoryUrl"
Write-Host "Source Repo: $sourceRepo"
Write-Host "Target Repo: $targetRepo"
Write-Host "File Path: $filePath"

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

    $uri = "$artifactoryUrl/api/storage/$repo/$folderPath?list&deep=1"
    $headers = @{
        "Authorization" = "Bearer $accessToken"
    }

    try {
        Write-Host "Requesting artifacts list from $uri"
        $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get
        Write-Host "Response: $($response | ConvertTo-Json -Depth 5)" # Debug output
        return $response.children
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

    $uri = "$artifactoryUrl/api/storage/$repo/$artifactPath"
    $headers = @{
        "Authorization" = "Bearer $accessToken"
    }

    try {
        Write-Host "Requesting artifact details from $uri"
        $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get
        Write-Host "Artifact details: $($response | ConvertTo-Json -Depth 5)" # Debug output
        return $response
    } catch {
        Write-Host "Error: Failed to get artifact details. Status Code: $($_.Exception.Response.StatusCode)"
        Write-Host "Error Message: $($_.Exception.Message)"
        return $null
    }
}

# Function to move artifact to the target repository with conflict handling
function Move-Artifact {
    param (
        [string]$sourceRepo,
        [string]$targetRepo,
        [string]$artifactPath
    )

    $uri = "$artifactoryUrl/api/move/$sourceRepo/$artifactPath" + "?to=/$targetRepo/$artifactPath"
    
    $headers = @{
        "Authorization" = "Bearer $accessToken"
    }

    try {
        Write-Host "Moving artifact from $sourceRepo/$artifactPath to $targetRepo/$artifactPath"
        $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Post
        Write-Host "Move response: $($response | ConvertTo-Json -Depth 5)" # Debug output
        return $response
    } catch {
        Write-Host "Error: Failed to move artifact. Status Code: $($_.Exception.Response.StatusCode)"
        if ($_.Exception.Response.StatusCode -eq 409) {
            Write-Host "Conflict detected: The file already exists in the target repository."
        }
        Write-Host "Error Message: $($_.Exception.Message)"
        return $null
    }
}

# Main Script
Write-Host "Finding the artifact $filePath in $sourceRepo..."

# Validate access token
Validate-AccessToken

# Get artifact details
$artifactDetails = Get-ArtifactDetails -repo $sourceRepo -artifactPath $filePath

if ($artifactDetails) {
    Write-Host "Artifact found: $filePath"

    # List artifacts in the target folder to ensure it's really empty
    $targetArtifacts = List-Artifacts -repo $targetRepo -folderPath "builds"
    if ($targetArtifacts) {
        Write-Host "Artifacts already in target folder:"
        $targetArtifacts | ForEach-Object { Write-Host $_.uri }
    } else {
        Write-Host "No artifacts found in the target folder."
    }

    # Move the artifact to the target repository
    $moveResult = Move-Artifact -sourceRepo $sourceRepo -targetRepo $targetRepo -artifactPath $filePath

    if ($moveResult) {
        Write-Host "Artifact successfully moved from $sourceRepo to $targetRepo"
    } else {
        Write-Host "Failed to move artifact from $sourceRepo to $targetRepo"
    }
} else {
    Write-Host "Artifact $filePath not found in $sourceRepo"
}

Write-Host "Artifact promotion script completed."
