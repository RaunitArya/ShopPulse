BEGIN;

CREATE TABLE analytics_reports (
    report_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    generated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    dataset_scope VARCHAR(100) NOT NULL,
    currency CHAR(3) NOT NULL DEFAULT 'GBP',
    period_start TIMESTAMP,
    period_end TIMESTAMP,
    payload JSONB NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_analytics_reports_generated_at
ON analytics_reports (generated_at DESC);

INSERT INTO schema_migrations (version, description)
VALUES (
    '002_analytics_reports',
    'Create analytics reports table for persistent KPI payloads'
);

COMMIT;
