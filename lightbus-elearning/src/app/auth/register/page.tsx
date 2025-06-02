'use client'

import React, { useState } from 'react'
import { useRouter } from 'next/navigation'
import Link from 'next/link'
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { z } from 'zod'
import { supabase } from '@/lib/supabase'
import { SignUpData } from '@/types'
import Button from '@/components/ui/Button'
import Input from '@/components/ui/Input'
import Card from '@/components/ui/Card'

const registerSchema = z.object({
  name: z.string().min(2, 'Name must be at least 2 characters'),
  email: z.string().email('Please enter a valid email address'),
  password: z.string().min(8, 'Password must be at least 8 characters'),
  confirmPassword: z.string(),
  role: z.enum(['student', 'teacher'], {
    required_error: 'Please select a role',
  }),
}).refine((data) => data.password === data.confirmPassword, {
  message: "Passwords don't match",
  path: ["confirmPassword"],
})

type RegisterFormData = z.infer<typeof registerSchema>

export default function RegisterPage() {
  const [isLoading, setIsLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [success, setSuccess] = useState(false)
  const router = useRouter()

  const {
    register,
    handleSubmit,
    formState: { errors },
    watch,
  } = useForm<RegisterFormData>({
    resolver: zodResolver(registerSchema),
  })

  const onSubmit = async (data: RegisterFormData) => {
    setIsLoading(true)
    setError(null)

    try {
      const { data: authData, error: authError } = await supabase.auth.signUp({
        email: data.email,
        password: data.password,
        options: {
          data: {
            name: data.name,
            role: data.role,
          },
        },
      })

      if (authError) {
        throw authError
      }

      if (authData.user && !authData.session) {
        // Email confirmation required
        setSuccess(true)
      } else if (authData.session) {
        // User is signed in immediately
        router.push(data.role === 'teacher' ? '/dashboard/teacher' : '/dashboard/student')
      }
    } catch (err: any) {
      console.error('Registration error:', err)
      setError(err.message || 'An error occurred during registration')
    } finally {
      setIsLoading(false)
    }
  }

  if (success) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-learning-50 to-achievement-50 py-12 px-4 sm:px-6 lg:px-8">
        <div className="container-form">
          <Card variant="primary" padding="lg" className="text-center">
            <div className="mb-6">
              <div className="bg-green-100 text-green-600 w-16 h-16 mx-auto mb-4 flex items-center justify-center text-2xl">
                ✓
              </div>
              <h2 className="heading-3 mb-4">Check Your Email</h2>
              <p className="text-neutral-gray mb-6">
                We've sent you a confirmation link. Please check your email and click the link to activate your account.
              </p>
              <Link href="/auth/login">
                <Button variant="primary">
                  Return to Sign In
                </Button>
              </Link>
            </div>
          </Card>
        </div>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-learning-50 to-achievement-50 py-12 px-4 sm:px-6 lg:px-8">
      <div className="container-form">
        <div className="text-center mb-8">
          <h1 className="heading-2 mb-4">Join Light Bus</h1>
          <p className="body-medium text-neutral-gray">
            Start your journey to more effective learning
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
              label="Full Name"
              type="text"
              placeholder="Enter your full name"
              {...register('name')}
              error={errors.name?.message}
              required
            />

            <Input
              label="Email Address"
              type="email"
              placeholder="Enter your email"
              {...register('email')}
              error={errors.email?.message}
              required
            />

            <div>
              <label className="block text-sm font-semibold text-neutral-charcoal mb-2">
                I am a... <span className="text-red-500">*</span>
              </label>
              <div className="grid grid-cols-2 gap-4">
                <label className="flex items-center p-4 border-2 border-neutral-gray hover:border-learning-500 cursor-pointer transition-colors">
                  <input
                    type="radio"
                    value="student"
                    {...register('role')}
                    className="sr-only"
                  />
                  <div className={`w-full text-center ${watch('role') === 'student' ? 'text-learning-500 font-semibold' : 'text-neutral-gray'}`}>
                    <div className="text-2xl mb-2">🎓</div>
                    <div>Student</div>
                    <div className="text-xs">Learn and study</div>
                  </div>
                </label>
                
                <label className="flex items-center p-4 border-2 border-neutral-gray hover:border-teacher-500 cursor-pointer transition-colors">
                  <input
                    type="radio"
                    value="teacher"
                    {...register('role')}
                    className="sr-only"
                  />
                  <div className={`w-full text-center ${watch('role') === 'teacher' ? 'text-teacher-500 font-semibold' : 'text-neutral-gray'}`}>
                    <div className="text-2xl mb-2">👨‍🏫</div>
                    <div>Teacher</div>
                    <div className="text-xs">Create and manage</div>
                  </div>
                </label>
              </div>
              {errors.role && (
                <p className="mt-2 text-sm text-red-600 font-medium">
                  {errors.role.message}
                </p>
              )}
            </div>

            <Input
              label="Password"
              type="password"
              placeholder="Create a strong password"
              {...register('password')}
              error={errors.password?.message}
              required
            />

            <Input
              label="Confirm Password"
              type="password"
              placeholder="Confirm your password"
              {...register('confirmPassword')}
              error={errors.confirmPassword?.message}
              required
            />

            <Button
              type="submit"
              variant="primary"
              size="lg"
              loading={isLoading}
              className="w-full"
            >
              Create Account
            </Button>
          </form>

          <div className="mt-6 pt-6 border-t-2 border-neutral-gray border-opacity-20 text-center">
            <p className="text-neutral-gray">
              Already have an account?{' '}
              <Link href="/auth/login" className="text-learning-500 hover:text-learning-600 font-semibold">
                Sign in here
              </Link>
            </p>
          </div>
        </Card>

        <div className="mt-8 text-center text-sm text-neutral-gray">
          By creating an account, you agree to our{' '}
          <Link href="/terms" className="text-learning-500 hover:text-learning-600">
            Terms of Service
          </Link>{' '}
          and{' '}
          <Link href="/privacy" className="text-learning-500 hover:text-learning-600">
            Privacy Policy
          </Link>
        </div>
      </div>
    </div>
  )
}