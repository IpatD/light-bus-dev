# Supabase SQL Editor - Clean SQL Instructions

## Problem Solved
- Removed all `\echo` commands (psql-specific) that cause syntax errors in Supabase SQL Editor
- Created clean, copy-paste ready SQL files for Supabase dashboard

## Files Created

### 1. Clean Migration File
**File:** [`scripts/migration-jwt-clean.sql`](../scripts/migration-jwt-clean.sql)
- Complete JWT metadata parsing fix
- Ready to copy-paste into Supabase SQL Editor
- No psql-specific commands

### 2. Step-by-Step Test File
**File:** [`scripts/test-jwt-step-by-step.sql`](../scripts/test-jwt-step-by-step.sql)
- Individual test queries with clear sections
- Copy each query separately to see individual results
- **RECOMMENDED FOR TESTING**

### 3. Simple Quick Test
**File:** [`scripts/test-jwt-simple.sql`](../scripts/test-jwt-simple.sql)
- Basic verification that functions work
- Minimal test for quick check

### 4. Complete Test File (Clean)
**File:** [`scripts/test-jwt-fixes-clean.sql`](../scripts/test-jwt-fixes-clean.sql)
- All tests in one file (will only show last result)
- Use if you want to run everything at once

## How to Use in Supabase SQL Editor

### Step 1: Apply Migration
1. Open Supabase Dashboard → SQL Editor
2. Copy content from [`scripts/migration-jwt-clean.sql`](../scripts/migration-jwt-clean.sql)
3. Paste and run
4. Should execute without syntax errors

### Step 2: Test Individual Queries
1. Open [`scripts/test-jwt-step-by-step.sql`](../scripts/test-jwt-step-by-step.sql)
2. Copy **one section at a time** (between the `==` lines)
3. Paste into Supabase SQL Editor
4. Run each query individually to see results
5. Look for `result = TRUE` in output

### Step 3: Verify Success
Each test should return:
- `result = TRUE` (function works)
- `result = FALSE` (function has issues)

## Example Usage

```sql
-- Copy this query first:
SELECT * FROM public.test_jwt_functions();

-- Then copy this query:
SELECT 
    'JWT Data Available' as test_name,
    CASE 
        WHEN auth.jwt() IS NOT NULL THEN 'TRUE'
        ELSE 'FALSE'
    END as result;

-- Continue with each section...
```

## Why Individual Queries?

Supabase SQL Editor executes each SELECT statement separately and only shows the result of the **last** query. That's why you only saw the final message before. By running queries individually, you can see each test result.

## Expected Results

### Successful Output Examples:
```
test_name: "JWT data access"
result: true
error_message: ""
additional_info: "JWT data available"
```

### Problem Output Examples:
```
test_name: "JWT data access"
result: false
error_message: "operator does not exist: text ->> unknown"
additional_info: ""
```

## Troubleshooting

1. **Syntax Error**: Use clean files - no `\echo` commands
2. **Only Last Result Shows**: Run queries individually from step-by-step file
3. **Function Not Found**: Apply migration first
4. **Permission Denied**: User needs to be authenticated in Supabase

## Quick Start Commands

1. **Apply Migration:**
   ```sql
   -- Copy entire content from scripts/migration-jwt-clean.sql
   ```

2. **Quick Test:**
   ```sql
   SELECT * FROM public.test_jwt_functions();
   ```

3. **Individual Function Test:**
   ```sql
   SELECT public.is_admin_user() as admin_status;
   SELECT public.get_user_role() as user_role;
   ```

## File Summary

| File | Purpose | Usage |
|------|---------|--------|
| `migration-jwt-clean.sql` | Apply fixes | Copy all → Run once |
| `test-jwt-step-by-step.sql` | Detailed testing | Copy sections → Run individually |
| `test-jwt-simple.sql` | Quick verification | Copy all → Run once |
| `test-jwt-fixes-clean.sql` | Complete test suite | Copy all → Run once (shows last result only) |

The key insight: **Supabase SQL Editor shows only the last SELECT result**, so use the step-by-step file for detailed testing!