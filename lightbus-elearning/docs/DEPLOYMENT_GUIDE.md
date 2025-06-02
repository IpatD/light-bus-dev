# 🚀 Light Bus E-Learning Platform - Production Deployment Guide

## Overview

This comprehensive guide provides step-by-step instructions for deploying the Light Bus E-Learning Platform to production environments. The platform supports multiple deployment strategies including cloud hosting, self-hosted solutions, and enterprise infrastructure.

## 📋 Pre-Deployment Checklist

### System Requirements
- [ ] **Node.js**: Version 18.0 or higher
- [ ] **PostgreSQL**: Version 14.0 or higher
- [ ] **Docker**: Version 20.0 or higher (for containerized deployment)
- [ ] **SSL Certificate**: Valid HTTPS certificate
- [ ] **Domain Name**: Configured DNS settings

### Service Dependencies
- [ ] **Supabase Account**: For database and backend services
- [ ] **OpenAI API Key**: For AI content generation and analysis
- [ ] **AssemblyAI API Key**: For advanced audio transcription
- [ ] **Vercel Account**: For frontend deployment (recommended)
- [ ] **CDN Setup**: For static asset delivery

### Security Prerequisites
- [ ] **Environment Variables**: Secure configuration management
- [ ] **Database Backup**: Automated backup strategy
- [ ] **SSL/TLS**: End-to-end encryption
- [ ] **Access Controls**: Firewall and security groups
- [ ] **Monitoring**: Application and infrastructure monitoring

## 🌐 Deployment Architecture Options

### Option 1: Cloud Deployment (Recommended)
```
Frontend: Vercel (Next.js)
Backend: Supabase Cloud
Database: Supabase PostgreSQL
CDN: Vercel Edge Network
Functions: Supabase Edge Functions
```

### Option 2: Self-Hosted Deployment
```
Frontend: Docker Container (Nginx)
Backend: Self-hosted Supabase
Database: PostgreSQL Server
CDN: CloudFlare or AWS CloudFront
Functions: Docker Containers
```

### Option 3: Enterprise Deployment
```
Frontend: Kubernetes Cluster
Backend: Enterprise Supabase
Database: Managed PostgreSQL
CDN: Enterprise CDN Solution
Functions: Kubernetes Jobs
```

## 🚀 Cloud Deployment (Vercel + Supabase)

### Step 1: Supabase Project Setup

1. **Create Supabase Project**
```bash
# Navigate to https://supabase.com/dashboard
# Click "New Project"
# Set project name: lightbus-elearning-prod
# Choose region closest to your users
# Set database password (strong password required)
```

2. **Configure Project Settings**
```bash
# In Supabase Dashboard:
# 1. Go to Settings > API
# 2. Copy Project URL and anon key
# 3. Generate service role key
# 4. Configure authentication providers if needed
```

3. **Apply Database Migrations**
```bash
# Install Supabase CLI
npm install -g supabase

# Link to your project
supabase link --project-ref YOUR_PROJECT_REF

# Apply all migrations
supabase db push

# Verify migration success
supabase db diff
```

4. **Deploy Edge Functions**
```bash
# Deploy AI processing functions
supabase functions deploy process-lesson-audio --project-ref YOUR_PROJECT_REF
supabase functions deploy generate-flashcards --project-ref YOUR_PROJECT_REF
supabase functions deploy analyze-content --project-ref YOUR_PROJECT_REF

# Verify function deployment
supabase functions list
```

### Step 2: Frontend Deployment (Vercel)

1. **Prepare Environment Variables**
```bash
# Create production environment file
cp .env.local.example .env.production

# Configure production values:
NEXT_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=your-anon-key
NEXT_PUBLIC_APP_URL=https://your-domain.com
NODE_ENV=production

# AI Service Configuration
OPENAI_API_KEY=your-openai-key
ASSEMBLYAI_API_KEY=your-assemblyai-key
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
```

2. **Deploy to Vercel**
```bash
# Install Vercel CLI
npm install -g vercel

# Build and test locally
npm run build
npm run start

# Deploy to Vercel
vercel --prod

# Configure environment variables in Vercel dashboard
# Project Settings > Environment Variables
```

3. **Configure Custom Domain**
```bash
# In Vercel Dashboard:
# 1. Go to Project Settings > Domains
# 2. Add your custom domain
# 3. Configure DNS records as instructed
# 4. Verify SSL certificate activation
```

### Step 3: Database Configuration

1. **Enable Row Level Security**
```sql
-- Verify RLS is enabled on all tables
SELECT schemaname, tablename, rowsecurity 
FROM pg_tables 
WHERE schemaname = 'public';

-- Enable RLS if not already enabled
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE lessons ENABLE ROW LEVEL SECURITY;
-- Repeat for all tables
```

