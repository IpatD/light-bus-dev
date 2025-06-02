# 🔧 Light Bus E-Learning Platform - Maintenance Guide

## Overview

This comprehensive maintenance guide provides detailed procedures for ongoing platform operations, including scheduled maintenance, performance optimization, backup strategies, security updates, and scaling procedures. Following these guidelines ensures optimal platform performance and reliability.

## 📅 Regular Maintenance Schedules

### Daily Maintenance Tasks

#### System Health Checks (Automated)

1. **Automated Monitoring**
   ```
   Daily Automated Checks:
   - Server uptime and performance metrics
   - Database connectivity and performance
   - Application response times
   - Error rate monitoring
   - Storage usage verification
   - Backup completion status
   - Security log review
   ```

2. **Manual Verification Tasks**
   ```
   Daily Manual Checks (5-10 minutes):
   1. Review system health dashboard
   2. Check error logs for anomalies
   3. Verify AI service functionality
   4. Monitor user activity patterns
   5. Review security alerts
   ```

#### Database Monitoring

1. **Performance Metrics**
   ```bash
   # Daily database health check queries
   
   -- Check connection pool usage
   SELECT state, count(*) 
   FROM pg_stat_activity 
   GROUP BY state;
   
   -- Monitor slow queries
   SELECT query, mean_exec_time, calls 
   FROM pg_stat_statements 
   ORDER BY mean_exec_time DESC 
   LIMIT 10;
   
   -- Check database size growth
   SELECT pg_size_pretty(pg_database_size('lightbus_production'));
   
   -- Verify backup completion
   SELECT * FROM pg_stat_archiver;
   ```

2. **Automated Alerts Configuration**
   ```yaml
   # Database monitoring alerts
   alerts:
     - name: "High CPU Usage"
       condition: cpu_usage > 80%
       duration: 5m
       action: notify_admin
     
     - name: "Slow Query Detected"
       condition: query_time > 1000ms
       duration: 1m
       action: log_and_notify
     
     - name: "Connection Pool Exhausted"
       condition: active_connections > 90%
       duration: 30s
       action: immediate_alert
   ```

### Weekly Maintenance Tasks

#### Database Maintenance

1. **Performance Optimization**
   ```sql
   -- Weekly database maintenance script
   
   -- Update table statistics
   ANALYZE;
   
   -- Rebuild indexes if fragmented
   REINDEX INDEX CONCURRENTLY idx_sr_reviews_next_review;
   REINDEX INDEX CONCURRENTLY idx_lessons_teacher_id;
   
   -- Clean up old processing logs (older than 30 days)
   DELETE FROM processing_logs 
   WHERE created_at < NOW() - INTERVAL '30 days';
   
   -- Vacuum tables to reclaim space
   VACUUM (ANALYZE, VERBOSE) sr_reviews;
   VACUUM (ANALYZE, VERBOSE) processing_jobs;
   ```

2. **Storage Management**
   ```bash
   # Weekly storage cleanup script
   
   # Clean up temporary files
   find /tmp -name "supabase-*" -mtime +7 -delete
   
   # Archive old log files
   find /var/log -name "*.log" -mtime +30 -exec gzip {} \;
   
   # Clean up old backup files (keep last 30 days)
   find /backup -name "*.sql" -mtime +30 -delete
   
   # Monitor disk usage
   df -h | grep -E "(80%|90%|95%)" && echo "WARNING: High disk usage detected"
   ```

#### Security Updates

1. **Dependency Updates**
   ```bash
   # Weekly dependency update process
   
   # Check for security updates
   npm audit
   
   # Update dependencies (non-breaking)
   npm update
   
   # Check for outdated packages
   npm outdated
   
   # Update Supabase CLI
   npm install -g supabase@latest
   ```

2. **Security Log Review**
   ```bash
   # Weekly security audit script
   
   # Review failed login attempts
   tail -1000 /var/log/auth.log | grep "Failed password"
   
   # Check for suspicious API requests
   grep -E "(40[1-4]|500)" /var/log/nginx/access.log | tail -100
   
   # Monitor unusual user activity
   psql -c "
   SELECT user_id, COUNT(*) as login_count 
   FROM audit_logs 
   WHERE action = 'login' 
   AND created_at > NOW() - INTERVAL '7 days'
   GROUP BY user_id 
   HAVING COUNT(*) > 100
   ORDER BY login_count DESC;"
   ```

