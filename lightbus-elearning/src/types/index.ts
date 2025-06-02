// User and Authentication Types
export interface User {
  id: string
  email: string
  name: string
  role: 'student' | 'teacher' | 'admin'
  created_at: string
  updated_at: string
}

export interface AuthUser {
  id: string
  email: string
  email_confirmed_at?: string
  created_at: string
}

export interface SignUpData {
  email: string
  password: string
  name: string
  role: 'student' | 'teacher'
}

export interface SignInData {
  email: string
  password: string
}

// Lesson Types
export interface Lesson {
  id: string
  teacher_id: string
  name: string
  description?: string
  scheduled_at: string
  duration_minutes?: number
  has_audio: boolean
  recording_path?: string
  created_at: string
  updated_at: string
  teacher?: User
  participants?: LessonParticipant[]
  cards?: SRCard[]
}

export interface LessonParticipant {
  lesson_id: string
  student_id: string
  enrolled_at: string
  student?: User
}

export interface CreateLessonData {
  name: string
  description?: string
  scheduled_at: string
  duration_minutes?: number
}

// Spaced Repetition Card Types
export interface SRCard {
  id: string
  lesson_id: string
  created_by: string
  front_content: string
  back_content: string
  card_type: string
  difficulty_level: number
  tags: string[]
  status: 'pending' | 'approved' | 'rejected'
  approved_by?: string
  approved_at?: string
  created_at: string
  updated_at: string
  lesson?: Lesson
  creator?: User
}

export interface CreateSRCardData {
  lesson_id: string
  front_content: string
  back_content: string
  card_type?: string
  difficulty_level?: number
  tags?: string[]
}

// Spaced Repetition Review Types
export interface SRReview {
  id: string
  card_id: string
  student_id: string
  scheduled_for: string
  completed_at?: string
  quality_rating?: number
  response_time_ms?: number
  interval_days: number
  ease_factor: number
  repetition_count: number
  created_at: string
  card?: SRCard
  student?: User
}

export interface SRProgress {
  id: string
  student_id: string
  lesson_id: string
  cards_total: number
  cards_reviewed: number
  cards_learned: number
  average_quality: number
  study_streak: number
  last_review_date?: string
  next_review_date?: string
  created_at: string
  updated_at: string
  student?: User
  lesson?: Lesson
}

// Study Session Types
export interface StudySession {
  lesson_id?: string
  cards: SRCard[]
  current_card_index: number
  total_cards: number
  reviews: Array<{
    card_id: string
    quality_rating: number
    response_time_ms: number
  }>
  started_at: string
  completed_at?: string
}

export interface StudyCardReview {
  card_id: string
  quality_rating: number
  response_time_ms: number
}

// Quality ratings for SM-2 algorithm
export type QualityRating = 0 | 1 | 2 | 3 | 4 | 5

export interface QualityOption {
  value: QualityRating
  label: string
  description: string
  color: string
}

// Dashboard Statistics Types
export interface UserStats {
  total_reviews: number
  average_quality: number
  study_streak: number
  cards_learned: number
  cards_due_today: number
  next_review_date?: string
  weekly_progress: number[]
  monthly_progress: number[]
}

export interface TeacherStats {
  total_lessons: number
  total_students: number
  total_cards_created: number
  pending_cards: number
  recent_activity: Array<{
    type: 'lesson_created' | 'card_approved' | 'student_enrolled'
    description: string
    timestamp: string
  }>
}

// Content Types
export interface Transcript {
  id: string
  lesson_id: string
  content: string
  transcript_type: 'auto' | 'manual' | 'corrected'
  confidence_score?: number
  created_at: string
  updated_at: string
}

export interface Summary {
  id: string
  lesson_id: string
  content: string
  summary_type: 'auto' | 'manual'
  created_at: string
  updated_at: string
}

// Component Props Types
export interface FlashcardProps {
  card: SRCard
  showAnswer: boolean
  onFlip: () => void
  onReview: (quality: QualityRating, responseTime: number) => void
  isLoading?: boolean
}

