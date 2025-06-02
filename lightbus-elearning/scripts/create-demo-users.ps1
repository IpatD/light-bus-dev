# Demo User Creation Script for LightBus E-Learning Platform (PowerShell)
#
# This script creates actual Supabase Auth users for testing purposes.
# It uses the Supabase Admin API to create users with passwords.
#
# Usage:
#   .\scripts\create-demo-users.ps1
#   .\scripts\create-demo-users.ps1 -SupabaseUrl "your_url" -ServiceRoleKey "your_key"
#
# Requirements:
#   - SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY environment variables
#   - Or provide them as parameters

param(
    [string]$SupabaseUrl = $env:SUPABASE_URL,
    [string]$ServiceRoleKey = $env:SUPABASE_SERVICE_ROLE_KEY
)

# Demo user configurations
$DEMO_USERS = @(
    @{
        email = "demo.teacher@lightbus.edu"
        password = "demo123456"
        name = "Demo Teacher"
        role = "teacher"
    },
    @{
        email = "demo.student@lightbus.edu"
        password = "demo123456"
        name = "Demo Student"
        role = "student"
    },
    @{
        email = "alex.student@lightbus.edu"
        password = "demo123456"
        name = "Alex Student"
        role = "student"
    },
    @{
        email = "jamie.learner@lightbus.edu"
        password = "demo123456"
        name = "Jamie Learner"
        role = "student"
    }
)

function Write-ColorOutput {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
}

function Test-SupabaseConnection {
    param([string]$Url, [string]$Key)
    
    try {
        $headers = @{
            "apikey" = $Key
            "Authorization" = "Bearer $Key"
            "Content-Type" = "application/json"
        }
        
        $response = Invoke-RestMethod -Uri "$Url/auth/v1/settings" -Headers $headers -Method GET
        return $true
    }
    catch {
        return $false
    }
}

function New-SupabaseUser {
    param([hashtable]$User, [string]$Url, [string]$Key)
    
    $headers = @{
        "apikey" = $Key
        "Authorization" = "Bearer $Key"
        "Content-Type" = "application/json"
    }
    
    $body = @{
        email = $User.email
        password = $User.password
        email_confirm = $true
        user_metadata = @{
            name = $User.name
            role = $User.role
        }
    } | ConvertTo-Json -Depth 3
    
    try {
        $response = Invoke-RestMethod -Uri "$Url/auth/v1/admin/users" -Headers $headers -Method POST -Body $body
        return @{ success = $true; user = $response }
    }
    catch {
        $errorMessage = $_.Exception.Message
        if ($_.Exception.Response) {
            $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
            $responseBody = $reader.ReadToEnd()
            $errorDetails = $responseBody | ConvertFrom-Json -ErrorAction SilentlyContinue
            if ($errorDetails.message) {
                $errorMessage = $errorDetails.message
            }
        }
        return @{ success = $false; error = $errorMessage }
    }
}

function Test-UserProfile {
    param([string]$Email, [string]$Url, [string]$Key)
    
    $headers = @{
        "apikey" = $Key
        "Authorization" = "Bearer $Key"
        "Content-Type" = "application/json"
    }
    
    try {
        $response = Invoke-RestMethod -Uri "$Url/rest/v1/profiles?email=eq.$Email&select=*" -Headers $headers -Method GET
        return $response.Count -gt 0
    }
    catch {
        return $false
    }
}

# Main script execution
Clear-Host
Write-ColorOutput "🚀 Creating demo users for LightBus E-Learning Platform..." "Cyan"
Write-Host ""

# Validate configuration
if (-not $SupabaseUrl -or -not $ServiceRoleKey) {
    Write-ColorOutput "❌ Missing Supabase configuration!" "Red"
    Write-Host ""
    Write-Host "Usage:"
    Write-Host "  Environment variables:"
    Write-Host "    `$env:SUPABASE_URL='your_url'; `$env:SUPABASE_SERVICE_ROLE_KEY='your_key'; .\scripts\create-demo-users.ps1"
    Write-Host ""
    Write-Host "  Command line parameters:"
    Write-Host "    .\scripts\create-demo-users.ps1 -SupabaseUrl 'your_url' -ServiceRoleKey 'your_key'"
    exit 1
}

# Test connection
Write-ColorOutput "🔗 Testing Supabase connection..." "Yellow"
if (-not (Test-SupabaseConnection -Url $SupabaseUrl -Key $ServiceRoleKey)) {
    Write-ColorOutput "❌ Failed to connect to Supabase. Check your URL and service role key." "Red"
    exit 1
}
Write-ColorOutput "   ✅ Connection successful" "Green"
Write-Host ""

$successCount = 0
$errorCount = 0

foreach ($user in $DEMO_USERS) {
    Write-ColorOutput "👤 Creating user: $($user.email) ($($user.role))" "White"
    
    $result = New-SupabaseUser -User $user -Url $SupabaseUrl -Key $ServiceRoleKey
    
    if ($result.success) {
        Write-ColorOutput "   ✅ Created auth user: $($result.user.id)" "Green"
        $successCount++
        
        # Check if profile was created
        Start-Sleep -Seconds 1  # Give trigger time to execute
        if (Test-UserProfile -Email $user.email -Url $SupabaseUrl -Key $ServiceRoleKey) {
            Write-ColorOutput "   ✅ Profile exists: $($user.name) ($($user.role))" "Green"
        } else {
            Write-ColorOutput "   ⚠️  Profile check failed" "Yellow"
        }
    } else {
        if ($result.error -like "*already registered*") {
            Write-ColorOutput "   ⚠️  User already exists: $($user.email)" "Yellow"
        } else {
            Write-ColorOutput "   ❌ Failed to create $($user.email): $($result.error)" "Red"
            $errorCount++
        }
    }
    
    Write-Host ""
}

# Summary
Write-ColorOutput "📊 Summary:" "Cyan"
Write-ColorOutput "   ✅ Successful: $successCount" "Green"
Write-ColorOutput "   ❌ Failed: $errorCount" "Red"
Write-ColorOutput "   📧 Total users: $($DEMO_USERS.Count)" "White"

if ($successCount -gt 0) {
    Write-Host ""
    Write-ColorOutput "🎉 Demo users created successfully!" "Green"
    Write-Host ""
    Write-ColorOutput "📝 Login credentials:" "Cyan"
    foreach ($user in $DEMO_USERS) {
        Write-Host "   $($user.role.ToUpper()): $($user.email) / $($user.password)"
    }
    
    Write-Host ""
    Write-ColorOutput "🔗 You can now test the platform at:" "Cyan"
    $loginUrl = $SupabaseUrl -replace "/rest/v1", ""
    Write-Host "   ${loginUrl}/auth/login"
}

if ($errorCount -gt 0) {
    Write-Host ""
    Write-ColorOutput "⚠️  Some users failed to create. Check the logs above for details." "Yellow"
    exit 1
}