### Monthly Maintenance Tasks

#### Performance Analysis

1. **System Performance Review**
   ```bash
   # Monthly performance analysis script
   
   # Generate performance report
   echo "=== MONTHLY PERFORMANCE REPORT ===" > /tmp/perf_report.txt
   echo "Date: $(date)" >> /tmp/perf_report.txt
   
   # Server metrics
   echo -e "\n--- SERVER METRICS ---" >> /tmp/perf_report.txt
   uptime >> /tmp/perf_report.txt
   free -h >> /tmp/perf_report.txt
   df -h >> /tmp/perf_report.txt
   
   # Database metrics
   echo -e "\n--- DATABASE METRICS ---" >> /tmp/perf_report.txt
   psql -c "SELECT * FROM pg_stat_database WHERE datname = 'lightbus_production';" >> /tmp/perf_report.txt
   
   # Application metrics
   echo -e "\n--- APPLICATION METRICS ---" >> /tmp/perf_report.txt
   curl -s http://localhost:3000/api/health >> /tmp/perf_report.txt
   ```

2. **Capacity Planning**
   ```sql
   -- Monthly capacity analysis queries
   
   -- User growth analysis
   SELECT 
     DATE_TRUNC('month', created_at) as month,
     COUNT(*) as new_users,
     SUM(COUNT(*)) OVER (ORDER BY DATE_TRUNC('month', created_at)) as total_users
   FROM profiles 
   WHERE created_at > NOW() - INTERVAL '12 months'
   GROUP BY DATE_TRUNC('month', created_at)
   ORDER BY month;
   
   -- Storage growth analysis
   SELECT 
     schemaname,
     tablename,
     pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size
   FROM pg_tables 
   WHERE schemaname = 'public'
   ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
   
   -- AI service usage analysis
   SELECT 
     DATE_TRUNC('month', created_at) as month,
     service_type,
     COUNT(*) as requests,
     AVG(processing_time) as avg_time
   FROM processing_jobs
   WHERE created_at > NOW() - INTERVAL '12 months'
   GROUP BY DATE_TRUNC('month', created_at), service_type
   ORDER BY month, service_type;
   ```

#### Security Audit

1. **Comprehensive Security Review**
   ```bash
   # Monthly security audit checklist
   
   # 1. Review user access permissions
   psql -c "
   SELECT 
     p.email,
     p.role,
     p.last_sign_in_at,
     CASE 
       WHEN p.last_sign_in_at < NOW() - INTERVAL '90 days' 
       THEN 'INACTIVE' 
       ELSE 'ACTIVE' 
     END as status
   FROM profiles p
   WHERE p.role IN ('admin', 'moderator')
   ORDER BY p.last_sign_in_at DESC;"
   
   # 2. Check for unused API keys
   psql -c "
   SELECT 
     key_name,
     last_used_at,
     created_at
   FROM api_keys
   WHERE last_used_at < NOW() - INTERVAL '30 days'
   OR last_used_at IS NULL;"
   
   # 3. Review RLS policies
   psql -c "
   SELECT 
     schemaname,
     tablename,
     policyname,
     permissive,
     roles,
     cmd,
     qual
   FROM pg_policies
   WHERE schemaname = 'public'
   ORDER BY tablename, policyname;"
   ```

2. **Vulnerability Assessment**
   ```bash
   # Monthly vulnerability scan
   
   # Scan npm dependencies
   npm audit --audit-level moderate
   
   # Check for SQL injection vulnerabilities
   grep -r "SELECT.*\$" src/ --include="*.ts" --include="*.js"
   
   # Review environment variables security
   env | grep -E "(KEY|SECRET|PASSWORD)" | wc -l
   ```

## 🗄️ Backup and Recovery Strategies

### Backup Procedures

#### Database Backup Strategy

