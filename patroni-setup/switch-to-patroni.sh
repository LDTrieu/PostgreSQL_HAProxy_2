#!/bin/bash

echo "🚀 CHUYỂN TỪ SIMPLE HA SANG PATRONI HA"
echo "====================================="

# Step 1: Stop Simple HA
echo ""
echo "🛑 STOPPING SIMPLE HA SETUP..."
docker-compose -f docker-compose-simple-ha.yml down --volumes
echo "✅ Simple HA stopped"

# Step 2: Cleanup data
echo ""
echo "🗑️ CLEANING UP OLD DATA..."
sudo rm -rf data/postgres-* 2>/dev/null || true
echo "✅ Data cleanup done"

# Step 3: Fix Patroni setup với simple approach
echo ""
echo "🔧 SETTING UP PATRONI WITH SIMPLE DOCKER IMAGES..."

# Create simplified docker-compose for Patroni
cat > docker-compose-patroni-simple.yml << 'EOF'
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
      - "2380:2380"
    networks:
      - postgres-ha

  # Patroni Node 1 (using PostgreSQL with Patroni)
  postgres-node1:
    image: patroni/patroni:3.0.2
    container_name: postgres-node1
    hostname: postgres-node1
    environment:
      PATRONI_SCOPE: postgres-ha
      PATRONI_NAME: postgres-node1
      PATRONI_ETCD_URL: http://etcd:2379
      PATRONI_RESTAPI_LISTEN: 0.0.0.0:8008
      PATRONI_RESTAPI_CONNECT_ADDRESS: postgres-node1:8008
      PATRONI_POSTGRESQL_LISTEN: 0.0.0.0:5432
      PATRONI_POSTGRESQL_CONNECT_ADDRESS: postgres-node1:5432
      PATRONI_POSTGRESQL_DATA_DIR: /var/lib/postgresql/data
      PATRONI_POSTGRESQL_PGPASS: /tmp/pgpass
      PATRONI_SUPERUSER_USERNAME: postgres
      PATRONI_SUPERUSER_PASSWORD: postgres123
      PATRONI_REPLICATION_USERNAME: replicator
      PATRONI_REPLICATION_PASSWORD: replicator123
      POSTGRES_PASSWORD: postgres123
    ports:
      - "5432:5432"
      - "8008:8008"
    volumes:
      - postgres-node1-data:/var/lib/postgresql/data
    depends_on:
      - etcd
    networks:
      - postgres-ha

  # Patroni Node 2
  postgres-node2:
    image: patroni/patroni:3.0.2
    container_name: postgres-node2
    hostname: postgres-node2
    environment:
      PATRONI_SCOPE: postgres-ha
      PATRONI_NAME: postgres-node2
      PATRONI_ETCD_URL: http://etcd:2379
      PATRONI_RESTAPI_LISTEN: 0.0.0.0:8008
      PATRONI_RESTAPI_CONNECT_ADDRESS: postgres-node2:8008
      PATRONI_POSTGRESQL_LISTEN: 0.0.0.0:5432
      PATRONI_POSTGRESQL_CONNECT_ADDRESS: postgres-node2:5432
      PATRONI_POSTGRESQL_DATA_DIR: /var/lib/postgresql/data
      PATRONI_POSTGRESQL_PGPASS: /tmp/pgpass
      PATRONI_SUPERUSER_USERNAME: postgres
      PATRONI_SUPERUSER_PASSWORD: postgres123
      PATRONI_REPLICATION_USERNAME: replicator
      PATRONI_REPLICATION_PASSWORD: replicator123
      POSTGRES_PASSWORD: postgres123
    ports:
      - "5433:5432"
      - "8009:8008"
    volumes:
      - postgres-node2-data:/var/lib/postgresql/data
    depends_on:
      - etcd
    networks:
      - postgres-ha

  # Patroni Node 3
  postgres-node3:
    image: patroni/patroni:3.0.2
    container_name: postgres-node3
    hostname: postgres-node3
    environment:
      PATRONI_SCOPE: postgres-ha
      PATRONI_NAME: postgres-node3
      PATRONI_ETCD_URL: http://etcd:2379
      PATRONI_RESTAPI_LISTEN: 0.0.0.0:8008
      PATRONI_RESTAPI_CONNECT_ADDRESS: postgres-node3:8008
      PATRONI_POSTGRESQL_LISTEN: 0.0.0.0:5432
      PATRONI_POSTGRESQL_CONNECT_ADDRESS: postgres-node3:5432
      PATRONI_POSTGRESQL_DATA_DIR: /var/lib/postgresql/data
      PATRONI_POSTGRESQL_PGPASS: /tmp/pgpass
      PATRONI_SUPERUSER_USERNAME: postgres
      PATRONI_SUPERUSER_PASSWORD: postgres123
      PATRONI_REPLICATION_USERNAME: replicator
      PATRONI_REPLICATION_PASSWORD: replicator123
      POSTGRES_PASSWORD: postgres123
    ports:
      - "5434:5432"
      - "8010:8008"
    volumes:
      - postgres-node3-data:/var/lib/postgresql/data
    depends_on:
      - etcd
    networks:
      - postgres-ha

  # HAProxy for load balancing
  haproxy:
    image: haproxy:2.8
    container_name: haproxy
    hostname: haproxy
    ports:
      - "5439:5439" # Write port
      - "5440:5440" # Read port  
      - "8080:8080" # Stats
    volumes:
      - ./config/haproxy-patroni.cfg:/usr/local/etc/haproxy/haproxy.cfg:ro
    depends_on:
      - postgres-node1
      - postgres-node2
      - postgres-node3
    networks:
      - postgres-ha

