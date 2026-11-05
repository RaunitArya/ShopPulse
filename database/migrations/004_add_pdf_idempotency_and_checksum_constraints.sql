BEGIN;

ALTER TABLE public.analytics_report_files
ADD COLUMN IF NOT EXISTS checksum_sha256 CHAR(64);

CREATE UNIQUE INDEX IF NOT EXISTS
    uq_analytics_report_files_storage_path
ON public.analytics_report_files (storage_path);

ALTER TABLE public.analytics_report_files
ADD CONSTRAINT chk_analytics_report_files_checksum
CHECK (
    checksum_sha256 IS NULL
    OR checksum_sha256 ~ '^[0-9a-f]{64}$'
);

INSERT INTO schema_migrations (version, description)
VALUES (
    '004_add_pdf_idempotency_and_checksum_constraints',
    'Add idempotency keys to prevent duplicate metadata insertion & store PDFs SHA-256 checksum'
);

COMMIT;
