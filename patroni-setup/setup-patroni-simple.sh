#!/bin/bash

echo "🚀 CREATING SIMPLIFIED PATRONI HA ENVIRONMENT"
echo "============================================="

# Stop any existing setup
echo "🛑 Stopping existing setup..."
docker-compose -f docker-compose-simple-ha.yml down --volumes 2>/dev/null || true
docker-compose -f docker-compose-patroni-simple.yml down --volumes 2>/dev/null || true

# Create working Patroni setup with regular PostgreSQL
echo ""
echo "🔧 Creating Patroni setup with PostgreSQL + Patroni installation..."

cat > docker-compose-patroni-working.yml << 'EOF'
version: '3.8'

services:
  # ETCD for Patroni consensus
  etcd:
    image: quay.io/coreos/etcd:v3.5.0
    container_name: etcd
    hostname: etcd
    command: >
      /usr/local/bin/etcd
      --data-dir=/etcd-data
      --name etcd
      --initial-advertise-peer-urls http://etcd:2380
      --listen-peer-urls http://0.0.0.0:2380
      --advertise-client-urls http://etcd:2379
      --listen-client-urls http://0.0.0.0:2379
      --initial-cluster etcd=http://etcd:2380
      --initial-cluster-state new
    ports:
      - "2379:2379"
    networks:
      - postgres-ha
    healthcheck:
      test: ["CMD", "etcdctl", "--endpoints=http://localhost:2379", "cluster-health"]
      interval: 10s
      timeout: 5s
      retries: 5

  # PostgreSQL Node 1 with Patroni
  postgres-node1:
    image: postgres:15
    container_name: postgres-node1
    hostname: postgres-node1
    environment:
      POSTGRES_DB: pos_db
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres123
    volumes:
      - postgres-node1-data:/var/lib/postgresql/data
      - ./scripts/install-patroni.sh:/docker-entrypoint-initdb.d/install-patroni.sh
      - ./config/patroni-node1.yml:/etc/patroni/patroni.yml
    ports:
      - "5432:5432"
      - "8008:8008"
    depends_on:
      etcd:
        condition: service_healthy
    networks:
      - postgres-ha
    command: >
      bash -c "
        apt-get update && 
        apt-get install -y python3-pip python3-dev curl &&
        pip3 install patroni[etcd] psycopg2-binary &&
        patroni /etc/patroni/patroni.yml
      "

  # PostgreSQL Node 2 with Patroni  
  postgres-node2:
    image: postgres:15
    container_name: postgres-node2
    hostname: postgres-node2
    environment:
      POSTGRES_DB: pos_db
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres123
    volumes:
      - postgres-node2-data:/var/lib/postgresql/data
      - ./config/patroni-node2.yml:/etc/patroni/patroni.yml
    ports:
      - "5433:5432"
      - "8009:8008"
    depends_on:
      etcd:
        condition: service_healthy
    networks:
      - postgres-ha
    command: >
      bash -c "
        apt-get update && 
        apt-get install -y python3-pip python3-dev curl &&
        pip3 install patroni[etcd] psycopg2-binary &&
        patroni /etc/patroni/patroni.yml
      "

  # PostgreSQL Node 3 with Patroni
  postgres-node3:
    image: postgres:15
    container_name: postgres-node3
    hostname: postgres-node3
    environment:
      POSTGRES_DB: pos_db
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres123
    volumes:
      - postgres-node3-data:/var/lib/postgresql/data
      - ./config/patroni-node3.yml:/etc/patroni/patroni.yml
    ports:
      - "5434:5432"
      - "8010:8008"
    depends_on:
      etcd:
        condition: service_healthy
    networks:
      - postgres-ha
    command: >
      bash -c "
        apt-get update && 
        apt-get install -y python3-pip python3-dev curl &&
        pip3 install patroni[etcd] psycopg2-binary &&
        patroni /etc/patroni/patroni.yml
      "

networks:
  postgres-ha:
    driver: bridge

volumes:
  postgres-node1-data:
  postgres-node2-data:
  postgres-node3-data:
EOF

# Create Patroni configs for each node
echo "📝 Creating Patroni configuration files..."

mkdir -p config

# Node 1 config
cat > config/patroni-node1.yml << 'EOF'
scope: postgres-cluster
namespace: /patroni/
name: postgres-node1

restapi:
  listen: 0.0.0.0:8008
  connect_address: postgres-node1:8008

etcd:
  hosts: etcd:2379

bootstrap:
  dcs:
    ttl: 30
    loop_wait: 10
    retry_timeout: 30
    maximum_lag_on_failover: 1048576
    postgresql:
      use_pg_rewind: true
      use_slots: true
      parameters:
        wal_level: replica
        hot_standby: "on"
        max_wal_senders: 10
        max_replication_slots: 10
        wal_log_hints: "on"

  initdb:
  - encoding: UTF8
  - data-checksums

  pg_hba:
  - host replication replicator 127.0.0.1/32 md5
  - host replication replicator 10.0.0.0/8 md5
  - host replication replicator 172.16.0.0/12 md5
  - host replication replicator 192.168.0.0/16 md5
  - host all all 0.0.0.0/0 md5

  users:
    admin:
      password: admin123
      options:
        - createrole
        - createdb

postgresql:
  listen: 0.0.0.0:5432
  connect_address: postgres-node1:5432
  data_dir: /var/lib/postgresql/data
  authentication:
    replication:
      username: replicator
      password: replicator123
    superuser:
      username: postgres
      password: postgres123

tags:
    nofailover: false
    noloadbalance: false
    clonefrom: false
    nosync: false
EOF

# Node 2 config (copy and modify)
sed 's/postgres-node1/postgres-node2/g' config/patroni-node1.yml > config/patroni-node2.yml

# Node 3 config (copy and modify)  
sed 's/postgres-node1/postgres-node3/g' config/patroni-node1.yml > config/patroni-node3.yml

echo "✅ Patroni configs created"

# Start the environment
echo ""
echo "🚀 Starting Patroni HA cluster..."
docker-compose -f docker-compose-patroni-working.yml up -d

echo ""
echo "⏳ Waiting for cluster initialization (60 seconds)..."
sleep 60

echo ""
echo "🔍 Checking cluster status..."

# Check containers
echo "📦 Container status:"
docker ps --filter "name=postgres-node\|etcd" --format "table {{.Names}}\t{{.Status}}"

echo ""
echo "🔥 Checking Patroni status..."

# Check each node
for i in 1 2 3; do
    port=$((8007 + i))
    echo -n "postgres-node$i: "
    
    if timeout 5 curl -s "http://localhost:$port/master" > /dev/null 2>&1; then
        echo "🔥 MASTER"
    elif timeout 5 curl -s "http://localhost:$port/replica" > /dev/null 2>&1; then
        echo "📘 REPLICA" 
    elif timeout 5 curl -s "http://localhost:$port" > /dev/null 2>&1; then
        echo "⚠️ STARTING..."
    else
        echo "❌ DOWN"
    fi
done

echo ""
echo "✅ PATRONI ENVIRONMENT SETUP COMPLETE!"
echo ""
echo "🎯 NOW YOU CAN TEST AUTOMATIC FAILOVER:"
echo "  ./patroni-monitor.sh status     # Check cluster"
echo "  ./patroni-monitor.sh failover   # Test automatic failover"
echo ""
echo "📝 Manual testing commands:"
echo "  docker stop postgres-node1     # Stop current master"
echo "  ./patroni-monitor.sh status     # See automatic failover"
echo "" 