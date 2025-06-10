# PostgreSQL High Availability Cluster with Grafana Monitoring

Hệ thống PostgreSQL HA Cluster hoàn chỉnh với automatic failover, recovery và real-time Grafana monitoring dashboard sử dụng schema pos_product.

## 🎯 Tổng Quan Dự Án

Dự án này cung cấp một giải pháp PostgreSQL High Availability hoàn chỉnh bao gồm:

- **1 Master PostgreSQL** + **3 Replica PostgreSQL** với streaming replication
- **HAProxy Load Balancer** với read/write separation
- **Grafana Dashboard** real-time monitoring với 4 panels chính
- **Prometheus** metrics collection
- **Automated Testing Suite** với comprehensive test scenarios
- **Interactive Demo** và health monitoring tools

## 🏗️ Kiến Trúc Hệ Thống

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Grafana       │    │   Prometheus    │    │   HAProxy       │
│   Dashboard     │    │   Metrics       │    │   Load Balancer │
│   Port: 3000    │    │   Port: 9090    │    │   Port: 8080    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
    ┌────────────────────────────┼────────────────────────────┐
    │                            │                            │
┌───▼──────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐
│ Master   │  │ Replica1 │  │ Replica2 │  │ Replica3 │
│ 5432     │  │ 5433     │  │ 5434     │  │ 5435     │
│ (Write)  │  │ (Read)   │  │ (Read)   │  │ (Read)   │
└──────────┘  └──────────┘  └──────────┘  └──────────┘
```

## 📋 Yêu Cầu Hệ Thống

### Prerequisites
- **Docker** & **Docker Compose**
- **PostgreSQL Client** (psql)
- **Linux/macOS** (Tested on Ubuntu 20.04+)
- **Tối thiểu 4GB RAM** và **10GB disk space**

### Cài Đặt Dependencies (Ubuntu)
```bash
# Docker & Docker Compose
sudo apt-get update
sudo apt-get install docker.io docker-compose

# PostgreSQL Client
sudo apt-get install postgresql-client

# Start Docker service
sudo systemctl start docker
sudo systemctl enable docker
```

## 🚀 Quick Start Guide

### 1. Clone và Setup
```bash
git clone <repository>
cd PostgreSQL_HAProxy_2
```

### 2. Khởi Động Hệ Thống
```bash
# Sử dụng menu-driven test runner (Recommended)
./scripts/run-all-tests.sh

# Hoặc khởi động trực tiếp
docker-compose -f docker-compose-simple-ha.yml up -d
```

### 3. Kiểm Tra Trạng Thái
```bash
# Real-time health monitoring
./scripts/cluster-health-check.sh

