# PART-B: Real-Time Crypto Analytics

**← [Back to Main Repository](../README.md) | ⚠️ Prerequisites: [Complete PART-A first](../PART-A/README.md)**

This tutorial builds a **production-grade real-time analytics platform** that streams live cryptocurrency prices from public APIs into your lakehouse. You'll learn by doing—starting from data modeling and progressing to real-time streaming ingestion.

## What You'll Build

A streaming data pipeline that:
- Fetches live crypto prices from CoinGecko API every 30 seconds
- Streams data through Kafka into your lakehouse
- Stores raw data in Iceberg tables on MinIO
- Processes millions of records with Spark Structured Streaming
- Applies medallion architecture (Bronze/Silver/Gold layers)

## Architecture Overview

```
┌─────────────────┐
│  CoinGecko API  │  Live crypto prices (free tier)
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Crypto Producer │  Python service polling API
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│      Kafka      │  Streaming message queue
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Spark Streaming │  Real-time data processing
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Iceberg Tables  │  ACID transactions on MinIO
│   (MinIO)       │  Bronze → Silver → Gold
└─────────────────┘
```

**Network:** All services run on the `dasnet` Docker network created by PART-A. This lets them access MinIO and Hive Metastore from the core infrastructure.

---

## Quick Start

### Step 1: Verify PART-A is Running

Before starting PART-B, ensure your core lakehouse is operational:

```bash
docker ps --filter "name=hive-minio" --filter "name=hive-metastore"
```

You should see both containers running. If not, start PART-A first:
- **Mac/Linux:** `cd PART-A && ./start.sh`
- **Windows:** `cd PART-A; ./start.ps1`

### Step 2: Launch Kafka & Crypto Producer

| OS         | Commands                                                                                  |
|------------|-------------------------------------------------------------------------------------------|
| Mac/Linux  | `cd PART-B`<br>`chmod +x setup.sh`<br>`./setup.sh`                                        |
| Windows    | `cd PART-B`<br>`Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass`<br>`./setup.ps1`|

The setup script will:
1. Check PART-A is running
2. Verify the `dasnet` network exists
3. Start Zookeeper and Kafka
4. Build and start the crypto price producer
5. Display service URLs

### Step 3: Verify Everything is Running

Check all containers are healthy:

```bash
docker ps | grep crypto
```

You should see:
- `crypto-zookeeper` - Running
- `crypto-kafka` - Running (healthy)
- `crypto-kafka-ui` - Running
- `crypto-producer` - Running

### Step 4: Access Services

| Service | URL | What You'll See |
|---------|-----|-----------------|
| Kafka UI | http://localhost:8080 | Topics, messages, consumer groups |
| Jupyter Notebook | http://localhost:8888 | From PART-A (for Spark queries) |

Open Kafka UI and look for the topic `crypto.prices.raw`. You should see messages flowing in every 30 seconds.

---

## Tutorial: Phase 1 - Understanding the Data

Before writing any code, let's understand what data we're working with.

### What Data Are We Getting?

The crypto producer fetches data from CoinGecko's free API:
```
GET https://api.coingecko.com/api/v3/simple/price?ids=bitcoin,ethereum&vs_currencies=usd&include_24hr_vol=true&include_24hr_change=true
```

**Sample Response:**
```json
{
  "bitcoin": {
    "usd": 43250.50,
    "usd_24h_vol": 28500000000,
    "usd_24h_change": 2.34
  },
  "ethereum": {
    "usd": 2280.75,
    "usd_24h_vol": 15200000000,
    "usd_24h_change": -1.12
  }
}
```

### View Real Data in Kafka

1. Open Kafka UI: http://localhost:8080
2. Click on **Topics** → `crypto.prices.raw`
3. Click **Messages** tab
4. You'll see JSON messages with structure:
   ```json
   {
     "timestamp": "2025-12-02T10:30:15Z",
     "source": "coingecko",
     "data": {
       "bitcoin": {...},
       "ethereum": {...}
     }
   }
   ```

**Key Observations:**
- Messages arrive every 30 seconds
- Each message contains multiple cryptocurrencies
- Prices change in real-time
- Data includes volume and 24h change

---

## Tutorial: Phase 2 - Data Modeling

Real projects start with design, not code. Let's plan our tables.

### The Medallion Architecture

We'll organize data into three layers:

