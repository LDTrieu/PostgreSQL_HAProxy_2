# CSDL_PT

## LÊ ĐÌNH TRIỀU - N18DCCN229

## 🎯 Tổng Quan

Hệ thống Cluster PostgreSQL 5 nodes với:
- **🔥 1 Master + 4 Replicas** - Tối ưu cho quorum (3/5 majority)
- **⚖️ Quorum-Based Elections** - Tránh split-brain scenarios
- **⚡ Auto-Failover** - Tự động promote replica tốt nhất
- **🔧 Auto Split-Brain Fix** - Tự động resolve conflicts
- **📊 Real-Time Monitoring** - Enhanced dashboard với event logging
- **🛡️ Production-Ready** - Robust error handling và timeouts

## 🏗️ Kiến Trúc 5-Node Cluster

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Grafana       │    │   Prometheus    │    │   HAProxy       │
│   Dashboard     │    │   Metrics       │    │   Load Balancer │
│   Port: 3000    │    │   Port: 9090    │    │   Stats: 8080   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
    ┌────────────────────────────┼────────────────────────────┐
    │                            │                            │
┌───▼──────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐
│ Master   │  │ Replica1 │  │ Replica2 │  │ Replica3 │  │ Replica4 │
│ 5432     │  │ 5433     │  │ 5434     │  │ 5435     │  │ 5436     │
│ (Write)  │  │ (Read)   │  │ (Read)   │  │ (Read)   │  │ (Read)   │
└──────────┘  └──────────┘  └──────────┘  └──────────┘  └──────────┘

🗳️ QUORUM: 3/5 nodes needed for master election
🔧 AUTO-FIX: Split-brain detection và automatic resolution
📊 MONITOR: Real-time cluster health với enhanced dashboard
```

## 📋 Prerequisites

### ✅ Yêu Cầu Hệ Thống
- **OS**: Linux (Ubuntu 20.04+), macOS
- **Docker**: 20.10+ 
- **Docker Compose**: 1.29+
- **RAM**: Tối thiểu 6GB (8GB recommended)
- **Disk**: 15GB free space
- **CPU**: 4 cores recommended

### 🚀 Cài Đặt Dependencies

#### Ubuntu/Debian:
```bash
# Update package index
sudo apt update

# Install Docker
sudo apt install docker.io docker-compose

# Install PostgreSQL client (for testing)
sudo apt install postgresql-client

# Add user to docker group (logout/login required)
sudo usermod -aG docker $USER

# Start Docker service
sudo systemctl start docker
sudo systemctl enable docker
```

# Start Docker
sudo systemctl start docker
sudo systemctl enable docker
```


## 🚀 Quick Start Guide

### 1. Clone Repository
```bash
git clone <repository-url>
cd PostgreSQL_HAProxy_2
```

### 2. Verify Setup
```bash
# Check Docker is running
docker --version
docker-compose --version

# Check system resources
docker system df
```

### 3. Start 5-Node Cluster
```bash
# Start full cluster
docker-compose -f docker-compose-simple-ha.yml up -d

# Wait for initialization (30-60 seconds)
sleep 60

# Check all containers are running
docker ps
```

### 4. Real-Time Monitoring
```bash
# Start enhanced monitoring dashboard
./enhanced-realtime-monitor.sh

# Auto-failover mode (default)
./enhanced-realtime-monitor.sh auto

# Manual mode
./enhanced-realtime-monitor.sh manual
```

## 🎛️ Enhanced Real-Time Monitor

### 🔥 Main Features

## 🧪 Testing Scenarios

### 1. 📊 Cluster Health Check
```bash
# Single status check
docker ps --format "table {{.Names}}\t{{.Status}}"

# Real-time monitoring
./enhanced-realtime-monitor.sh
```

### 2. 🔥 Master Failover Test
```bash
# Terminal 1: Start monitoring
./enhanced-realtime-monitor.sh

# Terminal 2: Stop current master
docker stop postgres-master

# Watch automatic promotion in monitor!
# Best replica will be auto-promoted to master
```

### 3. 🔄 Split-Brain Resolution Test
```bash
# Terminal 1: Monitor running
./enhanced-realtime-monitor.sh

# Terminal 2: Create split-brain
docker start postgres-master  # If stopped before

# Watch auto-fix in action:
# Script will detect 2 masters and fix automatically
```