# Single health check
./scripts/cluster-health-check.sh --single
```

## 📊 Grafana Dashboard

### 4 Panels Chính Theo Yêu Cầu:

#### 🎯 Panel 1: Products Count Realtime Comparison
- **Mục đích**: Hiển thị real-time product count trên master vs replicas
- **Query**: `SELECT COUNT(*) FROM pos_product` từ mỗi node
- **Alert**: Trigger nếu counts khác nhau giữa nodes (replication lag)

#### 🎯 Panel 2: Cluster Status Overview
- **Columns**:
  - Database name
  - Pod ID (container identifier)
  - product_count (total products)
  - Last 5 Product IDs (newest products)
  - Last 5 Product Names (newest product names)
  - Role (MASTER/REPLICA)
  - IP Address (container IP)

#### 🎯 Panel 3: Pod Start Time Monitoring
- **Mục đích**: Track pod restart/failure detection
- **Hiển thị**: start_time, uptime_seconds, status (RECENT_RESTART/STABLE)
- **Alert**: Flag pods restarted trong 5 phút qua

#### 🎯 Panel 4: Master Election Tracking
- **Mục đích**: Track pod nào đang được elected làm master
- **Hiển thị**: election_status, pod_ip, elected_time, replica_count
- **Monitor**: Master transitions và failover events

### Truy Cập Grafana
- **URL**: http://localhost:3000
- **Username**: admin
- **Password**: admin123

## 🔧 Cấu Hình Components

### PostgreSQL Cluster
- **Master**: `localhost:5432` (Read/Write)
- **Replica 1**: `localhost:5433` (Read-only)
- **Replica 2**: `localhost:5434` (Read-only)
- **Replica 3**: `localhost:5435` (Read-only)
- **Database**: `pos_db`
- **User**: `postgres` / **Password**: `postgres123`

### HAProxy Load Balancer
- **Write Operations**: `localhost:5439` (Master only)
- **Read Operations**: `localhost:5440` (Load balanced replicas)
- **Stats Dashboard**: http://localhost:8080/stats

### Monitoring Stack
- **Grafana**: http://localhost:3000 (admin/admin123)
- **Prometheus**: http://localhost:9090
- **HAProxy Stats**: http://localhost:8080/stats

## 🧪 Testing Suite

### 1. Menu-Driven Test Runner
```bash
./scripts/run-all-tests.sh
```
**Features**:
- Interactive menu interface
- Cluster management (start/stop/clean)
- Comprehensive automated tests
- Interactive step-by-step demo
- Real-time health monitoring
- Quick database operations
- Service logs viewing

### 2. Comprehensive Automated Tests
```bash
./scripts/test-ha-features.sh
```
**Test Scenarios**:
- ✅ Streaming Replication Test
- ✅ Load Balancing Test (HAProxy)
- ✅ Failover Simulation Test
- ✅ Auto-Recovery Test
- ✅ Monitoring Functions Test
- ✅ Performance Test (Concurrent operations)

### 3. Interactive Step-by-Step Demo
```bash
./scripts/manual-ha-demo.sh
```
**Demo Steps**:
1. Cluster Initialization
2. Streaming Replication Verification
3. Load Balancing Testing
4. Failover Simulation
5. Monitoring & Grafana Dashboard
6. Performance Testing

### 4. Real-time Health Monitoring
```bash
./scripts/cluster-health-check.sh
```
**Features**:
- Real-time cluster health dashboard
- Health scoring system (0-100)
- Color-coded status indicators
- Data consistency checking
- Automatic refresh every 5 seconds

## 📁 Cấu Trúc Thư Mục

```
PostgreSQL_HAProxy_2/
├── docker-compose-simple-ha.yml    # Main cluster configuration
├── config/
│   └── haproxy-simple.cfg          # HAProxy load balancer config
├── scripts/
│   ├── master-init.sql             # Database initialization
│   ├── run-all-tests.sh           # Menu-driven test runner
│   ├── test-ha-features.sh        # Automated comprehensive tests
│   ├── manual-ha-demo.sh          # Interactive demo
│   └── cluster-health-check.sh    # Health monitoring
├── prometheus/
│   └── prometheus.yml             # Metrics collection config
├── grafana/
│   ├── datasources/
│   │   └── datasource.yml         # Data source configurations
│   └── dashboards/
│       ├── postgresql-ha.json     # Main dashboard definition
│       └── dashboard.yml          # Dashboard provisioning
├── data/                          # PostgreSQL data volumes
│   ├── master/
│   ├── replica1/
│   ├── replica2/
│   └── replica3/
└── README.md                      # This file
```

## 🎨 Database Schema

### pos_product Table
```sql
CREATE TABLE pos_product (
    product_id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    price DECIMAL(10,2) NOT NULL,
    category_id INTEGER NOT NULL,
    image TEXT,
    sku VARCHAR(255) NOT NULL,
    is_available BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP,
    created_by INTEGER,
    updated_by INTEGER
);
```

### Sample Data
- 15 sample products (cafés, teas, pastries, desserts, salads, sandwiches, pizza)
- 3 sample users (admin, manager, cashier)
- Sample orders and order items

### Monitoring Functions
- `get_cluster_status()` - Complete cluster overview
- `get_replication_status()` - Replication lag và status
- `get_master_election_status()` - Master election tracking
- `get_product_count_realtime()` - Real-time product count comparison

## 🔍 Operations Guide

### Khởi Động Cluster
```bash
# Method 1: Menu interface
./scripts/run-all-tests.sh
# Choose option 1

# Method 2: Direct command
docker-compose -f docker-compose-simple-ha.yml up -d
```

### Dừng Cluster
```bash
# Method 1: Menu interface
./scripts/run-all-tests.sh
# Choose option 2

# Method 2: Direct command
docker-compose -f docker-compose-simple-ha.yml down
```

### Làm Sạch Cluster (Remove volumes)
```bash
# Method 1: Menu interface (Recommended)
./scripts/run-all-tests.sh
# Choose option 3

# Method 2: Direct command
docker-compose -f docker-compose-simple-ha.yml down --volumes
```

### Database Operations
```bash
# Connect to Master
PGPASSWORD=postgres123 psql -h localhost -p 5432 -U postgres -d pos_db