2. **Configure Database Optimizations**
```sql
-- Create performance indexes
CREATE INDEX CONCURRENTLY idx_sr_reviews_next_review 
ON sr_reviews(next_review_date) 
WHERE next_review_date <= NOW();

CREATE INDEX CONCURRENTLY idx_lessons_teacher_id 
ON lessons(teacher_id);

CREATE INDEX CONCURRENTLY idx_lesson_participants_student_id 
ON lesson_participants(student_id);

-- Update table statistics
ANALYZE;
```

3. **Set Up Automated Backups**
```bash
# In Supabase Dashboard:
# 1. Go to Settings > Database
# 2. Configure automated backups
# 3. Set backup retention (7-30 days recommended)
# 4. Test backup restoration process
```

### Step 4: AI Service Configuration

1. **Configure OpenAI Integration**
```bash
# Test OpenAI API connectivity
curl -H "Authorization: Bearer $OPENAI_API_KEY" \
     -H "Content-Type: application/json" \
     https://api.openai.com/v1/models
```

2. **Configure AssemblyAI Integration**
```bash
# Test AssemblyAI API connectivity
curl -H "Authorization: $ASSEMBLYAI_API_KEY" \
     https://api.assemblyai.com/v2/upload
```

3. **Configure Function Environment Variables**
```bash
# In Supabase Dashboard:
# 1. Go to Edge Functions > Settings
# 2. Add environment variables:
#    - OPENAI_API_KEY
#    - ASSEMBLYAI_API_KEY
#    - SUPABASE_SERVICE_ROLE_KEY
```

## 🐳 Self-Hosted Deployment

### Step 1: Server Preparation

1. **Server Requirements**
```bash
# Minimum specifications:
CPU: 4 cores
RAM: 8GB
Storage: 100GB SSD
Network: 1Gbps
OS: Ubuntu 20.04 LTS or similar
```

2. **Install Dependencies**
```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Docker and Docker Compose
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Install Node.js
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# Install PostgreSQL
sudo apt install postgresql postgresql-contrib
```

### Step 2: Database Setup

1. **Configure PostgreSQL**
```bash
# Create database and user
sudo -u postgres psql
CREATE DATABASE lightbus_production;
CREATE USER lightbus_user WITH ENCRYPTED PASSWORD 'secure_password';
GRANT ALL PRIVILEGES ON DATABASE lightbus_production TO lightbus_user;
\q

# Configure connection settings
sudo nano /etc/postgresql/*/main/postgresql.conf
# Set: listen_addresses = '*'
# Set: max_connections = 200

sudo nano /etc/postgresql/*/main/pg_hba.conf
# Add: host all all 0.0.0.0/0 md5

sudo systemctl restart postgresql
```

2. **Apply Database Schema**
```bash
# Clone repository
git clone <repository-url>
cd lightbus-elearning

# Install dependencies
npm install

# Apply migrations
npx supabase db reset --db-url postgresql://lightbus_user:secure_password@localhost:5432/lightbus_production
```

### Step 3: Application Deployment

1. **Build Application**
```bash
# Set production environment
export NODE_ENV=production

# Install dependencies
npm ci --production

# Build application
npm run build

# Create production bundle
tar -czf lightbus-production.tar.gz .next package*.json
```

2. **Docker Deployment**
```dockerfile
# Create Dockerfile
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --production
COPY .next .next/
COPY public public/
EXPOSE 3000
CMD ["npm", "start"]
```

```bash
# Build and run container
docker build -t lightbus-elearning .
docker run -d \
  --name lightbus-app \
  -p 3000:3000 \
  --env-file .env.production \
  lightbus-elearning
```

### Step 4: Reverse Proxy Setup (Nginx)

```nginx
# /etc/nginx/sites-available/lightbus
server {
    listen 80;
    server_name your-domain.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name your-domain.com;

    ssl_certificate /path/to/ssl/certificate.crt;
    ssl_certificate_key /path/to/ssl/private.key;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
}
```

## 🔧 Environment Configuration

### Production Environment Variables

```bash
# Application Configuration
NODE_ENV=production
NEXT_PUBLIC_APP_URL=https://your-domain.com

# Database Configuration
NEXT_PUBLIC_SUPABASE_URL=https://your-supabase-url.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=your-anon-key
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key

# AI Services
OPENAI_API_KEY=your-openai-api-key
ASSEMBLYAI_API_KEY=your-assemblyai-api-key

# Security Configuration
JWT_SECRET=your-jwt-secret
ENCRYPTION_KEY=your-encryption-key

# Monitoring & Analytics
SENTRY_DSN=your-sentry-dsn
ANALYTICS_ID=your-analytics-id
```

### Security Configuration

```bash
# SSL/TLS Configuration
SSL_CERT_PATH=/path/to/certificate.crt
SSL_KEY_PATH=/path/to/private.key
SSL_CHAIN_PATH=/path/to/chain.crt

# CORS Configuration
ALLOWED_ORIGINS=https://your-domain.com,https://admin.your-domain.com

# Rate Limiting
RATE_LIMIT_WINDOW=900000  # 15 minutes
RATE_LIMIT_MAX=100        # 100 requests per window
```

