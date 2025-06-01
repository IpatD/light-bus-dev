Okay, this is a significant shift in approach! We're now building a comprehensive, step-by-step, full-stack plan where AI assists in code generation, and human users are central to iterative testing and feedback. This will be highly detailed, breaking down each feature into frontend design considerations, backend (Supabase) implementation, and specific checkpoints for AI-User collaboration.

No references to previous versions. Everything self-contained.

Light Bus E-Learning Platform: AI-Assisted, User-Centric Full-Stack Development Plan

Project Vision: To collaboratively create an enterprise-grade e-learning platform, "Light Bus," leveraging AI for code generation and human users for iterative testing. The platform will utilize scientifically-proven spaced repetition techniques (SM-2 algorithm) to deliver a personalized, engaging, and effective learning experience, all built on the Supabase backend.

Core Principles for AI-User Collaboration:

AI as a Pair Programmer: AI generates initial code (frontend components, Supabase schema, PL/pgSQL, Edge Functions) based on detailed specifications.

Human as the Architect & Reviewer: Humans define the architecture, provide detailed prompts, review AI-generated code for correctness, security, and adherence to design.

Iterative Refinement: Short cycles of AI generation -> Human testing & feedback -> AI refinement.

Clear Checkpoints: Defined points where human users test specific functionalities and provide feedback.

Focus on "Energetic Clarity": The UI/UX design philosophy (bright, motivating colors, pronounced edges, clean structure) guides AI in generating frontend code.

Overall System Architecture (Supabase Focused)

graph TD
    subgraph "User Interface Layer (Frontend - React/Next.js)"
        UI_Web[Web Application]
        UI_Mobile[Mobile App (Future Scope)]
        UI_Admin[Admin Dashboard (Integrated into Web App)]
    end

    subgraph "Supabase Backend Platform"
        SB_Auth[Supabase Auth (JWT, RLS Integration)]
        SB_PostgREST[Supabase PostgREST API (Auto-generated from DB)]
        SB_DB[PostgreSQL Database (Tables, PL/pgSQL Functions, RLS)]
        SB_Storage[Supabase Storage (Audio/Video Files)]
        SB_EdgeFunc[Supabase Edge Functions (Deno - for custom server-side logic, external service calls)]
        SB_Realtime[Supabase Realtime (WebSockets for live updates)]
    end

    subgraph "External Services (Called by Supabase Edge Functions)"
        Ext_Audio[Audio Processing Service (e.g., AssemblyAI)]
        Ext_AI[AI Summarization Service (e.g., OpenAI API)]
        Ext_Email[Email Notification Service (e.g., SendGrid)]
    end

    UI_Web -- Supabase JS Client --> SB_Auth
    UI_Web -- Supabase JS Client --> SB_PostgREST
    UI_Web -- Supabase JS Client --> SB_Storage
    UI_Web -- Supabase JS Client --> SB_EdgeFunc
    UI_Web -- Supabase JS Client --> SB_Realtime

    SB_PostgREST --> SB_DB
    SB_Auth -- Manages users in --> SB_DB
    SB_EdgeFunc -- Can access --> SB_DB
    SB_Realtime -- Listens to changes in --> SB_DB

    SB_EdgeFunc --> Ext_Audio
    SB_EdgeFunc --> Ext_AI
    SB_EdgeFunc --> Ext_Email


Technology Stack:

Frontend:

Framework: Next.js (React)

Supabase Client: supabase-js

Styling: Tailwind CSS (for rapid implementation of "pronounced edges" and design system)

State Management: Zustand or React Context (for simplicity with Next.js)

Charting: Recharts

Forms: React Hook Form with Zod for validation

Backend (Supabase Platform):

Database: PostgreSQL

API: PostgREST

Authentication: Supabase Auth

Storage: Supabase Storage

Serverless Functions: Supabase Edge Functions (Deno, TypeScript)

Business Logic: PL/pgSQL functions

External Services: As defined in architecture.

AI Code Generation: Model like GPT-4 or specialized code generation tools.

Development Environment: VS Code with Supabase CLI, GitHub Copilot (optional, for human dev).

Phase 0: Project Setup & Core Authentication (Sprint 0-1)

Goal: Establish foundational project structures, implement user registration and login, and define the initial profiles table with RLS.

Module 0.1: Project Initialization & Supabase Setup

Task: Initialize Next.js project with Tailwind CSS.

AI Prompt: "Generate a Next.js 14 project setup with TypeScript and Tailwind CSS configured. Include basic directory structure (components, pages, lib, styles)."

Human Check: Verify project structure, Tailwind config, basic globals.css with "Energetic Clarity" primary font (Inter) and base styles.

Task: Create Supabase project.

Human Action: Create project via Supabase dashboard. Note API URL and Anon Key.

Human Check: Supabase project accessible.

Task: Initialize Supabase locally and link to remote project.

Human Action: supabase init, supabase login, supabase link --project-ref <YOUR_PROJECT_ID>.

Human Check: Local Supabase environment can pull schema from remote.

Task: Setup environment variables in Next.js for Supabase.

Human Action: Create .env.local with NEXT_PUBLIC_SUPABASE_URL and NEXT_PUBLIC_SUPABASE_ANON_KEY.