1. **Automated Backup Configuration**
   ```bash
   # Daily database backup script
   #!/bin/bash
   
   BACKUP_DIR="/backup/database"
   DATE=$(date +%Y%m%d_%H%M%S)
   DB_NAME="lightbus_production"
   
   # Create backup directory
   mkdir -p $BACKUP_DIR
   
   # Full database backup
   pg_dump -h localhost -U postgres -d $DB_NAME \
     --format=custom \
     --compress=9 \
     --file="$BACKUP_DIR/full_backup_$DATE.dump"
   
   # Schema-only backup
   pg_dump -h localhost -U postgres -d $DB_NAME \
     --schema-only \
     --file="$BACKUP_DIR/schema_backup_$DATE.sql"
   
   # Verify backup integrity
   pg_restore --list "$BACKUP_DIR/full_backup_$DATE.dump" > /dev/null
   
   if [ $? -eq 0 ]; then
     echo "Backup completed successfully: $DATE"
   else
     echo "Backup failed: $DATE" | mail -s "Backup Error" admin@example.com
   fi
   
   # Clean up old backups (keep 30 days)
   find $BACKUP_DIR -name "*.dump" -mtime +30 -delete
   find $BACKUP_DIR -name "*.sql" -mtime +30 -delete
   ```

2. **Application Files Backup**
   ```bash
   # Application backup script
   #!/bin/bash
   
   APP_DIR="/app/lightbus-elearning"
   BACKUP_DIR="/backup/application"
   DATE=$(date +%Y%m%d_%H%M%S)
   
   # Create application backup
   tar -czf "$BACKUP_DIR/app_backup_$DATE.tar.gz" \
     --exclude="node_modules" \
     --exclude=".git" \
     --exclude="*.log" \
     $APP_DIR
   
   # Backup uploaded files
   rsync -av /uploads/ "$BACKUP_DIR/uploads_$DATE/"
   
   # Backup configuration files
   cp /etc/nginx/nginx.conf "$BACKUP_DIR/nginx_$DATE.conf"
   cp .env.production "$BACKUP_DIR/env_$DATE.backup"
   ```

#### Recovery Procedures

1. **Database Recovery**
   ```bash
   # Database recovery script
   #!/bin/bash
   
   BACKUP_FILE=$1
   DB_NAME="lightbus_production"
   
   if [ -z "$BACKUP_FILE" ]; then
     echo "Usage: $0 <backup_file.dump>"
     exit 1
   fi
   
   # Create new database for recovery
   createdb -h localhost -U postgres "${DB_NAME}_recovery"
   
   # Restore from backup
   pg_restore -h localhost -U postgres \
     --dbname="${DB_NAME}_recovery" \
     --clean \
     --if-exists \
     "$BACKUP_FILE"
   
   # Verify restore integrity
   psql -h localhost -U postgres -d "${DB_NAME}_recovery" \
     -c "SELECT COUNT(*) FROM profiles;"
   
   echo "Recovery completed. Review ${DB_NAME}_recovery before switching."
   ```

2. **Point-in-Time Recovery**
   ```bash
   # PITR setup and recovery
   
   # Configure continuous archiving (postgresql.conf)
   archive_mode = on
   archive_command = 'cp %p /backup/wal_archive/%f'
   wal_level = replica
   
   # Recovery procedure
   restore_recovery_conf() {
     cat > recovery.conf << EOF
     restore_command = 'cp /backup/wal_archive/%f %p'
     recovery_target_time = '$1'
     recovery_target_action = 'promote'
   EOF
   }
   ```

### Disaster Recovery Planning

#### Recovery Time Objectives (RTO)

```
Service Priority Matrix:
┌─────────────────────┬─────────────┬─────────────┐
│ Service Component   │ Priority    │ RTO Target  │
├─────────────────────┼─────────────┼─────────────┤
│ User Authentication │ Critical    │ 5 minutes   │
│ Core Learning       │ Critical    │ 15 minutes  │
│ AI Processing       │ High        │ 1 hour      │
│ Analytics           │ Medium      │ 4 hours     │
│ Reporting           │ Low         │ 24 hours    │
└─────────────────────┴─────────────┴─────────────┘
```

#### Recovery Point Objectives (RPO)

```
Data Loss Tolerance:
┌─────────────────────┬─────────────┬─────────────┐
│ Data Type           │ Importance  │ RPO Target  │
├─────────────────────┼─────────────┼─────────────┤
│ User Data           │ Critical    │ 1 minute    │
│ Learning Progress   │ Critical    │ 5 minutes   │
│ Content Data        │ High        │ 15 minutes  │
│ Analytics Data      │ Medium      │ 1 hour      │
│ Log Data            │ Low         │ 24 hours    │
└─────────────────────┴─────────────┴─────────────┘
```