export interface ButtonProps {
  variant?: 'primary' | 'secondary' | 'accent' | 'ghost' | 'danger' | 'white-orange'
  size?: 'sm' | 'md' | 'lg'
  disabled?: boolean
  loading?: boolean
  children: React.ReactNode
  onClick?: () => void
  type?: 'button' | 'submit' | 'reset'
  className?: string
}

export interface InputProps {
  type?: 'text' | 'email' | 'password' | 'number' | 'textarea'
  placeholder?: string
  value?: string
  onChange?: (value: string) => void
  disabled?: boolean
  error?: string
  label?: string
  required?: boolean
  className?: string
}

export interface ModalProps {
  isOpen: boolean
  onClose: () => void
  title?: string
  children: React.ReactNode
  size?: 'sm' | 'md' | 'lg' | 'xl'
}

// API Response Types
export interface ApiResponse<T = any> {
  data?: T
  error?: string
  message?: string
  success: boolean
}

export interface PaginatedResponse<T = any> {
  data: T[]
  count: number
  page: number
  per_page: number
  total_pages: number
}

// Form Validation Types
export interface FormError {
  field: string
  message: string
}

export interface ValidationResult {
  isValid: boolean
  errors: FormError[]
}

// Navigation Types
export interface NavItem {
  label: string
  href: string
  icon?: string
  roles?: Array<'student' | 'teacher' | 'admin'>
  active?: boolean
}

// Theme and Design System Types
export interface Theme {
  colors: {
    primary: string
    secondary: string
    accent: string
    background: string
    foreground: string
    muted: string
  }
  fonts: {
    sans: string
    mono: string
  }
  breakpoints: {
    sm: string
    md: string
    lg: string
    xl: string
  }
}

// Utility Types
export type Role = 'student' | 'teacher' | 'admin'
export type CardStatus = 'pending' | 'approved' | 'rejected'
export type CardType = 'basic' | 'cloze' | 'multiple_choice' | 'audio'
export type TranscriptType = 'auto' | 'manual' | 'corrected'
export type SummaryType = 'auto' | 'manual'

// Error Types
export interface AppError {
  code: string
  message: string
  details?: any
}

export interface SupabaseError {
  message: string
  details?: string
  hint?: string
  code?: string
}

// AI Processing Types for Phase 3
export interface ProcessingJob {
  id: string
  lesson_id: string
  job_type: 'transcription' | 'summarization' | 'flashcard_generation' | 'content_analysis'
  status: 'pending' | 'processing' | 'completed' | 'failed' | 'cancelled'
  progress_percentage: number
  input_data?: any
  output_data?: any
  error_message?: string
  ai_service_provider?: 'openai' | 'assemblyai' | 'custom'
  api_request_id?: string
  processing_started_at?: string
  processing_completed_at?: string
  estimated_completion_time?: string
  cost_cents: number
  created_by: string
  created_at: string
  updated_at: string
}

export interface ContentAnalysis {
  id: string
  lesson_id: string
  processing_job_id?: string
  analysis_type: 'key_concepts' | 'learning_objectives' | 'prerequisites' | 'difficulty_assessment' | 'topic_extraction'
  analysis_data: any
  confidence_score?: number
  created_at: string
  updated_at: string
}

export interface AutoGeneratedCard {
  id: string
  lesson_id: string
  processing_job_id?: string
  sr_card_id?: string
  front_content: string
  back_content: string
  card_type: 'basic' | 'cloze' | 'multiple_choice' | 'true_false'
  difficulty_level: number
  confidence_score?: number
  source_text?: string
  source_timestamp_start?: number
  source_timestamp_end?: number
  tags: string[]
  quality_score: number
  review_status: 'pending' | 'approved' | 'rejected' | 'needs_review'
  reviewed_by?: string
  reviewed_at?: string
  auto_approved: boolean
  created_at: string
  updated_at: string
}

export interface ProcessingLog {
  id: string
  processing_job_id: string
  log_level: 'debug' | 'info' | 'warning' | 'error'
  message: string
  details?: any
  created_at: string
}