| Layer | Purpose | Data Quality |
|-------|---------|--------------|
| **Bronze** | Raw data exactly as received | Uncleaned, complete history |
| **Silver** | Cleaned, validated, typed | Business rules applied |
| **Gold** | Aggregated, analytics-ready | Optimized for queries |

### Bronze Layer Design

**Table:** `bronze.crypto_ticks_raw`

Stores every Kafka message as-is. This is your audit trail—never delete or modify Bronze data.

```sql
CREATE TABLE bronze.crypto_ticks_raw (
    raw_payload STRING,              -- Complete JSON from Kafka
    ingestion_timestamp TIMESTAMP,   -- When we wrote to Iceberg
    kafka_offset BIGINT,             -- Kafka message offset
    kafka_partition INT              -- Kafka partition number
)
PARTITIONED BY (days(ingestion_timestamp));
```

**Why this design?**
- `raw_payload` as STRING preserves everything, even malformed JSON
- Kafka metadata (`offset`, `partition`) enables exactly-once processing
- Partitioned by ingestion date for efficient querying and retention management

📖 **Deep Dive:** See [data-modeling/schema-design.md](data-modeling/schema-design.md) for complete Bronze/Silver/Gold table designs.

### Silver Layer Design

**Table:** `silver.crypto_prices_clean`

Parsed, validated, and typed data ready for analytics.

```sql
CREATE TABLE silver.crypto_prices_clean (
    crypto_symbol STRING,
    price_usd DECIMAL(18, 8),
    volume_24h DECIMAL(20, 2),
    percent_change_24h DECIMAL(10, 4),
    api_timestamp TIMESTAMP,
    processing_timestamp TIMESTAMP
)
PARTITIONED BY (days(api_timestamp));
```

**Transformations applied:**
- Parse JSON from `raw_payload`
- Validate: price > 0, timestamp reasonable
- Deduplicate: keep latest per symbol per minute
- Type conversion: string → decimal/timestamp

📖 **Deep Dive:** See [data-modeling/dimensional-model.md](data-modeling/dimensional-model.md) for the complete star schema with fact and dimension tables.

---

## Tutorial: Phase 3 - Streaming Ingestion (Bronze Layer)

Now let's write data from Kafka into Iceberg tables.

### Open Jupyter Notebook

1. Navigate to http://localhost:8888
2. Create a new notebook: **New** → **Python 3**
3. Name it `crypto_streaming_bronze.ipynb`

### Initialize Spark with Iceberg

```python
from pyspark.sql import SparkSession

spark = SparkSession.builder \
    .appName("CryptoStreamingBronze") \
    .config("spark.jars.packages", 
            "org.apache.iceberg:iceberg-spark-runtime-3.3_2.12:1.4.2,"
            "org.apache.spark:spark-sql-kafka-0-10_2.12:3.3.2") \
    .config("spark.sql.catalog.spark_catalog", "org.apache.iceberg.spark.SparkCatalog") \
    .config("spark.sql.catalog.spark_catalog.type", "hive") \
    .config("spark.sql.catalog.spark_catalog.uri", "thrift://hive-metastore:9083") \
    .getOrCreate()

print("Spark session created with Iceberg support")
```

### Read from Kafka

```python
# Read streaming data from Kafka
kafka_df = spark.readStream \
    .format("kafka") \
    .option("kafka.bootstrap.servers", "kafka:29092") \
    .option("subscribe", "crypto.prices.raw") \
    .option("startingOffsets", "latest") \
    .load()

# Kafka gives us binary data - convert to string
from pyspark.sql.functions import col, current_timestamp

bronze_df = kafka_df.select(
    col("value").cast("string").alias("raw_payload"),
    current_timestamp().alias("ingestion_timestamp"),
    col("offset").alias("kafka_offset"),
    col("partition").alias("kafka_partition")
)

# Show schema
bronze_df.printSchema()
```

### Create Bronze Database and Table

```python
# Create database if not exists
spark.sql("CREATE DATABASE IF NOT EXISTS bronze")

# Create Iceberg table
spark.sql("""
CREATE TABLE IF NOT EXISTS bronze.crypto_ticks_raw (
    raw_payload STRING,
    ingestion_timestamp TIMESTAMP,
    kafka_offset BIGINT,
    kafka_partition INT
)
USING iceberg
PARTITIONED BY (days(ingestion_timestamp))
""")

print("Bronze table created successfully")
```

### Write Stream to Iceberg

