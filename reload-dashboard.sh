#!/bin/bash

echo "🔄 RELOAD GRAFANA DASHBOARD"
echo "================================================"

# Delete old dashboard if exists
echo "1️⃣ Xóa dashboard cũ..."
curl -s -u admin:admin123 -X DELETE "http://localhost:3000/api/dashboards/uid/736100dc-00a6-4bd9-9f1f-f992afba51b0"

echo ""
echo "2️⃣ Import dashboard mới..."
RESULT=$(curl -s -u admin:admin123 -X POST \
  "http://localhost:3000/api/dashboards/db" \
  -H "Content-Type: application/json" \
  -d @grafana/dashboards/postgresql-ha-monitoring.json)

echo $RESULT | python3 -m json.tool

echo ""
echo "3️⃣ Lấy URL dashboard mới:"
NEW_UID=$(echo $RESULT | python3 -c "import sys, json; print(json.load(sys.stdin)['uid'])")
echo "🌐 Dashboard URL: http://localhost:3000/d/$NEW_UID/postgresql-ha-cluster-monitoring"

echo ""
echo "4️⃣ Test query Panel 1:"
curl -s -u admin:admin123 \
  -X POST "http://localhost:3000/api/ds/query" \
  -H "Content-Type: application/json" \
  -d '{
    "queries": [
      {
        "datasource": {"uid": "P08B8726A6F9294EC"},
        "rawSql": "SELECT '\''MASTER'\'' as role, COUNT(*) as product_count FROM pos_product",
        "format": "table",
        "refId": "A"
      },
      {
        "datasource": {"uid": "P8CC35BA9726F8E90"},
        "rawSql": "SELECT '\''REPLICA1'\'' as role, COUNT(*) as product_count FROM pos_product",
        "format": "table", 
        "refId": "B"
      }
    ]
  }' | python3 -m json.tool

echo ""
echo "✅ HOÀN TẤT! Hãy vào URL trên và refresh browser (Ctrl+F5)" 