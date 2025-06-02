# 👨‍💻 Light Bus E-Learning Platform - Developer Guide

## Overview

This comprehensive developer guide provides everything needed to understand, modify, and extend the Light Bus E-Learning Platform. Whether you're setting up a development environment, implementing new features, or contributing to the codebase, this guide will walk you through the entire development process.

## 🚀 Development Environment Setup

### Prerequisites

Before starting development, ensure you have the following installed:

```bash
# Required software
Node.js 18+                     # JavaScript runtime
npm 8+                          # Package manager
Git 2.30+                       # Version control
Docker Desktop                  # For local Supabase
VS Code                         # Recommended IDE

# Optional but recommended
Supabase CLI                    # Database management
Vercel CLI                      # Deployment testing
```

### Quick Setup

1. **Clone the Repository**
```bash
git clone <repository-url>
cd lightbus-elearning
```

2. **Install Dependencies**
```bash
npm install
```

3. **Environment Configuration**
```bash
cp .env.local.example .env.local
```

4. **Start Local Supabase**
```bash
npx supabase start
```

5. **Apply Database Migrations**
```bash
npx supabase db reset
```

6. **Start Development Server**
```bash
npm run dev
```

Your development environment is now ready at `http://localhost:3000`

## 📁 Project Structure Deep Dive

### Frontend Architecture (`src/`)

```
src/
├── app/                        # Next.js 14 App Router
│   ├── (auth)/                 # Authentication group
│   │   ├── login/              
│   │   │   └── page.tsx        # Login page
│   │   └── register/           
│   │       └── page.tsx        # Registration page
│   ├── dashboard/              # User dashboards
│   │   ├── student/            
│   │   │   └── page.tsx        # Student dashboard
│   │   └── teacher/            
│   │       └── page.tsx        # Teacher dashboard
│   ├── lessons/                # Lesson management
│   │   ├── create/             
│   │   │   └── page.tsx        # Lesson creation
│   │   ├── upload/             
│   │   │   └── page.tsx        # Content upload
│   │   └── [lesson_id]/        
│   │       └── teacher/        
│   │           └── page.tsx    # Lesson management
│   ├── study/                  # Study interface
│   │   └── [lesson_id]/        
│   │       └── page.tsx        # Study session
│   ├── admin/                  # Administrative tools
│   │   ├── moderation/         
│   │   │   └── page.tsx        # Content moderation
│   │   └── system/             
│   │       └── page.tsx        # System monitoring
│   ├── globals.css             # Global styles
│   ├── layout.tsx              # Root layout
│   └── page.tsx                # Landing page
├── components/                 # React components
│   ├── ui/                     # Base UI components
│   ├── study/                  # Study-specific components
│   ├── lessons/                # Lesson components
│   ├── ai/                     # AI processing components
│   ├── analytics/              # Analytics components
│   ├── dashboard/              # Dashboard components
│   └── common/                 # Shared components
├── lib/                        # Utilities and configurations
│   └── supabase.ts             # Supabase client
├── hooks/                      # Custom React hooks
│   └── useAuth.ts              # Authentication hook
└── types/                      # TypeScript definitions
    └── index.ts                # Type definitions
```

### Backend Architecture (`supabase/`)

```
supabase/
├── migrations/                 # Database migrations
│   ├── 001_initial_schema.sql  # Foundation schema
│   ├── 002_sr_functions.sql    # Spaced repetition
│   ├── 003_mock_data.sql       # Development data
│   ├── 004_teacher_functions.sql # Teacher features
│   ├── 005_ai_processing.sql   # AI integration
│   └── 006_moderation_realtime.sql # Enterprise features
├── functions/                  # Edge Functions
│   ├── process-lesson-audio/   # Audio transcription
│   ├── generate-flashcards/    # AI card generation
│   └── analyze-content/        # Content analysis
└── config.toml                 # Supabase configuration
```

