# Schema Design - Crypto Analytics Platform

This document defines the complete data model for our real-time crypto analytics platform, following the **Medallion Architecture** (Bronze → Silver → Gold).

## Design Principles

1. **Separation of Concerns:** Each layer has a distinct purpose
2. **Immutability:** Bronze never changes; transformations happen in Silver/Gold
3. **Auditability:** Track when and how data was processed
4. **Performance:** Partition strategically, optimize for common queries
5. **Quality:** Data gets cleaner as it moves through layers

---

## Bronze Layer - Raw Data Zone

**Purpose:** Store data exactly as received from source systems. This is your audit trail.

### Table: `bronze.crypto_ticks_raw`

**Description:** Every API response from CoinGecko, stored as-is.

**Schema:**
```sql
CREATE TABLE bronze.crypto_ticks_raw (
    raw_payload STRING,              -- Complete JSON from API
    api_call_timestamp TIMESTAMP,    -- When we called the API
    ingestion_timestamp TIMESTAMP,   -- When we wrote to Iceberg
    source_system STRING,             -- 'coingecko_v3'
    api_endpoint STRING,              -- '/simple/price'
    http_status_code INT             -- 200, 429 (rate limit), etc.
)
PARTITIONED BY (days(ingestion_timestamp))
```

**Why This Design:**
- `raw_payload` as STRING preserves everything (even malformed JSON)
- Multiple timestamps track data freshness and lag
- `http_status_code` helps debug API issues
- Partitioned by day for easy retention management (drop old partitions)

**Retention:** 30 days, then archive to cold storage

**Write Pattern:** Append-only from Spark Structured Streaming

---

## Silver Layer - Cleaned Data Zone

**Purpose:** Apply business rules, validate, and deduplicate. This is where data becomes usable.

### Table: `silver.crypto_prices_clean`

**Description:** Validated, typed, deduplicated cryptocurrency prices.

**Schema:**
```sql
CREATE TABLE silver.crypto_prices_clean (
    crypto_symbol STRING,             -- 'bitcoin', 'ethereum'
    price_usd DECIMAL(18, 8),        -- Price in USD (8 decimals for precision)
    volume_24h DECIMAL(20, 2),       -- 24-hour trading volume
    market_cap DECIMAL(20, 2),       -- Total market capitalization
    percent_change_1h DECIMAL(10, 4), -- % change in last hour
    percent_change_24h DECIMAL(10, 4),-- % change in last 24 hours
    last_updated TIMESTAMP,           -- Timestamp from API
    processing_timestamp TIMESTAMP,   -- When we processed this
    source_record_id STRING,          -- Reference to Bronze table
    data_quality_score INT            -- 0-100, based on validation rules
)
PARTITIONED BY (days(last_updated))
```

**Transformation Logic:**
```python
# Deduplication: Keep latest per symbol per minute
SELECT 
    crypto_symbol,
    LAST(price_usd) as price_usd,
    LAST(volume_24h) as volume_24h,
    ...
FROM parsed_bronze
GROUP BY crypto_symbol, date_trunc('minute', last_updated)
```

**Data Quality Rules:**
1. `price_usd` must be > 0
2. `last_updated` must be within 5 minutes of `processing_timestamp`
3. `crypto_symbol` must be in allowed list
4. No nulls in key fields

**Write Pattern:** dbt incremental model (processes only new Bronze records)

---

## Gold Layer - Analytics Zone

**Purpose:** Dimensional model optimized for analytics. This is what BI tools query.

### Star Schema Design

```
        ┌──────────────┐
        │  dim_crypto  │
        └───────┬──────┘
                │
         ┌──────▼───────────────────┐
         │  fact_crypto_ticks       │
         └──────┬───────────────────┘
                │
        ┌───────▼──────┐
        │   dim_time   │
        └──────────────┘
```

---

### Fact Table: `gold.fact_crypto_ticks`

**Description:** Grain = One price update per cryptocurrency.