export interface StudentAnalytics {
  id: string
  student_id: string
  lesson_id?: string
  analytics_date: string
  study_time_minutes: number
  cards_reviewed: number
  cards_correct: number
  average_response_time_ms: number
  learning_velocity: number
  retention_rate: number
  difficulty_progression: number
  engagement_score: number
  predicted_mastery_date?: string
  risk_score: number
  created_at: string
  updated_at: string
}

export interface LearningInsight {
  id: string
  student_id: string
  lesson_id?: string
  insight_type: 'weakness_identification' | 'study_recommendation' | 'optimal_timing' | 'progress_prediction' | 'intervention_needed'
  insight_data: any
  priority_level: number
  confidence_score?: number
  is_active: boolean
  expires_at?: string
  acted_upon: boolean
  created_at: string
  updated_at: string
}

export interface SystemMetrics {
  id: string
  metric_name: string
  metric_value: number
  metric_unit?: string
  metric_category?: 'performance' | 'usage' | 'cost' | 'quality' | 'user_engagement'
  metadata?: any
  recorded_at: string
}

// AI Service Integration Types
export interface TranscriptionRequest {
  audioUrl: string
  language?: string
  speakerLabels?: boolean
  punctuation?: boolean
  profanityFilter?: boolean
}

export interface TranscriptionResponse {
  text: string
  confidence: number
  segments?: Array<{
    text: string
    start: number
    end: number
    confidence: number
    speaker?: string
  }>
  processing_time_ms: number
}

export interface FlashcardGenerationRequest {
  content: string
  difficulty_level?: number
  card_count?: number
  card_types?: ('basic' | 'cloze' | 'multiple_choice')[]
  focus_topics?: string[]
}

export interface GeneratedFlashcard {
  front_content: string
  back_content: string
  card_type: 'basic' | 'cloze' | 'multiple_choice' | 'true_false'
  difficulty_level: number
  confidence_score: number
  source_text?: string
  tags: string[]
  explanation?: string
}

export interface ContentAnalysisRequest {
  content: string
  analysis_types: ('key_concepts' | 'learning_objectives' | 'prerequisites' | 'difficulty_assessment')[]
  educational_level?: string
  subject_area?: string
}

export interface ContentAnalysisResponse {
  key_concepts?: string[]
  learning_objectives?: string[]
  prerequisites?: string[]
  difficulty_score?: number
  readability_score?: number
  estimated_study_time?: number
  topic_categories?: string[]
}

// Analytics and Insights Types
export interface LearningProgress {
  student_id: string
  lesson_id: string
  mastery_percentage: number
  time_spent_minutes: number
  cards_mastered: number
  cards_struggling: number
  predicted_completion_date: string
  recommended_study_frequency: number
  weak_areas: string[]
  strong_areas: string[]
}

export interface StudyRecommendation {
  type: 'review_due' | 'focus_area' | 'break_suggestion' | 'difficulty_adjustment'
  title: string
  description: string
  priority: 'low' | 'medium' | 'high' | 'critical'
  estimated_time_minutes: number
  action_items: string[]
  expires_at?: string
}

export interface ProgressPrediction {
  student_id: string
  lesson_id: string
  predicted_mastery_date: string
  confidence_interval: {
    earliest: string
    latest: string
  }
  risk_factors: string[]
  success_probability: number
  recommended_interventions: string[]
}

// Component Props for AI Features
export interface ProcessingStatusProps {
  jobId: string
  onComplete?: (result: any) => void
  onError?: (error: string) => void
  showDetails?: boolean
}

export interface AICardReviewProps {
  cards: AutoGeneratedCard[]
  onApprove: (cardIds: string[]) => void
  onReject: (cardIds: string[]) => void
  onEdit: (cardId: string, updates: Partial<AutoGeneratedCard>) => void
  showBulkActions?: boolean
}

export interface ContentAnalysisProps {
  analysis: ContentAnalysis[]
  lesson: Lesson
  onExport?: () => void
  showInsights?: boolean
}

