# 🚀 Light Bus - Quick Setup Guide

## Prerequisites

- **Node.js**: Version 18 or higher
- **npm**: Comes with Node.js
- **Supabase Account**: Sign up at [supabase.com](https://supabase.com) (free tier available)

## ⚡ Quick Start (5 minutes)

### 1. Install Dependencies
```bash
npm install
```

### 2. Create Supabase Project
1. Go to [supabase.com](https://supabase.com) and create a new project
2. Wait for the database to be ready (2-3 minutes)
3. Go to **Settings** → **API** to get your credentials

### 3. Set Up Environment Variables
```bash
cp .env.local.example .env.local
```

Edit `.env.local` with your Supabase credentials:
```env
NEXT_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=your-anon-key
```

### 4. Set Up Database Schema
1. Go to your Supabase dashboard
2. Click **SQL Editor**
3. Copy the entire content from `supabase/migrations/001_initial_schema.sql`
4. Paste and click **Run**

### 5. Start Development Server
```bash
npm run dev
```

🎉 **Done!** Open [http://localhost:3000](http://localhost:3000)

## 🧪 Test with Demo Accounts

### Student Account
- **Email**: demo.student@lightbus.edu
- **Password**: demo123456

### Teacher Account
- **Email**: demo.teacher@lightbus.edu
- **Password**: demo123456

## 🔧 Development Commands

```bash
# Development
npm run dev                    # Start dev server
npm run build                  # Build for production
npm run start                  # Start production server

# Code Quality
npm run lint                   # Run ESLint
npm run type-check             # Check TypeScript

# Database (if using local Supabase)
npm run supabase:start         # Start local Supabase
npm run supabase:stop          # Stop local Supabase
npm run supabase:migrate       # Apply migrations
```

## 🚨 Troubleshooting

### "Supabase client error"
- Check your `.env.local` file has correct values
- Ensure Supabase project is fully initialized
- Verify API keys are correct

### "Database connection error"
- Make sure you've run the SQL migration
- Check Supabase project status in dashboard

### "TypeScript errors"
- Run `npm run type-check` to see detailed errors
- Ensure all dependencies are installed

### "Styling not working"
- Clear browser cache
- Restart development server
- Check Tailwind CSS is properly configured

## 📚 Next Steps

1. **Register as Teacher**: Create a teacher account to explore lesson creation
2. **Register as Student**: Create a student account to see the learning interface
3. **Explore Components**: Check out the UI components in the browser
4. **Read Documentation**: See `README.md` for detailed information

## 🆘 Need Help?

- **Documentation**: Check the `docs/` folder
- **Issues**: Report on GitHub
- **Community**: Join our Discord (link in README)

Happy Learning! 🚌✨