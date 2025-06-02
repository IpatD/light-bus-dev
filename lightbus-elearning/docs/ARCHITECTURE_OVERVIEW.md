# 🏗️ Light Bus E-Learning Platform - Architecture Overview

## System Architecture

The Light Bus E-Learning Platform is built on a modern, scalable architecture that combines cutting-edge frontend technologies with robust backend services and AI-powered features. The platform follows microservices principles with clear separation of concerns.

## 📐 High-Level Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Client Layer  │    │  CDN/Edge       │    │  External APIs  │
│                 │    │                 │    │                 │
│ • Web Browser   │◄──►│ • Vercel Edge   │    │ • OpenAI GPT-4  │
│ • Mobile App    │    │ • Static Assets │    │ • AssemblyAI    │
│ • PWA Support   │    │ • Edge Functions│    │ • Whisper API   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       ▲
         ▼                       ▼                       │
┌─────────────────────────────────────────────────────────────────┐
│                    Application Layer                             │
│                                                                 │
│  ┌─────────────────┐    ┌─────────────────┐                    │
│  │  Frontend App   │    │  Edge Functions │                    │
│  │                 │    │                 │                    │
│  │ • Next.js 14    │◄──►│ • Audio Process │                    │
│  │ • React 18      │    │ • AI Generation │                    │
│  │ • TypeScript    │    │ • Content Analysis                  │
│  │ • Tailwind CSS  │    │ • Real-time Sync│                    │
│  └─────────────────┘    └─────────────────┘                    │
└─────────────────────────────────────────────────────────────────┘
         │                       │
         ▼                       ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Backend Services Layer                       │
│                                                                 │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────┐ │
│  │   Supabase      │    │   PostgreSQL    │    │  Storage    │ │
│  │                 │    │                 │    │             │ │
│  │ • Auth Service  │◄──►│ • Primary DB    │◄──►│ • Media     │ │
│  │ • Real-time     │    │ • Row Level Sec │    │ • Uploads   │ │
│  │ • PostgREST API │    │ • Custom RPC    │    │ • Backups   │ │
│  │ • Edge Runtime  │    │ • Optimized IDX │    │ • CDN Cache │ │
│  └─────────────────┘    └─────────────────┘    └─────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

## 🎯 Core Components

### Frontend Architecture

#### Next.js 14 Application
```
src/app/                          # App Router Structure
├── (auth)/                       # Authentication routes
│   ├── login/                    # User login
│   └── register/                 # User registration
├── dashboard/                    # Role-based dashboards
│   ├── student/                  # Student interface
│   └── teacher/                  # Teacher interface
├── lessons/                      # Lesson management
│   ├── create/                   # Lesson creation
│   ├── upload/                   # Content upload
│   └── [lesson_id]/             # Dynamic lesson routes
├── study/                        # Study interface
│   └── [lesson_id]/             # Study sessions
└── admin/                        # Administrative tools
    ├── moderation/               # Content moderation
    └── system/                   # System monitoring
```

#### Component Architecture
```
src/components/
├── ui/                          # Base UI Components
│   ├── Button.tsx               # Reusable button component
│   ├── Card.tsx                 # Flexible card component
│   ├── Input.tsx                # Form input component
│   └── Modal.tsx                # Accessible modal system
├── study/                       # Study-Specific Components
│   ├── EnhancedFlashcard.tsx    # Advanced flashcard interface
│   ├── SessionProgress.tsx      # Progress tracking
│   └── LiveStudyRoom.tsx        # Real-time collaboration
├── ai/                          # AI Processing Components
│   ├── ProcessingStatus.tsx     # Real-time processing updates
│   ├── AICardReview.tsx         # Teacher review interface
│   └── ContentAnalysis.tsx      # AI insights display
├── analytics/                   # Analytics Components
│   └── LearningInsights.tsx     # AI-powered analytics
└── common/                      # Shared Components
    ├── Navigation.tsx           # Main navigation
    └── RealtimeNotifications.tsx # Live notifications
```

### Backend Architecture

#### Database Schema
```sql
-- Core Educational Tables
profiles                         -- User profiles with roles
lessons                         -- Teacher-created lessons
lesson_participants             -- Student enrollments
sr_cards                        -- Spaced repetition flashcards
sr_reviews                      -- Student review records
sr_progress                     -- Learning progress tracking

-- AI Processing Tables
processing_jobs                 -- AI processing status
content_analysis               -- AI analysis results
auto_generated_cards           -- AI-created flashcards
processing_logs                -- Processing audit trail
student_analytics              -- Enhanced analytics
learning_insights              -- AI recommendations

-- Enterprise Features
content_flags                  -- Content moderation
system_metrics                 -- Performance monitoring
audit_logs                     -- Security audit trail
```

