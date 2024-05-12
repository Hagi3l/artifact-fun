# Configuration Variables
$accessToken = ''
$baseUri = 'https://kangaroo.jfrog.io/artifactory/'


# Headers for Authentication
$headers = @{
    "Authorization" = "Bearer $accessToken"
}

# Repositories
$repositories = @('dev', 'devtest', 'preprod', 'prod')

# Function to fetch packages based on criteria
function Get-Packages($repo) {
    $uri = "$baseUri/storage/$repo"
    $response = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers
    return $response.children.where({ $_.folder -eq $false }) # Assuming packages are not folders
}

# Function to check and move packages
function Move-Package($sourceRepo, $targetRepo, $packageName) {
    $sourceUri = "$baseUri/copy/$sourceRepo/$packageName?to=/$targetRepo/$packageName"
    $result = Invoke-RestMethod -Uri $sourceUri -Method Post -Headers $headers
    return $result
}

# Main Logic
foreach ($repo in $repositories) {
    $nextRepoIndex = [array]::IndexOf($repositories, $repo) + 1
    if ($nextRepoIndex -lt $repositories.Length) {
        $packages = Get-Packages -repo $repo
        foreach ($package in $packages) {
            # Placeholder for package criteria checks
            $shouldMove = $true # Implement actual checks here
            if ($shouldMove) {
                $moveResult = Move-Package -sourceRepo $repo -targetRepo $repositories[$nextRepoIndex] -packageName $package.name
                Write-Output "Package moved: $($package.name)"
            }
        }
    }
}