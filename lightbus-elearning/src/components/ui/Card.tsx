'use client'

import React from 'react'

interface CardProps {
  children: React.ReactNode
  variant?: 'default' | 'primary' | 'accent' | 'bordered'
  padding?: 'sm' | 'md' | 'lg'
  shadow?: 'none' | 'sm' | 'md' | 'lg' | 'xl'
  hover?: boolean
  className?: string
  onClick?: () => void
}

const Card: React.FC<CardProps> = ({
  children,
  variant = 'default',
  padding = 'md',
  shadow = 'md',
  hover = false,
  className = '',
  onClick,
}) => {
  const baseStyles = `
    bg-white transition-all duration-200 cursor-default
  `

  const variantStyles = {
    default: 'border-2 border-neutral-gray',
    primary: 'border-2 border-learning-500',
    accent: 'border-2 border-focus-500',
    bordered: 'border-4 border-neutral-charcoal',
  }

  const paddingStyles = {
    sm: 'p-4',
    md: 'p-6',
    lg: 'p-8',
  }

  const shadowStyles = {
    none: '',
    sm: 'shadow-sm',
    md: 'shadow-lg',
    lg: 'shadow-xl',
    xl: 'shadow-2xl',
  }

  const hoverStyles = hover ? 'hover:shadow-xl hover:transform hover:scale-[1.02] cursor-pointer' : ''

  const combinedClassName = `
    ${baseStyles}
    ${variantStyles[variant]}
    ${paddingStyles[padding]}
    ${shadowStyles[shadow]}
    ${hoverStyles}
    ${className}
  `.trim()

  return (
    <div
      className={combinedClassName}
      onClick={onClick}
      style={{ borderRadius: '0px' }} // Pronounced edges
    >
      {children}
    </div>
  )
}

export default Card