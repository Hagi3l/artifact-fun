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
$baseUri = "https://kangaroo.jfrog.io/artifactory"
$repositoryName = "devtest"
$filePath = "D:\Projects\artifactory\builds\m2m-1.37.7z"
$fileName = "m2m-1.37.7z"
$fileChecksum = ""  # Replace with the actual checksum of the file

# Headers for Authentication and Checksum
$headers = @{
    "Authorization" = "Bearer $accessToken"
    "X-Checksum-Md5" = $fileChecksum
}

# Full URL to upload the file
$fileUri = "$baseUri/$repositoryName/builds/$fileName"

try {
    # Read the file content
    $fileContent = [System.IO.File]::ReadAllBytes($filePath)

    # Invoke the REST method to upload the file
    $response = Invoke-RestMethod -Uri $fileUri -Method Put -Headers $headers -Body $fileContent -ContentType "application/octet-stream" -ErrorAction Stop
    Write-Output "File '$fileName' uploaded successfully to repository '$repositoryName'."
} catch {
    Write-Error "Error uploading file '$fileName' to repository '$repositoryName': $($_.Exception.Message)"
    if ($_.Exception.Response) {
        $responseContent = $_.Exception.Response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($responseContent)
        $responseBody = $reader.ReadToEnd()
        Write-Error "Response content: $responseBody"
    }
}
