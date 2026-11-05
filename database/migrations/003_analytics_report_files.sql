BEGIN;

CREATE TABLE analytics_report_files (
    report_file_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    report_id BIGINT NOT NULL,

    filename VARCHAR(255) NOT NULL,
    storage_path TEXT NOT NULL,

    content_type VARCHAR(100) NOT NULL DEFAULT 'application/pdf',
    file_size_bytes BIGINT NOT NULL CHECK (file_size_bytes > 0),
    checksum_sha256 CHAR(64),

    generated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT fk_analytics_report_files_report
        FOREIGN KEY (report_id)
        REFERENCES analytics_reports(report_id)
        ON DELETE RESTRICT,

    CONSTRAINT uq_analytics_report_files_storage_path
        UNIQUE (storage_path),

    CONSTRAINT chk_analytics_report_files_content_type
        CHECK (content_type = 'application/pdf')
);

CREATE INDEX idx_analytics_report_files_report_id
ON analytics_report_files (report_id);

CREATE INDEX idx_analytics_report_files_generated_at
ON analytics_report_files (generated_at DESC);


INSERT INTO schema_migrations (version, description)
VALUES (
    '003_analytics_report_files',
    'Create analytics report files table for persistent PDF storage'
);

COMMIT;