## 🔄 Performance Monitoring and Optimization

### Performance Monitoring Setup

#### Application Performance Monitoring (APM)

1. **Monitoring Stack Configuration**
   ```yaml
   # docker-compose.monitoring.yml
   version: '3.8'
   
   services:
     prometheus:
       image: prom/prometheus:latest
       ports:
         - "9090:9090"
       volumes:
         - ./prometheus.yml:/etc/prometheus/prometheus.yml
     
     grafana:
       image: grafana/grafana:latest
       ports:
         - "3001:3000"
       environment:
         - GF_SECURITY_ADMIN_PASSWORD=admin123
       volumes:
         - grafana-storage:/var/lib/grafana
     
     node-exporter:
       image: prom/node-exporter:latest
       ports:
         - "9100:9100"
   
   volumes:
     grafana-storage:
   ```

2. **Custom Metrics Collection**
   ```typescript
   // Performance monitoring middleware
   import { NextRequest } from 'next/server';
   
   export class PerformanceMonitor {
     private static metrics = new Map<string, number[]>();
     
     static trackRequest(req: NextRequest, duration: number) {
       const endpoint = req.nextUrl.pathname;
       
       if (!this.metrics.has(endpoint)) {
         this.metrics.set(endpoint, []);
       }
       
       this.metrics.get(endpoint)!.push(duration);
       
       // Send to monitoring system
       this.sendMetric('response_time', duration, {
         endpoint,
         method: req.method,
         status: 'success'
       });
     }
     
     static sendMetric(name: string, value: number, labels: Record<string, string>) {
       // Implementation for sending metrics to Prometheus/Grafana
       fetch('/api/metrics', {
         method: 'POST',
         body: JSON.stringify({ name, value, labels, timestamp: Date.now() })
       });
     }
   }
   ```

#### Database Performance Monitoring

1. **PostgreSQL Monitoring Queries**
   ```sql
   -- Create monitoring views
   CREATE VIEW performance_overview AS
   SELECT 
     schemaname,
     tablename,
     seq_scan,
     seq_tup_read,
     idx_scan,
     idx_tup_fetch,
     n_tup_ins,
     n_tup_upd,
     n_tup_del
   FROM pg_stat_user_tables;
   
   -- Monitor slow queries
   CREATE VIEW slow_queries AS
   SELECT 
     query,
     calls,
     total_exec_time,
     mean_exec_time,
     stddev_exec_time,
     rows
   FROM pg_stat_statements
   WHERE mean_exec_time > 100
   ORDER BY mean_exec_time DESC;
   
   -- Index usage analysis
   CREATE VIEW index_usage AS
   SELECT 
     schemaname,
     tablename,
     indexname,
     idx_scan,
     idx_tup_read,
     idx_tup_fetch
   FROM pg_stat_user_indexes
   ORDER BY idx_scan DESC;
   ```

2. **Automated Performance Alerts**
   ```bash
   # Performance alert script
   #!/bin/bash
   
   # Check for slow queries
   SLOW_QUERIES=$(psql -t -c "
   SELECT COUNT(*) 
   FROM pg_stat_statements 
   WHERE mean_exec_time > 1000;")
   
   if [ "$SLOW_QUERIES" -gt 10 ]; then
     echo "WARNING: $SLOW_QUERIES slow queries detected" | 
     mail -s "Performance Alert" admin@example.com
   fi
   
   # Check database connection usage
   CONNECTIONS=$(psql -t -c "
   SELECT COUNT(*) 
   FROM pg_stat_activity 
   WHERE state = 'active';")
   
   if [ "$CONNECTIONS" -gt 80 ]; then
     echo "WARNING: High connection usage: $CONNECTIONS" |
     mail -s "Connection Alert" admin@example.com
   fi
   ```

### Performance Optimization

#### Database Optimization