**Schema:**
```sql
CREATE TABLE gold.fact_crypto_ticks (
    tick_id BIGINT,                  -- Surrogate key
    crypto_id INT,                   -- FK to dim_crypto
    time_id BIGINT,                  -- FK to dim_time
    
    -- Measures (Numeric Facts)
    price_usd DECIMAL(18, 8),
    volume_24h DECIMAL(20, 2),
    market_cap DECIMAL(20, 2),
    percent_change_1h DECIMAL(10, 4),
    percent_change_24h DECIMAL(10, 4),
    
    -- Metadata
    data_quality_score INT,
    last_updated TIMESTAMP
)
PARTITIONED BY (days(last_updated))
```

**Indexing Strategy:**
- Z-Order by: `crypto_id`, `last_updated` (optimizes queries like "Bitcoin prices in last hour")

---

### Fact Table: `gold.fact_crypto_hourly`

**Description:** Grain = One row per cryptocurrency per hour (OHLC format).

**Schema:**
```sql
CREATE TABLE gold.fact_crypto_hourly (
    hourly_id BIGINT,                -- Surrogate key
    crypto_id INT,                   -- FK to dim_crypto
    time_id BIGINT,                  -- FK to dim_time (hour level)
    
    -- OHLC Measures
    open_price DECIMAL(18, 8),       -- First price in the hour
    high_price DECIMAL(18, 8),       -- Max price in the hour
    low_price DECIMAL(18, 8),        -- Min price in the hour
    close_price DECIMAL(18, 8),      -- Last price in the hour
    
    -- Aggregates
    avg_price DECIMAL(18, 8),
    total_volume DECIMAL(20, 2),
    tick_count INT,                  -- How many ticks in this hour
    
    -- Metadata
    hour_start TIMESTAMP,
    hour_end TIMESTAMP
)
PARTITIONED BY (days(hour_start))
```

**Aggregation Logic:**
```sql
SELECT 
    crypto_id,
    date_trunc('hour', last_updated) as hour_start,
    FIRST(price_usd) as open_price,
    MAX(price_usd) as high_price,
    MIN(price_usd) as low_price,
    LAST(price_usd) as close_price,
    AVG(price_usd) as avg_price,
    SUM(volume_24h) as total_volume,
    COUNT(*) as tick_count
FROM gold.fact_crypto_ticks
GROUP BY crypto_id, date_trunc('hour', last_updated)
```

---

### Dimension Table: `gold.dim_crypto`

**Description:** Slowly Changing Dimension (SCD Type 2) tracking cryptocurrency attributes.

**Schema:**
```sql
CREATE TABLE gold.dim_crypto (
    crypto_id INT,                   -- Surrogate key
    crypto_symbol STRING,            -- Business key: 'bitcoin'
    crypto_name STRING,              -- Display name: 'Bitcoin'
    category STRING,                 -- 'layer-1', 'defi', 'meme'
    market_cap_rank INT,             -- Ranking by market cap
    
    -- SCD Type 2 Tracking
    valid_from TIMESTAMP,            -- When this version became active
    valid_to TIMESTAMP,              -- When it was superseded (NULL = current)
    is_current BOOLEAN,              -- TRUE for active version
    
    -- Metadata
    first_seen_date DATE,
    created_at TIMESTAMP,
    updated_at TIMESTAMP
)
```

**SCD Type 2 Example:**
```
crypto_id | symbol    | name      | market_cap_rank | valid_from          | valid_to            | is_current
----------|-----------|-----------|-----------------|---------------------|---------------------|------------
1         | bitcoin   | Bitcoin   | 1               | 2024-01-01 00:00:00 | 2024-03-15 10:30:00 | FALSE
1         | bitcoin   | Bitcoin   | 2               | 2024-03-15 10:30:00 | NULL                | TRUE
```

**Why SCD Type 2:**
- If Bitcoin drops to #2 by market cap, we need to know it *was* #1 historically
- Enables "What was the top crypto by market cap on Jan 1?" queries

---

### Dimension Table: `gold.dim_time`

**Description:** Pre-populated time dimension for fast joins.

