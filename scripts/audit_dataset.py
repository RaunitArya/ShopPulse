import json
from pathlib import Path

import pandas as pd

PROJECT_ROOT = Path(__file__).resolve().parent.parent
INPUT_FILE = PROJECT_ROOT / "data" / "samples" / "online_retail_sample.csv"
OUTPUT_FILE = PROJECT_ROOT / "reports" / "dataset_audit.json"

REQUIRED_COLUMNS = [
    "SourceRowNumber",
    "InvoiceNo",
    "StockCode",
    "Description",
    "Quantity",
    "InvoiceDate",
    "UnitPrice",
    "CustomerID",
    "Country",
]

SOURCE_COLUMNS = [
    "InvoiceNo",
    "StockCode",
    "Description",
    "Quantity",
    "InvoiceDate",
    "UnitPrice",
    "CustomerID",
    "Country",
]


def main() -> None:
    if not INPUT_FILE.exists():
        raise FileNotFoundError(f"Sample not found: {INPUT_FILE}")

    df = pd.read_csv(
        INPUT_FILE,
        dtype={
            "InvoiceNo": "string",
            "StockCode": "string",
            "Description": "string",
            "CustomerID": "string",
            "Country": "string",
        },
    )

    missing_columns = sorted(set(REQUIRED_COLUMNS) - set(df.columns))
    if missing_columns:
        raise ValueError(f"Missing columns: {missing_columns}")

    # Parse fields into temporary audit representations.
    quantity = pd.to_numeric(df["Quantity"], errors="coerce")
    unit_price = pd.to_numeric(df["UnitPrice"], errors="coerce")
    invoice_date = pd.to_datetime(df["InvoiceDate"], errors="coerce")

    invoice_no = df["InvoiceNo"].str.strip()
    stock_code = df["StockCode"].str.strip()
    country = df["Country"].str.strip()

    is_cancellation = invoice_no.str.startswith("C", na=False) | quantity.lt(0)

    # These are potential hard validation failures.
    invalid_masks = {
        "missing_invoice_no": invoice_no.isna() | invoice_no.eq(""),
        "missing_stock_code": stock_code.isna() | stock_code.eq(""),
        "missing_country": country.isna() | country.eq(""),
        "invalid_quantity": quantity.isna(),
        "zero_quantity": quantity.eq(0),
        "invalid_unit_price": unit_price.isna(),
        "negative_unit_price": unit_price.lt(0),
        "invalid_invoice_date": invoice_date.isna(),
    }

    # These are data-quality observations, not automatic rejections.
    observation_masks = {
        "missing_description": df["Description"].isna()
        | df["Description"].str.strip().eq(""),
        "missing_customer_id": df["CustomerID"].isna()
        | df["CustomerID"].str.strip().eq(""),
        "negative_quantity": quantity.lt(0),
        "cancellation_invoice": invoice_no.str.startswith("C", na=False),
        "zero_unit_price": unit_price.eq(0),
    }

    # Duplicate comparison excludes SourceRowNumber because it is
    # provenance metadata, not part of the transaction itself.
    duplicate_mask = df.duplicated(
        subset=SOURCE_COLUMNS,
        keep=False,
    )

    exact_duplicate_rows = int(duplicate_mask.sum())

    duplicate_details = (
        df.loc[
            duplicate_mask,
            ["SourceRowNumber", *SOURCE_COLUMNS],
        ]
        .fillna("")
        .astype(str)
        .to_dict(orient="records")
    )

    invalid_any = pd.Series(False, index=df.index)
    for mask in invalid_masks.values():
        invalid_any |= mask.fillna(False)

    report = {
        "file": INPUT_FILE.name,
        "total_records": int(len(df)),
        "columns": list(df.columns),
        "exact_duplicate_rows": exact_duplicate_rows,
        "potential_invalid_records": int(invalid_any.sum()),
        "potential_valid_records": int((~invalid_any).sum()),
        "cancellation_or_return_records": int(is_cancellation.sum()),
        "missing_values": {
            column: int(df[column].isna().sum()) for column in REQUIRED_COLUMNS
        },
        "validation_checks": {
            name: int(mask.fillna(False).sum()) for name, mask in invalid_masks.items()
        },
        "data_quality_observations": {
            name: int(mask.fillna(False).sum())
            for name, mask in observation_masks.items()
        },
        "duplicate_details": duplicate_details,
    }

    OUTPUT_FILE.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_FILE.write_text(
        json.dumps(report, indent=4),
        encoding="utf-8",
    )

    print(json.dumps(report, indent=4))
    print(f"\nAudit report saved to: {OUTPUT_FILE}")


if __name__ == "__main__":
    main()