1. **Query Optimization**
   ```sql
   -- Optimize common queries
   
   -- Add missing indexes based on query patterns
   CREATE INDEX CONCURRENTLY idx_sr_cards_lesson_difficulty 
   ON sr_cards(lesson_id, difficulty_level) 
   WHERE difficulty_level > 0;
   
   -- Optimize spaced repetition query
   CREATE INDEX CONCURRENTLY idx_sr_reviews_user_due 
   ON sr_reviews(user_id, next_review_date) 
   WHERE next_review_date <= CURRENT_DATE;
   
   -- Partition large tables by date
   CREATE TABLE processing_logs_2025_q1 
   PARTITION OF processing_logs 
   FOR VALUES FROM ('2025-01-01') TO ('2025-04-01');
   ```

2. **Connection Pool Optimization**
   ```javascript
   // Supabase connection optimization
   const supabaseConfig = {
     db: {
       pool: {
         min: 2,
         max: 20,
         acquireTimeoutMillis: 30000,
         createTimeoutMillis: 30000,
         destroyTimeoutMillis: 5000,
         idleTimeoutMillis: 30000,
         reapIntervalMillis: 1000,
         createRetryIntervalMillis: 200,
       }
     }
   };
   ```

#### Application Optimization

1. **Caching Strategy**
   ```typescript
   // Implement Redis caching
   import Redis from 'ioredis';
   
   const redis = new Redis(process.env.REDIS_URL);
   
   export class CacheManager {
     static async get<T>(key: string): Promise<T | null> {
       const cached = await redis.get(key);
       return cached ? JSON.parse(cached) : null;
     }
     
     static async set(key: string, value: any, ttl = 3600): Promise<void> {
       await redis.setex(key, ttl, JSON.stringify(value));
     }
     
     static async invalidate(pattern: string): Promise<void> {
       const keys = await redis.keys(pattern);
       if (keys.length > 0) {
         await redis.del(...keys);
       }
     }
   }
   
   // Cache lesson data
   export async function getCachedLesson(lessonId: string) {
     const cacheKey = `lesson:${lessonId}`;
     
     let lesson = await CacheManager.get(cacheKey);
     if (!lesson) {
       lesson = await fetchLessonFromDB(lessonId);
       await CacheManager.set(cacheKey, lesson, 1800); // 30 minutes
     }
     
     return lesson;
   }
   ```

2. **Code Optimization**
   ```typescript
   // Optimize React components
   import { memo, useMemo, useCallback } from 'react';
   
   // Memoize expensive components
   export const FlashcardList = memo(({ cards, onCardClick }) => {
     const sortedCards = useMemo(() => 
       cards.sort((a, b) => new Date(a.dueDate) - new Date(b.dueDate)),
       [cards]
     );
     
     const handleCardClick = useCallback((cardId: string) => {
       onCardClick(cardId);
     }, [onCardClick]);
     
     return (
       <div>
         {sortedCards.map(card => (
           <FlashcardItem 
             key={card.id}
             card={card}
             onClick={handleCardClick}
           />
         ))}
       </div>
     );
   });
   ```

## 🔒 Security Updates and Patch Management

### Security Update Procedures

#### Dependency Management

1. **Automated Vulnerability Scanning**
   ```bash
   # Weekly security scan script
   #!/bin/bash
   
   echo "=== SECURITY SCAN REPORT ===" > security_report.txt
   echo "Date: $(date)" >> security_report.txt
   
   # Scan npm dependencies
   echo -e "\n--- NPM AUDIT ---" >> security_report.txt
   npm audit --audit-level moderate >> security_report.txt
   
   # Check for outdated packages
   echo -e "\n--- OUTDATED PACKAGES ---" >> security_report.txt
   npm outdated >> security_report.txt
   
   # Scan Docker images
   echo -e "\n--- DOCKER SECURITY ---" >> security_report.txt
   docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
     aquasec/trivy image lightbus-elearning:latest >> security_report.txt
   
   # Email report
   mail -s "Weekly Security Scan" -a security_report.txt admin@example.com < /dev/null
   ```

2. **Patch Management Process**
   ```bash
   # Security patch deployment script
   #!/bin/bash
   
   ENVIRONMENT=$1
   
   if [ "$ENVIRONMENT" != "staging" ] && [ "$ENVIRONMENT" != "production" ]; then
     echo "Usage: $0 [staging|production]"
     exit 1
   fi
   
   # Create backup before patching
   ./backup_system.sh
   
   # Update dependencies
   npm update
   
   # Run tests
   npm test
   
   if [ $? -eq 0 ]; then
     echo "Tests passed. Deploying to $ENVIRONMENT..."
     
     if [ "$ENVIRONMENT" = "staging" ]; then
       vercel --target staging
     else
       vercel --prod
     fi
   else
     echo "Tests failed. Aborting deployment."
     exit 1
   fi
   ```