export interface TranscriptViewerProps {
  transcript: Transcript
  lesson: Lesson
  onCreateCard?: (selection: { text: string; start?: number; end?: number }) => void
  onExport?: (format: 'pdf' | 'txt') => void
  searchable?: boolean
}

export interface LearningInsightsProps {
  insights: LearningInsight[]
  student: User
  onActionTaken?: (insightId: string) => void
  showRecommendations?: boolean
}

// Workflow Types
export interface ProcessingWorkflowStep {
  id: string
  name: string
  status: 'pending' | 'processing' | 'completed' | 'failed' | 'skipped'
  progress_percentage: number
  estimated_duration_minutes?: number
  dependencies?: string[]
  can_retry: boolean
  can_skip: boolean
}

export interface ProcessingWorkflow {
  id: string
  lesson_id: string
  workflow_type: 'full_processing' | 'transcription_only' | 'cards_only' | 'analysis_only'
  status: 'pending' | 'processing' | 'completed' | 'failed' | 'cancelled'
  steps: ProcessingWorkflowStep[]
  current_step?: string
  started_at?: string
  completed_at?: string
  total_cost_cents: number
}

// API Response Types for AI Services
export interface AIServiceResponse<T = any> {
  success: boolean
  data?: T
  error?: string
  processing_time_ms: number
  cost_cents?: number
  service_provider: string
  request_id?: string
}

// Error Types for AI Processing
export interface AIProcessingError {
  code: 'RATE_LIMIT_EXCEEDED' | 'QUOTA_EXCEEDED' | 'INVALID_INPUT' | 'SERVICE_UNAVAILABLE' | 'PROCESSING_TIMEOUT' | 'UNKNOWN_ERROR'
  message: string
  details?: any
  retryable: boolean
  retry_after_seconds?: number
}

// =============================================
// PHASE 4: MODERATION, REALTIME & ADMIN TYPES
// =============================================

// Content Moderation Types
export interface ContentFlag {
  id: string
  content_type: 'lesson' | 'card' | 'comment' | 'transcript' | 'user_profile'
  content_id: string
  reporter_id: string
  flag_category: 'inappropriate' | 'incorrect' | 'spam' | 'offensive' | 'copyright' | 'misleading' | 'other'
  flag_reason: string
  evidence_text?: string
  evidence_screenshots?: string[]
  severity_level: number
  status: 'pending' | 'under_review' | 'resolved' | 'dismissed'
  anonymous_report: boolean
  resolved_by?: string
  resolved_at?: string
  resolution_notes?: string
  created_at: string
  updated_at: string
  reporter?: User
  resolver?: User
}

export interface ModerationQueueItem {
  id: string
  content_flag_id: string
  content_type: string
  content_id: string
  priority_score: number
  assigned_moderator_id?: string
  status: 'pending' | 'in_progress' | 'completed' | 'escalated'
  review_deadline?: string
  escalation_level: number
  context_data?: any
  created_at: string
  updated_at: string
  flag?: ContentFlag
  moderator?: User
}

export interface ModerationAction {
  id: string
  queue_item_id: string
  moderator_id: string
  action_type: 'approve' | 'reject' | 'remove' | 'warn_user' | 'ban_user' | 'edit_content' | 'escalate'
  action_reason: string
  previous_content?: any
  new_content?: any
  user_notified: boolean
  notification_sent_at?: string
  created_at: string
  moderator?: User
  queue_item?: ModerationQueueItem
}

export interface UserViolation {
  id: string
  user_id: string
  violation_type: 'content_violation' | 'spam' | 'harassment' | 'impersonation' | 'copyright' | 'multiple_accounts'
  severity: 'minor' | 'moderate' | 'major' | 'severe'
  description: string
  moderation_action_id?: string
  points_assigned: number
  expires_at?: string
  is_active: boolean
  created_at: string
  user?: User
  action?: ModerationAction
}

