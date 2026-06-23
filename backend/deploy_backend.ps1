<#
PowerShell deploy script for CineMemo backend to Cloud Run.

Usage: run from repo root in PowerShell (Windows). It reads backend env values from env\dev.json.
Requires: gcloud CLI installed and logged in, Docker not required (Cloud Build used).

This script will:
- set gcloud project
- enable required APIs
- build and push image via Cloud Build
- create secrets in Secret Manager from env\dev.json (MOMO keys)
- deploy Cloud Run service with secrets mapped and CORS configured

Edit variables below as needed.
#>

param(
    [string]$ProjectId = 'cinememo-app',
    [string]$Region = 'asia-southeast1',
    [string]$ServiceName = 'cinememo-backend',
    [string]$BackendFolder = 'backend'
)

Write-Host "Deploying backend to project $ProjectId in region $Region"

if (-not (Get-Command gcloud -ErrorAction SilentlyContinue)) {
    Write-Error "gcloud CLI not found. Install and authenticate first: https://cloud.google.com/sdk/docs/install"
    exit 1
}

gcloud auth login
gcloud config set project $ProjectId

Write-Host "Enabling Cloud Run, Cloud Build and Secret Manager APIs..."
gcloud services enable run.googleapis.com cloudbuild.googleapis.com secretmanager.googleapis.com --quiet

Write-Host "Building container image with Cloud Build..."
gcloud builds submit --tag gcr.io/$ProjectId/$ServiceName:latest $BackendFolder

$envFile = Join-Path $PSScriptRoot '..\env\dev.json'
if (-Not (Test-Path $envFile)) {
    Write-Warning "env/dev.json not found at $envFile. You'll need to set secrets manually or edit this script."
} else {
    $json = Get-Content $envFile -Raw | ConvertFrom-Json

    $secrets = @{
        'MOMO_SECRET_KEY' = $json.MOMO_SECRET_KEY
        'MOMO_ACCESS_KEY' = $json.MOMO_ACCESS_KEY
        'MOMO_PARTNER_CODE' = $json.MOMO_PARTNER_CODE
    }

    foreach ($name in $secrets.Keys) {
        $val = $secrets[$name]
        if ([string]::IsNullOrWhiteSpace($val)) { continue }

        # create secret if not exists
        $exists = $true
        try {
            gcloud secrets describe $name --project $ProjectId --format="value(name)" > $null 2>&1
        } catch {
            $exists = $false
        }
        if (-not $exists) {
            Write-Host "Creating secret $name"
            gcloud secrets create $name --replication-policy="automatic" --project $ProjectId
        } else {
            Write-Host "Secret $name already exists - adding new version"
        }

        # add version from value
        Write-Host "Adding secret version for $name"
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($val)
        $tmp = New-TemporaryFile
        [System.IO.File]::WriteAllBytes($tmp.FullName, $bytes)
        gcloud secrets versions add $name --data-file=$tmp.FullName --project $ProjectId
        Remove-Item $tmp.FullName -Force
    }
}

Write-Host "Deploying Cloud Run service $ServiceName..."

# Build secret mapping for --update-secrets parameter
$secretMappings = @()
foreach ($s in @('MOMO_SECRET_KEY','MOMO_ACCESS_KEY','MOMO_PARTNER_CODE')) {
    # map SECRET_NAME=SECRET_NAME:latest
    $secretMappings += "$s=$s:latest"
}
$secretArg = $secretMappings -join ','

gcloud run deploy $ServiceName `
  --image gcr.io/$ProjectId/$ServiceName:latest `
  --platform managed `
  --region $Region `
  --allow-unauthenticated `
  --update-secrets $secretArg `
  --set-env-vars=CORS_ORIGINS=https://cinememo-app.web.app `
  --project $ProjectId

Write-Host "Deployment finished. Retrieving service URL..."
$url = gcloud run services describe $ServiceName --region $Region --format="value(status.url)" --project $ProjectId
Write-Host "Service URL: $url"

Write-Host "Next: rebuild web with this backend URL and deploy hosting. Example:" 
Write-Host "flutter build web --release --dart-define=MOMO_BACKEND_URL=\"$url\""
Write-Host "firebase deploy --only hosting"

Write-Host "Done."