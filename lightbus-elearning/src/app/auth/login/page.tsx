'use client'

import React, { useState } from 'react'
import { useRouter } from 'next/navigation'
import Link from 'next/link'
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { z } from 'zod'
import { supabase } from '@/lib/supabase'
import { SignInData } from '@/types'
import Button from '@/components/ui/Button'
import Input from '@/components/ui/Input'
import Card from '@/components/ui/Card'

const loginSchema = z.object({
  email: z.string().email('Please enter a valid email address'),
  password: z.string().min(1, 'Password is required'),
})

type LoginFormData = z.infer<typeof loginSchema>

export default function LoginPage() {
  const [isLoading, setIsLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const router = useRouter()

  const {
    register,
    handleSubmit,
    formState: { errors },
  } = useForm<LoginFormData>({
    resolver: zodResolver(loginSchema),
  })

  const onSubmit = async (data: LoginFormData) => {
    setIsLoading(true)
    setError(null)

    try {
      const { data: authData, error: authError } = await supabase.auth.signInWithPassword({
        email: data.email,
        password: data.password,
      })

      if (authError) {
        throw authError
      }

      if (authData.user) {
        // Get user role from metadata to redirect appropriately
        const role = authData.user.user_metadata?.role || 'student'
        router.push(role === 'teacher' ? '/dashboard/teacher' : '/dashboard/student')
      }
    } catch (err: any) {
      console.error('Login error:', err)
      if (err.message.includes('Invalid login credentials')) {
        setError('Invalid email or password. Please try again.')
      } else if (err.message.includes('Email not confirmed')) {
        setError('Please check your email and click the confirmation link before signing in.')
      } else {
        setError(err.message || 'An error occurred during sign in')
      }
    } finally {
      setIsLoading(false)
    }
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-learning-50 to-achievement-50 py-12 px-4 sm:px-6 lg:px-8">
      <div className="container-form">
        <div className="text-center mb-8">
          <h1 className="heading-2 mb-4">Welcome Back</h1>
          <p className="body-medium text-neutral-gray">
            Sign in to continue your learning journey
          </p>
        </div>

        <Card variant="default" padding="lg">
          <form onSubmit={handleSubmit(onSubmit)} className="space-y-6">
            {error && (
              <div className="status-error">
                {error}
              </div>
            )}

            <Input
              label="Email Address"
              type="email"
              placeholder="Enter your email"
              {...register('email')}
              error={errors.email?.message}
              required
            />

            <Input
              label="Password"
              type="password"
              placeholder="Enter your password"
              {...register('password')}
              error={errors.password?.message}
              required
            />

            <div className="flex items-center justify-between">
              <div className="flex items-center">
                <input
                  id="remember-me"
                  name="remember-me"
                  type="checkbox"
                  className="h-4 w-4 text-learning-500 focus:ring-learning-500 border-neutral-gray"
                />
                <label htmlFor="remember-me" className="ml-2 block text-sm text-neutral-gray">
                  Remember me
                </label>
              </div>

              <div className="text-sm">
                <Link
                  href="/auth/forgot-password"
                  className="text-learning-500 hover:text-learning-600 font-medium"
                >
                  Forgot your password?
                </Link>
              </div>
            </div>

            <Button
              type="submit"
              variant="primary"
              size="lg"
              loading={isLoading}
              className="w-full"
            >
              Sign In
            </Button>
          </form>

          <div className="mt-6 pt-6 border-t-2 border-neutral-gray border-opacity-20 text-center">
            <p className="text-neutral-gray">
              Don't have an account?{' '}
              <Link href="/auth/register" className="text-learning-500 hover:text-learning-600 font-semibold">
                Create one here
              </Link>
            </p>
          </div>
        </Card>

        {/* Demo Accounts */}
        <Card variant="default" padding="md" className="mt-6">
          <h3 className="font-semibold text-neutral-charcoal mb-3 text-center">Demo Accounts</h3>
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 text-sm">
            <div className="text-center p-3 bg-learning-50 border border-learning-200">
              <h4 className="font-semibold text-learning-600">Student Demo</h4>
              <p className="text-neutral-gray mt-1">
                Email: demo.student@lightbus.edu<br />
                Password: demo123456
              </p>
            </div>
            <div className="text-center p-3 bg-teacher-50 border border-teacher-200">
              <h4 className="font-semibold text-teacher-600">Teacher Demo</h4>
              <p className="text-neutral-gray mt-1">
                Email: demo.teacher@lightbus.edu<br />
                Password: demo123456
              </p>
            </div>
          </div>
        </Card>
      </div>
    </div>
  )
}