Human Check: Variables accessible in the Next.js app.

Task: Create Supabase client utility.

AI Prompt: "Generate a Supabase client utility file (lib/supabaseClient.js or .ts) for a Next.js project using environment variables."

Human Check: Client initializes correctly.

Module 0.2: User Profile Table & RLS

Task: Define profiles table schema (as per backend docs).

AI Prompt: "Generate a SQL migration script for Supabase to create the profiles table with columns: id (UUID, references auth.users, PK), updated_at (TIMESTAMPTZ), name (TEXT, NOT NULL), role (TEXT, NOT NULL, CHECK role IN ('student', 'teacher', 'admin')), email (TEXT, UNIQUE, NOT NULL, references auth.users.email for consistency, though auth.users is the source of truth for auth email)."

Human Check: SQL syntax correct, constraints match, foreign key to auth.users.id established. Apply migration: supabase db push (if using remote directly for early dev) or supabase migration new create_profiles_table then supabase migration up.

Task: Create RLS policies for profiles.

AI Prompt: "Generate SQL for Supabase RLS policies for the profiles table:

Users can view their own profile.

Users can update their own profile (name only initially).

Admins can view all profiles.

(Future: Teachers can view profiles of students in their lessons - placeholder for now)."

Human Check: Policies use auth.uid() and auth.role() correctly. Enable RLS on the table.

Task: Create a DB trigger to populate profiles on new user signup.

AI Prompt: "Generate a PostgreSQL function and trigger for Supabase. The function should run after a new user is inserted into auth.users and populate the profiles table with the user's id, email, and default role (e.g., 'student') and name (can be derived from email or set to a default)." (Note: name and role can also be passed in options.data during signUp).

Human Check: Trigger function correctly inserts into profiles. Test by manually adding a user in Supabase Auth dashboard.

Module 0.3: Frontend Authentication UI & Logic

Task: Design and implement Registration Page.

Frontend Design Details:

Layout: Centered form on a clean page.

Fields: Name, Email, Password, Confirm Password, Role (Dropdown: Student, Teacher).

Styling: "Energetic Clarity" - Learning Orange for button, Deep Charcoal for text, Clean White background, pronounced edges on form inputs and button (0px border-radius).

AI Prompt (Component): "Generate a Next.js React component for a Registration page (pages/auth/register.tsx) using Tailwind CSS. Include fields for name, email, password, confirm password, and a role selector ('student', 'teacher'). Use React Hook Form and Zod for validation. On submit, call supabase.auth.signUp with email, password, and options: { data: { name, role } }. Handle success (redirect to login/dashboard) and errors (display messages)."

Human Check: Component renders correctly, styles match design, form validation works, Supabase call is correct.

Task: Design and implement Login Page.

Frontend Design Details:

Layout: Similar to registration.

Fields: Email, Password. "Forgot Password?" link.

Styling: Consistent with registration page.

AI Prompt (Component): "Generate a Next.js React component for a Login page (pages/auth/login.tsx) using Tailwind CSS. Include fields for email and password. Use React Hook Form and Zod. On submit, call supabase.auth.signInWithPassword. Handle success (redirect to dashboard) and errors."

Human Check: Component renders correctly, Supabase call correct, error handling.

Task: Implement basic Navigation Bar with Login/Logout state.

Frontend Design Details:

Simple header: Logo, "Dashboard" (if logged in), "Logout" (if logged in) or "Login" / "Register" (if logged out).

Styling: Deep Charcoal background, Clean White or Learning Orange text for links.

AI Prompt (Component): "Generate a React component for a Navigation Bar. It should display 'Login' and 'Register' links if no user is logged in. If a user is logged in (check supabase.auth.getSession()), display their email/name, a 'Dashboard' link, and a 'Logout' button. Logout should call supabase.auth.signOut() and redirect."

Human Check: Nav bar state changes correctly based on auth status. Logout works.

Task: Implement Auth State Listener.

AI Prompt: "Show how to use supabase.auth.onAuthStateChange in a Next.js _app.tsx or a layout component to manage user session state globally and redirect users (e.g., to login if trying to access a protected page while logged out, or to dashboard if trying to access login page while logged in)."

Human Check: Auth state is managed correctly across page navigations.

AI-User Collaboration Checkpoint 0.A (End of Sprint 1):

User Testing Focus:

Can users successfully register as a 'student' and 'teacher'?

Is the profiles table populated correctly (including role and name from signup)?

Can users log in with their credentials?

Does the navigation bar update correctly based on login status?

Can users log out?

Are error messages clear for incorrect login/registration attempts?

Does the UI adhere to the "Energetic Clarity" design (colors, edges, fonts)?

Feedback Collection: User provides feedback on usability, clarity, and any bugs.

AI Iteration: Human provides feedback to AI for code refinement if needed.

Phase 1: Student Dashboard & Core Spaced Repetition Flow (Sprint 2-3)

Goal: Students can view their dashboard, see lessons they are enrolled in (mocked for now), see cards due for review, and complete a review session with the SM-2 algorithm logic working.

Module 1.1: Student Dashboard UI Shell & Profile Display