## 🧩 Core Development Patterns

### Component Development Pattern

```typescript
// Standard component structure
interface ComponentProps {
  // Define prop types
  id: string;
  children?: React.ReactNode;
  className?: string;
}

export const Component: React.FC<ComponentProps> = ({
  id,
  children,
  className = ''
}) => {
  // State management
  const [state, setState] = useState<ComponentState>();
  
  // Effects
  useEffect(() => {
    // Component logic
  }, []);
  
  // Event handlers
  const handleEvent = useCallback(() => {
    // Event logic
  }, []);
  
  // Render
  return (
    <div className={`base-styles ${className}`}>
      {children}
    </div>
  );
};
```

### Custom Hook Pattern

```typescript
// Custom hook for data management
export const useDataHook = (id: string) => {
  const [data, setData] = useState<DataType | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  
  useEffect(() => {
    const fetchData = async () => {
      try {
        setLoading(true);
        const result = await apiCall(id);
        setData(result);
      } catch (err) {
        setError(err instanceof Error ? err.message : 'Unknown error');
      } finally {
        setLoading(false);
      }
    };
    
    fetchData();
  }, [id]);
  
  const refetch = useCallback(() => {
    // Refetch logic
  }, [id]);
  
  return { data, loading, error, refetch };
};
```

### Database Function Pattern

```sql
-- Database function template
CREATE OR REPLACE FUNCTION function_name(
  param1 TEXT,
  param2 INTEGER DEFAULT 0
)
RETURNS TABLE(
  column1 TEXT,
  column2 INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Validation
  IF param1 IS NULL OR param1 = '' THEN
    RAISE EXCEPTION 'param1 cannot be null or empty';
  END IF;
  
  -- Business logic
  RETURN QUERY
  SELECT 
    t.column1,
    t.column2
  FROM table_name t
  WHERE t.condition = param1;
END;
$$;
```

## 🔧 Code Architecture Guidelines

### TypeScript Best Practices

```typescript
// Comprehensive type definitions
export interface User {
  id: string;
  email: string;
  role: 'student' | 'teacher' | 'admin';
  profile: UserProfile;
  createdAt: string;
  updatedAt: string;
}

export interface UserProfile {
  firstName: string;
  lastName: string;
  avatar?: string;
  preferences: UserPreferences;
}

export interface UserPreferences {
  theme: 'light' | 'dark';
  notifications: NotificationSettings;
  language: string;
}

// Type guards for runtime validation
export const isUser = (obj: any): obj is User => {
  return (
    typeof obj === 'object' &&
    typeof obj.id === 'string' &&
    typeof obj.email === 'string' &&
    ['student', 'teacher', 'admin'].includes(obj.role)
  );
};

// Generic utility types
export type ApiResponse<T> = {
  data: T;
  error: string | null;
  loading: boolean;
};

export type AsyncState<T> = {
  data: T | null;
  loading: boolean;
  error: string | null;
};
```

### Component Organization

```typescript
// Component file structure
// ComponentName.tsx

import React, { useState, useEffect, useCallback } from 'react';
import { ComponentProps } from './types';
import { useComponentLogic } from './hooks';
import styles from './ComponentName.module.css';

// Component implementation
export const ComponentName: React.FC<ComponentProps> = (props) => {
  // Implementation
};

// Default export
export default ComponentName;

// Named exports for testing
export { ComponentName };
```

### Error Handling Pattern

```typescript
// Centralized error handling
export class AppError extends Error {
  constructor(
    message: string,
    public code: string,
    public statusCode: number = 500
  ) {
    super(message);
    this.name = 'AppError';
  }
}

// Error boundary component
export class ErrorBoundary extends React.Component<
  ErrorBoundaryProps,
  ErrorBoundaryState
> {
  constructor(props: ErrorBoundaryProps) {
    super(props);
    this.state = { hasError: false, error: null };
  }
  
  static getDerivedStateFromError(error: Error): ErrorBoundaryState {
    return { hasError: true, error };
  }
  
  componentDidCatch(error: Error, errorInfo: React.ErrorInfo) {
    // Log error to monitoring service
    console.error('Error caught by boundary:', error, errorInfo);
  }
  
  render() {
    if (this.state.hasError) {
      return <ErrorFallback error={this.state.error} />;
    }
    
    return this.props.children;
  }
}
```

