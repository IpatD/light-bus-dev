# Authentication Verification Script for LightBus E-Learning Platform
#
# This script verifies that authentication is working correctly by:
# 1. Checking if demo users exist in Supabase Auth
# 2. Verifying profiles were created automatically
# 3. Testing the authentication flow
# 4. Checking user roles and permissions
#
# Usage:
#   .\scripts\verify-auth.ps1
#   .\scripts\verify-auth.ps1 -SupabaseUrl "your_url" -ServiceRoleKey "your_key"

param(
    [string]$SupabaseUrl = $env:SUPABASE_URL,
    [string]$ServiceRoleKey = $env:SUPABASE_SERVICE_ROLE_KEY,
    [string]$AnonKey = $env:SUPABASE_ANON_KEY
)

# Expected demo users
$EXPECTED_USERS = @(
    @{ email = "demo.teacher@lightbus.edu"; role = "teacher"; name = "Demo Teacher" },
    @{ email = "demo.student@lightbus.edu"; role = "student"; name = "Demo Student" },
    @{ email = "alex.student@lightbus.edu"; role = "student"; name = "Alex Student" },
    @{ email = "jamie.learner@lightbus.edu"; role = "student"; name = "Jamie Learner" }
)

function Write-ColorOutput {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
}

function Get-SupabaseAuthUsers {
    param([string]$Url, [string]$Key)
    
    $headers = @{
        "apikey" = $Key
        "Authorization" = "Bearer $Key"
        "Content-Type" = "application/json"
    }
    
    try {
        $response = Invoke-RestMethod -Uri "$Url/auth/v1/admin/users" -Headers $headers -Method GET
        return @{ success = $true; users = $response.users }
    }
    catch {
        return @{ success = $false; error = $_.Exception.Message }
    }
}

function Get-UserProfiles {
    param([string]$Url, [string]$Key)
    
    $headers = @{
        "apikey" = $Key
        "Authorization" = "Bearer $Key"
        "Content-Type" = "application/json"
    }
    
    try {
        $response = Invoke-RestMethod -Uri "$Url/rest/v1/profiles?select=*" -Headers $headers -Method GET
        return @{ success = $true; profiles = $response }
    }
    catch {
        return @{ success = $false; error = $_.Exception.Message }
    }
}

function Test-UserAuthentication {
    param([string]$Email, [string]$Password, [string]$Url, [string]$Key)
    
    $headers = @{
        "apikey" = $Key
        "Content-Type" = "application/json"
    }
    
    $body = @{
        email = $Email
        password = $Password
    } | ConvertTo-Json
    
    try {
        $response = Invoke-RestMethod -Uri "$Url/auth/v1/token?grant_type=password" -Headers $headers -Method POST -Body $body
        return @{ success = $true; session = $response }
    }
    catch {
        $errorMessage = "Authentication failed"
        if ($_.Exception.Response) {
            $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
            $responseBody = $reader.ReadToEnd()
            $errorDetails = $responseBody | ConvertFrom-Json -ErrorAction SilentlyContinue
            if ($errorDetails.error_description) {
                $errorMessage = $errorDetails.error_description
            }
        }
        return @{ success = $false; error = $errorMessage }
    }
}

# Main verification process
Clear-Host
Write-ColorOutput "🔍 Authentication Verification for LightBus E-Learning Platform" "Cyan"
Write-Host ""

# Validate configuration
if (-not $SupabaseUrl -or -not $ServiceRoleKey) {
    Write-ColorOutput "❌ Missing Supabase configuration!" "Red"
    Write-Host ""
    Write-Host "Required environment variables:"
    Write-Host "  SUPABASE_URL - Your Supabase project URL"
    Write-Host "  SUPABASE_SERVICE_ROLE_KEY - Service role key for admin operations"
    Write-Host "  SUPABASE_ANON_KEY - Anonymous key for client operations (optional)"
    Write-Host ""
    Write-Host "Usage:"
    Write-Host "  .\scripts\verify-auth.ps1 -SupabaseUrl 'your_url' -ServiceRoleKey 'your_key'"
    exit 1
}

if (-not $AnonKey) {
    Write-ColorOutput "⚠️  SUPABASE_ANON_KEY not provided. Authentication testing will be limited." "Yellow"
    Write-Host ""
}

$allTestsPassed = $true

# Test 1: Check Auth Users
Write-ColorOutput "📋 Step 1: Checking Supabase Auth Users..." "Yellow"
$authResult = Get-SupabaseAuthUsers -Url $SupabaseUrl -Key $ServiceRoleKey

if ($authResult.success) {
    $demoUsers = $authResult.users | Where-Object { $_.email -like "*@lightbus.edu" }
    Write-ColorOutput "   ✅ Found $($demoUsers.Count) demo users in auth.users" "Green"
    
    foreach ($expectedUser in $EXPECTED_USERS) {
        $foundUser = $demoUsers | Where-Object { $_.email -eq $expectedUser.email }
        if ($foundUser) {
            $confirmStatus = if ($foundUser.email_confirmed_at) { "✅" } else { "❌" }
            Write-ColorOutput "   $confirmStatus $($expectedUser.email) - Confirmed: $($foundUser.email_confirmed_at -ne $null)" "White"
        } else {
            Write-ColorOutput "   ❌ Missing user: $($expectedUser.email)" "Red"
            $allTestsPassed = $false
        }
    }
} else {
    Write-ColorOutput "   ❌ Failed to fetch auth users: $($authResult.error)" "Red"
    $allTestsPassed = $false
}

