#!/bin/bash

echo "🚀 POSTGRESQL HA REAL-TIME TEST SUITE"
echo "====================================="

echo ""
echo "✅ AUTOMATIC FAILOVER ĐÃ ĐƯỢC THIẾT LẬP!"
echo "🔥 postgres-replica3 đã được promote làm MASTER"
echo ""

echo "🎯 CHỌN LOẠI TEST:"
echo "=================="
echo ""
echo "1️⃣ Enhanced Real-Time Monitor (AUTO-FAILOVER ON)"
echo "   - Tự động promote replica khi master down"
echo "   - Press 'A' để toggle on/off"
echo "   - Refresh mỗi 2 giây"
echo ""
echo "2️⃣ Standard Real-Time Monitor"  
echo "   - Chỉ monitor, không auto-failover"
echo "   - Xem được real-time status changes"
echo "   - Refresh mỗi 2 giây"
echo ""
echo "3️⃣ Daemon Mode (Background)"
echo "   - Chạy auto-failover daemon ở background"
echo "   - Chỉ log events khi có failover"
echo "   - Không có UI"
echo ""

read -p "👉 Chọn mode (1/2/3): " mode

case $mode in
    1)
        echo ""
        echo "🔥 STARTING ENHANCED MONITOR WITH AUTO-FAILOVER..."
        echo "=================================================="
        echo ""
        echo "📋 Features:"
        echo "  ✅ Real-time cluster monitoring"
        echo "  ✅ Automatic failover khi master down"  
        echo "  ✅ Smart replica selection (based on data)"
        echo "  ✅ Event logging"
        echo "  ✅ Interactive controls (Press 'A' to toggle)"
        echo ""
        echo "🎯 TEST INSTRUCTIONS:"
        echo "  • Mở terminal khác"
        echo "  • Chạy: docker stop postgres-replica3    # Stop current master"
        echo "  • Watch automatic promotion happen!"
        echo "  • Chạy: docker start postgres-master     # Restart old master"
        echo "  • Press Ctrl+C để thoát"
        echo ""
        read -p "🚀 Ready? Press Enter to start..."
        ./enhanced-realtime-monitor.sh auto
        ;;
    2)
        echo ""
        echo "🔍 STARTING STANDARD REAL-TIME MONITOR..."
        echo "========================================="
        echo ""
        echo "📋 Features:"
        echo "  ✅ Real-time cluster monitoring"
        echo "  ❌ No automatic failover"
        echo "  ✅ Clean visual interface"
        echo "  ✅ Container health checking"
        echo ""
        echo "🎯 TEST INSTRUCTIONS:"
        echo "  • Mở terminal khác"
        echo "  • Chạy: docker stop postgres-replica3    # Stop current master"
        echo "  • Xem cluster status → NO MASTER"
        echo "  • Chạy: ./safe-commands.sh promote       # Manual promote"
        echo "  • Press Ctrl+C để thoát"
        echo ""
        read -p "🚀 Ready? Press Enter to start..."
        ./realtime-monitor.sh
        ;;
    3)
        echo ""
        echo "🤖 STARTING AUTO-FAILOVER DAEMON..."
        echo "==================================="
        echo ""
        echo "📋 Features:"
        echo "  ✅ Background automatic failover"
        echo "  ✅ Smart master election"
        echo "  ✅ Event logging to failover-daemon.log"
        echo "  ✅ No visual interference"
        echo ""
        echo "🎯 TEST INSTRUCTIONS:"
        echo "  • Daemon sẽ chạy ở background"
        echo "  • Monitor log: tail -f failover-daemon.log"
        echo "  • Test: docker stop postgres-replica3"
        echo "  • Watch automatic promotion trong log!"
        echo "  • Press Ctrl+C để thoát daemon"
        echo ""
        read -p "🚀 Ready? Press Enter to start daemon..."
        ./automatic-failover-daemon.sh start
        ;;
    *)
        echo ""
        echo "❌ Invalid choice. Starting Enhanced Monitor (default)..."
        sleep 2
        ./enhanced-realtime-monitor.sh auto
        ;;
esac 