**Schema:**
```sql
CREATE TABLE gold.dim_time (
    time_id BIGINT,                  -- Surrogate key (epoch seconds)
    timestamp TIMESTAMP,             -- Actual timestamp
    
    -- Time Hierarchies
    minute INT,                      -- 0-59
    hour INT,                        -- 0-23
    day INT,                         -- 1-31
    month INT,                       -- 1-12
    quarter INT,                     -- 1-4
    year INT,                        -- 2024
    day_of_week INT,                 -- 1=Monday, 7=Sunday
    day_of_year INT,                 -- 1-366
    
    -- Business Attributes
    is_weekend BOOLEAN,
    is_holiday BOOLEAN,
    is_trading_hour BOOLEAN,         -- Crypto trades 24/7, but useful for stocks later
    
    -- Formatted Strings
    date_string STRING,              -- '2024-01-15'
    time_string STRING,              -- '14:30:00'
    datetime_string STRING           -- '2024-01-15 14:30:00'
)
```

**Population:**
```python
# Pre-populate for 2024-2030, minute-level granularity
import pandas as pd
date_range = pd.date_range('2024-01-01', '2030-12-31', freq='1min')
# Convert to DataFrame and write to Iceberg
```

---

## Data Flow Summary

```
┌─────────────────────────────────────────────────────────────────┐
│                      CoinGecko API                              │
│  GET /simple/price?ids=bitcoin,ethereum&vs_currencies=usd       │
└─────────────────────┬───────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────────┐
│              Kafka Topic: crypto.prices.raw                     │
│  { "bitcoin": {"usd": 45000.23}, "timestamp": 1234567890 }      │
└─────────────────────┬───────────────────────────────────────────┘
                      │
                      ▼ (Spark Structured Streaming)
┌─────────────────────────────────────────────────────────────────┐
│           Bronze: crypto_ticks_raw (append-only)                │
│  raw_payload | ingestion_timestamp | source_system              │
└─────────────────────┬───────────────────────────────────────────┘
                      │
                      ▼ (dbt incremental model)
┌─────────────────────────────────────────────────────────────────┐
│         Silver: crypto_prices_clean (deduplicated)              │
│  symbol | price_usd | volume_24h | last_updated                 │
└─────────────────────┬───────────────────────────────────────────┘
                      │
          ┌───────────┼───────────────┐
          ▼           ▼               ▼
    ┌─────────┐  ┌─────────┐  ┌────────────┐
    │  Gold:  │  │  Gold:  │  │   Gold:    │
    │  fact_  │  │  fact_  │  │ dim_crypto │
    │  ticks  │  │ hourly  │  │  (SCD-2)   │
    └─────────┘  └─────────┘  └────────────┘
```

---

## Query Examples (What We Can Answer)

### 1. Current Price
```sql
SELECT c.crypto_name, f.price_usd, f.last_updated
FROM gold.fact_crypto_ticks f
JOIN gold.dim_crypto c ON f.crypto_id = c.crypto_id
WHERE c.is_current = TRUE
  AND f.last_updated = (SELECT MAX(last_updated) FROM gold.fact_crypto_ticks)
```

### 2. Hourly Chart (Last 24 hours)
```sql
SELECT 
    c.crypto_name,
    h.hour_start,
    h.open_price,
    h.high_price,
    h.low_price,
    h.close_price
FROM gold.fact_crypto_hourly h
JOIN gold.dim_crypto c ON h.crypto_id = c.crypto_id
WHERE c.crypto_symbol = 'bitcoin'
  AND h.hour_start >= current_timestamp - INTERVAL 24 HOURS
ORDER BY h.hour_start
```

### 3. Time Travel (Price 2 hours ago)
```sql
SELECT c.crypto_name, f.price_usd, f.last_updated
FROM gold.fact_crypto_ticks FOR SYSTEM_TIME AS OF current_timestamp - INTERVAL 2 HOURS f
JOIN gold.dim_crypto c ON f.crypto_id = c.crypto_id
WHERE c.crypto_symbol = 'ethereum'
  AND f.last_updated <= current_timestamp - INTERVAL 2 HOURS
ORDER BY f.last_updated DESC
LIMIT 1
```

---

## Next Steps

1. Review this schema design
2. Create the tables in your lakehouse (we'll do this in Phase 2)
3. Move to [dimensional-model.md](dimensional-model.md) for ERD diagrams
