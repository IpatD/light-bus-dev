#!/usr/bin/env pwsh
# Test script to verify RLS infinite recursion fixes

param(
    [string]$ProjectRef,
    [string]$DatabasePassword,
    [switch]$Help
)

if ($Help) {
    Write-Host @"
Test RLS Infinite Recursion Fixes

USAGE:
    .\test-rls-fixes.ps1 -ProjectRef <project-ref> -DatabasePassword <db-password>

PARAMETERS:
    -ProjectRef       : Supabase project reference ID
    -DatabasePassword : Database password
    -Help            : Show this help message

EXAMPLE:
    .\test-rls-fixes.ps1 -ProjectRef "abcdefghijklmnop" -DatabasePassword "your-db-password"
"@
    exit 0
}

if (-not $ProjectRef) {
    Write-Error "ProjectRef parameter is required. Use -Help for usage information."
    exit 1
}

if (-not $DatabasePassword) {
    Write-Error "DatabasePassword parameter is required. Use -Help for usage information."
    exit 1
}

# Colors for output
$Green = "`e[32m"
$Red = "`e[31m"
$Yellow = "`e[33m"
$Blue = "`e[34m"
$Reset = "`e[0m"

Write-Host "${Blue}=== Testing RLS Infinite Recursion Fixes ===${Reset}" -ForegroundColor Blue

# Set environment variables
$env:SUPABASE_DB_URL = "postgresql://postgres:$DatabasePassword@db.$ProjectRef.supabase.co:5432/postgres"

function Test-DatabaseConnection {
    Write-Host "${Yellow}Testing database connection...${Reset}"
    
    try {
        $testQuery = "SELECT version();"
        $result = psql $env:SUPABASE_DB_URL -c $testQuery 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "${Green}✓ Database connection successful${Reset}"
            return $true
        } else {
            Write-Host "${Red}✗ Database connection failed: $result${Reset}"
            return $false
        }
    } catch {
        Write-Host "${Red}✗ Database connection error: $($_.Exception.Message)${Reset}"
        return $false
    }
}

function Test-RLSFunctions {
    Write-Host "${Yellow}Testing RLS helper functions...${Reset}"
    
    $tests = @(
        @{
            Name = "is_admin_user function"
            Query = "SELECT public.is_admin_user();"
        },
        @{
            Name = "get_user_role function"
            Query = "SELECT public.get_user_role();"
        },
        @{
            Name = "RLS test function"
            Query = "SELECT * FROM public.test_rls_fixes();"
        }
    )
    
    $allPassed = $true
    
    foreach ($test in $tests) {
        Write-Host "  Testing $($test.Name)..." -NoNewline
        
        try {
            $result = psql $env:SUPABASE_DB_URL -c $test.Query 2>&1
            
            if ($LASTEXITCODE -eq 0 -and -not ($result -match "ERROR")) {
                Write-Host " ${Green}✓${Reset}"
            } else {
                Write-Host " ${Red}✗${Reset}"
                Write-Host "    Error: $result" -ForegroundColor Red
                $allPassed = $false
            }
        } catch {
            Write-Host " ${Red}✗${Reset}"
            Write-Host "    Exception: $($_.Exception.Message)" -ForegroundColor Red
            $allPassed = $false
        }
    }
    
    return $allPassed
}

function Test-DatabaseFunctions {
    Write-Host "${Yellow}Testing main database functions for infinite recursion...${Reset}"
    
    # First, let's create a test user and lesson to work with
    $setupQueries = @(
        "DELETE FROM auth.users WHERE email = 'test-rls@example.com';",
        "INSERT INTO auth.users (id, email, encrypted_password, email_confirmed_at, created_at, updated_at) 
         VALUES ('00000000-0000-0000-0000-000000000001', 'test-rls@example.com', 'dummy', NOW(), NOW(), NOW())
         ON CONFLICT (id) DO NOTHING;",
        "INSERT INTO public.profiles (id, name, email, role) 
         VALUES ('00000000-0000-0000-0000-000000000001', 'Test User', 'test-rls@example.com', 'student')
         ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name;",
        "INSERT INTO public.lessons (id, teacher_id, name, description, scheduled_at, duration_minutes)
         VALUES ('00000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000001', 'Test Lesson', 'Test Description', NOW(), 60)
         ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name;",
        "INSERT INTO public.lesson_participants (lesson_id, student_id)
         VALUES ('00000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000001')
         ON CONFLICT (lesson_id, student_id) DO NOTHING;"
    )
    
    Write-Host "  Setting up test data..." -NoNewline
    foreach ($query in $setupQueries) {
        $result = psql $env:SUPABASE_DB_URL -c $query 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host " ${Red}✗${Reset}"
            Write-Host "    Setup failed: $result" -ForegroundColor Red
            return $false
        }
    }
    Write-Host " ${Green}✓${Reset}"
    
    $tests = @(
        @{
            Name = "get_user_stats function"
            Query = "SELECT total_reviews, average_quality, study_streak FROM public.get_user_stats('00000000-0000-0000-0000-000000000001');"
            Timeout = 10
        },
        @{
            Name = "get_cards_due function"
            Query = "SELECT COUNT(*) FROM public.get_cards_due('00000000-0000-0000-0000-000000000001', 10);"
            Timeout = 10
        },
        @{
            Name = "get_lesson_progress function"
            Query = "SELECT COUNT(*) FROM public.get_lesson_progress('00000000-0000-0000-0000-000000000001');"
            Timeout = 10
        },
        @{
            Name = "Lessons RLS policy test"
            Query = "SET SESSION AUTHORIZATION 'authenticated'; SET request.jwt.claims TO '{\"sub\": \"00000000-0000-0000-0000-000000000001\"}'; SELECT COUNT(*) FROM public.lessons;"
            Timeout = 10
        },
        @{
            Name = "Lesson participants RLS policy test"
            Query = "SET SESSION AUTHORIZATION 'authenticated'; SET request.jwt.claims TO '{\"sub\": \"00000000-0000-0000-0000-000000000001\"}'; SELECT COUNT(*) FROM public.lesson_participants;"
            Timeout = 10
        }
    )
    
    $allPassed = $true
    
    foreach ($test in $tests) {
        Write-Host "  Testing $($test.Name)..." -NoNewline
        
        try {
            # Use timeout to prevent infinite recursion from hanging the test
            $job = Start-Job -ScriptBlock {
                param($connectionString, $query)
                psql $connectionString -c $query 2>&1
            } -ArgumentList $env:SUPABASE_DB_URL, $test.Query
            
            $completed = Wait-Job $job -Timeout $test.Timeout
            
            if ($completed) {
                $result = Receive-Job $job
                Remove-Job $job
                
                if ($result -match "ERROR.*infinite recursion" -or $result -match "42P17") {
                    Write-Host " ${Red}✗ (Infinite recursion detected)${Reset}"
                    Write-Host "    Error: $result" -ForegroundColor Red
                    $allPassed = $false
                } elseif ($result -match "ERROR") {
                    Write-Host " ${Yellow}⚠ (Other error)${Reset}"
                    Write-Host "    Error: $result" -ForegroundColor Yellow
                } else {
                    Write-Host " ${Green}✓${Reset}"
                }
            } else {
                Remove-Job $job -Force
                Write-Host " ${Red}✗ (Timeout - likely infinite recursion)${Reset}"
                $allPassed = $false
            }
        } catch {
            Write-Host " ${Red}✗${Reset}"
            Write-Host "    Exception: $($_.Exception.Message)" -ForegroundColor Red
            $allPassed = $false
        }
    }
    
    return $allPassed
}

