# Configuration Variables
$accessToken = ""
$baseUri = "https://kangaroo.jfrog.io/artifactory"
$repositoryName = "prod"
$filePath = "D:\Projects\artifactory\example.txt"
$fileName = "example.txt"
$fileChecksum = ""  # Replace with the actual checksum of the file

# Headers for Authentication and Checksum
$headers = @{
    "Authorization" = "Bearer $accessToken"
    "X-Checksum-Md5" = $fileChecksum
}

# Full URL to upload the file
$fileUri = "$baseUri/$repositoryName/testing/$fileName"

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
