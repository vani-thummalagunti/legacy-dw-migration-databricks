"""
Unit Tests for Legacy-to-Cloud Migration Pipeline & Reconciliation
"""

import unittest
from reconciliation.data_reconciliation_audit import DataReconciler

class TestMigrationReconciliation(unittest.TestCase):

    def setUp(self):
        self.reconciler = DataReconciler(output_report_path="reports/test_report.md")

    def test_reconciliation_pass_scenario(self):
        legacy = [
            {"CustomerCode": "C01", "FullName": "John Doe", "Email": "john@test.com", "AddressLine": "Apt 1", "City": "NYC"}
        ]
        modern = [
            {"CustomerCode": "C01", "FullName": "John Doe", "Email": "john@test.com", "AddressLine": "Apt 1", "City": "NYC"}
        ]
        res = self.reconciler.reconcile_datasets(legacy, modern)
        self.assertTrue(res["passed"])
        self.assertEqual(res["count_difference"], 0)
        self.assertEqual(res["checksum_mismatch_count"], 0)

    def test_reconciliation_detects_data_corruption(self):
        legacy = [
            {"CustomerCode": "C01", "FullName": "John Doe", "Email": "john@test.com", "AddressLine": "Apt 1", "City": "NYC"}
        ]
        modern = [
            {"CustomerCode": "C01", "FullName": "John Doe", "Email": "DIFFERENT_EMAIL@test.com", "AddressLine": "Apt 1", "City": "NYC"}
        ]
        res = self.reconciler.reconcile_datasets(legacy, modern)
        self.assertFalse(res["passed"])
        self.assertEqual(res["checksum_mismatch_count"], 1)

if __name__ == "__main__":
    unittest.main()