export interface AutomatedModeration {
  id: string
  content_type: string
  content_id: string
  content_text: string
  ai_service_provider?: 'openai' | 'azure_ai' | 'google_ai' | 'custom'
  moderation_result: any
  confidence_score?: number
  flags_detected: string[]
  action_taken: 'none' | 'flagged' | 'blocked' | 'requires_review'
  human_review_required: boolean
  reviewed_by_human: boolean
  human_reviewer_id?: string
  human_review_at?: string
  human_review_result?: 'confirmed' | 'overruled' | 'modified'
  processing_time_ms?: number
  cost_cents: number
  created_at: string
}

// Realtime Collaborative Features Types
export interface StudyRoom {
  id: string
  name: string
  description?: string
  host_id: string
  lesson_id?: string
  room_code: string
  max_participants: number
  current_participants: number
  is_public: boolean
  requires_approval: boolean
  status: 'active' | 'paused' | 'ended' | 'archived'
  session_config: any
  started_at: string
  ended_at?: string
  created_at: string
  updated_at: string
  host?: User
  lesson?: Lesson
  participants?: StudyRoomParticipant[]
}

export interface StudyRoomParticipant {
  id: string
  room_id: string
  user_id: string
  role: 'host' | 'moderator' | 'participant'
  joined_at: string
  left_at?: string
  is_active: boolean
  progress_sync: any
  last_seen: string
  user?: User
  room?: StudyRoom
}

export interface StudyRoomEvent {
  id: string
  room_id: string
  user_id?: string
  event_type: 'card_flip' | 'card_answer' | 'chat_message' | 'progress_sync' | 'user_join' | 'user_leave' | 'session_pause' | 'session_resume'
  event_data: any
  timestamp: string
  processed: boolean
  user?: User
}

export interface RealtimeNotification {
  id: string
  user_id: string
  notification_type: 'study_invitation' | 'lesson_update' | 'card_approved' | 'achievement_unlocked' | 'reminder' | 'system_alert'
  title: string
  message: string
  data: any
  priority: 'low' | 'normal' | 'high' | 'urgent'
  read_at?: string
  dismissed_at?: string
  expires_at?: string
  delivery_method: string[]
  sent_via: string[]
  created_at: string
}

export interface LiveClassSession {
  id: string
  lesson_id: string
  teacher_id: string
  session_name: string
  status: 'scheduled' | 'live' | 'paused' | 'ended'
  started_at?: string
  ended_at?: string
  recording_enabled: boolean
  recording_url?: string
  max_students: number
  current_students: number
  session_config: any
  created_at: string
  updated_at: string
  lesson?: Lesson
  teacher?: User
  participants?: LiveClassParticipant[]
}

export interface LiveClassParticipant {
  id: string
  session_id: string
  student_id: string
  joined_at: string
  left_at?: string
  engagement_score: number
  questions_asked: number
  cards_completed: number
  attention_duration_minutes: number
  last_activity: string
  student?: User
  session?: LiveClassSession
}

// Admin Console Types
export interface SystemHealthMetric {
  id: string
  metric_type: 'cpu_usage' | 'memory_usage' | 'database_performance' | 'api_response_time' | 'error_rate' | 'active_users' | 'storage_usage'
  metric_value: number
  metric_unit?: string
  threshold_warning?: number
  threshold_critical?: number
  status: 'normal' | 'warning' | 'critical'
  additional_data?: any
  recorded_at: string
}

export interface SecurityAuditLog {
  id: string
  event_type: 'login_attempt' | 'failed_login' | 'privilege_escalation' | 'data_access' | 'data_modification' | 'account_creation' | 'password_change' | 'suspicious_activity'
  user_id?: string
  ip_address?: string
  user_agent?: string
  resource_accessed?: string
  action_performed?: string
  success: boolean
  risk_score: number
  geolocation?: any
  session_id?: string
  additional_context?: any
  created_at: string
  user?: User
}