#### Row Level Security (RLS) Policies
```sql
-- Student Data Protection
CREATE POLICY "Students can only access their own data" ON sr_reviews
FOR ALL USING (user_id = auth.uid());

-- Teacher Authorization
CREATE POLICY "Teachers can manage their lessons" ON lessons
FOR ALL USING (teacher_id = auth.uid());

-- Role-Based Access
CREATE POLICY "Admin full access" ON audit_logs
FOR ALL USING (
  EXISTS (
    SELECT 1 FROM profiles 
    WHERE id = auth.uid() AND role = 'admin'
  )
);
```

### AI Processing Pipeline

#### Audio Processing Workflow
```
Input Audio File
      │
      ▼
┌─────────────────┐
│ Edge Function:  │
│ process-lesson- │
│ audio           │
└─────────────────┘
      │
      ▼
┌─────────────────┐    ┌─────────────────┐
│ AssemblyAI      │◄──►│ OpenAI Whisper  │
│ Transcription   │    │ Backup Service  │
└─────────────────┘    └─────────────────┘
      │
      ▼
┌─────────────────┐
│ Database Store  │
│ • Transcript    │
│ • Metadata      │
│ • Status Updates│
└─────────────────┘
```

#### Content Analysis Pipeline
```
Lesson Content
      │
      ▼
┌─────────────────┐
│ Edge Function:  │
│ analyze-content │
└─────────────────┘
      │
      ▼
┌─────────────────┐
│ OpenAI GPT-4    │
│ • Key concepts  │
│ • Difficulty    │
│ • Learning obj. │
└─────────────────┘
      │
      ▼
┌─────────────────┐
│ Database Store  │
│ • Analysis data │
│ • Insights      │
│ • Metrics       │
└─────────────────┘
```

#### Flashcard Generation Pipeline
```
Content + Analysis
      │
      ▼
┌─────────────────┐
│ Edge Function:  │
│ generate-       │
│ flashcards      │
└─────────────────┘
      │
      ▼
┌─────────────────┐
│ OpenAI GPT-4    │
│ • Generate Q&A  │
│ • Quality score │
│ • Difficulty    │
└─────────────────┘
      │
      ▼
┌─────────────────┐
│ Teacher Review  │
│ • Approve/Edit  │
│ • Quality check │
│ • Publish       │
└─────────────────┘
```

## 🔄 Real-time Architecture

### WebSocket Connections
```typescript
// Real-time subscriptions
const subscription = supabase
  .channel('lesson-updates')
  .on('postgres_changes', {
    event: '*',
    schema: 'public',
    table: 'processing_jobs'
  }, (payload) => {
    updateProcessingStatus(payload);
  })
  .subscribe();
```

### Live Collaboration Features
- **Study Rooms**: Real-time synchronized learning sessions
- **Processing Updates**: Live AI processing status
- **Notifications**: Cross-device instant messaging
- **Activity Feeds**: Real-time student activity monitoring

## 🔐 Security Architecture

### Authentication Flow
```
User Login Request
      │
      ▼
┌─────────────────┐
│ Supabase Auth   │
│ • Email/Pass    │
│ • JWT Generation│
│ • Session Mgmt  │
└─────────────────┘
      │
      ▼
┌─────────────────┐
│ Database RLS    │
│ • Policy Check  │
│ • Role Validation│
│ • Data Access   │
└─────────────────┘
```

### Data Protection Layers
1. **Transport Security**: HTTPS/TLS encryption
2. **Authentication**: JWT tokens with refresh
3. **Authorization**: Row Level Security policies
4. **Input Validation**: Client and server-side
5. **Audit Logging**: Complete activity tracking

## 📊 Data Architecture

### Database Relationships
```sql
profiles (1) ──────────────── (*) lessons
    │                           │
    │                           │
    (1)                         (1)
    │                           │
    │                           │
(*) sr_reviews              (*) lesson_participants
    │                           │
    │                           │
    (*)                         (1)
    │                           │
    │                           │
sr_cards ──────────────────── lessons
```

### Performance Optimizations
```sql
-- High-performance indexes
CREATE INDEX CONCURRENTLY idx_sr_reviews_next_review 
ON sr_reviews(next_review_date) 
WHERE next_review_date <= NOW();

CREATE INDEX CONCURRENTLY idx_lessons_teacher_performance 
ON lessons(teacher_id, created_at DESC);

CREATE INDEX CONCURRENTLY idx_processing_status 
ON processing_jobs(status, created_at);
```

## 🔧 Integration Architecture

### External Service Integration
```typescript
// AI Service Integration
interface AIServiceConfig {
  openai: {
    apiKey: string;
    model: 'gpt-4' | 'gpt-3.5-turbo';
    maxTokens: number;
  };
  assemblyai: {
    apiKey: string;
    config: TranscriptionConfig;
  };
}

// Service abstraction layer
class AIServiceManager {
  async processAudio(audioFile: File): Promise<Transcript>;
  async generateFlashcards(content: string): Promise<Flashcard[]>;
  async analyzeContent(text: string): Promise<ContentAnalysis>;
}
```