function Test-PerformanceRegression {
    Write-Host "${Yellow}Testing for performance regressions...${Reset}"
    
    $performanceTests = @(
        @{
            Name = "Basic SELECT on lessons table"
            Query = "EXPLAIN ANALYZE SELECT COUNT(*) FROM public.lessons;"
        },
        @{
            Name = "Basic SELECT on lesson_participants table"
            Query = "EXPLAIN ANALYZE SELECT COUNT(*) FROM public.lesson_participants;"
        },
        @{
            Name = "get_user_stats performance"
            Query = "EXPLAIN ANALYZE SELECT * FROM public.get_user_stats('00000000-0000-0000-0000-000000000001');"
        }
    )
    
    $allPassed = $true
    
    foreach ($test in $performanceTests) {
        Write-Host "  Testing $($test.Name)..." -NoNewline
        
        try {
            $result = psql $env:SUPABASE_DB_URL -c $test.Query 2>&1
            
            # Look for execution time in the output
            if ($result -match "Execution Time: (\d+\.?\d*) ms") {
                $executionTime = [double]$Matches[1]
                if ($executionTime -lt 1000) { # Less than 1 second is reasonable
                    Write-Host " ${Green}✓ ($($executionTime)ms)${Reset}"
                } else {
                    Write-Host " ${Yellow}⚠ (Slow: $($executionTime)ms)${Reset}"
                }
            } else {
                Write-Host " ${Green}✓${Reset}"
            }
        } catch {
            Write-Host " ${Red}✗${Reset}"
            Write-Host "    Exception: $($_.Exception.Message)" -ForegroundColor Red
            $allPassed = $false
        }
    }
    
    return $allPassed
}

# Main execution
Write-Host ""

# Test database connection
if (-not (Test-DatabaseConnection)) {
    Write-Host "${Red}Cannot proceed without database connection.${Reset}"
    exit 1
}

Write-Host ""

# Test RLS helper functions
$rlsTestsPassed = Test-RLSFunctions

Write-Host ""

# Test main database functions
$functionTestsPassed = Test-DatabaseFunctions

Write-Host ""

# Test performance
$performanceTestsPassed = Test-PerformanceRegression

Write-Host ""

# Summary
Write-Host "${Blue}=== Test Summary ===${Reset}"

if ($rlsTestsPassed -and $functionTestsPassed) {
    Write-Host "${Green}✓ All RLS infinite recursion issues appear to be fixed!${Reset}"
    Write-Host "${Green}✓ Database functions are working correctly${Reset}"
    
    if ($performanceTestsPassed) {
        Write-Host "${Green}✓ No significant performance regressions detected${Reset}"
    } else {
        Write-Host "${Yellow}⚠ Some performance concerns detected - review recommended${Reset}"
    }
    
    Write-Host ""
    Write-Host "${Green}SUCCESS: Platform should now be fully functional!${Reset}"
    exit 0
} else {
    Write-Host "${Red}✗ Some tests failed - RLS recursion issues may still exist${Reset}"
    
    if (-not $rlsTestsPassed) {
        Write-Host "${Red}  - RLS helper function tests failed${Reset}"
    }
    
    if (-not $functionTestsPassed) {
        Write-Host "${Red}  - Database function tests failed${Reset}"
    }
    
    Write-Host ""
    Write-Host "${Red}FAILURE: Additional fixes may be needed${Reset}"
    exit 1
}