Task: Design Student Dashboard Layout (as per frontend docs).

Frontend Design Details:

Header: User name, progress summary (e.g., "Cards due today: X", "Streak: Y days").

Main sections: "Due Cards", "Recent Lessons", "Achievements".

Styling: "Energetic Clarity" - Learning Orange for primary actions, Achievement Yellow for streak/achievements, Focus Amber for highlights.

AI Prompt (Component): "Generate a Next.js page component for a Student Dashboard (pages/dashboard/student.tsx). It should be a protected route. Fetch and display the logged-in user's name from their profiles table. Lay out sections for 'Due Cards', 'Recent Lessons', and 'Achievements' using Tailwind CSS according to the 'Energetic Clarity' design (placeholders for content)."

Human Check: Page is protected, user's name displays, layout matches design doc.

Task: Implement get_user_profile and get_user_stats PL/pgSQL functions.

AI Prompt (SQL): "Generate the PL/pgSQL function get_user_profile(p_user_id UUID) that returns the user's profile from the profiles table. Ensure it's SECURITY DEFINER if needed for RLS. Also, generate get_user_stats(p_user_id UUID) which returns a JSON object with mock data for now: { total_reviews: 0, avg_quality: 0.0, study_streak: 0, cards_learned: 0 }."

Human Check: Functions compile, return expected data. Test RPC via Supabase SQL editor.

Task: Fetch and display user stats on dashboard.

AI Prompt (Frontend): "In the Student Dashboard component, call the get_user_stats RPC function using supabase.rpc() and display the mock stats."

Human Check: Mock stats are displayed correctly.

Module 1.2: Lesson & Card Tables (Schema & Mock Data)

Task: Define lessons, lesson_participants, sr_cards tables (as per backend docs).

AI Prompt (SQL): "Generate SQL migration scripts for Supabase to create:

lessons table (id, teacher_id FK profiles, name, date, etc.).

lesson_participants table (lesson_id FK lessons, student_id FK profiles, PK on both).

sr_cards table (id, lesson_id FK lessons, created_by FK profiles, front_content, back_content, status ('pending', 'approved'), etc.)."

Human Check: Schemas are correct, FKs established. Apply migrations.

Task: Implement RLS for lessons, lesson_participants, sr_cards.

AI Prompt (SQL): "Generate RLS policies:

lessons: Students can see lessons they are a participant in. Teachers can see lessons they created.

lesson_participants: Students/Teachers can see participation records related to lessons they have access to.

sr_cards: Students can see 'approved' cards from lessons they are in. Teachers can see all cards from lessons they created."

Human Check: RLS policies are correct. Enable RLS.

Task: Create mock data for lessons and cards.

Human Action: Manually insert a few sample lessons, assign the test student to one lesson, and create a few 'approved' SR cards for that lesson.

Human Check: Mock data exists and is accessible according to RLS when querying as the test student.

Module 1.3: Displaying Due Cards & Study Session Flow

Task: Implement get_cards_due PL/pgSQL function.

AI Prompt (SQL): "Generate get_cards_due(p_user_id UUID, p_limit INT) PL/pgSQL function. For now, it should return all 'approved' sr_cards from lessons the p_user_id is enrolled in, limited by p_limit. (Actual SM-2 scheduling logic will come later in sr_reviews). Return sr_cards columns."

Human Check: Function returns expected mock cards for the test student.

Task: Implement EnhancedFlashcard component (as per frontend docs).

Frontend Design Details: As specified in your frontend doc (container, content, quality buttons styles with "Energetic Clarity").

AI Prompt (Component): "Generate the EnhancedFlashcard React component as detailed in the frontend design document. It should take card (with front_content, back_content), showAnswer, onFlip, and onReview props. Style with Tailwind CSS for 'Energetic Clarity' (0px border-radius, orange/yellow/gray colors, specific font sizes for question/answer)."

Human Check: Component renders correctly, props work, styling matches.

Task: Implement Study Session Page.

Frontend Design Details: Focus area for the EnhancedFlashcard. Minimal distractions. Progress indicator (e.g., "Card 1 of 5").

AI Prompt (Page): "Create a Next.js page pages/study/[lesson_id].tsx. On load, it should call get_cards_due RPC for the current user (mock lesson_id for now, or assume all due cards are for one session). Display one card at a time using EnhancedFlashcard. Implement onFlip to toggle showAnswer. The onReview prop on EnhancedFlashcard should (for now) log the quality and advance to the next card or show a 'Session Complete' message."

Human Check: Can fetch due cards, display them one by one, flip card, select quality, and complete a session.

Module 1.4: Spaced Repetition Logic (SM-2 Core)

Task: Define sr_reviews and sr_progress tables.

AI Prompt (SQL): "Generate SQL migration scripts for sr_reviews (id, card_id, student_id, scheduled_for, completed_at, quality_rating, interval_days, ease_factor, repetition_count) and sr_progress (id, student_id, lesson_id, cards_total, cards_reviewed, etc.) tables."

Human Check: Schemas correct. Apply migrations. Implement basic RLS (user owns their reviews/progress).