### 4. ⚖️ Quorum Testing
```bash
# Stop 2 nodes (still have 3/5 quorum)
docker stop postgres-replica1 postgres-replica2

# Monitor shows: "DEGRADED (quorum: 3/5 ✅)"
# Cluster still functional

# Stop 1 more (lose quorum)
docker stop postgres-replica3

# Monitor shows: "DEGRADED - NO QUORUM (2/5 < 3)"
```

### 5. 📈 Load Testing
```bash
# Connect to write endpoint
PGPASSWORD=postgres123 psql -h localhost -p 5439 -U postgres -d pos_db

# Insert test data
INSERT INTO pos_order (customer_name, total_amount, order_date, created_by) 
VALUES ('Test Customer', 100.00, NOW(), 1);

# Check replication on all nodes
SELECT COUNT(*) FROM pos_order;
```

## 🛠️ Configuration Details

### 🐳 Container Ports
| Service | Container | Host Port | Purpose |
|---------|-----------|-----------|----------|
| postgres-master | Master DB | 5432 | Read/Write |
| postgres-replica1 | Replica 1 | 5433 | Read-only |
| postgres-replica2 | Replica 2 | 5434 | Read-only |
| postgres-replica3 | Replica 3 | 5435 | Read-only |
| postgres-replica4 | Replica 4 | 5436 | Read-only |
| haproxy | Load Balancer | 5439/5440/8080 | Write/Read/Stats |
| grafana | Dashboard | 3000 | Monitoring |
| prometheus | Metrics | 9090 | Data Collection |

### 🔐 Default Credentials
```bash
# PostgreSQL
Username: postgres
Password: postgres123
Database: pos_db

# Grafana  
Username: admin
Password: admin123

# Access URLs
PostgreSQL Master: localhost:5432
HAProxy Write: localhost:5439
HAProxy Read: localhost:5440
HAProxy Stats: http://localhost:8080/stats
Grafana: http://localhost:3000
Prometheus: http://localhost:9090
```

### 🗃️ Database Schema
```sql
-- Main tables
pos_order (order_id, customer_name, total_amount, order_date, created_by)
pos_user (user_id, username, email, role, created_at)

-- Sample data: 15 orders, 3 users
-- Used for replication testing and monitoring
```

## ⚙️ Operations Guide

### 🔄 Cluster Management

#### Start Cluster:
```bash
docker-compose -f docker-compose-simple-ha.yml up -d
```

#### Stop Cluster:
```bash
docker-compose -f docker-compose-simple-ha.yml down
```

#### Clean Restart (Remove all data):
```bash
docker-compose -f docker-compose-simple-ha.yml down --volumes
docker-compose -f docker-compose-simple-ha.yml up -d
```

#### View Logs:
```bash
# All services
docker-compose -f docker-compose-simple-ha.yml logs

# Specific service
docker-compose -f docker-compose-simple-ha.yml logs postgres-master

# Follow logs
docker-compose -f docker-compose-simple-ha.yml logs -f postgres-replica2
```

### 🔍 Database Operations

#### Connect to Nodes:
```bash
# Master (Read/Write)
PGPASSWORD=postgres123 psql -h localhost -p 5432 -U postgres -d pos_db

# Replica 1 (Read-only)
PGPASSWORD=postgres123 psql -h localhost -p 5433 -U postgres -d pos_db

# Via HAProxy Write
PGPASSWORD=postgres123 psql -h localhost -p 5439 -U postgres -d pos_db

# Via HAProxy Read (Load balanced)
PGPASSWORD=postgres123 psql -h localhost -p 5440 -U postgres -d pos_db
```

#### Check Replication Status:
```sql
-- On Master: Check connected replicas
SELECT client_addr, state, sync_state FROM pg_stat_replication;

-- On Replica: Check if in recovery mode
SELECT pg_is_in_recovery();

-- Check replication lag
SELECT NOW() - pg_last_xact_replay_timestamp() AS replication_lag;
```

#### Test Data Operations:
```sql
-- Insert new order (on master/write endpoint)
INSERT INTO pos_order (customer_name, total_amount, order_date, created_by) 
VALUES ('New Customer', 150.00, NOW(), 1);

-- Check order count on all nodes
SELECT COUNT(*) FROM pos_order;

-- Check latest orders
SELECT * FROM pos_order ORDER BY order_id DESC LIMIT 5;
```

## 🚨 Troubleshooting

### ❌ Common Issues & Solutions