## 🧪 Testing Strategies

### Unit Testing with Jest

```typescript
// Component testing
import { render, screen, fireEvent } from '@testing-library/react';
import { Button } from '../Button';

describe('Button Component', () => {
  it('renders correctly', () => {
    render(<Button>Click me</Button>);
    expect(screen.getByRole('button')).toBeInTheDocument();
  });
  
  it('handles click events', () => {
    const handleClick = jest.fn();
    render(<Button onClick={handleClick}>Click me</Button>);
    
    fireEvent.click(screen.getByRole('button'));
    expect(handleClick).toHaveBeenCalledTimes(1);
  });
  
  it('applies custom styles', () => {
    render(<Button className="custom-class">Click me</Button>);
    expect(screen.getByRole('button')).toHaveClass('custom-class');
  });
});
```

### Integration Testing

```typescript
// Database function testing
import { createClient } from '@supabase/supabase-js';

describe('Database Functions', () => {
  let supabase: SupabaseClient;
  
  beforeAll(() => {
    supabase = createClient(
      process.env.SUPABASE_URL!,
      process.env.SUPABASE_SERVICE_ROLE_KEY!
    );
  });
  
  it('creates lesson successfully', async () => {
    const { data, error } = await supabase.rpc('create_lesson', {
      title: 'Test Lesson',
      description: 'Test Description',
      duration: 60
    });
    
    expect(error).toBeNull();
    expect(data).toHaveProperty('id');
    expect(data.title).toBe('Test Lesson');
  });
});
```

### End-to-End Testing with Playwright

```typescript
// E2E testing
import { test, expect } from '@playwright/test';

test.describe('User Authentication', () => {
  test('user can register and login', async ({ page }) => {
    // Navigate to registration
    await page.goto('/auth/register');
    
    // Fill registration form
    await page.fill('[data-testid="email"]', 'test@example.com');
    await page.fill('[data-testid="password"]', 'securepassword');
    await page.click('[data-testid="register-button"]');
    
    // Verify successful registration
    await expect(page).toHaveURL('/dashboard/student');
    
    // Test login flow
    await page.goto('/auth/logout');
    await page.goto('/auth/login');
    
    await page.fill('[data-testid="email"]', 'test@example.com');
    await page.fill('[data-testid="password"]', 'securepassword');
    await page.click('[data-testid="login-button"]');
    
    await expect(page).toHaveURL('/dashboard/student');
  });
});
```

## 🔄 Database Development

### Migration Development

```sql
-- Migration file template
-- supabase/migrations/XXX_feature_name.sql

-- Create tables
CREATE TABLE IF NOT EXISTS table_name (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_table_name_user_id 
ON table_name(user_id);

-- Enable RLS
ALTER TABLE table_name ENABLE ROW LEVEL SECURITY;

-- Create policies
CREATE POLICY "Users can view their own records" 
ON table_name FOR SELECT 
USING (user_id = auth.uid());

-- Create functions
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create triggers
CREATE TRIGGER update_table_name_updated_at
  BEFORE UPDATE ON table_name
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at();
```

### Database Function Development

