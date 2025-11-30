# MinIO + Hive Metastore + Iceberg Lakehouse

A complete data lakehouse setup using Apache Iceberg, MinIO, and Hive Metastore, organized for learning and production use.

## Repository Structure

This repository is organized into two main parts:

###  PART-A: Core Infrastructure
The production-ready lakehouse foundation. Start here first.

- **MinIO** - S3-compatible object storage
- **Hive Metastore** - Catalog service
- **PostgreSQL** - Metadata database  
- **Spark Notebook** - Interactive development environment

** [Go to PART-A Documentation](PART-A/README.md)**

### PART-B: Real-Time Streaming Analytics
Production-grade streaming data pipeline for cryptocurrency analytics.

- Real-time crypto price ingestion via Kafka
- Spark Structured Streaming (Bronze layer)
- dbt transformations (Silver/Gold layers)
- Airflow orchestration & scheduling

** [Go to PART-B Documentation](PART-B/ReadMe.md)**

## Quick Start

### 1. Setup Core Infrastructure (PART-A)

```bash
cd PART-A
./setup.sh
```

This creates the base lakehouse with MinIO, Hive, and Spark.

### 2. Access Services

| Service | URL | Credentials |
|---------|-----|-------------|
| Jupyter Notebook | http://localhost:8888 | No password |
| MinIO Console | http://localhost:9001 | minioadmin / minioadmin |
| Spark UI | http://localhost:4040 | (Active during queries) |

### 3. Run Streaming Analytics (Optional)

Once PART-A is running, you can start the real-time streaming pipeline:

```bash
cd PART-B
./setup.sh
```

## Daily Workflow

### PART-A (Core Infrastructure)

```bash
cd PART-A

# Start your day
./start.sh

# End of day
./stop.sh

# Complete cleanup (removes all data)
./nuke.sh
```

### PART-B (Streaming Analytics)

```bash
cd PART-B

# Start streaming pipeline
./setup.sh

# Access services
# - Kafka UI: http://localhost:8080
# - Airflow: http://localhost:8081
```

## Architecture

The architecture consists of two main components:
1. **PART-A: Core Lakehouse Infrastructure**
   - MinIO for object storage
   - Hive Metastore for table cataloging
   - PostgreSQL for metadata persistence
   - Spark Notebook for interactive data processing
2. **PART-B: Real-Time Streaming Analytics**
   - Kafka for data ingestion
   - Spark Structured Streaming for real-time data processing
   - dbt for data transformations
   - Airflow for orchestration and scheduling

![](images/20251201010050.png)

## What Persists?

Both PART-A and PART-B use Docker volumes for persistence:

- **postgres_data** - All table metadata and schemas
- **minio_data** - Your actual Parquet/Iceberg data files

When you stop containers with `./stop.sh`, everything is preserved. Only `./nuke.sh` removes data permanently.

## Network Architecture

- **PART-A** creates the `dasnet` Docker network
- **PART-B** connects to the same `dasnet` network as an external network
- This allows PART-B services (Kafka, Airflow) to access PART-A services (MinIO, Hive)

## Prerequisites

- Docker Desktop (Mac/Windows) or Docker Engine (Linux)
- 8GB+ RAM available for Docker
- 10GB+ free disk space

## Troubleshooting

### PART-A won't start

Check [PART-A/README.md](PART-A/README.md#troubleshooting) for detailed troubleshooting.

Common issues:
- Missing JAR files (run `./setup.sh` to download)
- Ports already in use (5432, 9000, 9001, 8888)
- Not enough memory allocated to Docker

### PART-B can't connect to PART-A

Make sure PART-A is running first:

```bash
cd PART-A
docker-compose ps
```

All services should show "Up" status. If not:

```bash
cd PART-A
./stop.sh
./start.sh
```

Then retry PART-B:

```bash
cd PART-B
./setup.sh
```

### Network not found error

The `dasnet` network is created by PART-A. Always start PART-A before PART-B.

## What's Different From Standard Setups?

### Why Hive Metastore Instead of Polaris?

**Polaris:** Regenerates credentials on restart, requires reconfiguration  
**Hive Metastore:** Set it once, works forever

For learning and development, Hive is more practical.

### Why Separate PART-A and PART-B?

**PART-A:** Core infrastructure you always need  
**PART-B:** Real-time streaming analytics with Kafka, dbt, and Airflow

You can use PART-A for batch processing and exploratory work without the streaming complexity of PART-B.

## Contributing

Found a bug? Have a suggestion? Open an issue!

## License

MIT License - Use freely for learning and commercial projects.
