# Authentication Setup Guide

## Overview

This guide explains how to set up working authentication for the LightBus E-Learning Platform. The platform uses Supabase Auth for user management and requires proper setup of demo users for testing.

## The Authentication Problem

The platform creates sample **profiles** but not actual **Supabase Auth users**. This means:

- ❌ Users exist in `profiles` table but not in `auth.users`
- ❌ No passwords are set for authentication
- ❌ Login attempts fail with "Invalid login credentials"

## Solutions

### Option 1: Automated Demo User Creation (Recommended)

Use the provided scripts to create working demo users with proper authentication.

#### PowerShell (Windows)
```powershell
# Set environment variables
$env:SUPABASE_URL = "https://your-project.supabase.co/rest/v1"
$env:SUPABASE_SERVICE_ROLE_KEY = "your-service-role-key"

# Run the script
.\scripts\create-demo-users.ps1
```

#### Node.js (Cross-platform)
```bash
# Set environment variables
export SUPABASE_URL="https://your-project.supabase.co/rest/v1"
export SUPABASE_SERVICE_ROLE_KEY="your-service-role-key"

# Install dependencies (if needed)
npm install @supabase/supabase-js

# Run the script
node scripts/create-demo-users.js
```

#### Command Line Arguments
```powershell
# PowerShell
.\scripts\create-demo-users.ps1 -SupabaseUrl "your_url" -ServiceRoleKey "your_key"
```

```bash
# Node.js
node scripts/create-demo-users.js "your_url" "your_key"
```

### Option 2: Manual User Creation

#### Via Supabase Dashboard

1. **Open Supabase Dashboard**
   - Go to [supabase.com](https://supabase.com)
   - Navigate to your project
   - Go to Authentication > Users

2. **Create Demo Teacher**
   - Click "Add user"
   - Email: `demo.teacher@lightbus.edu`
   - Password: `demo123456`
   - Email confirmed: ✅ Yes
   - User metadata:
     ```json
     {
       "name": "Demo Teacher",
       "role": "teacher"
     }
     ```

3. **Create Demo Student**
   - Click "Add user"
   - Email: `demo.student@lightbus.edu`
   - Password: `demo123456`
   - Email confirmed: ✅ Yes
   - User metadata:
     ```json
     {
       "name": "Demo Student", 
       "role": "student"
     }
     ```

4. **Create Additional Students** (Optional)
   - Email: `alex.student@lightbus.edu`
   - Email: `jamie.learner@lightbus.edu`
   - Same password and metadata pattern

#### Via Supabase API (cURL)

```bash
# Set variables
SUPABASE_URL="https://your-project.supabase.co"
SERVICE_KEY="your-service-role-key"

# Create demo teacher
curl -X POST "$SUPABASE_URL/auth/v1/admin/users" \
  -H "apikey: $SERVICE_KEY" \
  -H "Authorization: Bearer $SERVICE_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "demo.teacher@lightbus.edu",
    "password": "demo123456",
    "email_confirm": true,
    "user_metadata": {
      "name": "Demo Teacher",
      "role": "teacher"
    }
  }'

# Create demo student
curl -X POST "$SUPABASE_URL/auth/v1/admin/users" \
  -H "apikey: $SERVICE_KEY" \
  -H "Authorization: Bearer $SERVICE_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "demo.student@lightbus.edu", 
    "password": "demo123456",
    "email_confirm": true,
    "user_metadata": {
      "name": "Demo Student",
      "role": "student"
    }
  }'
```

## Demo Credentials

After setup, use these credentials to test the platform:

| Role | Email | Password |
|------|-------|----------|
| **Teacher** | `demo.teacher@lightbus.edu` | `demo123456` |
| **Student** | `demo.student@lightbus.edu` | `demo123456` |
| **Student** | `alex.student@lightbus.edu` | `demo123456` |
| **Student** | `jamie.learner@lightbus.edu` | `demo123456` |

## Verification Steps

### 1. Check User Creation
```sql
-- In Supabase SQL Editor
SELECT id, email, created_at, email_confirmed_at 
FROM auth.users 
WHERE email LIKE '%@lightbus.edu';
```

### 2. Check Profile Creation
```sql
-- Profiles should be created automatically via trigger
SELECT id, name, email, role, created_at 
FROM public.profiles 
WHERE email LIKE '%@lightbus.edu';
```

### 3. Test Login
1. Navigate to `/auth/login`
2. Use demo credentials
3. Should redirect to appropriate dashboard
4. Check that user role is detected correctly

### 4. Test User Flow
- **Student**: Should see study dashboard with lessons and cards
- **Teacher**: Should see teacher dashboard with lesson management
- **Profile**: Should display correct name and role

## Troubleshooting

### "Invalid login credentials" Error
- ✅ Verify users exist in Supabase Auth dashboard
- ✅ Check email is confirmed
- ✅ Verify password is correct
- ✅ Ensure SUPABASE_URL and SUPABASE_ANON_KEY are correct

### "User not authorized" Error
- ✅ Check Row Level Security policies
- ✅ Verify profile was created with correct user ID
- ✅ Ensure user metadata includes role

### Profile Not Created
- ✅ Check if `handle_new_user()` trigger exists
- ✅ Verify trigger is enabled on `auth.users`
- ✅ Check for trigger execution errors in logs

### Scripts Fail to Run
- ✅ Verify service role key has admin permissions
- ✅ Check network connectivity to Supabase
- ✅ Ensure Node.js/PowerShell has required permissions

## Security Notes

### For Development
- ✅ Use demo credentials for testing only
- ✅ Service role key should be kept secure
- ✅ Don't commit service keys to version control

### For Production  
- ❌ Remove or disable demo users
- ❌ Change default passwords
- ✅ Implement proper user registration flow
- ✅ Add email verification requirements
- ✅ Set up proper user roles and permissions

## Advanced Setup

### Custom User Creation Script
```javascript
// Create your own users programmatically
const { createClient } = require('@supabase/supabase-js')

const supabase = createClient(
  process.env.SUPABASE_URL, 
  process.env.SUPABASE_SERVICE_ROLE_KEY,
  { auth: { autoRefreshToken: false, persistSession: false } }
)

async function createUser(email, password, metadata) {
  const { data, error } = await supabase.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    user_metadata: metadata
  })
  
  if (error) throw error
  return data.user
}
```

### Bulk User Import
```sql
-- For importing many users, create a SQL function
CREATE OR REPLACE FUNCTION create_mock_user(
  user_email TEXT,
  user_name TEXT,
  user_role TEXT
) RETURNS UUID AS $$
DECLARE
  new_user_id UUID := gen_random_uuid();
BEGIN
  -- Insert profile (auth user must be created separately via API)
  INSERT INTO public.profiles (id, name, email, role)
  VALUES (new_user_id, user_name, user_email, user_role);
  
  RETURN new_user_id;
END;
$$ LANGUAGE plpgsql;
```

## Next Steps

1. **Run demo user creation script**
2. **Test authentication flow** 
3. **Verify all user roles work correctly**
4. **Proceed with platform testing**
5. **Set up production authentication** when deploying

For additional help, see:
- [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md)
- [DEVELOPER_GUIDE.md](./DEVELOPER_GUIDE.md)
- [Supabase Auth Documentation](https://supabase.com/docs/guides/auth)