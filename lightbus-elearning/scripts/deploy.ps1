# Light Bus E-Learning Platform - Production Deployment Script
# PowerShell script for Windows deployment automation

param(
    [Parameter(Mandatory=$true)]
    [string]$ProjectRef,
    
    [Parameter(Mandatory=$true)]
    [string]$Domain,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipTests = $false
)

Write-Host "🚀 Starting Light Bus E-Learning Platform Deployment" -ForegroundColor Green
Write-Host "=================================================" -ForegroundColor Green

# Function to check if command exists
function Test-Command($cmdname) {
    return [bool](Get-Command -Name $cmdname -ErrorAction SilentlyContinue)
}

# Check prerequisites
Write-Host "🔍 Checking prerequisites..." -ForegroundColor Yellow

$prerequisites = @(
    @{Name="node"; DisplayName="Node.js"},
    @{Name="npm"; DisplayName="NPM"},
    @{Name="supabase"; DisplayName="Supabase CLI"},
    @{Name="vercel"; DisplayName="Vercel CLI"}
)

foreach ($prereq in $prerequisites) {
    if (Test-Command $prereq.Name) {
        Write-Host "✅ $($prereq.DisplayName) is installed" -ForegroundColor Green
    } else {
        Write-Host "❌ $($prereq.DisplayName) is not installed" -ForegroundColor Red
        Write-Host "Please install $($prereq.DisplayName) before continuing"
        exit 1
    }
}

# Check environment file
if (!(Test-Path ".env.production.local")) {
    Write-Host "❌ .env.production.local not found" -ForegroundColor Red
    Write-Host "Please create .env.production.local with your production configuration"
    exit 1
}

Write-Host "✅ All prerequisites met" -ForegroundColor Green

# Install dependencies
Write-Host "`n📦 Installing dependencies..." -ForegroundColor Yellow
npm ci
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to install dependencies" -ForegroundColor Red
    exit 1
}

# Run tests (unless skipped)
if (!$SkipTests) {
    Write-Host "`n🧪 Running tests..." -ForegroundColor Yellow
    npm run type-check
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Type checking failed" -ForegroundColor Red
        exit 1
    }
    
    npm run lint
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Linting failed" -ForegroundColor Red
        exit 1
    }
}

# Build application
Write-Host "`n🏗️ Building application..." -ForegroundColor Yellow
npm run build
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Build failed" -ForegroundColor Red
    exit 1
}

# Deploy to Supabase
Write-Host "`n🗄️ Deploying to Supabase..." -ForegroundColor Yellow

# Link to Supabase project
Write-Host "Linking to Supabase project: $ProjectRef"
supabase link --project-ref $ProjectRef
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to link to Supabase project" -ForegroundColor Red
    exit 1
}

# Apply database migrations
Write-Host "Applying database migrations..."
supabase db push
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to apply database migrations" -ForegroundColor Red
    exit 1
}

# Deploy edge functions
Write-Host "Deploying edge functions..."
$functions = @("process-lesson-audio", "generate-flashcards", "analyze-content")

foreach ($function in $functions) {
    Write-Host "Deploying $function..."
    supabase functions deploy $function
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Failed to deploy $function function" -ForegroundColor Red
        exit 1
    }
}

# Deploy to Vercel
Write-Host "`n🌐 Deploying to Vercel..." -ForegroundColor Yellow
vercel --prod --yes
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to deploy to Vercel" -ForegroundColor Red
    exit 1
}

# Post-deployment verification
Write-Host "`n✅ Running post-deployment verification..." -ForegroundColor Yellow

# Test application health
Write-Host "Testing application health..."
$healthUrl = "https://$Domain/api/health"
try {
    $response = Invoke-WebRequest -Uri $healthUrl -UseBasicParsing -TimeoutSec 30
    if ($response.StatusCode -eq 200) {
        Write-Host "✅ Application health check passed" -ForegroundColor Green
    } else {
        Write-Host "⚠️ Application health check returned status: $($response.StatusCode)" -ForegroundColor Yellow
    }
} catch {
    Write-Host "⚠️ Could not reach application health endpoint" -ForegroundColor Yellow
    Write-Host "This might be normal if DNS hasn't propagated yet" -ForegroundColor Yellow
}

# Test SSL certificate
Write-Host "Testing SSL certificate..."
try {
    $sslResponse = Invoke-WebRequest -Uri "https://$Domain" -UseBasicParsing -TimeoutSec 30
    Write-Host "✅ SSL certificate is working" -ForegroundColor Green
} catch {
    Write-Host "⚠️ SSL certificate test failed" -ForegroundColor Yellow
    Write-Host "This might be normal if DNS hasn't propagated yet" -ForegroundColor Yellow
}

Write-Host "`n🎉 Deployment completed successfully!" -ForegroundColor Green
Write-Host "=================================================" -ForegroundColor Green
Write-Host "Your application is deployed at: https://$Domain" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Wait for DNS propagation (up to 24 hours)" -ForegroundColor White
Write-Host "2. Test all application features" -ForegroundColor White
Write-Host "3. Create admin user account" -ForegroundColor White
Write-Host "4. Configure monitoring and alerts" -ForegroundColor White
Write-Host "5. Set up backup verification" -ForegroundColor White
Write-Host ""
Write-Host "For troubleshooting, check:" -ForegroundColor Yellow
Write-Host "- Vercel deployment logs: https://vercel.com/dashboard" -ForegroundColor White
Write-Host "- Supabase project logs: https://supabase.com/dashboard" -ForegroundColor White
Write-Host "- Deployment walkthrough: docs/DEPLOYMENT_WALKTHROUGH.md" -ForegroundColor White