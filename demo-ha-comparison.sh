#!/bin/bash

echo "📊 HIGH AVAILABILITY COMPARISON DEMO"
echo "===================================="

demo_simple_ha() {
    echo ""
    echo "🔹 SIMPLE HA (Current Setup) - Manual Failover:"
    echo "-----------------------------------------------"
    
    echo "1️⃣ Initial status:"
    ./safe-commands.sh roles
    
    echo ""
    echo "2️⃣ Master failure simulation:"
    docker stop postgres-master 2>/dev/null || true
    sleep 2
    
    echo "3️⃣ Status after master down:"
    ./safe-commands.sh roles
    
    echo ""
    echo "❌ RESULT: No automatic failover - replicas remain as replicas!"
    echo "💡 Manual intervention required: ./safe-commands.sh promote"
    
    echo ""
    echo "4️⃣ Manual promotion:"
    ./safe-commands.sh promote
    
    echo ""
    echo "✅ Manual failover completed"
}

demo_automatic_ha() {
    echo ""
    echo "🔸 AUTOMATIC HA (Simulated) - Auto Failover:"
    echo "--------------------------------------------"
    
    # Start fresh
    docker start postgres-master 2>/dev/null
    sleep 5
    
    echo "1️⃣ Initial status:"
    ./safe-commands.sh roles
    
    echo ""
    echo "2️⃣ Automatic failover simulation:"
    ./simulate-automatic-failover.sh manual-trigger
    
    echo ""
    echo "✅ RESULT: Automatic failover completed without manual intervention!"
}

case "${1:-}" in
    "simple")
        demo_simple_ha
        ;;
    "automatic")
        demo_automatic_ha
        ;;
    "compare"|"")
        echo "🎯 COMPLETE COMPARISON DEMO"
        echo ""
        demo_simple_ha
        echo ""
        echo "=========================================="
        demo_automatic_ha
        echo ""
        echo "📋 SUMMARY:"
        echo "  Simple HA:    Manual intervention required"
        echo "  Automatic HA: Zero manual intervention"
        ;;
    *)
        echo "Usage: $0 [simple|automatic|compare]"
        ;;
esac