export interface PlatformAnalytic {
  id: string
  metric_name: string
  metric_category: 'user_engagement' | 'learning_outcomes' | 'content_performance' | 'system_usage' | 'financial'
  time_period: 'hourly' | 'daily' | 'weekly' | 'monthly'
  period_start: string
  period_end: string
  metric_value: number
  metric_unit?: string
  dimensions?: any
  calculated_at: string
}

export interface UserSession {
  id: string
  user_id: string
  session_token: string
  ip_address?: string
  user_agent?: string
  device_info?: any
  location_data?: any
  started_at: string
  last_activity: string
  ended_at?: string
  duration_minutes?: number
  pages_visited: number
  actions_performed: number
  is_active: boolean
  user?: User
}

// Analytics and Dashboard Types
export interface ModerationStats {
  total_flags: number
  pending_flags: number
  resolved_flags: number
  avg_resolution_time_hours: number
  top_categories: any
  moderator_performance: any
}

export interface SystemHealth {
  cpu_usage: number
  memory_usage: number
  active_connections: number
  error_rate: number
  response_time_ms: number
  status: 'normal' | 'warning' | 'critical'
}

export interface UserAnalytics {
  total_users: number
  active_users: number
  new_users: number
  user_retention_rate: number
  avg_session_duration: number
  top_user_activities: any
}

export interface PlatformMetrics {
  daily_active_users: number
  monthly_active_users: number
  total_lessons: number
  total_cards: number
  total_study_sessions: number
  average_session_duration: number
  completion_rate: number
  user_satisfaction_score: number
  revenue_metrics: any
  growth_metrics: any
}

export interface LearningEffectivenessMetrics {
  average_retention_rate: number
  optimal_interval_adherence: number
  card_effectiveness_scores: any
  learning_path_completion: number
  time_to_mastery: number
  spaced_repetition_effectiveness: number
}

export interface CostAnalytics {
  ai_processing_costs: number
  infrastructure_costs: number
  per_user_cost: number
  cost_per_lesson: number
  cost_trends: any
  optimization_opportunities: any
}

// Component Props for Phase 4 Features
export interface ModerationQueueProps {
  queueItems: ModerationQueueItem[]
  onActionTaken: (itemId: string, action: string, reason: string) => void
  onAssignModerator: (itemId: string, moderatorId: string) => void
  showBulkActions?: boolean
  currentUser: User
}

export interface ContentFlagModalProps {
  isOpen: boolean
  onClose: () => void
  contentType: string
  contentId: string
  onSubmit: (flagData: Partial<ContentFlag>) => void
}

export interface ModerationDashboardProps {
  stats: ModerationStats
  queueItems: ModerationQueueItem[]
  moderators: User[]
  onRefresh: () => void
}

export interface LiveStudyRoomProps {
  room: StudyRoom
  currentUser: User
  onLeaveRoom: () => void
  onSendMessage: (message: string) => void
  onSyncProgress: (progress: any) => void
}

export interface RealtimeNotificationsProps {
  notifications: RealtimeNotification[]
  onMarkAsRead: (notificationId: string) => void
  onDismiss: (notificationId: string) => void
  maxVisible?: number
}

export interface LiveClassMonitorProps {
  session: LiveClassSession
  participants: LiveClassParticipant[]
  onEndSession: () => void
  onSendAlert: (studentId: string, message: string) => void
  realTimeData: any
}

export interface SystemHealthDashboardProps {
  metrics: SystemHealthMetric[]
  health: SystemHealth
  alerts: any[]
  onAcknowledgeAlert: (alertId: string) => void
}

export interface UserManagementConsoleProps {
  users: User[]
  analytics: UserAnalytics
  onUserAction: (userId: string, action: string) => void
  onBulkAction: (userIds: string[], action: string) => void
  filters: any
}

export interface ContentAnalyticsProps {
  analytics: PlatformAnalytic[]
  metrics: PlatformMetrics
  timeRange: string
  onTimeRangeChange: (range: string) => void
}

export interface SecurityAuditProps {
  logs: SecurityAuditLog[]
  onExportLogs: (filters: any) => void
  onInvestigate: (logId: string) => void
  riskThreshold: number
}

