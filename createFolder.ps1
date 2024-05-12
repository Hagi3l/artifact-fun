# Configuration Variables
$accessToken = ""
$baseUri = "https://kangaroo.jfrog.io/artifactory"
$repositoryName = "dev"
$folderName = "testing/"

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