## 📊 Database Migration & Rollback

### Production Migration Process

1. **Pre-Migration Checklist**
```bash
# Create database backup
pg_dump -h localhost -U lightbus_user lightbus_production > backup_$(date +%Y%m%d_%H%M%S).sql

# Test migration on staging environment
npx supabase db diff --schema public
```

2. **Apply Migration**
```bash
# Apply migration with rollback preparation
npx supabase db push --create-backup

# Verify migration success
npx supabase db diff
psql -h localhost -U lightbus_user -d lightbus_production -c "\dt"
```

3. **Rollback Strategy**
```bash
# If rollback needed, restore from backup
psql -h localhost -U lightbus_user -d lightbus_production < backup_file.sql

# Or use Supabase rollback
npx supabase db reset --db-url $DATABASE_URL
```

## ⚡ Edge Functions Deployment

### Function Deployment Process

1. **Prepare Functions**
```bash
# Test functions locally
npx supabase functions serve

# Build functions for production
npx supabase functions deploy process-lesson-audio --no-verify-jwt
npx supabase functions deploy generate-flashcards --no-verify-jwt
npx supabase functions deploy analyze-content --no-verify-jwt
```

2. **Configure Function Environment**
```bash
# Set function secrets
supabase secrets set OPENAI_API_KEY=your-key
supabase secrets set ASSEMBLYAI_API_KEY=your-key
supabase secrets set SUPABASE_SERVICE_ROLE_KEY=your-key
```

3. **Monitor Function Performance**
```bash
# View function logs
supabase functions logs process-lesson-audio

# Monitor function metrics
# Available in Supabase Dashboard > Edge Functions
```

## 🔍 Performance Optimization

### Database Optimization

```sql
-- Performance monitoring queries
SELECT * FROM pg_stat_user_tables 
WHERE relname IN ('profiles', 'lessons', 'sr_cards', 'sr_reviews');

-- Index optimization
CREATE INDEX CONCURRENTLY idx_performance_1 ON sr_reviews(user_id, next_review_date);
CREATE INDEX CONCURRENTLY idx_performance_2 ON lessons(teacher_id, created_at);

-- Query optimization
VACUUM ANALYZE;
```

### Frontend Optimization

```bash
# Build optimization
npm run build

# Analyze bundle size
npx @next/bundle-analyzer

# Configure CDN caching
# Set cache headers for static assets
# Enable gzip compression
# Implement service worker for offline support
```

### Monitoring Setup

```bash
# Application monitoring
npm install @sentry/nextjs

# Infrastructure monitoring
# Set up Prometheus + Grafana
# Configure alerting rules
# Monitor key metrics:
# - Response time
# - Error rate
# - Database performance
# - AI service usage
```

## 🚨 Rollback Procedures

### Application Rollback

```bash
# Quick rollback using Vercel
vercel rollback [deployment-url]

# Manual rollback for self-hosted
docker stop lightbus-app
docker run -d --name lightbus-app-rollback previous-image-tag
```

### Database Rollback

```bash
# Restore from automated backup
pg_restore -h localhost -U lightbus_user -d lightbus_production backup_file.dump

# Or use point-in-time recovery
# Configure continuous archiving for PITR capability
```

## ✅ Post-Deployment Verification

### Health Checks

```bash
# Application health check
curl -f https://your-domain.com/api/health

# Database connectivity
psql -h your-db-host -U username -d database -c "SELECT 1;"

# AI services connectivity
curl -H "Authorization: Bearer $OPENAI_API_KEY" https://api.openai.com/v1/models
```

### Functional Testing

```bash
# User registration/login
# Lesson creation
# Flashcard generation
# AI processing workflow
# Real-time features
# Content moderation
```

### Performance Testing

```bash
# Load testing with Apache Bench
ab -n 1000 -c 10 https://your-domain.com/

# Database performance testing
pgbench -h localhost -U lightbus_user -d lightbus_production

# Monitor during load test:
# - Response times
# - Error rates
# - Database performance
# - Memory usage
```

## 📞 Support & Maintenance

### Monitoring Dashboard URLs
- **Application Metrics**: https://your-domain.com/admin/metrics
- **Database Monitoring**: Supabase Dashboard
- **Error Tracking**: Sentry Dashboard
- **Performance Monitoring**: Vercel Analytics

### Emergency Contacts
- **Technical Lead**: [Contact Information]
- **Database Administrator**: [Contact Information]
- **DevOps Engineer**: [Contact Information]

### Escalation Procedures
1. **Level 1**: Application restart, basic troubleshooting
2. **Level 2**: Database intervention, advanced debugging
3. **Level 3**: Architecture changes, major incident response

---

**Deployment Guide Version**: 1.0  
**Last Updated**: 2025  
**Next Review**: Quarterly

This guide ensures reliable, secure, and scalable deployment of the Light Bus E-Learning Platform in production environments.