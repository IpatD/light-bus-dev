import { createClient } from '@supabase/supabase-js'

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!

export const supabase = createClient(supabaseUrl, supabaseAnonKey)

// Database types will be generated from Supabase CLI
export type Database = {
  public: {
    Tables: {
      profiles: {
        Row: {
          id: string
          updated_at: string
          name: string
          role: 'student' | 'teacher' | 'admin'
          email: string
          created_at: string
        }
        Insert: {
          id: string
          updated_at?: string
          name: string
          role: 'student' | 'teacher' | 'admin'
          email: string
          created_at?: string
        }
        Update: {
          id?: string
          updated_at?: string
          name?: string
          role?: 'student' | 'teacher' | 'admin'
          email?: string
          created_at?: string
        }
      }
      lessons: {
        Row: {
          id: string
          teacher_id: string
          name: string
          description: string | null
          scheduled_at: string
          duration_minutes: number | null
          has_audio: boolean
          recording_path: string | null
          created_at: string
          updated_at: string
        }
        Insert: {
          id?: string
          teacher_id: string
          name: string
          description?: string | null
          scheduled_at: string
          duration_minutes?: number | null
          has_audio?: boolean
          recording_path?: string | null
          created_at?: string
          updated_at?: string
        }
        Update: {
          id?: string
          teacher_id?: string
          name?: string
          description?: string | null
          scheduled_at?: string
          duration_minutes?: number | null
          has_audio?: boolean
          recording_path?: string | null
          created_at?: string
          updated_at?: string
        }
      }
      sr_cards: {
        Row: {
          id: string
          lesson_id: string
          created_by: string
          front_content: string
          back_content: string
          card_type: string
          difficulty_level: number
          tags: string[]
          status: 'pending' | 'approved' | 'rejected'
          approved_by: string | null
          approved_at: string | null
          created_at: string
          updated_at: string
        }
        Insert: {
          id?: string
          lesson_id: string
          created_by: string
          front_content: string
          back_content: string
          card_type?: string
          difficulty_level?: number
          tags?: string[]
          status?: 'pending' | 'approved' | 'rejected'
          approved_by?: string | null
          approved_at?: string | null
          created_at?: string
          updated_at?: string
        }
        Update: {
          id?: string
          lesson_id?: string
          created_by?: string
          front_content?: string
          back_content?: string
          card_type?: string
          difficulty_level?: number
          tags?: string[]
          status?: 'pending' | 'approved' | 'rejected'
          approved_by?: string | null
          approved_at?: string | null
          created_at?: string
          updated_at?: string
        }
      }
    }
  }
}

// Auth helper functions
export const getCurrentUser = async () => {
  const { data: { user } } = await supabase.auth.getUser()
  return user
}

export const getCurrentSession = async () => {
  const { data: { session } } = await supabase.auth.getSession()
  return session
}

export const signOut = async () => {
  const { error } = await supabase.auth.signOut()
  return { error }
}

// Profile helper functions
export const getUserProfile = async (userId: string) => {
  const { data, error } = await supabase
    .from('profiles')
    .select('*')
    .eq('id', userId)
    .single()
  
  return { data, error }
}

export const updateUserProfile = async (userId: string, updates: Database['public']['Tables']['profiles']['Update']) => {
  const { data, error } = await supabase
    .from('profiles')
    .update(updates)
    .eq('id', userId)
    .select()
    .single()
  
  return { data, error }
}