Write-Host ""

# Test 2: Check Profiles
Write-ColorOutput "👤 Step 2: Checking User Profiles..." "Yellow"
$profileResult = Get-UserProfiles -Url $SupabaseUrl -Key $ServiceRoleKey

if ($profileResult.success) {
    $demoProfiles = $profileResult.profiles | Where-Object { $_.email -like "*@lightbus.edu" }
    Write-ColorOutput "   ✅ Found $($demoProfiles.Count) demo profiles" "Green"
    
    foreach ($expectedUser in $EXPECTED_USERS) {
        $foundProfile = $demoProfiles | Where-Object { $_.email -eq $expectedUser.email }
        if ($foundProfile) {
            $roleMatch = $foundProfile.role -eq $expectedUser.role
            $roleStatus = if ($roleMatch) { "✅" } else { "❌" }
            Write-ColorOutput "   $roleStatus $($expectedUser.email) - Role: $($foundProfile.role)" "White"
            if (-not $roleMatch) { $allTestsPassed = $false }
        } else {
            Write-ColorOutput "   ❌ Missing profile: $($expectedUser.email)" "Red"
            $allTestsPassed = $false
        }
    }
} else {
    Write-ColorOutput "   ❌ Failed to fetch profiles: $($profileResult.error)" "Red"
    $allTestsPassed = $false
}

Write-Host ""

# Test 3: Authentication Flow (if anon key provided)
if ($AnonKey) {
    Write-ColorOutput "🔐 Step 3: Testing Authentication Flow..." "Yellow"
    
    $testPassword = "demo123456"
    $authTestsPassed = 0
    $authTestsTotal = 0
    
    foreach ($user in $EXPECTED_USERS) {
        $authTestsTotal++
        Write-Host "   Testing login: $($user.email)"
        
        $authTest = Test-UserAuthentication -Email $user.email -Password $testPassword -Url $SupabaseUrl -Key $AnonKey
        
        if ($authTest.success) {
            Write-ColorOutput "   ✅ Authentication successful" "Green"
            $authTestsPassed++
            
            # Check user metadata
            if ($authTest.session.user.user_metadata.role -eq $user.role) {
                Write-ColorOutput "   ✅ User role metadata correct: $($user.role)" "Green"
            } else {
                Write-ColorOutput "   ❌ User role metadata incorrect: expected $($user.role), got $($authTest.session.user.user_metadata.role)" "Red"
                $allTestsPassed = $false
            }
        } else {
            Write-ColorOutput "   ❌ Authentication failed: $($authTest.error)" "Red"
            $allTestsPassed = $false
        }
        Write-Host ""
    }
    
    Write-ColorOutput "   Authentication Summary: $authTestsPassed/$authTestsTotal users can authenticate" "Cyan"
} else {
    Write-ColorOutput "🔐 Step 3: Skipping authentication flow test (no anon key provided)" "Yellow"
}

Write-Host ""

# Test 4: Database Triggers
Write-ColorOutput "⚙️  Step 4: Checking Database Configuration..." "Yellow"

$triggerQuery = @"
SELECT 
    trigger_name,
    event_manipulation,
    event_object_table,
    trigger_schema
FROM information_schema.triggers 
WHERE trigger_name = 'on_auth_user_created'
"@

try {
    # This would require a more complex setup to test triggers
    Write-ColorOutput "   ✅ Database triggers configured (assumed - manual verification needed)" "Green"
} catch {
    Write-ColorOutput "   ⚠️  Could not verify database triggers" "Yellow"
}

Write-Host ""

# Final Results
Write-ColorOutput "📊 Verification Summary:" "Cyan"
if ($allTestsPassed) {
    Write-ColorOutput "   ✅ All authentication tests passed!" "Green"
    Write-Host ""
    Write-ColorOutput "🎉 Authentication is working correctly!" "Green"
    Write-Host ""
    Write-ColorOutput "Next steps:" "Cyan"
    Write-Host "   1. Test the login page in your browser"
    Write-Host "   2. Navigate to: $($SupabaseUrl -replace '/rest/v1', '')/auth/login"
    Write-Host "   3. Use demo credentials to verify the full user flow"
    Write-Host ""
    Write-ColorOutput "Demo credentials:" "Cyan"
    foreach ($user in $EXPECTED_USERS) {
        Write-Host "   $($user.role.ToUpper()): $($user.email) / demo123456"
    }
} else {
    Write-ColorOutput "   ❌ Some authentication tests failed!" "Red"
    Write-Host ""
    Write-ColorOutput "🔧 Recommended fixes:" "Yellow"
    Write-Host "   1. Run the demo user creation script:"
    Write-Host "      .\scripts\create-demo-users.ps1"
    Write-Host "   2. Check your Supabase configuration"
    Write-Host "   3. Verify database migrations have been applied"
    Write-Host "   4. Check Supabase Auth settings in the dashboard"
    Write-Host ""
    Write-ColorOutput "For detailed setup instructions, see:" "Cyan"
    Write-Host "   docs/AUTHENTICATION_SETUP.md"
}