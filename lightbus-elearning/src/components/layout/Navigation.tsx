'use client'

import React, { useState, useEffect } from 'react'
import Link from 'next/link'
import { useRouter, usePathname } from 'next/navigation'
import { User } from '@/types'
import { getCurrentUser, signOut } from '@/lib/supabase'
import Button from '../ui/Button'

const Navigation: React.FC = () => {
  const [user, setUser] = useState<User | null>(null)
  const [isLoading, setIsLoading] = useState(true)
  const [isMobileMenuOpen, setIsMobileMenuOpen] = useState(false)
  const router = useRouter()
  const pathname = usePathname()

  useEffect(() => {
    const fetchUser = async () => {
      try {
        const currentUser = await getCurrentUser()
        if (currentUser) {
          // In a real app, you'd fetch the user profile from your profiles table
          // For now, we'll use the auth user data
          setUser({
            id: currentUser.id,
            email: currentUser.email || '',
            name: currentUser.user_metadata?.name || currentUser.email?.split('@')[0] || 'User',
            role: currentUser.user_metadata?.role || 'student',
            created_at: currentUser.created_at,
            updated_at: currentUser.updated_at || currentUser.created_at,
          })
        }
      } catch (error) {
        console.error('Error fetching user:', error)
      } finally {
        setIsLoading(false)
      }
    }

    fetchUser()
  }, [])

  const handleSignOut = async () => {
    try {
      await signOut()
      setUser(null)
      router.push('/')
    } catch (error) {
      console.error('Error signing out:', error)
    }
  }

  const navLinks = user ? [
    {
      label: 'Dashboard',
      href: user.role === 'teacher' ? '/dashboard/teacher' : '/dashboard/student',
      roles: ['student', 'teacher', 'admin'],
    },
    ...(user.role === 'teacher' ? [
      { label: 'My Lessons', href: '/lessons', roles: ['teacher'] },
      { label: 'Create Lesson', href: '/lessons/create', roles: ['teacher'] },
    ] : []),
    ...(user.role === 'student' ? [
      { label: 'Study', href: '/study', roles: ['student'] },
      { label: 'My Progress', href: '/progress', roles: ['student'] },
    ] : []),
    ...(user.role === 'admin' ? [
      { label: 'Admin Panel', href: '/admin', roles: ['admin'] },
    ] : []),
  ] : []

  const isLinkActive = (href: string) => {
    return pathname === href || pathname.startsWith(href + '/')
  }

  if (isLoading) {
    return (
      <nav className="nav-header">
        <div className="container-main">
          <div className="flex items-center justify-between h-16">
            <div className="flex items-center">
              <Link href="/" className="text-2xl font-bold text-white">
                🚌 Light Bus
              </Link>
            </div>
            <div className="animate-pulse flex space-x-4">
              <div className="h-4 bg-neutral-gray bg-opacity-20 w-16"></div>
              <div className="h-4 bg-neutral-gray bg-opacity-20 w-16"></div>
            </div>
          </div>
        </div>
      </nav>
    )
  }

  return (
    <nav className="nav-header">
      <div className="container-main">
        <div className="flex items-center justify-between h-16">
          {/* Logo */}
          <div className="flex items-center">
            <Link href="/" className="text-2xl font-bold text-white hover:text-achievement-500 transition-colors">
              🚌 Light Bus
            </Link>
          </div>

          {/* Desktop Navigation */}
          <div className="hidden md:block">
            <div className="ml-10 flex items-baseline space-x-4">
              {user ? (
                <>
                  {navLinks
                    .filter(link => link.roles.includes(user.role))
                    .map((link) => (
                      <Link
                        key={link.href}
                        href={link.href}
                        className={`nav-link px-3 py-2 text-sm font-medium ${
                          isLinkActive(link.href) ? 'active' : ''
                        }`}
                      >
                        {link.label}
                      </Link>
                    ))}
                  
                  {/* User Menu */}
                  <div className="ml-4 flex items-center space-x-4">
                    <span className="text-white text-sm">
                      Hello, <span className="font-semibold">{user.name}</span>
                    </span>
                    <span className={`
                      px-2 py-1 text-xs font-semibold text-white
                      ${user.role === 'teacher' ? 'bg-teacher-500' : 
                        user.role === 'admin' ? 'bg-purple-500' : 'bg-learning-500'}
                    `}>
                      {user.role.toUpperCase()}
                    </span>
                    <Button
                      variant="ghost"
                      size="sm"
                      onClick={handleSignOut}
                      className="text-white border-white hover:bg-white hover:text-neutral-charcoal"
                    >
                      Sign Out
                    </Button>
                  </div>
                </>
              ) : (
                <div className="flex items-center space-x-4">
                  <Link
                    href="/auth/login"
                    className="nav-link px-3 py-2 text-sm font-medium"
                  >
                    Sign In
                  </Link>
                  <Button
                    variant="secondary"
                    size="sm"
                    onClick={() => router.push('/auth/register')}
                  >
                    Get Started
                  </Button>
                </div>
              )}
            </div>
          </div>

          {/* Mobile menu button */}
          <div className="md:hidden">
            <button
              onClick={() => setIsMobileMenuOpen(!isMobileMenuOpen)}
              className="text-white hover:text-achievement-500 p-2"
            >
              <svg className="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                {isMobileMenuOpen ? (
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                ) : (
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 6h16M4 12h16M4 18h16" />
                )}
              </svg>
            </button>
          </div>
        </div>

        {/* Mobile Navigation */}
        {isMobileMenuOpen && (
          <div className="md:hidden">
            <div className="px-2 pt-2 pb-3 space-y-1 border-t border-neutral-gray border-opacity-20">
              {user ? (
                <>
                  <div className="px-3 py-2 text-white text-sm">
                    Hello, <span className="font-semibold">{user.name}</span>
                    <span className={`
                      ml-2 px-2 py-1 text-xs font-semibold text-white
                      ${user.role === 'teacher' ? 'bg-teacher-500' : 
                        user.role === 'admin' ? 'bg-purple-500' : 'bg-learning-500'}
                    `}>
                      {user.role.toUpperCase()}
                    </span>
                  </div>
                  
                  {navLinks
                    .filter(link => link.roles.includes(user.role))
                    .map((link) => (
                      <Link
                        key={link.href}
                        href={link.href}
                        className={`nav-link block px-3 py-2 text-sm font-medium ${
                          isLinkActive(link.href) ? 'active' : ''
                        }`}
                        onClick={() => setIsMobileMenuOpen(false)}
                      >
                        {link.label}
                      </Link>
                    ))}
                  
                  <button
                    onClick={handleSignOut}
                    className="block w-full text-left px-3 py-2 text-sm font-medium text-white hover:text-achievement-500"
                  >
                    Sign Out
                  </button>
                </>
              ) : (
                <>
                  <Link
                    href="/auth/login"
                    className="nav-link block px-3 py-2 text-sm font-medium"
                    onClick={() => setIsMobileMenuOpen(false)}
                  >
                    Sign In
                  </Link>
                  <Link
                    href="/auth/register"
                    className="nav-link block px-3 py-2 text-sm font-medium"
                    onClick={() => setIsMobileMenuOpen(false)}
                  >
                    Get Started
                  </Link>
                </>
              )}
            </div>
          </div>
        )}
      </div>
    </nav>
  )
}

export default Navigation