```sql
-- Complex database function example
CREATE OR REPLACE FUNCTION get_student_progress(
  p_lesson_id UUID,
  p_student_id UUID DEFAULT auth.uid()
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  result JSON;
BEGIN
  -- Validation
  IF p_lesson_id IS NULL THEN
    RAISE EXCEPTION 'lesson_id cannot be null';
  END IF;
  
  -- Check permissions
  IF NOT EXISTS (
    SELECT 1 FROM lesson_participants 
    WHERE lesson_id = p_lesson_id 
    AND student_id = p_student_id
  ) THEN
    RAISE EXCEPTION 'Access denied: not enrolled in lesson';
  END IF;
  
  -- Calculate progress
  SELECT json_build_object(
    'total_cards', COUNT(*),
    'mastered_cards', COUNT(*) FILTER (WHERE repetitions >= 3),
    'due_cards', COUNT(*) FILTER (WHERE next_review_date <= NOW()),
    'average_ease_factor', AVG(ease_factor),
    'study_streak', COALESCE(MAX(study_streak), 0),
    'last_review', MAX(last_review_date)
  )
  INTO result
  FROM sr_cards sc
  LEFT JOIN sr_reviews sr ON sc.id = sr.card_id AND sr.user_id = p_student_id
  WHERE sc.lesson_id = p_lesson_id;
  
  RETURN result;
END;
$$;
```

## 🔌 AI Integration Development

### Edge Function Development

```typescript
// Edge function template
// supabase/functions/function-name/index.ts

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

interface RequestBody {
  // Define request structure
}

interface ResponseBody {
  // Define response structure
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // Parse request
    const { data }: { data: RequestBody } = await req.json();
    
    // Validate input
    if (!data) {
      throw new Error('Invalid request data');
    }
    
    // Initialize Supabase client
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    );
    
    // Process request
    const result = await processRequest(data, supabase);
    
    // Return response
    return new Response(
      JSON.stringify({ success: true, data: result }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      }
    );
    
  } catch (error) {
    return new Response(
      JSON.stringify({ 
        success: false, 
        error: error instanceof Error ? error.message : 'Unknown error'
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 500,
      }
    );
  }
});

async function processRequest(
  data: RequestBody, 
  supabase: SupabaseClient
): Promise<ResponseBody> {
  // Implementation logic
}
```

### AI Service Integration

```typescript
// AI service abstraction
export class AIService {
  private openaiApiKey: string;
  private assemblyaiApiKey: string;
  
  constructor() {
    this.openaiApiKey = process.env.OPENAI_API_KEY!;
    this.assemblyaiApiKey = process.env.ASSEMBLYAI_API_KEY!;
  }
  
  async transcribeAudio(audioFile: Blob): Promise<TranscriptionResult> {
    try {
      // Upload to AssemblyAI
      const uploadResponse = await fetch('https://api.assemblyai.com/v2/upload', {
        method: 'POST',
        headers: {
          'Authorization': this.assemblyaiApiKey,
        },
        body: audioFile,
      });
      
      const { upload_url } = await uploadResponse.json();
      
      // Submit transcription job
      const transcriptResponse = await fetch('https://api.assemblyai.com/v2/transcript', {
        method: 'POST',
        headers: {
          'Authorization': this.assemblyaiApiKey,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          audio_url: upload_url,
          speaker_labels: true,
          auto_chapters: true,
        }),
      });
      
      const transcript = await transcriptResponse.json();
      return transcript;
      
    } catch (error) {
      throw new Error(`Transcription failed: ${error}`);
    }
  }
  
  async generateFlashcards(content: string): Promise<FlashcardData[]> {
    try {
      const response = await fetch('https://api.openai.com/v1/chat/completions', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${this.openaiApiKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          model: 'gpt-4',
          messages: [
            {
              role: 'system',
              content: 'You are an expert educator. Generate high-quality flashcards from educational content.',
            },
            {
              role: 'user',
              content: `Generate flashcards from this content: ${content}`,
            },
          ],
          temperature: 0.7,
          max_tokens: 2000,
        }),
      });
      
      const result = await response.json();
      return this.parseFlashcards(result.choices[0].message.content);
      
    } catch (error) {
      throw new Error(`Flashcard generation failed: ${error}`);
    }
  }
  
  private parseFlashcards(content: string): FlashcardData[] {
    // Parse AI response into structured flashcard data
  }
}
```

