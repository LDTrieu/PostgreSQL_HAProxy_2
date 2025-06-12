# CSDL_PT

## LÊ ĐÌNH TRIỀU - N18DCCN229

##  Tổng Quan

Hệ thống Cluster PostgreSQL 5 nodes với:
- ** 1 Master + 4 Replicas** - Tối ưu cho quorum (3/5 majority)
- ** Quorum-Based Elections** - Tránh split-brain scenarios
- ** Auto-Failover** - Tự động promote replica tốt nhất
- ** Auto Split-Brain Fix** - Tự động resolve conflicts
- ** Real-Time Monitoring** - Enhanced dashboard với event logging
- ** Production-Ready** - Robust error handling và timeouts

##  Kiến Trúc 5-Node Cluster

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

 QUORUM: 3/5 nodes needed for master election
 AUTO-FIX: Split-brain detection và automatic resolution
 MONITOR: Real-time cluster health với enhanced dashboard
```

##  Prerequisites

###  Yêu Cầu Hệ Thống
- **OS**: Linux (Ubuntu 20.04+), macOS
- **Docker**: 20.10+ 
- **Docker Compose**: 1.29+
- **RAM**: Tối thiểu 6GB (8GB recommended)
- **Disk**: 15GB free space
- **CPU**: 4 cores recommended

###  Cài Đặt Dependencies

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


##  Quick Start Guide

### 1. Clone Repository
```bash
git clone <repository-url>
cd PostgreSQL_HAProxy_2
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

##  Enhanced Real-Time Monitor

###  Main Features

##  Testing Scenarios

### 1.  Cluster Health Check
```bash
# Single status check
docker ps --format "table {{.Names}}\t{{.Status}}"

# Real-time monitoring
./enhanced-realtime-monitor.sh
```

### 2.  Master Failover Test
```bash
# Terminal 1: Start monitoring
./enhanced-realtime-monitor.sh

# Terminal 2: Stop current master
docker stop postgres-master

# Watch automatic promotion in monitor!
# Best replica will be auto-promoted to master
```

### 3.  Split-Brain Resolution Test
```bash
# Terminal 1: Monitor running
./enhanced-realtime-monitor.sh

# Terminal 2: Create split-brain
docker start postgres-master  # If stopped before

# Watch auto-fix in action:
# Script will detect 2 masters and fix automatically
```

### 4.  Quorum Testing
```bash
# Stop 2 nodes (still have 3/5 quorum)
docker stop postgres-replica1 postgres-replica2

# Monitor shows: "DEGRADED (quorum: 3/5 ✅)"
# Cluster still functional

# Stop 1 more (lose quorum)
docker stop postgres-replica3

# Monitor shows: "DEGRADED - NO QUORUM (2/5 < 3)"
```

### 5.  Load Testing
```bash
# Connect to write endpoint
PGPASSWORD=postgres123 psql -h localhost -p 5439 -U postgres -d pos_db

# Insert test data
INSERT INTO pos_order (customer_name, total_amount, order_date, created_by) 
VALUES ('Test Customer', 100.00, NOW(), 1);

# Check replication on all nodes
SELECT COUNT(*) FROM pos_order;
```


###  Database Schema
```sql
-- Main tables
pos_order (order_id, customer_name, total_amount, order_date, created_by)
pos_user (user_id, username, email, role, created_at)


#### 5. Monitor Script Issues
```bash
# Make executable
chmod +x enhanced-realtime-monitor.sh

# Run with debug
bash -x enhanced-realtime-monitor.sh

# Check Docker access
docker ps
```

##  Success Criteria

###  Cluster Health Indicators
- **5/5 containers running**: All PostgreSQL nodes operational
- **Quorum maintained**: Minimum 3/5 nodes active
- **Replication lag**: < 1 second between master and replicas
- **Auto-failover**: < 30 seconds promotion time
- **Split-brain resolution**: Automatic detection and fix

```
 NODE STATUS:
═══════════════
Master   :  MASTER (15 orders)
Replica-1:  REPLICA (15 orders)
Replica-2:  REPLICA (15 orders)  
Replica-3:  REPLICA (15 orders)
Replica-4:  REPLICA (15 orders)



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