export interface PlatformMetricsProps {
  metrics: PlatformMetrics
  timeRange: string
  onDrillDown: (metric: string) => void
  showComparisons?: boolean
}

export interface LearningEffectivenessAnalyticsProps {
  metrics: LearningEffectivenessMetrics
  lessons: Lesson[]
  onOptimize: (lessonId: string) => void
  showRecommendations?: boolean
}

export interface CostAnalyticsProps {
  analytics: CostAnalytics
  timeRange: string
  onOptimize: (area: string) => void
  showPredictions?: boolean
}

// Mobile and Responsive Types
export interface MobileStudyInterfaceProps {
  lesson: Lesson
  cards: SRCard[]
  onCardReview: (cardId: string, quality: QualityRating) => void
  touchGestures?: boolean
  offlineMode?: boolean
}

export interface TabletTeacherConsoleProps {
  lessons: Lesson[]
  students: User[]
  analytics: TeacherStats
  onCreateLesson: () => void
  onViewAnalytics: (lessonId: string) => void
}

// Security and Compliance Types
export interface SecurityMonitoringProps {
  threats: any[]
  alerts: any[]
  onBlockThreat: (threatId: string) => void
  onDismissAlert: (alertId: string) => void
  realTimeMode?: boolean
}

export interface ComplianceCenterProps {
  compliance_status: any
  audit_reports: any[]
  data_requests: any[]
  onGenerateReport: (type: string) => void
  onProcessDataRequest: (requestId: string) => void
}

// Performance and Integration Types
export interface PerformanceMonitorProps {
  metrics: SystemHealthMetric[]
  optimizations: any[]
  onApplyOptimization: (optimizationId: string) => void
  showRecommendations?: boolean
}

export interface IntegrationCenterProps {
  integrations: any[]
  webhooks: any[]
  api_keys: any[]
  onConfigureIntegration: (integrationId: string) => void
  onTestWebhook: (webhookId: string) => void
}

export interface APIDocumentationProps {
  endpoints: any[]
  authentication: any
  examples: any[]
  onTryEndpoint: (endpoint: string, params: any) => void
}

// Testing and Quality Assurance Types
export interface TestingSuiteProps {
  test_results: any[]
  coverage_reports: any[]
  performance_tests: any[]
  onRunTests: (testSuite: string) => void
  onViewReport: (reportId: string) => void
}

export interface QualityMetricsProps {
  code_quality: any
  test_coverage: number
  bug_reports: any[]
  user_feedback: any[]
  onViewDetails: (metric: string) => void
}

// Request/Response Types for Phase 4
export interface FlagContentRequest {
  content_type: string
  content_id: string
  flag_category: string
  flag_reason: string
  evidence_text?: string
  anonymous?: boolean
}

export interface CreateStudyRoomRequest {
  name: string
  description?: string
  lesson_id?: string
  is_public?: boolean
  max_participants?: number
}

export interface JoinStudyRoomRequest {
  room_code: string
}

export interface StudyRoomEventRequest {
  room_id: string
  event_type: string
  event_data: any
}

export interface ModerationActionRequest {
  queue_id: string
  action_type: string
  action_reason: string
  new_content?: any
}

// Utility Types for Phase 4
export type ModerationStatus = 'pending' | 'under_review' | 'resolved' | 'dismissed'
export type ModerationActionType = 'approve' | 'reject' | 'remove' | 'warn_user' | 'ban_user' | 'edit_content' | 'escalate'
export type ViolationSeverity = 'minor' | 'moderate' | 'major' | 'severe'
export type StudyRoomStatus = 'active' | 'paused' | 'ended' | 'archived'
export type NotificationPriority = 'low' | 'normal' | 'high' | 'urgent'
export type SystemStatus = 'normal' | 'warning' | 'critical'
export type SecurityEventType = 'login_attempt' | 'failed_login' | 'privilege_escalation' | 'data_access' | 'data_modification' | 'account_creation' | 'password_change' | 'suspicious_activity'