#### Security Configuration Updates

1. **SSL/TLS Certificate Management**
   ```bash
   # Automated SSL certificate renewal
   #!/bin/bash
   
   # Check certificate expiration
   CERT_EXPIRE=$(openssl x509 -in /etc/ssl/certs/lightbus.crt -noout -dates | 
                 grep notAfter | cut -d= -f2)
   EXPIRE_DATE=$(date -d "$CERT_EXPIRE" +%s)
   CURRENT_DATE=$(date +%s)
   DAYS_UNTIL_EXPIRE=$(( ($EXPIRE_DATE - $CURRENT_DATE) / 86400 ))
   
   if [ $DAYS_UNTIL_EXPIRE -lt 30 ]; then
     echo "Certificate expires in $DAYS_UNTIL_EXPIRE days. Renewing..."
     
     # Renew certificate (example with Let's Encrypt)
     certbot renew --nginx
     
     # Restart services
     systemctl reload nginx
     
     echo "Certificate renewed successfully."
   fi
   ```

2. **Security Headers Configuration**
   ```nginx
   # Nginx security headers configuration
   server {
     # Security headers
     add_header X-Frame-Options "SAMEORIGIN" always;
     add_header X-Content-Type-Options "nosniff" always;
     add_header X-XSS-Protection "1; mode=block" always;
     add_header Referrer-Policy "strict-origin-when-cross-origin" always;
     add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' https://fonts.gstatic.com;" always;
     add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
     
     # Remove server information
     server_tokens off;
   }
   ```

## 📈 Scaling Procedures

### Horizontal Scaling

#### Load Balancer Configuration

1. **Nginx Load Balancer Setup**
   ```nginx
   # Load balancer configuration
   upstream lightbus_backend {
     least_conn;
     server app1.lightbus.com:3000 max_fails=3 fail_timeout=30s;
     server app2.lightbus.com:3000 max_fails=3 fail_timeout=30s;
     server app3.lightbus.com:3000 max_fails=3 fail_timeout=30s;
   }
   
   server {
     listen 80;
     server_name lightbus.com;
     
     location / {
       proxy_pass http://lightbus_backend;
       proxy_set_header Host $host;
       proxy_set_header X-Real-IP $remote_addr;
       proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
       proxy_set_header X-Forwarded-Proto $scheme;
       
       # Health checks
       proxy_next_upstream error timeout http_500 http_502 http_503;
       proxy_connect_timeout 5s;
       proxy_send_timeout 10s;
       proxy_read_timeout 30s;
     }
   }
   ```

2. **Auto-scaling Configuration**
   ```yaml
   # Kubernetes auto-scaling example
   apiVersion: autoscaling/v2
   kind: HorizontalPodAutoscaler
   metadata:
     name: lightbus-app-hpa
   spec:
     scaleTargetRef:
       apiVersion: apps/v1
       kind: Deployment
       name: lightbus-app
     minReplicas: 3
     maxReplicas: 20
     metrics:
     - type: Resource
       resource:
         name: cpu
         target:
           type: Utilization
           averageUtilization: 70
     - type: Resource
       resource:
         name: memory
         target:
           type: Utilization
           averageUtilization: 80
   ```

#### Database Scaling

1. **Read Replica Configuration**
   ```bash
   # PostgreSQL read replica setup
   
   # On primary server
   echo "wal_level = replica" >> /etc/postgresql/14/main/postgresql.conf
   echo "max_wal_senders = 3" >> /etc/postgresql/14/main/postgresql.conf
   echo "wal_keep_segments = 8" >> /etc/postgresql/14/main/postgresql.conf
   
   # Create replication user
   psql -c "CREATE USER replicator REPLICATION LOGIN CONNECTION LIMIT 3 ENCRYPTED PASSWORD 'replica_password';"
   
   # On replica server
   pg_basebackup -h primary-server -D /var/lib/postgresql/14/main -U replicator -P -v -R -W
   ```