networks:
  postgres-ha:
    driver: bridge

volumes:
  postgres-node1-data:
  postgres-node2-data:
  postgres-node3-data:
EOF

echo "✅ Created simplified Patroni docker-compose"

# Step 4: Fix HAProxy config for Patroni
echo ""
echo "🔧 UPDATING HAPROXY CONFIG FOR PATRONI..."

cat > config/haproxy-patroni-simple.cfg << 'EOF'
global
    daemon
    user haproxy
    group haproxy

defaults
    mode http
    timeout connect 10s
    timeout client 1m
    timeout server 1m
    option httplog
    retries 3

# HAProxy Stats
listen stats
    bind *:8080
    mode http
    stats enable
    stats uri /stats
    stats refresh 10s
    stats admin if TRUE

# PostgreSQL Master (Write)
listen postgres-master
    bind *:5439
    mode tcp
    option httpchk
    http-check expect status 200
    default-server inter 3s fall 3 rise 2
    
    # Patroni health check for master
    server postgres-node1 postgres-node1:5432 maxconn 100 check port 8008 httpchk GET /master
    server postgres-node2 postgres-node2:5432 maxconn 100 check port 8008 httpchk GET /master
    server postgres-node3 postgres-node3:5432 maxconn 100 check port 8008 httpchk GET /master

# PostgreSQL Replica (Read)
listen postgres-replica
    bind *:5440
    mode tcp
    option httpchk
    http-check expect status 200
    default-server inter 3s fall 3 rise 2
    balance roundrobin
    
    # Patroni health check for replica
    server postgres-node1 postgres-node1:5432 maxconn 100 check port 8008 httpchk GET /replica
    server postgres-node2 postgres-node2:5432 maxconn 100 check port 8008 httpchk GET /replica
    server postgres-node3 postgres-node3:5432 maxconn 100 check port 8008 httpchk GET /replica
EOF

# Update HAProxy config path
sed -i 's|haproxy-patroni.cfg|haproxy-patroni-simple.cfg|g' docker-compose-patroni-simple.yml

echo "✅ HAProxy config updated"

# Step 5: Start Patroni setup
echo ""
echo "🚀 STARTING PATRONI HA CLUSTER..."
docker-compose -f docker-compose-patroni-simple.yml up -d

echo ""
echo "⏳ WAITING FOR CLUSTER TO INITIALIZE..."
sleep 15

# Step 6: Check cluster status
echo ""
echo "🔍 CHECKING PATRONI CLUSTER STATUS..."
echo ""

echo "📦 Container Status:"
docker ps --filter "name=postgres-node" --format "table {{.Names}}\t{{.Status}}"

echo ""
echo "🔥 Patroni REST API Status:"
for node in postgres-node1 postgres-node2 postgres-node3; do
    echo -n "$node: "
    if curl -s "http://localhost:800$((8 + ${node: -1} - 1))/master" > /dev/null 2>&1; then
        echo "MASTER"
    elif curl -s "http://localhost:800$((8 + ${node: -1} - 1))/replica" > /dev/null 2>&1; then
        echo "REPLICA"
    else
        echo "UNKNOWN"
    fi
done

echo ""
echo "✅ PATRONI SETUP COMPLETE!"
echo ""
echo "🔧 PATRONI MONITORING COMMANDS:"
echo "  curl http://localhost:8008/master   # Check master"
echo "  curl http://localhost:8009/replica  # Check replica"
echo "  curl http://localhost:8010/health   # Check health"
echo ""
echo "🌐 HAProxy Stats: http://localhost:8080/stats"
echo "📊 Write Port: localhost:5439"
echo "📖 Read Port: localhost:5440" 