## 🔍 Debugging and Troubleshooting

### Common Development Issues

```typescript
// Debug utilities
export const debug = {
  log: (message: string, data?: any) => {
    if (process.env.NODE_ENV === 'development') {
      console.log(`[DEBUG] ${message}`, data);
    }
  },
  
  error: (message: string, error?: Error) => {
    console.error(`[ERROR] ${message}`, error);
  },
  
  performance: (label: string, fn: () => void) => {
    console.time(label);
    fn();
    console.timeEnd(label);
  },
};

// Database debugging
export const debugDatabase = {
  logQuery: (query: string, params?: any[]) => {
    debug.log('Database Query', { query, params });
  },
  
  logResult: (result: any) => {
    debug.log('Database Result', result);
  },
};
```

### Performance Monitoring

```typescript
// Performance monitoring
export const performanceMonitor = {
  trackPageLoad: (pageName: string) => {
    const startTime = performance.now();
    
    return {
      end: () => {
        const endTime = performance.now();
        const loadTime = endTime - startTime;
        
        // Send to analytics
        if (typeof window !== 'undefined') {
          (window as any).gtag?.('event', 'page_load_time', {
            page_name: pageName,
            load_time: loadTime,
          });
        }
      },
    };
  },
  
  trackApiCall: async (apiName: string, apiCall: () => Promise<any>) => {
    const startTime = performance.now();
    
    try {
      const result = await apiCall();
      const endTime = performance.now();
      
      debug.log(`API Call ${apiName}`, {
        duration: endTime - startTime,
        success: true,
      });
      
      return result;
    } catch (error) {
      const endTime = performance.now();
      
      debug.error(`API Call ${apiName} failed`, error as Error);
      debug.log(`API Call ${apiName}`, {
        duration: endTime - startTime,
        success: false,
      });
      
      throw error;
    }
  },
};
```

## 🚀 Deployment and CI/CD

### GitHub Actions Workflow

```yaml
# .github/workflows/ci-cd.yml
name: CI/CD Pipeline

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'
          cache: 'npm'
      
      - name: Install dependencies
        run: npm ci
      
      - name: Run linting
        run: npm run lint
      
      - name: Run type checking
        run: npm run type-check
      
      - name: Run tests
        run: npm run test
      
      - name: Build application
        run: npm run build

  deploy:
    needs: test
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Deploy to Vercel
        uses: amondnet/vercel-action@v20
        with:
          vercel-token: ${{ secrets.VERCEL_TOKEN }}
          vercel-org-id: ${{ secrets.ORG_ID }}
          vercel-project-id: ${{ secrets.PROJECT_ID }}
          vercel-args: '--prod'
```

## 📚 Contributing Guidelines

### Code Review Checklist

- [ ] **Functionality**: Does the code work as expected?
- [ ] **Performance**: Are there any performance implications?
- [ ] **Security**: Are there any security vulnerabilities?
- [ ] **Tests**: Are there adequate tests covering the changes?
- [ ] **Documentation**: Is the code properly documented?
- [ ] **Type Safety**: Are TypeScript types properly defined?
- [ ] **Accessibility**: Are accessibility standards met?
- [ ] **Mobile Responsiveness**: Does it work on mobile devices?

### Git Workflow

```bash
# Feature development workflow
git checkout develop
git pull origin develop
git checkout -b feature/feature-name

# Make changes and commit
git add .
git commit -m "feat: add new feature description"

# Push and create PR
git push origin feature/feature-name
# Create pull request to develop branch

# After review and merge
git checkout develop
git pull origin develop
git branch -d feature/feature-name
```

This developer guide provides a comprehensive foundation for contributing to and extending the Light Bus E-Learning Platform. Always refer to the latest documentation and follow established patterns when implementing new features.