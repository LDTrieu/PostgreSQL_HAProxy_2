#!/bin/bash

echo "🎯 QUICK REAL-TIME MONITOR TEST"
echo "==============================="

# Set permissions and test
chmod +x realtime-monitor.sh

echo ""
echo "📋 Testing real-time monitor (single check)..."
./realtime-monitor.sh once

echo ""
echo ""
echo "🚀 READY FOR REAL-TIME TESTING!"
echo "================================"
echo ""
echo "🔥 STEP 1: Start real-time monitor"
echo "   ./realtime-monitor.sh"
echo ""
echo "🎯 STEP 2: In another terminal, test these commands:"
echo "   docker stop postgres-master      # Watch master go down"
echo "   docker stop postgres-replica1    # Watch replica go down"
echo "   docker start postgres-master     # Watch master come back"
echo ""
echo "💡 MODES AVAILABLE:"
echo "   ./realtime-monitor.sh           # Normal (2s refresh)"
echo "   ./realtime-monitor.sh fast      # Fast (1s refresh)"
echo "   ./realtime-monitor.sh slow      # Slow (5s refresh)"
echo "   ./realtime-monitor.sh once      # Single check only"
echo ""
echo "🎉 The monitor will show real-time changes when you:"
echo "   ✅ Stop/start containers"
echo "   ✅ Master/replica role changes"
echo "   ✅ Data sync status"
echo "   ✅ Cluster health status"
echo ""

read -p "🚀 Start real-time monitor now? (y/n): " answer
if [[ $answer =~ ^[Yy]$ ]]; then
    echo ""
    echo "🔍 Starting real-time monitor... (Press Ctrl+C to stop)"
    echo "💡 Open another terminal to run docker commands!"
    sleep 3
    ./realtime-monitor.sh
else
    echo ""
    echo "📝 To start monitoring later, run:"
    echo "   ./realtime-monitor.sh"
fi 