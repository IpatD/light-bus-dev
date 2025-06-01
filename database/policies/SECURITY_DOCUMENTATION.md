# Row Level Security (RLS) Documentation
## Light Bus E-Learning Platform

**Created:** 2025-05-30  
**Version:** 1.0  
**Security Level:** Enterprise-Grade  

---

## Table of Contents

1. [Overview](#overview)
2. [Security Model](#security-model)
3. [Policy Summary](#policy-summary)
4. [Table-by-Table Analysis](#table-by-table-analysis)
5. [Access Control Matrix](#access-control-matrix)
6. [Security Features](#security-features)
7. [Implementation Guide](#implementation-guide)
8. [Monitoring & Maintenance](#monitoring--maintenance)
9. [Compliance & Privacy](#compliance--privacy)
10. [Troubleshooting](#troubleshooting)

---

## Overview

The Light Bus e-learning platform implements comprehensive Row Level Security (RLS) policies across 10 core tables with a total of **43 policies**. This enterprise-grade security model ensures data protection, user privacy, and appropriate access control for educational content.

### Architecture Highlights

- **Role-based access control** (Teacher/Student/Moderator)
- **User ownership validation** using `auth.uid()`
- **Lesson participation verification**
- **Multi-tier content moderation**
- **Forced RLS** on sensitive tables
- **Public content discovery** with authentication

---

## Security Model

### Core Principles

1. **Principle of Least Privilege**: Users access only data they need
2. **Defense in Depth**: Multiple validation layers
3. **Data Ownership**: Clear ownership and control mechanisms
4. **Educational Context**: Access based on teacher-student relationships
5. **Privacy by Design**: Default privacy with opt-in sharing

### Authentication Requirements

- All policies require authenticated users (`auth.uid()`)
- No anonymous access to any educational data
- Session-based authentication through Supabase Auth

### Authorization Hierarchy

```
System Admin (bypasses RLS)
├── Moderator (content oversight)
├── Teacher (classroom control)
└── Student (participation-based access)
```

---

## Policy Summary

| Table | RLS Status | Policies | Security Level | Primary Use |
|-------|------------|----------|----------------|-------------|
| `lesson_participants` | ENABLED + FORCED | 5 | High | Enrollment Management |
| `lessons` | ENABLED + FORCED | 7 | High | Course Content |
| `profiles` | ENABLED | 4 | Standard | User Information |
| `sr_card_flags` | ENABLED | 7 | Standard | Content Moderation |
| `sr_cards` | ENABLED | 8 | Standard | Learning Content |
| `sr_progress` | ENABLED | 3 | Standard | Personal Analytics |
| `sr_reviews` | ENABLED | 2 | Standard | Study Sessions |
| `student_lesson_interactions` | ENABLED | 4 | Standard | Engagement Tracking |
| `summaries` | ENABLED | 2 | Standard | Lesson Summaries |
| `transcripts` | ENABLED + FORCED | 7 | High | Audio/Video Content |

**Total Policies: 43**

---

## Table-by-Table Analysis

### 1. Lesson Participants (5 Policies)

**Security Level:** High (Forced RLS)  
**Purpose:** Manage student enrollment in lessons

#### Policies:
- Students view own participations
- Teachers view lesson participations
- Teachers add participants
- Teachers update participation status
- Teachers remove participants

#### Security Features:
- Forced RLS prevents policy bypass
- Student privacy protection
- Teacher classroom authority
- Enrollment validation

### 2. Lessons (7 Policies)

**Security Level:** High (Forced RLS)  
**Purpose:** Core educational content management

#### Policies:
- Teachers view own lessons
- Students view participated lessons
- Teachers create lessons
- Teachers update own lessons
- Teachers delete own lessons
- Public lessons viewable by authenticated users
- Archived lessons restricted access

#### Security Features:
- Teacher ownership control
- Student participation validation
- Public content discovery
- Archive protection

### 3. Profiles (4 Policies)

**Security Level:** Standard  
**Purpose:** User information and networking

#### Policies:
- Users view own profile
- Users update own profile
- Teachers view student profiles
- Public profiles viewable

#### Security Features:
- Personal information protection
- Educational relationship validation
- Optional public networking
- Teacher-student connection

### 4. SR Card Flags (7 Policies)

**Security Level:** Standard  
**Purpose:** Content moderation system

#### Policies:
- Users view own card flags
- Teachers view lesson card flags
- Users flag own cards
- Teachers flag lesson cards
- Moderators view all flags
- Moderators update flags
- Users update own flags

#### Security Features:
- Multi-tier moderation
- Content quality control
- Role-based permissions
- Community self-regulation

### 5. SR Cards (8 Policies)

**Security Level:** Standard  
**Purpose:** Spaced repetition learning content

#### Policies:
- Users view own cards
- Students view lesson cards
- Teachers view lesson cards
- Users create lesson cards
- Teachers create cards in lessons
- Users update own cards
- Teachers update lesson cards
- Public cards viewable by all

#### Security Features:
- Personal learning content
- Lesson-based sharing
- Teacher oversight
- Community knowledge sharing

### 6. SR Progress (3 Policies)

**Security Level:** Standard  
**Purpose:** Personal learning analytics

#### Policies:
- Users view own progress
- Teachers view lesson progress
- Users update own progress

#### Security Features:
- Private learning data
- Teacher insights
- Algorithm integration
- Performance tracking

### 7. SR Reviews (2 Policies)

**Security Level:** Standard  
**Purpose:** Study session records

#### Policies:
- Users manage own reviews
- Teachers view lesson reviews

#### Security Features:
- Personal study sessions
- Engagement monitoring
- Algorithm data
- Privacy protection

### 8. Student Lesson Interactions (4 Policies)

**Security Level:** Standard  
**Purpose:** Classroom engagement tracking

#### Policies:
- Students view own interactions
- Teachers view lesson interactions
- Students create interactions
- Students update own interactions

#### Security Features:
- Participation tracking
- Engagement analytics
- Real-time monitoring
- Student ownership

### 9. Summaries (2 Policies)

**Security Level:** Standard  
**Purpose:** AI-generated lesson summaries

#### Policies:
- Users view lesson summaries
- Teachers manage lesson summaries

#### Security Features:
- Study aid access
- Teacher content control
- AI-generated content
- Quality management

### 10. Transcripts (7 Policies)

**Security Level:** High (Forced RLS)  
**Purpose:** Audio/video lesson transcriptions

#### Policies:
- Teachers view lesson transcripts
- Students view lesson transcripts
- Teachers create lesson transcripts
- Teachers update lesson transcripts
- Teachers delete lesson transcripts
- Public transcripts viewable
- Approved transcripts enhanced access

#### Security Features:
- Sensitive content protection
- Quality approval workflow
- Accessibility support
- Privacy compliance

---

## Access Control Matrix

| Role | lesson_participants | lessons | profiles | sr_cards | sr_progress | transcripts |
|------|-------------------|---------|----------|----------|-------------|-------------|
| **Student** | View own | View enrolled | View own/public | View own/lesson | View own | View enrolled |
| **Teacher** | Full lesson control | Full own control | View students | Full lesson control | View lesson | Full lesson control |
| **Moderator** | - | - | - | - | - | Approval workflow |
| **Public** | None | View public | View public | View public | None | View public approved |
| **Anonymous** | None | None | None | None | None | None |

---

## Security Features

### 1. User Ownership Validation

```sql
USING (user_id = auth.uid())
```

- Validates user owns the record
- Prevents cross-user data access
- Core security mechanism

### 2. Lesson Participation Validation

```sql
lesson_id IN (
    SELECT lesson_id FROM lesson_participants 
    WHERE user_id = auth.uid()
)
```

- Ensures student is enrolled in lesson
- Prevents unauthorized lesson access
- Educational context validation

### 3. Teacher Authority Validation

```sql
lesson_id IN (
    SELECT id FROM lessons WHERE teacher_id = auth.uid()
)
```

- Validates teacher owns the lesson
- Enables classroom management
- Maintains educational hierarchy

### 4. Role-Based Permissions

```sql
EXISTS (
    SELECT 1 FROM profiles 
    WHERE id = auth.uid() AND role = 'moderator'
)
```

- Enables special role privileges
- Supports moderation workflows
- Maintains platform quality

### 5. Public Content Access

```sql
is_public = true AND auth.uid() IS NOT NULL
```

- Allows content discovery
- Requires authentication
- Protects against abuse

---

## Implementation Guide

### 1. Enable RLS on Tables

```sql
-- Standard RLS
ALTER TABLE table_name ENABLE ROW LEVEL SECURITY;

-- Forced RLS (high security)
ALTER TABLE table_name ENABLE ROW LEVEL SECURITY;
ALTER TABLE table_name FORCE ROW LEVEL SECURITY;
```

### 2. Create Policies

```sql
CREATE POLICY "policy_name" ON table_name
    FOR operation
    USING (condition)
    WITH CHECK (condition);
```

### 3. Management Functions

```sql
-- Enable all RLS
SELECT enable_all_rls();

-- Disable all RLS (maintenance)
SELECT disable_all_rls();

-- Check RLS status
SELECT * FROM get_rls_status();
```

### 4. Policy Monitoring

```sql
-- View all policies
SELECT * FROM policy_security_overview;

-- Check policy effectiveness
SELECT table_name, policy_count 
FROM get_rls_status() 
ORDER BY policy_count DESC;
```

---

## Monitoring & Maintenance

### 1. Regular Security Audits

- Review policy effectiveness monthly
- Monitor access patterns
- Validate security assumptions
- Update policies as needed

### 2. Performance Monitoring

- Check query performance with RLS
- Monitor index usage
- Optimize policy conditions
- Scale security measures

### 3. Policy Testing

```sql
-- Test as different users
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" TO '{"sub":"user-id"}';

-- Verify policy behavior
SELECT COUNT(*) FROM protected_table;
```

### 4. Security Metrics

- Policy bypass attempts
- Authentication failures
- Unauthorized access logs
- Data access patterns

---

## Compliance & Privacy

### 1. Educational Privacy (FERPA)

- Student data protection
- Parental consent workflows
- Data retention policies
- Access audit trails

### 2. Data Protection (GDPR)

- Right to access
- Right to deletion
- Data portability
- Consent management

### 3. Platform Security

- Authentication requirements
- Data encryption
- Secure communications
- Regular security updates

---

## Troubleshooting

### Common Issues

#### 1. Policy Not Working

```sql
-- Check if RLS is enabled
SELECT tablename, rowsecurity FROM pg_tables 
WHERE tablename = 'your_table';

-- Check policy exists
SELECT * FROM pg_policies 
WHERE tablename = 'your_table';
```

#### 2. Access Denied Errors

- Verify user authentication
- Check policy conditions
- Validate user roles
- Review table relationships

#### 3. Performance Issues

- Add indexes for policy conditions
- Optimize complex joins
- Consider policy simplification
- Monitor query plans

### Emergency Procedures

#### Disable RLS (Emergency Only)

```sql
-- Disable specific table
ALTER TABLE table_name DISABLE ROW LEVEL SECURITY;

-- Disable all tables
SELECT disable_all_rls();
```

#### Re-enable Security

```sql
-- Re-enable all security
SELECT enable_all_rls();

-- Verify policies active
SELECT * FROM get_rls_status();
```

---

## Best Practices

### 1. Policy Design

- Keep policies simple and readable
- Use descriptive policy names
- Document security assumptions
- Test with real users

### 2. Performance

- Index columns used in policies
- Avoid complex subqueries
- Use efficient join patterns
- Monitor query performance

### 3. Maintenance

- Regular security reviews
- Policy effectiveness testing
- Documentation updates
- Security training

### 4. Development

- Test policies in development
- Use realistic test data
- Validate all user roles
- Document policy changes

---

## Conclusion

The Light Bus platform implements enterprise-grade Row Level Security with 43 comprehensive policies across 10 tables. This security model ensures data protection, user privacy, and appropriate access control while supporting the educational mission of the platform.

The policies provide:
- **Complete data protection** for all user types
- **Educational context awareness** for classroom management
- **Scalable security architecture** for platform growth
- **Compliance readiness** for educational regulations

Regular monitoring, testing, and updates ensure the security model remains effective and aligned with platform evolution.

---

**Document Version:** 1.0  
**Last Updated:** 2025-05-30  
**Next Review:** 2025-06-30  
**Security Contact:** Platform Security Team