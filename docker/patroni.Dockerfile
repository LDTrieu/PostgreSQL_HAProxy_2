FROM postgres:14

# Install patroni and dependencies
RUN apt-get update && \
    apt-get install -y python3-pip python3-dev libpq-dev curl && \
    pip3 install patroni[etcd]==2.1.4 psycopg2-binary && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Copy patroni configuration
COPY config/patroni.yml /etc/patroni.yml

# Copy startup script
COPY scripts/patroni-entrypoint.sh /usr/local/bin/patroni-entrypoint.sh
RUN chmod +x /usr/local/bin/patroni-entrypoint.sh

# Copy init SQL if needed
COPY scripts/master-init-pos-order.sql /docker-entrypoint-initdb.d/

# Set patroni as the main command
ENTRYPOINT ["/usr/local/bin/patroni-entrypoint.sh"] 