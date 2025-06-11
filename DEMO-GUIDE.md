# 🎯 DEMO AUTOMATIC FAILOVER - HƯỚNG DẪN

## ✅ **ENVIRONMENT ĐÃ SẴN SÀNG!**

Cluster đã được setup với:
- ✅ 1 Master + 3 Replicas 
- ✅ Monitoring scripts không bị hanging
- ✅ Automatic failover simulation
- ✅ 15 orders data trong database

---

## 🔥 **CÁCH 1: QUICK TEST - Xem automatic failover ngay lập tức**

```bash
# Chạy lệnh này để thấy automatic failover simulation:
./simulate-automatic-failover.sh manual-trigger
```

**Kết quả mong đợi:**
```
Step 1: Current status
Master: ✅ MASTER
postgres-replica1: 📘 REPLICA  
postgres-replica2: 📘 REPLICA
postgres-replica3: 📘 REPLICA

Step 2: Stopping master (simulating failure)...
postgres-master

Step 3: Simulating automatic failover...
🚨 MASTER FAILURE DETECTED!
🗳️ Running master election algorithm...
📊 Evaluating replica candidates...
  postgres-replica1: 15 orders
  postgres-replica2: 15 orders  
  postgres-replica3: 15 orders

🏆 ELECTED NEW MASTER: postgres-replica1
⚡ Promoting postgres-replica1 to master...
✅ AUTOMATIC FAILOVER COMPLETED!

Step 4: New cluster status after automatic failover:
Master: ❌ DOWN
postgres-replica1: 🔥 NEW-MASTER (Promoted!)
postgres-replica2: 📘 REPLICA
postgres-replica3: 📘 REPLICA

🎉 AUTOMATIC FAILOVER SUCCESSFUL!
```

---

## 📊 **CÁCH 2: COMPARISON DEMO - So sánh Manual vs Automatic**

```bash
# Xem sự khác biệt giữa Simple HA vs Automatic HA:
./demo-ha-comparison.sh compare
```

**Sẽ thấy:**
1. **Simple HA**: Manual intervention required - replicas không tự promote
2. **Automatic HA**: Zero manual intervention - tự động elect master mới

---

## 🔍 **CÁCH 3: INTERACTIVE TEST - Thử tự tay**

### **Terminal 1** (Monitoring):
```bash
./simulate-automatic-failover.sh start-monitoring
```

### **Terminal 2** (Your action):
```bash
# Tự tay stop master để thấy automatic detection:
docker stop postgres-master
```

**→ Terminal 1 sẽ tự động detect failure và promote replica!**

---

## 📋 **MONITORING COMMANDS**

### **Kiểm tra status hiện tại:**
```bash
./safe-commands.sh status        # Full cluster status
./safe-commands.sh roles         # PostgreSQL roles only
./safe-commands.sh containers    # Container status
```

### **Manual operations:**
```bash
./safe-commands.sh kill-master   # Stop master
./safe-commands.sh promote       # Manual promote replica1
./safe-commands.sh start-master  # Start master again
```

---

## 🎯 **SỰ KHÁC BIỆT BẠN SẼ THẤY:**

### **TRƯỚC (Simple HA):**
```
Master down → Replicas vẫn ở REPLICA mode → Cần manual promote
```

### **SAU (Automatic HA Simulation):**
```
Master down → Tự động detect → Election algorithm → Auto promote best replica
```

---

## 🔧 **TROUBLESHOOTING**

### **Nếu có vấn đề:**
```bash
# Reset environment:
docker-compose -f docker-compose-simple-ha.yml restart

# Check logs:
docker logs postgres-master
docker logs postgres-replica1

# Manual failover nếu simulation không hoạt động:
./safe-commands.sh test-failover
```

---

## 🎉 **READY TO TEST!**

**Bây giờ hãy chạy:**
```bash
./simulate-automatic-failover.sh manual-trigger
```

**Và thấy magic xảy ra! 🪄**

Bạn sẽ thấy:
- 🚨 **Master failure detection**
- 🗳️ **Automatic election process**  
- ⚡ **Auto promotion of best replica**
- ✅ **Zero manual intervention needed**

**Đây chính là sự khác biệt giữa Simple HA và True HA với automatic failover!** 🎯 