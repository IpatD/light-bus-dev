# Supabase Migration Deployment Commands

## Step 1: Navigate to project directory
```powershell
cd lightbus-elearning
```

## Step 2: Check Supabase status and login (if needed)
```powershell
supabase status
supabase login
```

## Step 3: Deploy the migration
```powershell
supabase db push
```

**OR** if you want to apply specific migration:
```powershell
supabase migration up
```

## Step 4: Verify migration was applied
```powershell
supabase db diff
```

## Alternative: Direct SQL execution (if migration files don't work)
```powershell
# Execute the main migration
Get-Content "supabase/migrations/035_fix_date_discrepancies_comprehensive.sql" | supabase db sql

# Execute diagnostic tools
Get-Content "debug_date_discrepancies.sql" | supabase db sql

# Execute test suite
Get-Content "test_date_discrepancies.sql" | supabase db sql
```

## Quick Test Commands (after deployment)
```powershell
# Test the fix with a sample query in Supabase SQL Editor
# Or run via CLI:
echo "SELECT * FROM generate_date_discrepancy_report();" | supabase db sql
```

## Summary Commands to Run:
```powershell
cd lightbus-elearning
supabase login
supabase db push
supabase status
```

## If you encounter permission issues:
```powershell
# Reset and reapply all migrations
supabase db reset --linked
```

## Verify the fix worked:
After deployment, check the dashboard to see if date discrepancies are resolved.