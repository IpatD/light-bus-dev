# Scripts Directory

This directory contains utility scripts for managing the LightBus E-Learning Platform.

## Authentication Scripts

### Demo User Creation
Creates working Supabase Auth users for testing the platform.

**PowerShell (Windows):**
```powershell
.\scripts\create-demo-users.ps1
```

**Node.js (Cross-platform):**
```bash
node scripts/create-demo-users.js
```

**NPM Scripts:**
```bash
npm run auth:create-demo-users     # Node.js version
npm run auth:create-demo-users:ps  # PowerShell version
npm run auth:setup                 # Create + verify
```

### Authentication Verification
Verifies that authentication is working correctly.

```powershell
.\scripts\verify-auth.ps1
npm run auth:verify
```

## Deployment Scripts

### Production Deployment
```powershell
.\scripts\deploy.ps1
npm run deploy:production
```

### Deployment Verification
```powershell
.\scripts\verify-deployment.ps1
npm run deploy:verify
```

## Environment Variables Required

```bash
SUPABASE_URL="https://your-project.supabase.co/rest/v1"
SUPABASE_SERVICE_ROLE_KEY="your-service-role-key"
SUPABASE_ANON_KEY="your-anon-key" # Optional for auth verification
```

## Quick Start

1. **Set up authentication:**
   ```bash
   npm run auth:setup
   ```

2. **Test login with demo credentials:**
   - Teacher: `demo.teacher@lightbus.edu` / `demo123456`
   - Student: `demo.student@lightbus.edu` / `demo123456`

3. **Deploy to production:**
   ```bash
   npm run deploy:production
   ```

For detailed instructions, see [docs/AUTHENTICATION_SETUP.md](../docs/AUTHENTICATION_SETUP.md)