Task: Implement calculate_sr_interval PL/pgSQL function (core SM-2 logic from backend docs).

AI Prompt (SQL): "Generate the calculate_sr_interval(p_current_interval INT, p_easiness_factor DECIMAL, p_quality INT) PL/pgSQL function implementing the SM-2 algorithm logic as described in the backend documentation (quality 0-5, EF updates, next interval calculation)."

Human Check: Logic matches SM-2 specification. Test with various inputs.

Task: Implement record_sr_review PL/pgSQL function.

AI Prompt (SQL): "Generate record_sr_review(p_user_id UUID, p_card_id UUID, p_quality INT, p_response_time_ms INT) PL/pgSQL function. This function should:

Fetch the card's current ease_factor, repetition_count, interval_days for the user (from sr_reviews or a new user-card specific table if preferred, for simplicity let's assume we might need to store last review per user per card. Or, for a first pass, assume first review for all cards).

Call calculate_sr_interval with current values and p_quality.

Insert a new record into sr_reviews with the review details, new EF, new interval, updated repetition count, and scheduled_for = NOW() + (new_interval_days * '1 day'::interval).

Update sr_progress for the user and lesson (increment cards_reviewed, update last_review_date, next_review_date)."

Human Check: Function correctly records review, updates EF/interval, schedules next review, and updates progress. This is a complex one, careful testing needed.

Task: Integrate record_sr_review into Study Session Page.

AI Prompt (Frontend): "Update the Study Session Page. The onReview callback of EnhancedFlashcard should now call the record_sr_review RPC with the card_id, selected quality, and measured responseTime."

Human Check: Review is successfully recorded in the database. sr_reviews and sr_progress tables are updated.

AI-User Collaboration Checkpoint 1.A (End of Sprint 3):

User Testing Focus (Student Role):

Does the Student Dashboard display mock stats correctly?

Can the student navigate to a "Study Session" (e.g., from a "Start Review" button on the dashboard that fetches all due cards)?

Are flashcards displayed correctly using the EnhancedFlashcard component?

Does flipping the card work?

Can the student select a quality rating (Again, Hard, Good, Easy)?

Is the review recorded in the sr_reviews table with correct EF, interval, and next scheduled_for date based on SM-2?

Is sr_progress updated?

Is the UI for flashcards and study session adhering to "Energetic Clarity"?

Feedback Collection: Detailed feedback on the study flow, card appearance, and perceived accuracy of scheduling (even if based on initial reviews).

AI Iteration: Refine PL/pgSQL logic, frontend components based on feedback.

Phase 2: Teacher - Lesson & Card Management (Sprint 4-5)

Goal: Teachers can create lessons, upload recordings (stubbed processing), manually create and approve flashcards for their lessons, and assign students.

Module 2.1: Teacher Dashboard & Lesson Creation UI

Task: Design Teacher Dashboard Layout.

Frontend Design Details: Sections for "My Lessons", "Create New Lesson", "Class Analytics (placeholder)". Accent color: Teacher Purple.

AI Prompt (Component): "Generate a Next.js page for a Teacher Dashboard (pages/dashboard/teacher.tsx). Protected route. Display a list of lessons created by the teacher (fetch from lessons table where teacher_id is current user). Include a button/link to 'Create New Lesson'. Style with 'Energetic Clarity' and Teacher Purple accents."

Human Check: Layout correct, fetches and displays teacher's (mock) lessons.

Task: Implement create_lesson PL/pgSQL function.

AI Prompt (SQL): "Generate create_lesson(p_title TEXT, p_description TEXT, p_scheduled_at TIMESTAMPTZ, p_teacher_id UUID) PL/pgSQL function. It should insert into lessons and also into lesson_participants to add the teacher as a participant with a 'teacher' role (if your schema supports this, or just ensure teacher ownership)."

Human Check: Function creates lesson and correctly assigns teacher.

Task: Implement Lesson Creation Form/Page.

Frontend Design Details: (As per frontend docs: Title, Date, Duration, Has Audio checkbox). Learning Orange for "Create" button.

AI Prompt (Page/Component): "Generate a Next.js page/modal for 'Create Lesson'. Form fields: title, description (optional), scheduled date. On submit, call create_lesson RPC. Redirect to Teacher Dashboard or lesson detail page on success."

Human Check: Form works, lesson created, teacher listed as owner/participant.

Module 2.2: Basic Lesson Detail View & Participant Management

Task: Implement get_lesson_details PL/pgSQL function.

AI Prompt (SQL): "Generate get_lesson_details(p_lesson_id UUID) PL/pgSQL function. It should return lesson details and a list of participants (names/roles from profiles joined via lesson_participants). Ensure RLS allows teacher owner or student participant to call."

Human Check: Function returns lesson details and participants.

Task: Implement Lesson Detail Page (Teacher View).

Frontend Design Details: Display lesson info, list of participants, sections for "Manage Content (Cards)", "Upload Recording".

AI Prompt (Page): "Generate a Next.js page pages/lessons/[lesson_id].tsx. Fetch lesson details using get_lesson_details RPC. Display lesson information. For teachers, show a list of participants and an 'Add Student' button (non-functional for now)."

Human Check: Lesson details and participants displayed for teacher.