# Connect to Replica
PGPASSWORD=postgres123 psql -h localhost -p 5433 -U postgres -d pos_db

# Via HAProxy (Write)
PGPASSWORD=postgres123 psql -h localhost -p 5439 -U postgres -d pos_db

# Via HAProxy (Read)
PGPASSWORD=postgres123 psql -h localhost -p 5440 -U postgres -d pos_db
```

### Test Sample Operations
```sql
-- Insert new product
INSERT INTO pos_product (name, description, price, category_id, sku, is_available, created_by) 
VALUES ('Test Product', 'Test description', 50000, 1, 'TEST-001', true, 1);

-- Check product count on all nodes
SELECT COUNT(*) FROM pos_product;

-- Check cluster status
SELECT * FROM get_cluster_status();

-- Check replication status
SELECT * FROM get_replication_status();
```

## 🚨 Troubleshooting

### Common Issues

#### 1. Containers không khởi động được
```bash
# Check Docker service
sudo systemctl status docker

# Check available resources
docker system df

# Clean up unused resources
docker system prune -f
```

#### 2. PostgreSQL connection refused
```bash
# Check container logs
docker-compose -f docker-compose-simple-ha.yml logs postgres-master

# Check if ports are available
sudo netstat -tlnp | grep :5432
```

#### 3. Replication lag issues
```bash
# Check replication status
PGPASSWORD=postgres123 psql -h localhost -p 5432 -U postgres -d pos_db -c "SELECT * FROM pg_stat_replication;"

# Check replica status
PGPASSWORD=postgres123 psql -h localhost -p 5433 -U postgres -d pos_db -c "SELECT pg_is_in_recovery();"
```

#### 4. HAProxy health check failures
```bash
# Check HAProxy logs
docker-compose -f docker-compose-simple-ha.yml logs haproxy

# Check HAProxy stats
curl http://localhost:8080/stats
```

### Health Check Commands
```bash
# Overall cluster health
./scripts/cluster-health-check.sh --single

# Individual component check
docker-compose -f docker-compose-simple-ha.yml ps

# Service connectivity test
./scripts/run-all-tests.sh
# Choose option 9 -> option 4
```

## 📈 Performance Monitoring

### Key Metrics to Monitor
1. **Replication Lag**: Should be < 1 second
2. **Connection Count**: Monitor active connections
3. **Query Performance**: Response time < 100ms
4. **Disk Usage**: Monitor data directory growth
5. **Memory Usage**: PostgreSQL shared buffers
6. **HAProxy Stats**: Request distribution

### Grafana Alerts
- Replication lag > 5 seconds
- Node restart detected (uptime < 5 minutes)
- Data inconsistency between nodes
- Connection failures to any node

## 🏆 Success Criteria

### ✅ Core HA Features
- **Streaming Replication**: 0 bytes lag, immediate sync
- **Automatic Failover**: Zero downtime promotion
- **Auto-Recovery**: pg_rewind automatic rejoin
- **Load Balancing**: Read/write separation working

### ✅ Grafana Monitoring
- **Real-time Dashboards**: All 4 panels operational
- **Alert Rules**: Notification on failures/lag
- **Data Sources**: PostgreSQL connections to all nodes
- **Refresh Rate**: 5-second updates

### ✅ Expected Container Setup
```bash
$ docker ps
postgres-master     ✅ Running (port 5432)
postgres-replica1   ✅ Running (port 5433)
postgres-replica2   ✅ Running (port 5434)
postgres-replica3   ✅ Running (port 5435)
haproxy            ✅ Running (ports 5439, 5440, 8080)
grafana            ✅ Running (port 3000)
prometheus         ✅ Running (port 9090)
```

## 🎯 Next Steps

1. **Production Deployment**: Adapt for production with proper security
2. **SSL/TLS Configuration**: Add encryption for all connections
3. **Backup Strategy**: Implement automated backup and restore
4. **Monitoring Alerts**: Configure email/Slack notifications
5. **Resource Scaling**: Add more replicas as needed
6. **Geographic Distribution**: Multi-datacenter setup

## 🤝 Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open Pull Request

## 📝 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🙏 Acknowledgments

- PostgreSQL Community for excellent documentation
- HAProxy for reliable load balancing
- Grafana for beautiful dashboards
- Prometheus for metrics collection
- Docker for containerization simplicity

---

**🚀 Enjoy your PostgreSQL HA Cluster with real-time monitoring!**

Để bắt đầu, chỉ cần chạy:
```bash
./scripts/run-all-tests.sh
``` 