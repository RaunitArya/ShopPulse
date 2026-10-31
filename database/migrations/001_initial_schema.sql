BEGIN;

-- 1. Migration tracking
CREATE TABLE schema_migrations (
    version VARCHAR(100) PRIMARY KEY,
    description TEXT NOT NULL,
    applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. Ingestion batch tracking
CREATE TABLE ingestion_batches (
    batch_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    source_file VARCHAR(255) NOT NULL,
    file_hash CHAR(64) NOT NULL,

    status VARCHAR(20) NOT NULL DEFAULT 'processing'
        CHECK (
            status IN ('processing', 'completed', 'failed')
        ),

    total_records INTEGER NOT NULL DEFAULT 0
        CHECK (total_records >= 0),

    valid_records INTEGER NOT NULL DEFAULT 0
        CHECK (valid_records >= 0),

    rejected_records INTEGER NOT NULL DEFAULT 0
        CHECK (rejected_records >= 0),

    started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ,

    error_message TEXT,

    CONSTRAINT chk_batch_completion
        CHECK (
            completed_at IS NULL
            OR completed_at >= started_at
        )
);

-- Prevent concurrent or completed re-imports
-- of the same source file.
CREATE UNIQUE INDEX uq_ingestion_file_hash
ON ingestion_batches (file_hash)
WHERE status IN ('processing', 'completed');

-- 3. Validated sales transactions
CREATE TABLE sales_transactions (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    batch_id UUID NOT NULL
        REFERENCES ingestion_batches(batch_id),

    source_row_number INTEGER NOT NULL
        CHECK (source_row_number > 0),

    invoice_no VARCHAR(20) NOT NULL,
    stock_code VARCHAR(50) NOT NULL,
    description TEXT,

    quantity INTEGER NOT NULL
        CHECK (quantity <> 0),

    invoice_date TIMESTAMP NOT NULL,

    unit_price NUMERIC(12, 4) NOT NULL
        CHECK (unit_price >= 0),

    customer_id VARCHAR(30),
    country VARCHAR(100) NOT NULL,

    -- Calculated by PostgreSQL
    line_amount NUMERIC(16, 4)
        GENERATED ALWAYS AS (
            quantity * unit_price
        ) STORED,

    -- Detect cancellations and returns
    is_cancellation BOOLEAN
        GENERATED ALWAYS AS (
            invoice_no LIKE 'C%' OR quantity < 0
        ) STORED,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_batch_source_row
        UNIQUE (batch_id, source_row_number)
);

-- 4. Rejected records
CREATE TABLE rejected_records (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    batch_id UUID NOT NULL
        REFERENCES ingestion_batches(batch_id),

    source_row_number INTEGER NOT NULL
        CHECK (source_row_number > 0),

    raw_record JSONB NOT NULL,

    rejection_reason TEXT NOT NULL,

    rejected_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_rejected_batch_source_row
        UNIQUE (batch_id, source_row_number)
);

-- 5. Daily analytical summary
CREATE TABLE daily_sales_summary (
    sales_date DATE PRIMARY KEY,

    gross_revenue NUMERIC(16, 2) NOT NULL DEFAULT 0,
    cancellation_value NUMERIC(16, 2) NOT NULL DEFAULT 0,
    net_revenue NUMERIC(16, 2) NOT NULL DEFAULT 0,

    completed_orders BIGINT NOT NULL DEFAULT 0
        CHECK (completed_orders >= 0),

    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 6. Indexes for common analytical queries
CREATE INDEX idx_sales_invoice_date
    ON sales_transactions (invoice_date);

CREATE INDEX idx_sales_stock_code
    ON sales_transactions (stock_code);

CREATE INDEX idx_sales_country
    ON sales_transactions (country);

CREATE INDEX idx_sales_batch_id
    ON sales_transactions (batch_id);

CREATE INDEX idx_rejected_batch_id
    ON rejected_records (batch_id);

-- 7. Record this migration
INSERT INTO schema_migrations (
    version,
    description
)
VALUES (
    '001_initial_schema',
    'Create ingestion, sales, rejection and analytics tables'
);

COMMIT;
