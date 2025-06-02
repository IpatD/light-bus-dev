# JWT Metadata Parsing Fix - Quick Guide

## What to Upload to Supabase Dashboard

### 1. Main Fix (REQUIRED)
**File**: [`010_fix_jwt_metadata_syntax.sql`](lightbus-elearning/supabase/migrations/010_fix_jwt_metadata_syntax.sql)
- **Purpose**: Fixes the JWT metadata parsing syntax errors
- **Action**: Copy entire file content and paste into Supabase SQL Editor, then execute

### 2. Test Script (RECOMMENDED)
**File**: [`test-jwt-fixes.sql`](lightbus-elearning/scripts/test-jwt-fixes.sql)
- **Purpose**: Comprehensive testing of the JWT fixes
- **Action**: Run after applying the main fix to verify everything works

## Quick Steps

1. **Open Supabase Dashboard** → SQL Editor
2. **Copy content** from [`010_fix_jwt_metadata_syntax.sql`](lightbus-elearning/supabase/migrations/010_fix_jwt_metadata_syntax.sql)
3. **Paste and execute** in SQL Editor
4. **Copy content** from [`test-jwt-fixes.sql`](lightbus-elearning/scripts/test-jwt-fixes.sql)
5. **Paste and execute** to verify fixes work

## What This Fixes

- ❌ **Before**: `auth.jwt() ->> 'app_metadata' ->> 'role'` (INCORRECT)
- ✅ **After**: `auth.jwt() -> 'app_metadata' ->> 'role'` (CORRECT)

## Expected Results

All tests should return `result: TRUE` and no error messages.

## Key Functions Fixed

- [`is_admin_user()`](lightbus-elearning/supabase/migrations/010_fix_jwt_metadata_syntax.sql:10) - Admin role verification
- [`can_access_lesson()`](lightbus-elearning/supabase/migrations/010_fix_jwt_metadata_syntax.sql:52) - Lesson access permissions
- [`get_user_role()`](lightbus-elearning/supabase/migrations/010_fix_jwt_metadata_syntax.sql:30) - User role retrieval

---

**Files Ready**: 3 files created for JWT metadata parsing fix  
**Status**: Ready to apply in Supabase dashboard  
**Priority**: Medium (fixes admin and lesson access functionality)