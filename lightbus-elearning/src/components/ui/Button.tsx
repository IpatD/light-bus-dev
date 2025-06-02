'use client'

import React from 'react'
import { ButtonProps } from '@/types'

const Button: React.FC<ButtonProps> = ({
  variant = 'primary',
  size = 'md',
  disabled = false,
  loading = false,
  children,
  onClick,
  type = 'button',
  className = '',
}) => {
  const baseStyles = `
    font-semibold transition-all duration-200 focus:outline-none focus:ring-2 focus:ring-offset-2
    disabled:opacity-50 disabled:cursor-not-allowed inline-flex items-center justify-center
    border-0 font-inter
  `

  const variantStyles = {
    primary: 'bg-[#ff6b35] hover:bg-[#e55a2b] focus:ring-[#ff6b35] text-white',
    secondary: 'bg-white border-2 border-black hover:bg-[#ff6b35] hover:text-white focus:ring-[#ff6b35] text-gray-800',
    accent: 'bg-[#ff6b35] hover:bg-[#e55a2b] focus:ring-[#ff6b35] text-white',
    ghost: 'bg-transparent border-2 border-black hover:bg-[#ff6b35] hover:text-white focus:ring-[#ff6b35] text-gray-800',
    danger: 'bg-red-500 hover:bg-red-600 focus:ring-red-500 text-white',
    'white-orange': 'bg-white border-2 border-[#ff6b35] hover:bg-[#ff6b35] hover:text-white focus:ring-[#ff6b35] text-[#ff6b35]',
  }

  const sizeStyles = {
    sm: 'py-2 px-4 text-sm',
    md: 'py-3 px-6 text-base',
    lg: 'py-4 px-8 text-lg',
  }

  const combinedClassName = `
    ${baseStyles}
    ${variantStyles[variant]}
    ${sizeStyles[size]}
    ${className}
  `.trim()

  return (
    <button
      type={type}
      className={combinedClassName}
      onClick={onClick}
      disabled={disabled || loading}
      style={{ borderRadius: '0px' }} // Pronounced edges
    >
      {loading && (
        <svg
          className="animate-spin -ml-1 mr-3 h-5 w-5"
          xmlns="http://www.w3.org/2000/svg"
          fill="none"
          viewBox="0 0 24 24"
        >
          <circle
            className="opacity-25"
            cx="12"
            cy="12"
            r="10"
            stroke="currentColor"
            strokeWidth="4"
          ></circle>
          <path
            className="opacity-75"
            fill="currentColor"
            d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
          ></path>
        </svg>
      )}
      {children}
    </button>
  )
}

export default Button