```python
# Write stream to Iceberg table
query = bronze_df.writeStream \
    .format("iceberg") \
    .outputMode("append") \
    .option("path", "bronze.crypto_ticks_raw") \
    .option("checkpointLocation", "/tmp/checkpoint/bronze_crypto") \
    .trigger(processingTime="30 seconds") \
    .start()

print("Streaming query started. Data is being written to Bronze table.")
print(f"Query ID: {query.id}")
```

### Monitor the Stream

```python
# Check query status
query.status

# See recent progress
query.recentProgress
```

**In another notebook cell**, query the Bronze table:

```python
# Read from Bronze table
spark.sql("SELECT COUNT(*) as row_count FROM bronze.crypto_ticks_raw").show()

# See latest records
spark.sql("""
SELECT 
    raw_payload,
    ingestion_timestamp,
    kafka_offset
FROM bronze.crypto_ticks_raw 
ORDER BY ingestion_timestamp DESC 
LIMIT 5
""").show(truncate=False)
```

**What you should see:**
- Row count increasing every 30 seconds
- JSON data in `raw_payload` column
- Timestamps showing when data was ingested

🎉 **Congratulations!** You've built a real-time streaming pipeline from Kafka to Iceberg.

---

## What's Working vs. What's Planned

### ✅ Currently Implemented

| Component | Status | What Works |
|-----------|--------|------------|
| Kafka Stack | ✅ Complete | Zookeeper, Kafka, Kafka UI running |
| Crypto Producer | ✅ Complete | Fetches live prices every 30s from CoinGecko |
| Data Modeling Docs | ✅ Complete | Bronze/Silver/Gold schemas documented |
| Bronze Ingestion | ✅ Tutorial Ready | Step-by-step guide above |

### 🚧 Planned for Future Updates

| Component | Status | What's Needed |
|-----------|--------|---------------|
| Silver Layer | 📝 Documented | Need transformation notebook/script |
| Gold Layer | 📝 Documented | Need dbt project setup |
| Airflow Orchestration | 🔜 Planned | DAG for end-to-end pipeline |
| Time Travel Queries | 🔜 Planned | Examples using Iceberg snapshots |
| Performance Tuning | 🔜 Planned | Compaction, Z-ordering examples |

---

## Next Steps

### Continue Learning

1. **Practice Bronze Ingestion:** Run the tutorial above and let data accumulate for 10-15 minutes
2. **Explore the Data:** 
   - Query Bronze tables with different time ranges
   - Count records per partition
   - Parse JSON and extract specific coins
3. **Study the Schema Designs:**
   - Read [data-modeling/schema-design.md](data-modeling/schema-design.md)
   - Understand why each table is partitioned differently
   - Review the data quality rules for Silver layer
4. **Design Silver Transformations:**
   - How would you parse the JSON?
   - What validations would you add?
   - How would you handle duplicate records?

### Stop the Services

When you're done experimenting:

```bash
# Stop PART-B (preserves data)
docker-compose down

# Stop PART-A
cd ../PART-A
./stop.sh    # Mac/Linux
./stop.ps1   # Windows
```

All data is preserved in Docker volumes. Restart anytime with `./start.sh` (PART-A) and `docker-compose up -d` (PART-B).

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| "Network dasnet not found" | Start PART-A first: `cd PART-A && ./start.sh` |
| Crypto producer not sending data | Check logs: `docker logs crypto-producer` |
| Kafka UI shows no messages | Wait 30 seconds for first API call, refresh page |
| Spark can't connect to Kafka | Ensure Kafka is healthy: `docker ps \| grep kafka` |
| "Table already exists" error | Normal - Iceberg tables persist across restarts |

### View Logs

```bash
# Producer logs (shows API calls)
docker logs -f crypto-producer

# Kafka logs
docker logs -f crypto-kafka

# All PART-B services
docker-compose logs -f
```

---

## Contributing

Found a bug or have suggestions? This is a learning project—your feedback helps everyone. Open an issue or submit a pull request!

---

## What Makes This Real

Unlike typical tutorials, this project uses:
- ✅ **Real APIs** - Live data from CoinGecko (not CSV files)
- ✅ **Production Patterns** - Medallion architecture, proper partitioning
- ✅ **Real Challenges** - API rate limits, late data, duplicates
- ✅ **Industry Tools** - Kafka, Spark, Iceberg, not toy examples

**You're learning production skills, not just following scripts.**