2. **Connection Pooling**
   ```bash
   # PgBouncer configuration
   cat > /etc/pgbouncer/pgbouncer.ini << EOF
   [databases]
   lightbus_production = host=localhost port=5432 dbname=lightbus_production
   
   [pgbouncer]
   listen_port = 6432
   listen_addr = *
   auth_type = md5
   auth_file = /etc/pgbouncer/userlist.txt
   pool_mode = transaction
   max_client_conn = 1000
   default_pool_size = 20
   min_pool_size = 5
   reserve_pool_size = 5
   max_db_connections = 50
   EOF
   ```

### Vertical Scaling

#### Resource Optimization

1. **Memory Optimization**
   ```bash
   # Monitor memory usage
   #!/bin/bash
   
   # Check current memory usage
   free -h
   
   # Identify memory-intensive processes
   ps aux --sort=-%mem | head -10
   
   # Monitor Node.js heap usage
   node --inspect --max-old-space-size=4096 server.js
   ```

2. **CPU Optimization**
   ```bash
   # CPU performance monitoring
   #!/bin/bash
   
   # Monitor CPU usage by process
   top -b -n 1 | head -20
   
   # Check CPU-intensive operations
   iotop -a -o -d 1
   
   # Monitor database CPU usage
   psql -c "
   SELECT 
     query,
     state,
     cpu_usage
   FROM pg_stat_activity 
   WHERE state != 'idle'
   ORDER BY cpu_usage DESC;"
   ```

## 📊 Maintenance Reporting

### Automated Reporting

#### Daily Maintenance Reports

```bash
# Daily maintenance report generator
#!/bin/bash

REPORT_DATE=$(date +%Y-%m-%d)
REPORT_FILE="/reports/daily_maintenance_$REPORT_DATE.txt"

cat > $REPORT_FILE << EOF
LIGHT BUS E-LEARNING PLATFORM
Daily Maintenance Report - $REPORT_DATE
===============================================

SYSTEM HEALTH:
$(systemctl status lightbus-app --no-pager)

DATABASE STATUS:
$(psql -c "SELECT 
  pg_size_pretty(pg_database_size('lightbus_production')) as db_size,
  (SELECT count(*) FROM pg_stat_activity) as connections,
  (SELECT count(*) FROM pg_stat_activity WHERE state = 'active') as active_connections;")

DISK USAGE:
$(df -h)

MEMORY USAGE:
$(free -h)

AI SERVICE STATUS:
$(curl -s https://api.openai.com/v1/models | jq '.data | length')

BACKUP STATUS:
$(ls -la /backup/database/ | tail -5)

SECURITY ALERTS:
$(grep -c "ALERT" /var/log/security.log || echo "0")

PERFORMANCE METRICS:
Average Response Time: $(tail -1000 /var/log/nginx/access.log | awk '{sum += $10; count++} END {print sum/count "ms"}')
Error Rate: $(tail -1000 /var/log/nginx/access.log | grep -E " [45][0-9][0-9] " | wc -l)%

EOF

# Email report
mail -s "Daily Maintenance Report - $REPORT_DATE" -a $REPORT_FILE admin@example.com < /dev/null
```

### Maintenance Metrics Dashboard

#### Key Performance Indicators

```sql
-- Maintenance KPI queries
CREATE VIEW maintenance_kpis AS
SELECT 
  'System Uptime' as metric,
  EXTRACT(EPOCH FROM (NOW() - pg_postmaster_start_time()))/3600 as value,
  'hours' as unit
UNION ALL
SELECT 
  'Database Size',
  pg_database_size('lightbus_production')/1024/1024/1024,
  'GB'
UNION ALL
SELECT 
  'Active Connections',
  (SELECT count(*) FROM pg_stat_activity WHERE state = 'active'),
  'connections'
UNION ALL
SELECT 
  'Today Backups',
  (SELECT count(*) FROM backup_log WHERE created_at::date = CURRENT_DATE),
  'backups'
UNION ALL
SELECT 
  'Security Incidents',
  (SELECT count(*) FROM security_log WHERE created_at >= CURRENT_DATE),
  'incidents';
```

This comprehensive maintenance guide ensures the Light Bus E-Learning Platform operates at peak performance with minimal downtime and optimal user experience.