'use client'

import React, { forwardRef } from 'react'

interface InputProps {
  type?: 'text' | 'email' | 'password' | 'number' | 'textarea'
  placeholder?: string
  value?: string
  onChange?: (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement>) => void
  disabled?: boolean
  error?: string
  label?: string
  required?: boolean
  className?: string
  name?: string
}

const Input = forwardRef<HTMLInputElement | HTMLTextAreaElement, InputProps>(
  ({
    type = 'text',
    placeholder,
    value,
    onChange,
    disabled = false,
    error,
    label,
    required = false,
    className = '',
    name,
    ...props
  }, ref) => {
    const baseStyles = `
      w-full px-4 py-3 border-2 bg-white text-neutral-charcoal placeholder-neutral-gray
      focus:outline-none transition-colors duration-200 font-inter
      disabled:opacity-50 disabled:cursor-not-allowed
    `

    const borderStyles = error
      ? 'border-red-500 focus:border-red-600'
      : 'border-neutral-gray focus:border-learning-500'

    const combinedClassName = `
      ${baseStyles}
      ${borderStyles}
      ${className}
    `.trim()

    const inputProps = {
      className: combinedClassName,
      placeholder,
      value,
      onChange,
      disabled,
      required,
      name,
      style: { borderRadius: '0px' }, // Pronounced edges
      ...props,
    }

    return (
      <div className="w-full">
        {label && (
          <label className="block text-sm font-semibold text-neutral-charcoal mb-2">
            {label}
            {required && <span className="text-red-500 ml-1">*</span>}
          </label>
        )}
        
        {type === 'textarea' ? (
          <textarea
            {...(inputProps as any)}
            ref={ref as React.Ref<HTMLTextAreaElement>}
            rows={4}
          />
        ) : (
          <input
            {...(inputProps as any)}
            ref={ref as React.Ref<HTMLInputElement>}
            type={type}
          />
        )}
        
        {error && (
          <p className="mt-2 text-sm text-red-600 font-medium">
            {error}
          </p>
        )}
      </div>
    )
  }
)

Input.displayName = 'Input'

export default Input