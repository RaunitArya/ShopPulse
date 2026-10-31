from pathlib import Path

import pandas as pd

PROJECT_ROOT = Path(__file__).resolve().parent.parent

SOURCE_FILE = PROJECT_ROOT / "data" / "raw" / "online_retail.xlsx"
OUTPUT_FILE = PROJECT_ROOT / "data" / "samples" / "online_retail_sample.csv"

SAMPLE_SIZE = 10_000
RANDOM_SEED = 42


def main() -> None:
    if not SOURCE_FILE.exists():
        raise FileNotFoundError(f"Source dataset not found: {SOURCE_FILE}")

    OUTPUT_FILE.parent.mkdir(parents=True, exist_ok=True)

    print("Reading original Excel workbook...")

    df = pd.read_excel(
        SOURCE_FILE,
        engine="openpyxl",
        dtype={
            "InvoiceNo": "string",
            "StockCode": "string",
            "Description": "string",
            "CustomerID": "string",
            "Country": "string",
        },
    )

    print(f"Source records: {len(df):,}")

    if len(df) < SAMPLE_SIZE:
        raise ValueError(
            f"Expected at least {SAMPLE_SIZE:,} records, but found {len(df):,}"
        )

    # Excel row 1 contains headers, so data begins at row 2.
    df.insert(0, "SourceRowNumber", df.index + 2)

    sample = df.sample(n=SAMPLE_SIZE, random_state=RANDOM_SEED).sort_values(
        "SourceRowNumber"
    )

    sample.to_csv(
        OUTPUT_FILE,
        index=False,
        encoding="utf-8",
    )

    print("\nSample created successfully.")
    print(f"Output: {OUTPUT_FILE}")
    print(f"Sample records: {len(sample):,}")
    print(f"Random seed: {RANDOM_SEED}")
    print(
        "Original Excel row range represented: "
        f"{sample['SourceRowNumber'].min()} - "
        f"{sample['SourceRowNumber'].max()}"
    )


if __name__ == "__main__":
    main()
