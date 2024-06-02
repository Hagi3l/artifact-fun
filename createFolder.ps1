# Function to load .env file
function Load-EnvFile {
    param (
        [string]$filePath
    )

    if (Test-Path $filePath) {
        $envVars = Get-Content -Path $filePath | ForEach-Object {
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

# Configuration Variables
$accessToken = $env:ACCESS_TOKEN
$baseUri = "https://kangaroo1.jfrog.io/artifactory"
$repositoryName = "preprod"
$folderName = "builds/"

# Headers for Authentication
$headers = @{
    "Authorization" = "Bearer $accessToken"
    "Content-Type" = "application/json"
}

# Create new folder
$folderUri = "$baseUri/$repositoryName/$folderName;"

try {
    # Invoke the REST method to create the folder
    $response = Invoke-RestMethod -Uri $folderUri -Method Put -Headers $headers -ErrorAction Stop
    Write-Output "Folder '$folderName' created successfully in repository '$repositoryName'."
} catch {
    Write-Error "Error creating folder '$folderName' in repository '$repositoryName': $($_.Exception.Message)"
    if ($_.Exception.Response) {
        $responseContent = $_.Exception.Response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($responseContent)
        $responseBody = $reader.ReadToEnd()
        Write-Error "Response content: $responseBody"
    }
}

#