#### 1. Container Won't Start
```bash
# Check system resources
docker system df
docker system prune -f

# Check logs
docker-compose -f docker-compose-simple-ha.yml logs postgres-master

# Restart service
docker-compose -f docker-compose-simple-ha.yml restart postgres-master
```

#### 2. Connection Refused
```bash
# Check if container is running
docker ps | grep postgres-master

# Check port binding
netstat -tlnp | grep 5432

# Test connectivity
timeout 5 docker exec postgres-master psql -U postgres -c "SELECT 1"
```

#### 3. Replication Not Working
```bash
# Check master replication slots
PGPASSWORD=postgres123 psql -h localhost -p 5432 -U postgres -c "SELECT * FROM pg_replication_slots;"

# Check replica status
PGPASSWORD=postgres123 psql -h localhost -p 5433 -U postgres -c "SELECT pg_is_in_recovery();"

# Check network connectivity
docker exec postgres-replica1 ping postgres-master
```

#### 4. Split-Brain Detected
```bash
# Check which nodes think they're master
for port in 5432 5433 5434 5435 5436; do
  echo -n "Port $port: "
  PGPASSWORD=postgres123 psql -h localhost -p $port -U postgres -c "SELECT CASE WHEN pg_is_in_recovery() THEN 'REPLICA' ELSE 'MASTER' END;" -t 2>/dev/null || echo "FAILED"
done

# Use enhanced monitor to auto-fix
./enhanced-realtime-monitor.sh
# Script will detect and fix automatically
```

#### 5. Monitor Script Issues
```bash
# Make executable
chmod +x enhanced-realtime-monitor.sh

# Run with debug
bash -x enhanced-realtime-monitor.sh

# Check Docker access
docker ps
```

### 🛠️ Health Check Commands

```bash
# Quick cluster overview
docker ps --format "table {{.Names}}\t{{.Status}}\t{{Ports}}"

# Check all PostgreSQL connections
for port in 5432 5433 5434 5435 5436; do
  echo "Testing port $port..."
  PGPASSWORD=postgres123 timeout 5 psql -h localhost -p $port -U postgres -c "SELECT 'OK'" 2>/dev/null || echo "FAILED"
done

# Enhanced monitoring
./enhanced-realtime-monitor.sh
```

## 📊 Production Considerations

### 🔒 Security Hardening
- Change default passwords
- Use SSL/TLS encryption
- Configure pg_hba.conf properly
- Use Docker secrets for passwords
- Network segmentation

### 📈 Performance Tuning
```sql
-- PostgreSQL configuration
shared_buffers = 256MB
effective_cache_size = 1GB
max_connections = 200
wal_buffers = 16MB
checkpoint_completion_target = 0.9
```

### 🗄️ Backup Strategy
```bash
# Automated backup script
pg_dump -h localhost -p 5432 -U postgres pos_db > backup_$(date +%Y%m%d_%H%M%S).sql

# WAL archiving (already configured)
archive_mode = on
archive_command = 'test ! -f /archive/%f && cp %p /archive/%f'
```

## 🎯 Success Criteria

### ✅ Cluster Health Indicators
- **5/5 containers running**: All PostgreSQL nodes operational
- **Quorum maintained**: Minimum 3/5 nodes active
- **Replication lag**: < 1 second between master and replicas
- **Auto-failover**: < 30 seconds promotion time
- **Split-brain resolution**: Automatic detection and fix

### ✅ Expected Monitor Output
```
📦 NODE STATUS:
═══════════════
Master   : 🔥 MASTER (15 orders)
Replica-1: 📘 REPLICA (15 orders)
Replica-2: 📘 REPLICA (15 orders)  
Replica-3: 📘 REPLICA (15 orders)
Replica-4: 📘 REPLICA (15 orders)



# 1. Clone repo
git clone <repo-url>
cd PostgreSQL_HAProxy_2

# 2. Start cluster
docker-compose -f docker-compose-simple-ha.yml up -d

# 3. Wait for init
sleep 60

# 4. Monitor
./enhanced-realtime-monitor.sh

# 5. Test failover
docker stop postgres-master
# Watch auto-promotion!

# Checl CMD

```PGPASSWORD="postgres" psql -h localhost -p 5439 -U postgres -d postgres -c "SELECT *  FROM pos_order;"  
```


```
REPLICA1_PORT=5433
REPLICA2_PORT=5434
REPLICA3_PORT=5435
REPLICA4_PORT=5436
```