Task: Implement add_lesson_participant and remove_lesson_participant PL/pgSQL functions.

AI Prompt (SQL): "Generate add_lesson_participant(p_lesson_id UUID, p_student_id UUID) and remove_lesson_participant(p_lesson_id UUID, p_student_id UUID) PL/pgSQL functions. They should manage entries in lesson_participants."

Human Check: Functions correctly add/remove students.

Task: (Optional UI for Add/Remove Student - can be deferred)

Module 2.3: Manual Card Creation & Approval by Teacher

Task: Implement create_sr_card PL/pgSQL function.

AI Prompt (SQL): "Generate create_sr_card(p_lesson_id UUID, p_created_by UUID, p_front_content TEXT, p_back_content TEXT, p_card_type TEXT, p_difficulty_level INT, p_tags TEXT[]) PL/pgSQL function. It should insert into sr_cards with status = 'pending' by default if created by teacher for their lesson, or status = 'approved' if admin/policy allows." (For simplicity, let's say teacher-created cards for their own lesson are auto-approved or they explicitly approve them).

Human Check: Function creates card with correct status.

Task: Implement UI for Teachers to Add/Edit SR Cards within a Lesson Detail Page.

Frontend Design Details: Form for Front Content, Back Content. "Save Card" button. List of existing cards for the lesson with "Edit", "Approve" (if pending), "Delete" buttons.

AI Prompt (Component): "In the Lesson Detail Page (Teacher View), add a section for 'Flashcards'. Include a form to create a new card (front/back text). On submit, call create_sr_card RPC. Display a list of cards associated with the lesson (fetch from sr_cards table filtered by lesson_id). Each card should show front/back, status, and an 'Approve Card' button if status is 'pending'."

Human Check: Teacher can create cards for their lesson. Cards are listed.

Task: Implement approve_sr_card and update_sr_card PL/pgSQL functions.

AI Prompt (SQL): "Generate approve_sr_card(p_card_id UUID, p_approved_by UUID) to update sr_cards.status to 'approved' and set approved_by, approved_at. Generate update_sr_card(p_card_id UUID, p_front_text TEXT, p_back_text TEXT, ...)."

Human Check: Functions work as expected.

Task: Connect "Approve Card" button in UI.

AI Prompt (Frontend): "Wire the 'Approve Card' button in the card list to call approve_sr_card RPC."

Human Check: Teacher can approve pending cards. Status updates in UI (may need re-fetch or optimistic update).

Module 2.4: Recording Upload Stub & Content Tables

Task: Define transcripts and summaries tables.

AI Prompt (SQL): "Generate SQL migration scripts for transcripts (id, lesson_id FK, content, transcript_type) and summaries (id, lesson_id FK, content)."

Human Check: Schemas correct. Basic RLS (access tied to lesson access).

Task: Implement UI for lesson recording upload (to Supabase Storage).

Frontend Design Details: File input button. Progress bar during upload.

AI Prompt (Component): "In the Lesson Detail Page (Teacher View), add an 'Upload Recording' section. Use <input type='file'>. On file selection, upload to Supabase Storage bucket (e.g., 'lesson-recordings') using supabase.storage.from(...).upload(). Display upload progress. On success, update lessons.recording_path with the storage path by calling an RPC function update_lesson_recording_path(p_lesson_id UUID, p_path TEXT)."

Human Check: File uploads to Supabase Storage. lessons.recording_path is updated.

Task: Implement update_lesson_recording_path PL/pgSQL function.

AI Prompt (SQL): "Generate update_lesson_recording_path(p_lesson_id UUID, p_path TEXT) PL/pgSQL function to update the recording_path and has_audio=TRUE in the lessons table."

Human Check: Function updates the lesson record.

AI-User Collaboration Checkpoint 2.A (End of Sprint 5):

User Testing Focus (Teacher Role):

Can the teacher view their dashboard and see their lessons?

Can the teacher create a new lesson?

Can the teacher view lesson details?

Can the teacher manually create SR cards (front/back) for their lesson?

Are these cards initially 'pending' (or 'approved' based on chosen logic)? Can the teacher approve them?

Can the teacher upload a mock audio file? Is lessons.recording_path updated?

(Student Role) Can students now see these teacher-created and approved cards in their study sessions for that lesson?

Is the teacher UI adhering to "Energetic Clarity" with Teacher Purple accents?

Feedback Collection: Usability of lesson/card creation, clarity of status, any issues.

AI Iteration: Refine based on feedback.

Phase 3: Content Processing Pipeline & Student Analytics (Sprint 6-8)

Goal: Implement the backend pipeline for audio transcription and summarization using Supabase Edge Functions and external AI services. Display this content to students. Implement student progress analytics.

Module 3.1: Supabase Edge Function for Audio Processing

Task: Design the Edge Function process-lesson-audio.

Logic Flow:

Receives lesson_id and storagePath.

Downloads audio file from Supabase Storage (or gets a signed URL for external service).

Calls external Audio Processing Service (e.g., AssemblyAI) with the audio.

Receives transcript.

Calls external AI Summarization Service (e.g., OpenAI) with the transcript.

Receives summary.

Saves transcript to transcripts table (via supabase.rpc('create_transcript', ...) or direct insert if using service key).

Saves summary to summaries table (via supabase.rpc('create_summary', ...)).

Updates lessons table flags (has_transcript=TRUE, has_summary=TRUE, transcription_progress=100).

AI Prompt (Deno/TS - Edge Function): "Generate a Supabase Edge Function named process-lesson-audio (Deno, TypeScript). It should:

Accept lesson_id and storagePath in the request body.

(Mock) Simulate calling an external transcription service (log input, return mock transcript text).

(Mock) Simulate calling an external summarization service (log input, return mock summary text).

Use the Supabase client (with service role key for backend updates) to call (mocked for now) RPCs create_transcript and create_summary, and to update the lessons table flags."

Human Check: Edge function structure is correct. Supabase client usage for backend updates is sound. Mocks are in place. Deploy Edge Function.

Task: Implement create_transcript and create_summary PL/pgSQL functions.

AI Prompt (SQL): "Generate create_transcript(p_lesson_id UUID, p_content TEXT, p_transcript_type TEXT) and create_summary(p_lesson_id UUID, p_content TEXT) PL/pgSQL functions to insert into their respective tables."

Human Check: Functions insert data correctly.

Task: Trigger Edge Function after recording upload.

Method 1 (DB Trigger): Create a DB trigger on lessons table, AFTER UPDATE OF recording_path that calls supabase.functions.invoke('process-lesson-audio', ...).

Method 2 (RPC): Modify update_lesson_recording_path RPC to also invoke the Edge Function.

AI Prompt (SQL/Deno): "Show how to create a PostgreSQL trigger function that invokes the Supabase Edge Function process-lesson-audio with lesson_id and new recording_path when lessons.recording_path is updated and not null."

Human Check: Trigger is set up correctly and invokes the Edge Function (check Edge Function logs).

Module 3.2: Integrate Real External AI Services

Task: Integrate actual Audio Processing Service into Edge Function.

Human Action: Choose service (e.g., AssemblyAI), get API key. Store key securely in Supabase secrets: supabase secrets set ASSEMBLYAI_API_KEY <key>.

AI Prompt (Deno/TS - Edge Function): "Update the process-lesson-audio Edge Function. Replace the mock transcription with a real call to AssemblyAI's API using its SDK or a fetch call. Retrieve the API key from Supabase secrets (Deno.env.get('ASSEMBLYAI_API_KEY')). Handle API response and errors."

Human Check: Transcription works with a real audio file. Transcript saved to DB.

Task: Integrate actual AI Summarization Service into Edge Function.

Human Action: Choose service (e.g., OpenAI), get API key. Store as Supabase secret.

AI Prompt (Deno/TS - Edge Function): "Update process-lesson-audio. After getting the transcript, replace mock summarization with a real call to OpenAI's Chat Completions API (using gpt-3.5-turbo or similar) to summarize the transcript. Retrieve API key from Supabase secrets. Handle API response and errors."

Human Check: Summarization works. Summary saved to DB. lessons flags updated.

Module 3.3: Display Transcript & Summary to Students

Task: Implement get_lesson_content PL/pgSQL function.

AI Prompt (SQL): "Generate get_lesson_content(p_lesson_id UUID) PL/pgSQL function that returns the lesson's transcript (from transcripts table) and summary (from summaries table) as a JSON object or separate records."

Human Check: Function returns transcript and summary for a processed lesson.

Task: Enhance Student Lesson View to show transcript/summary.

Frontend Design Details: Tabs or sections within a lesson view for "Overview", "Flashcards", "Transcript", "Summary".

AI Prompt (Frontend): "Create a Student Lesson Detail page (pages/lessons/student/[lesson_id].tsx). Fetch lesson details and content using get_lesson_details and get_lesson_content RPCs. Display the transcript and summary if available. Include a section/tab for 'Study Flashcards' for this lesson."

Human Check: Students can view transcripts and summaries for lessons that have been processed.

Module 3.4: Student Progress Analytics

Task: Implement get_user_lesson_progress and get_user_learning_analytics PL/pgSQL functions.

AI Prompt (SQL): "Generate get_user_lesson_progress(p_user_id UUID, p_lesson_id UUID) to return the student's record from sr_progress for that lesson. Generate get_user_learning_analytics(p_user_id UUID, p_days_back INT) to calculate and return JSON analytics (total reviews, avg quality, cards learned/mastered, daily breakdown) by querying sr_reviews and sr_progress for the user within the p_days_back period." (This will be complex, iterate with AI).

Human Check: Functions return accurate progress and analytics data.

Task: Implement Student Progress Dashboard UI (as per frontend docs).

Frontend Design Details: ProgressChart component, metrics cards. "Energetic Gradient" for charts.

AI Prompt (Component/Page): "Generate the Student Progress Dashboard page (pages/dashboard/student/progress.tsx). Use get_user_learning_analytics RPC to fetch data. Implement the ProgressChart component (using Recharts, as per frontend docs) to display reviews per day and average quality. Display other metrics in styled cards."

Human Check: Progress dashboard displays analytics correctly and visually appealingly.

AI-User Collaboration Checkpoint 3.A (End of Sprint 8):

User Testing Focus (Teacher Role):

Upload a short (real) audio file for a lesson.

Does the processing pipeline trigger? (Check lessons flags, transcripts, summaries tables after a few minutes).

Is the transcript reasonably accurate? Is the summary sensible?

User Testing Focus (Student Role):

Can students view the transcript and summary for a processed lesson?

Does the Student Progress Dashboard show meaningful (even if based on limited data) analytics?

Is the ProgressChart rendering correctly with "Energetic Gradient"?

Are all new UIs adhering to "Energetic Clarity"?

Feedback Collection: Accuracy of transcription/summary, usability of content display, clarity of analytics.

AI Iteration: Refine Edge Functions, PL/pgSQL analytics queries, frontend components.

Phase 4: Moderation, Teacher Analytics & Realtime (Sprint 9-10)

Goal: Implement card flagging and moderation. Provide teachers with analytics for their classes. Introduce basic realtime updates.

Module 4.1: Card Flagging & Moderation Workflow

Task: Define sr_card_flags table and RLS.

AI Prompt (SQL): "Generate SQL migration script for sr_card_flags (id, card_id, student_id, flag_type, comments, status ('open', 'resolved', 'dismissed'), resolved_by, etc.). Implement RLS: Students can create flags. Users who flagged can see their flags. Moderators/Admins can see all flags. Teachers can see flags on cards in their lessons."

Human Check: Schema and RLS correct.

Task: Implement flag_card, resolve_card_flag, get_pending_flags PL/pgSQL functions.

AI Prompt (SQL): "Generate PL/pgSQL functions:

flag_card(p_card_id UUID, p_student_id UUID, p_flag_type TEXT, p_comments TEXT) to insert into sr_card_flags.

resolve_card_flag(p_flag_id UUID, p_resolved_by UUID, p_resolution_notes TEXT) to update flag status to 'resolved'.

get_pending_flags(p_limit INT, p_offset INT) to return 'open' flags for moderators."

Human Check: Functions work as specified.

Task: UI for Students/Teachers to Flag Cards.

Frontend Design Details: Small "Flag" icon/button on flashcards. Modal to select flag type and add comments.

AI Prompt (Frontend): "Add a 'Flag Card' button to the EnhancedFlashcard component (visible during review). On click, open a modal with a dropdown for flag_type (incorrect, unclear, etc.) and a textarea for comments. On submit, call flag_card RPC."

Human Check: Flagging UI works, flag recorded in DB.

Task: UI for Moderators to Manage Flags.

Frontend Design Details: A "Moderation Queue" page listing pending flags. Ability to view flagged card, flag details, and resolve/dismiss.

AI Prompt (Page): "Create a pages/admin/moderation.tsx page (for users with 'moderator' or 'admin' role). Fetch pending flags using get_pending_flags RPC. Display flags in a table. For each flag, allow viewing card content (fetch sr_cards by ID) and provide buttons to 'Resolve' or 'Dismiss' (calling resolve_card_flag or a similar dismiss_card_flag RPC)."

Human Check: Moderators can view and action pending flags.

Module 4.2: Teacher Class Analytics

Task: Implement get_lesson_analytics PL/pgSQL function.

AI Prompt (SQL): "Generate get_lesson_analytics(p_lesson_id UUID) PL/pgSQL function. It should return JSON with stats for that lesson: avg student progress (from sr_progress), number of students, avg quality score on cards (from sr_reviews), most flagged cards, etc." (Iterate on complexity).

Human Check: Analytics query is reasonably performant and accurate.

Task: Implement Teacher Class Analytics Dashboard (as per frontend docs).

Frontend Design Details: Student performance grid, lesson effectiveness charts (avg quality scores). Teacher Purple accents.

AI Prompt (Page): "Create a Teacher Lesson Analytics page (pages/lessons/teacher/[lesson_id]/analytics.tsx). Fetch data using get_lesson_analytics RPC. Display metrics in cards and charts (e.g., bar chart for average quality scores per student)."

Human Check: Teacher can view analytics for their lessons.

Module 4.3: Basic Realtime Updates

Task: Enable Supabase Realtime on relevant tables (e.g., sr_cards status).

Human Action: In Supabase Dashboard, enable Realtime for sr_cards table.

Task: Subscribe to card status changes in Teacher's Lesson View.

AI Prompt (Frontend): "In the Teacher's Lesson Detail Page (where cards are listed), use supabase.channel(...).on('postgres_changes', ...) to listen for updates on the sr_cards table where lesson_id matches the current lesson. When a card's status changes (e.g., student flags it, or moderator approves it elsewhere), update the card's display in the list without a full page reload."

Human Check: If a card status is changed directly in DB or by another user, the Teacher's UI updates in realtime.

AI-User Collaboration Checkpoint 4.A (End of Sprint 10):

User Testing Focus (Student, Teacher, Moderator Roles):

(Student) Can students flag a card during review? Is the UI intuitive?

(Moderator) Can moderators see the queue of flagged cards? Can they resolve/dismiss flags? Does this update the card/flag status?

(Teacher) Can teachers see analytics for their lessons? Is the data meaningful?

(Teacher) If a card in their lesson is approved by a moderator (or another teacher with rights), does their lesson view update in (near) realtime to reflect the new status?

Are all new UIs adhering to "Energetic Clarity"?

Feedback Collection: Usability of moderation, clarity of teacher analytics, effectiveness of realtime updates.

AI Iteration: Refine based on feedback.

Phase 5: Admin Tools, Polish & Pre-Launch (Sprint 11-12)

Goal: Implement Admin console, conduct thorough testing, optimize performance, and prepare for launch.

Module 5.1: Admin User Management

Task: Implement Admin-specific PL/pgSQL functions for user management.

AI Prompt (SQL): "Generate PL/pgSQL functions for Admins:

admin_get_users(p_limit INT, p_offset INT, p_role_filter TEXT, p_search_term TEXT) to list users from profiles with filtering.

admin_update_user_role(p_user_id UUID, p_new_role TEXT) to change a user's role in profiles."

Human Check: Functions work, RLS must ensure only Admins can call these.

Task: Implement Admin User Management Console UI (as per frontend docs).

Frontend Design Details: Table of users, filters, search, "Edit Role" action. Admin Blue accents.

AI Prompt (Page): "Create an Admin User Management page (pages/admin/users.tsx). Fetch users using admin_get_users RPC. Display in a table with search and filter options. Allow admins to change a user's role by calling admin_update_user_role RPC."

Human Check: Admins can view and manage user roles.

Module 5.2: System Health & Stats for Admin

Task: Implement system_health_check and get_database_stats PL/pgSQL functions (as per backend docs).

AI Prompt (SQL): "Generate system_health_check() (e.g., returns { status: 'OK' } or checks DB connectivity) and get_database_stats() (e.g., counts from key tables, DB size estimate if possible from pg_catalog functions available to users)."

Human Check: Functions provide basic health/stats info.

Task: Implement Admin System Health Dashboard.

Frontend Design Details: Display key metrics from the RPC calls.

AI Prompt (Page): "Create an Admin System Health page (pages/admin/health.tsx). Call and display results from system_health_check and get_database_stats RPCs."

Human Check: Admins can view system health indicators.

Module 5.3: Final Testing, Optimization & Polish

Task: Comprehensive End-to-End Testing.

Human Action: Manually test all key user journeys for all roles. Document any bugs or UI/UX issues.

Task: Performance Optimization.

Human Action: Use browser dev tools to check FE performance. Review Supabase query performance for slow RPCs/queries.

AI Prompt (if issues found): "The RPC function get_user_learning_analytics is slow. Here's the current SQL: [...]. Can you suggest optimizations or indexing strategies for tables sr_reviews and sr_progress?"

Task: Accessibility Audit (WCAG 2.1 AA).

Human Action: Use tools like Axe, manual keyboard navigation, screen reader testing.

AI Prompt (if issues found): "The EnhancedFlashcard component is not fully keyboard accessible. How can I improve its focus management and ensure screen readers announce content changes correctly?"

Task: UI Polish and consistency check.

Human Action: Review all pages for adherence to "Energetic Clarity" design system. Check for consistent spacing, typography, colors, and pronounced edges.

Task: Review all RLS policies and security configurations in Supabase.

Human Action: Double-check that RLS is enabled on all tables and policies are restrictive enough. Review Edge Function security (use of service role key).

AI-User Collaboration Checkpoint 5.A (End of Sprint 12 - Pre-Launch):

User Testing Focus (All Roles, focused on overall experience):

Is the platform stable and relatively bug-free across all features?

Is the performance acceptable?

Is the UI consistent and does it effectively embody "Energetic Clarity"?

(Admin) Is the Admin console functional and useful?

Are there any remaining critical usability issues or security concerns?

Feedback Collection: Final punch list of issues. Go/No-Go decision for beta launch.

AI Iteration: Address critical bugs and feedback.

Deployment & Launch:

Human Action:

Ensure production Supabase project is configured correctly (backups, custom domain, etc.).

Deploy frontend to Vercel/Netlify production environment.

Run final smoke tests on production.

Announce launch / open to beta users.

Post-Launch: Ongoing AI-User Collaboration for Maintenance & Iteration:

Monitoring: Humans monitor Supabase dashboard, frontend error tracking (Sentry), and user feedback channels.

Bug Fixing:

Human: Identifies and documents bug.

AI Prompt: "Users report an error when X. Here's the error message and relevant code snippet: [...]. What could be the cause and how can I fix it?"

Human: Reviews AI suggestion, implements, tests.

New Feature Development: Follow similar AI-User collaboration cycle as above for new features based on user feedback and product roadmap.

Optimization:

Human: Identifies performance bottleneck (e.g., slow query from Supabase logs).

AI Prompt: "This query is slow: [...]. Can you suggest optimizations or alternative approaches?"

Human: Implements and tests AI suggestions.

This detailed, phased plan emphasizes the collaborative nature between AI code generation and human oversight/testing. Each module has clear tasks and checkpoints, allowing for iterative development and refinement, ensuring the final platform is robust, user-friendly, and aligns with the "Energetic Clarity" vision.