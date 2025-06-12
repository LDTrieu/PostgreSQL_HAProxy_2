#!/bin/bash

# Import PostgreSQL Order Streaming Dashboard to Grafana

echo "📊 Importing PostgreSQL Order Streaming Dashboard..."

# Wait for Grafana to be ready
echo "⏳ Waiting for Grafana to be ready..."
sleep 5

# Import dashboard using Grafana API
echo "🔄 Importing dashboard via API..."

curl -X POST \
  http://admin:admin123@localhost:3000/api/dashboards/db \
  -H 'Content-Type: application/json' \
  -d @grafana/dashboards/postgresql-ha-order-streaming-import.json

echo
echo "✅ Dashboard import completed!"
echo
echo "🌐 Access your new dashboard at:"
echo "   http://localhost:3000/d/postgresql-order-streaming"
echo 
echo "📊 Dashboard Features:"
echo "   • 📊 Order Count - All Nodes"
echo "   • ⏰ Node Start Time & Status" 
echo "   • 🔄 Streaming Status: Order Count + Last 5 Order IDs"
echo "   • 📈 Real-Time Order Count Comparison (Streaming Lag Visualization)"
echo
echo "🧪 To test streaming lag:"
echo "   1. Insert new order: PGPASSWORD=postgres123 psql -h localhost -p 5432 -U postgres -d pos_db -c \"INSERT INTO pos_order (order_number, order_type, status_id, pos_id, total_amount, created_by) VALUES ('ORD-TEST-$(date +%s)', 'ONLINE', 1, 1, 99.99, 1);\""
echo "   2. Watch dashboard panels update in real-time"
echo "   3. Compare order counts and last_5_order_ids across nodes"
echo "   4. Time series chart shows instant streaming with different colors per node"
echo
echo "🎯 Auto-refresh: 5 seconds" 