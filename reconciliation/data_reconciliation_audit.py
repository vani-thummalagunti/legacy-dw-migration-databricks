"""
Dual-Run Data Reconciliation & Validation Tool
Compares output of Legacy SQL Server / Informatica pipeline against Modern Databricks Delta Lake.
Validates:
1. Row count parity
2. Primary Key / Business Key alignment
3. Column-level checksums for transformation integrity
4. Generates an executive audit markdown / console report.
"""

import hashlib
import json
import logging
import os
import sys

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("DataReconciliation")

class DataReconciler:
    def __init__(self, output_report_path="reports/migration_reconciliation_report.md"):
        self.output_report_path = output_report_path

    def compute_record_hash(self, record, columns):
        """Computes deterministic SHA256 checksum across specified columns."""
        concatenated = "||".join(str(record.get(col, "")).strip().lower() for col in columns)
        return hashlib.sha256(concatenated.encode("utf-8")).hexdigest()

    def reconcile_datasets(self, legacy_records, modern_records, key_column="CustomerCode", compare_columns=None):
        """
        Runs dual-run validation between legacy and modernized data batches.
        """
        if compare_columns is None:
            compare_columns = ["CustomerCode", "FullName", "Email", "AddressLine", "City"]

        legacy_dict = {r[key_column]: r for r in legacy_records}
        modern_dict = {r[key_column]: r for r in modern_records}

        legacy_count = len(legacy_records)
        modern_count = len(modern_records)

        missing_in_modern = [k for k in legacy_dict if k not in modern_dict]
        missing_in_legacy = [k for k in modern_dict if k not in legacy_dict]

        common_keys = set(legacy_dict.keys()) & set(modern_dict.keys())
        mismatched_records = []

        for key in common_keys:
            leg_rec = legacy_dict[key]
            mod_rec = modern_dict[key]

            leg_hash = self.compute_record_hash(leg_rec, compare_columns)
            mod_hash = self.compute_record_hash(mod_rec, compare_columns)

            if leg_hash != mod_hash:
                diffs = {}
                for col in compare_columns:
                    val_l = str(leg_rec.get(col, "")).strip().lower()
                    val_m = str(mod_rec.get(col, "")).strip().lower()
                    if val_l != val_m:
                        diffs[col] = {"legacy": val_l, "modern": val_m}
                mismatched_records.append({"key": key, "differences": diffs})

        passed = (legacy_count == modern_count) and (len(missing_in_modern) == 0) and (len(mismatched_records) == 0)

        report = {
            "passed": passed,
            "legacy_row_count": legacy_count,
            "modern_row_count": modern_count,
            "count_difference": modern_count - legacy_count,
            "missing_in_modern_count": len(missing_in_modern),
            "missing_in_legacy_count": len(missing_in_legacy),
            "checksum_mismatch_count": len(mismatched_records),
            "mismatch_sample": mismatched_records[:5]
        }

        self.generate_markdown_report(report)
        return report

    def generate_markdown_report(self, results):
        """Generates a structured audit report."""
        os.makedirs(os.path.dirname(self.output_report_path), exist_ok=True)
        status_badge = "✅ PASSED (100% Match)" if results["passed"] else "❌ FAILED (Discrepancies Found)"

        md = f"""# 📊 Legacy-to-Cloud Dual-Run Data Reconciliation Audit

**Audit Status:** {status_badge}

## 1. Summary Metrics
| Metric | Legacy Pipeline (SQL Server / Informatica) | Modern Lakehouse (ADF / Databricks) | Variance |
|---|---|---|---|
| **Total Row Count** | {results['legacy_row_count']:,} | {results['modern_row_count']:,} | {results['count_difference']} |
| **Missing Keys in Modern** | - | {results['missing_in_modern_count']} | - |
| **Unexpected New Keys** | - | {results['missing_in_legacy_count']} | - |
| **Column Checksum Discrepancies** | - | {results['checksum_mismatch_count']} | - |

## 2. Validation Verdict
- **Row Count Parity:** {"PASS" if results['count_difference'] == 0 else "FAIL"}
- **Business Key Alignment:** {"PASS" if results['missing_in_modern_count'] == 0 else "FAIL"}
- **Transformation Integrity:** {"PASS" if results['checksum_mismatch_count'] == 0 else "FAIL"}
"""
        with open(self.output_report_path, "w") as f:
            f.write(md)
        logger.info(f"Reconciliation report saved to: {self.output_report_path}")

def run_sample_reconciliation():
    sample_legacy = [
        {"CustomerCode": "CUST101", "FullName": "Alice Smith", "Email": "alice@company.com", "AddressLine": "100 Main St", "City": "Dallas"},
        {"CustomerCode": "CUST102", "FullName": "Bob Johnson", "Email": "bob@company.com", "AddressLine": "200 Pine Ave", "City": "Austin"},
        {"CustomerCode": "CUST103", "FullName": "Carol White", "Email": "carol@company.com", "AddressLine": "300 Oak Blvd", "City": "Houston"},
    ]
    # Modern matches 100%
    sample_modern = [
        {"CustomerCode": "CUST101", "FullName": "Alice Smith", "Email": "alice@company.com", "AddressLine": "100 Main St", "City": "Dallas"},
        {"CustomerCode": "CUST102", "FullName": "Bob Johnson", "Email": "bob@company.com", "AddressLine": "200 Pine Ave", "City": "Austin"},
        {"CustomerCode": "CUST103", "FullName": "Carol White", "Email": "carol@company.com", "AddressLine": "300 Oak Blvd", "City": "Houston"},
    ]

    reconciler = DataReconciler()
    result = reconciler.reconcile_datasets(sample_legacy, sample_modern)
    print(json.dumps(result, indent=2))

if __name__ == "__main__":
    run_sample_reconciliation()