### API Architecture
```typescript
// RESTful API endpoints
/api/lessons                    // Lesson CRUD operations
/api/cards                      // Flashcard management
/api/study                      // Study session endpoints
/api/analytics                  // Analytics and insights
/api/admin                      // Administrative functions

// Real-time endpoints
/api/realtime/processing        // AI processing updates
/api/realtime/collaboration     // Live study sessions
/api/realtime/notifications     // Instant messaging
```

## 📈 Scalability Architecture

### Horizontal Scaling Strategy
```
Load Balancer
      │
      ▼
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│ App Instance 1  │  │ App Instance 2  │  │ App Instance N  │
└─────────────────┘  └─────────────────┘  └─────────────────┘
      │                      │                      │
      └──────────────────────┼──────────────────────┘
                             │
                             ▼
                    ┌─────────────────┐
                    │ Shared Database │
                    │ • Read Replicas │
                    │ • Connection    │
                    │   Pooling       │
                    └─────────────────┘
```

### Caching Strategy
```
┌─────────────────┐
│ CDN Cache       │  ← Static assets, images
│ (Edge Locations)│
└─────────────────┘
         │
         ▼
┌─────────────────┐
│ Application     │  ← API responses, computed data
│ Cache (Redis)   │
└─────────────────┘
         │
         ▼
┌─────────────────┐
│ Database        │  ← Query results, sessions
│ Cache           │
└─────────────────┘
```

## 🔍 Monitoring Architecture

### Application Monitoring
```typescript
// Performance monitoring
interface MonitoringMetrics {
  responseTime: number;
  errorRate: number;
  throughput: number;
  aiServiceLatency: number;
  databasePerformance: number;
}

// Error tracking
class ErrorTracker {
  trackError(error: Error, context: ErrorContext): void;
  trackPerformance(metric: PerformanceMetric): void;
  generateReport(): MonitoringReport;
}
```

### Health Check Endpoints
```typescript
// Application health
GET /api/health
{
  "status": "healthy",
  "database": "connected",
  "aiServices": "operational",
  "uptime": "99.9%",
  "lastCheck": "2025-01-01T12:00:00Z"
}
```

## 🚀 Deployment Architecture

### Multi-Environment Strategy
```
Development Environment
├── Local Supabase
├── Local Next.js dev server
└── Mock AI services

Staging Environment
├── Supabase staging project
├── Vercel preview deployment
└── AI services (limited quota)

Production Environment
├── Supabase production project
├── Vercel production deployment
├── Full AI services integration
└── Monitoring and alerting
```

### CI/CD Pipeline
```
Code Commit
    │
    ▼
GitHub Actions
    │
    ├─ Lint & Type Check
    ├─ Unit Tests
    ├─ Integration Tests
    └─ Security Scan
    │
    ▼
Build & Deploy
    │
    ├─ Build Next.js app
    ├─ Deploy to Vercel
    ├─ Apply DB migrations
    └─ Deploy Edge Functions
    │
    ▼
Post-Deployment
    │
    ├─ Health checks
    ├─ Performance tests
    └─ Notification
```

## 🎯 Design Patterns

### Component Patterns
```typescript
// Higher-Order Component pattern
const withAuth = (Component: React.FC) => {
  return (props: any) => {
    const { user } = useAuth();
    if (!user) return <LoginRequired />;
    return <Component {...props} />;
  };
};

// Compound Component pattern
const Flashcard = {
  Container: FlashcardContainer,
  Question: FlashcardQuestion,
  Answer: FlashcardAnswer,
  Actions: FlashcardActions,
};
```

### State Management Patterns
```typescript
// Custom hooks for state management
const useStudySession = (lessonId: string) => {
  const [session, setSession] = useState<StudySession>();
  const [loading, setLoading] = useState(true);
  
  const startSession = () => { /* ... */ };
  const endSession = () => { /* ... */ };
  const reviewCard = (rating: number) => { /* ... */ };
  
  return { session, loading, startSession, endSession, reviewCard };
};
```

## 📚 Data Flow Architecture

### Spaced Repetition Algorithm Flow
```
Card Review Request
      │
      ▼
┌─────────────────┐
│ Get Next Cards  │
│ • Due today     │
│ • Overdue first │
│ • New cards     │
└─────────────────┘
      │
      ▼
┌─────────────────┐
│ Present Card    │
│ • Show question │
│ • Start timer   │
│ • Track attempt │
└─────────────────┘
      │
      ▼
┌─────────────────┐
│ User Response   │
│ • Quality rating│
│ • Response time │
│ • Confidence    │
└─────────────────┘
      │
      ▼
┌─────────────────┐
│ SM-2 Algorithm  │
│ • Calculate EF  │
│ • Set interval  │
│ • Update stats  │
└─────────────────┘
      │
      ▼
┌─────────────────┐
│ Update Database │
│ • Review record │
│ • Progress data │
│ • Analytics     │
└─────────────────┘
```

This architecture ensures scalability, maintainability, and optimal performance while providing a robust foundation for the advanced features of the Light Bus E-Learning Platform.