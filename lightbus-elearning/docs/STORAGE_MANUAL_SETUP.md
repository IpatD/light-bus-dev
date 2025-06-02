# Storage Manual Setup Instructions - LightBus E-Learning

## 🚨 **CRITICAL: Manual RLS Setup Required**

**Date:** January 6, 2025  
**Issue:** Migration cannot enable RLS due to permission restrictions  
**Status:** 🔴 Requires Manual Intervention  
**Priority:** HIGH - Blocks storage functionality

---

## 📋 **Problem Summary**

The storage migration `007_storage_policies.sql` was updated to **remove the problematic RLS ALTER command** that requires superuser permissions:

```sql
-- This command was REMOVED from migration due to permissions error:
-- ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;
-- Error: "must be owner of table objects (SQLSTATE 42501)"
```

**What works automatically:**
- ✅ Storage buckets creation (`lesson-media`, `user-uploads`, `media`)
- ✅ Storage policies creation (all RLS policies)
- ✅ Helper functions and indexes

**What requires manual setup:**
- ❌ Enabling RLS on `storage.objects` table
- ❌ Verification of policy activation

---

## 🛠️ **Manual Setup Instructions**

### **Step 1: Run the Fixed Migration**

```powershell
# Navigate to project directory
cd lightbus-elearning

# Apply the corrected migration (without problematic RLS command)
npx supabase db push

# Verify migration applied successfully
npx supabase db diff --remote
```

### **Step 2: Enable RLS via Supabase Dashboard**

1. **Open Supabase Dashboard:**
   - Go to: https://supabase.com/dashboard
   - Select your project
   - Navigate to: **Database > Tables**

2. **Access Storage Schema:**
   - In the schema selector, choose: **`storage`**
   - Find the **`objects`** table
   - Click on the table name

3. **Enable Row Level Security:**
   - Click the **settings/gear icon** next to the table name
   - Look for **"Row Level Security"** section
   - **Enable RLS** by toggling the switch to ON
   - Confirm the action

   **Alternative SQL Method:**
   ```sql
   -- If you have direct SQL access with proper permissions:
   ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;
   ```

4. **Create Performance Indexes:**
   ```sql
   -- These indexes improve storage query performance
   -- Run in Supabase SQL Editor with admin permissions:
   CREATE INDEX IF NOT EXISTS idx_storage_objects_bucket_owner
   ON storage.objects (bucket_id, owner);
   
   CREATE INDEX IF NOT EXISTS idx_storage_objects_name
   ON storage.objects USING gin (name gin_trgm_ops);
   ```

### **Step 3: Verify RLS and Policies are Active**

Run this verification query in the Supabase SQL Editor:

```sql
-- Check if RLS is enabled on storage.objects
SELECT 
  schemaname,
  tablename,
  rowsecurity as rls_enabled
FROM pg_tables 
WHERE schemaname = 'storage' AND tablename = 'objects';

-- Expected result: rls_enabled should be 'true'
```

```sql
-- Verify storage policies were created
SELECT 
  policyname,
  cmd,
  permissive,
  roles,
  qual
FROM pg_policies 
WHERE schemaname = 'storage' AND tablename = 'objects'
ORDER BY policyname;

-- Expected: Should show all storage policies from migration
```

### **Step 4: Test Storage Functionality**

```powershell
# Start development server
npm run dev

# Test file upload at: http://localhost:3000/lessons/upload
```

**Test scenarios:**
1. **Teacher Upload Test:** Login as teacher → Upload lesson media
2. **Student Access Test:** Login as student → Access enrolled lesson files
3. **Permission Test:** Try accessing files from non-enrolled lessons (should fail)

---

## 🔍 **Verification Checklist**

- [ ] ✅ Migration `007_storage_policies.sql` applied without errors
- [ ] ✅ Storage buckets created (`lesson-media`, `user-uploads`, `media`)
- [ ] ✅ RLS manually enabled on `storage.objects` via dashboard
- [ ] ✅ Storage policies active (verified via SQL query)
- [ ] ✅ File upload functionality works
- [ ] ✅ Permission boundaries respected (students can't access others' files)

---

## 🚨 **Troubleshooting**

### **Issue: "Permission denied for table objects"**
```
Solution: RLS not properly enabled
1. Double-check RLS is ON via Supabase Dashboard
2. Refresh the page and try again
3. Verify policies exist with SQL query above
```

### **Issue: "Bucket does not exist"**
```
Solution: Migration didn't complete
1. Check migration status: npx supabase db diff --remote
2. Re-run migration: npx supabase db push
3. Verify buckets: SELECT * FROM storage.buckets;
```

### **Issue: "Upload fails despite RLS enabled"**
```
Solution: Check user authentication and roles
1. Verify user is logged in: auth.uid() returns value
2. Check user role: SELECT role FROM profiles WHERE id = auth.uid()
3. For teachers: Verify lesson ownership in database
```

### **Issue: "Policies not working"**
```
Solution: Policies may not be active
1. Disable and re-enable RLS via dashboard
2. Check policy syntax with: \d+ storage.objects in psql
3. Test with simplified policy first
```

---

## 📊 **Expected Database State After Setup**

### **Storage Buckets:**
```sql
SELECT name, public, file_size_limit FROM storage.buckets;

-- Expected output:
-- lesson-media | true  | 104857600
-- user-uploads | false | 52428800  
-- media        | true  | 104857600
```

### **Storage Policies:**
```sql
SELECT count(*) FROM pg_policies WHERE schemaname = 'storage';

-- Expected: 13+ policies (varies by exact migration content)
```

### **RLS Status:**
```sql
SELECT rowsecurity FROM pg_tables 
WHERE schemaname = 'storage' AND tablename = 'objects';

-- Expected: true
```

---

## 🎯 **Alternative Approach: Split Migration**

If manual RLS setup is not feasible, consider this alternative:

### **Option A: Database Admin Setup**
- Have database administrator run the RLS command directly
- Provide them with: `ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;`

### **Option B: Supabase CLI with Admin Credentials**
```powershell
# If you have admin access to Supabase CLI
npx supabase db reset --db-url "postgresql://admin:password@db.supabase.co:5432/postgres"
```

### **Option C: Post-Migration SQL Script**
Create a separate admin script:
```sql
-- File: scripts/enable-storage-rls.sql
-- Run this with admin credentials after migration
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;
```

---

## ✅ **Setup Complete Confirmation**

Once all steps are completed, you should see:

1. **No migration errors** when running `npx supabase db push`
2. **File upload works** in the application
3. **Proper access control** (students can't access unauthorized files)
4. **All verification queries return expected results**

---

## 📞 **Support**

If you encounter issues with this manual setup:

1. **Check Supabase Documentation:** https://supabase.com/docs/guides/storage
2. **Review RLS Documentation:** https://supabase.com/docs/guides/auth/row-level-security
3. **Contact your database administrator** for superuser-level commands

---

**🎉 Manual Storage Setup Complete!**  
*Once RLS is manually enabled, the LightBus E-Learning platform will have fully functional secure file storage.*