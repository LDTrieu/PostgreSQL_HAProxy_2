#!/bin/bash

# Safe PostgreSQL HA Monitor - Tránh hanging
# Dùng timeout và safe commands

set -e
set -o pipefail

echo "=== PostgreSQL HA Safe Monitor ==="
echo "Time: $(date)"
echo ""

# Safe container check
echo "📦 CONTAINER STATUS:"
echo "-------------------"
for container in postgres-master postgres-replica1 postgres-replica2 postgres-replica3 haproxy; do
    if timeout 5 docker ps --filter "name=^${container}$" --format "table {{.Names}}\t{{.Status}}" | grep -q "${container}"; then
        echo "✅ ${container}: UP"
    else
        echo "❌ ${container}: DOWN"
    fi
done

echo ""
echo "🔥 POSTGRESQL ROLES:"
echo "-------------------"

# Master check with timeout
echo -n "Master: "
if timeout 10 docker exec postgres-master psql -U postgres -t -c "SELECT 'CONNECTED'" >/dev/null 2>&1; then
    role=$(timeout 10 docker exec postgres-master psql -U postgres -t -c "SELECT CASE WHEN pg_is_in_recovery() THEN 'REPLICA' ELSE 'MASTER' END;" 2>/dev/null | tr -d ' \t\n\r')
    if [ "$role" = "MASTER" ]; then
        echo "✅ MASTER"
    else
        echo "📘 REPLICA"
    fi
else
    echo "❌ DOWN/FAILED"
fi

# Replicas check with timeout
for replica in postgres-replica1 postgres-replica2 postgres-replica3; do
    echo -n "${replica}: "
    if timeout 10 docker exec ${replica} psql -U postgres -t -c "SELECT 'CONNECTED'" >/dev/null 2>&1; then
        role=$(timeout 10 docker exec ${replica} psql -U postgres -t -c "SELECT CASE WHEN pg_is_in_recovery() THEN 'REPLICA' ELSE 'NEW-MASTER' END;" 2>/dev/null | tr -d ' \t\n\r')
        if [ "$role" = "REPLICA" ]; then
            echo "📘 REPLICA"
        else
            echo "🔥 NEW-MASTER"
        fi
    else
        echo "❌ DOWN/FAILED"
    fi
done

echo ""
echo "📊 ORDERS COUNT:"
echo "---------------"

for node in postgres-master postgres-replica1 postgres-replica2 postgres-replica3; do
    echo -n "${node}: "
    if count=$(timeout 10 docker exec ${node} psql -U postgres -d pos_db -t -c "SELECT COUNT(*) FROM pos_order;" 2>/dev/null | tr -d ' \t\n\r'); then
        echo "${count} orders"
    else
        echo "FAILED"
    fi
done

echo ""
echo "=== Monitor Complete ===" 