#!/usr/bin/env node

/**
 * Demo User Creation Script for LightBus E-Learning Platform
 * 
 * This script creates actual Supabase Auth users for testing purposes.
 * It uses the Supabase Admin API to create users with passwords.
 * 
 * Usage:
 *   node scripts/create-demo-users.js
 * 
 * Requirements:
 *   - SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY environment variables
 *   - Or provide them as command line arguments
 */

const { createClient } = require('@supabase/supabase-js')

// Demo user configurations
const DEMO_USERS = [
  {
    email: 'demo.teacher@lightbus.edu',
    password: 'demo123456',
    name: 'Demo Teacher',
    role: 'teacher'
  },
  {
    email: 'demo.student@lightbus.edu', 
    password: 'demo123456',
    name: 'Demo Student',
    role: 'student'
  },
  {
    email: 'alex.student@lightbus.edu',
    password: 'demo123456', 
    name: 'Alex Student',
    role: 'student'
  },
  {
    email: 'jamie.learner@lightbus.edu',
    password: 'demo123456',
    name: 'Jamie Learner', 
    role: 'student'
  }
]

async function createDemoUsers() {
  // Get Supabase configuration
  const supabaseUrl = process.env.SUPABASE_URL || process.argv[2]
  const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY || process.argv[3]

  if (!supabaseUrl || !supabaseServiceKey) {
    console.error('❌ Missing Supabase configuration!')
    console.log('\nUsage:')
    console.log('  Environment variables:')
    console.log('    SUPABASE_URL=your_url SUPABASE_SERVICE_ROLE_KEY=your_key node scripts/create-demo-users.js')
    console.log('\n  Command line arguments:')
    console.log('    node scripts/create-demo-users.js <supabase_url> <service_role_key>')
    process.exit(1)
  }

  console.log('🚀 Creating demo users for LightBus E-Learning Platform...\n')

  // Create Supabase admin client
  const supabase = createClient(supabaseUrl, supabaseServiceKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false
    }
  })

  let successCount = 0
  let errorCount = 0

  for (const user of DEMO_USERS) {
    try {
      console.log(`👤 Creating user: ${user.email} (${user.role})`)
      
      // Create user with Supabase Auth
      const { data: authData, error: authError } = await supabase.auth.admin.createUser({
        email: user.email,
        password: user.password,
        email_confirm: true, // Auto-confirm email
        user_metadata: {
          name: user.name,
          role: user.role
        }
      })

      if (authError) {
        if (authError.message.includes('already registered')) {
          console.log(`   ⚠️  User already exists: ${user.email}`)
        } else {
          throw authError
        }
      } else {
        console.log(`   ✅ Created auth user: ${authData.user?.id}`)
        successCount++
      }

      // Verify profile was created by trigger
      const { data: profile, error: profileError } = await supabase
        .from('profiles')
        .select('*')
        .eq('email', user.email)
        .single()

      if (profileError) {
        console.log(`   ⚠️  Profile check failed: ${profileError.message}`)
      } else {
        console.log(`   ✅ Profile exists: ${profile.name} (${profile.role})`)
      }

    } catch (error) {
      console.log(`   ❌ Failed to create ${user.email}: ${error.message}`)
      errorCount++
    }
    
    console.log() // Empty line for readability
  }

  // Summary
  console.log('📊 Summary:')
  console.log(`   ✅ Successful: ${successCount}`)
  console.log(`   ❌ Failed: ${errorCount}`)
  console.log(`   📧 Total users: ${DEMO_USERS.length}`)

  if (successCount > 0) {
    console.log('\n🎉 Demo users created successfully!')
    console.log('\n📝 Login credentials:')
    DEMO_USERS.forEach(user => {
      console.log(`   ${user.role.toUpperCase()}: ${user.email} / ${user.password}`)
    })
    
    console.log('\n🔗 You can now test the platform at:')
    console.log(`   ${supabaseUrl.replace('/rest/v1', '')}/auth/login`)
  }

  if (errorCount > 0) {
    console.log('\n⚠️  Some users failed to create. Check the logs above for details.')
    process.exit(1)
  }
}

// Run the script
createDemoUsers().catch(error => {
  console.error('💥 Script failed:', error.message)
  process.exit(1)
})