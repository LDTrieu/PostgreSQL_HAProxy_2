#!/bin/bash

echo "🔍 KIỂM TRA DỮ LIỆU TỪ TẤT CẢ NODES"
echo "================================================"

# Test Master
echo "📊 MASTER - Product Count:"
docker exec postgres-master psql -U postgres -d pos_db -t -c "SELECT COUNT(*) FROM pos_product;"

echo "📊 REPLICA1 - Product Count:"
docker exec postgres-replica1 psql -U postgres -d pos_db -t -c "SELECT COUNT(*) FROM pos_product;"

echo "📊 REPLICA2 - Product Count:"
docker exec postgres-replica2 psql -U postgres -d pos_db -t -c "SELECT COUNT(*) FROM pos_product;"

echo "📊 REPLICA3 - Product Count:"
docker exec postgres-replica3 psql -U postgres -d pos_db -t -c "SELECT COUNT(*) FROM pos_product;"

echo ""
echo "🎯 KIỂM TRA GRAFANA API QUERY"
echo "================================================"

# Test Grafana query trực tiếp
echo "🔗 Test query từ Master qua Grafana API:"
curl -s -u admin:admin123 \
  -X POST "http://localhost:3000/api/ds/query" \
  -H "Content-Type: application/json" \
  -d '{
    "queries": [
      {
        "datasource": {"uid": "P08B8726A6F9294EC"},
        "rawSql": "SELECT COUNT(*) as product_count FROM pos_product",
        "format": "table",
        "refId": "A"
      }
    ]
  }' | python3 -m json.tool

echo ""
echo "🔗 Test query từ Replica1 qua Grafana API:"
curl -s -u admin:admin123 \
  -X POST "http://localhost:3000/api/ds/query" \
  -H "Content-Type: application/json" \
  -d '{
    "queries": [
      {
        "datasource": {"uid": "P8CC35BA9726F8E90"},
        "rawSql": "SELECT COUNT(*) as product_count FROM pos_product", 
        "format": "table",
        "refId": "A"
      }
    ]
  }' | python3 -m json.tool 