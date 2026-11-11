# Informatica PowerCenter to PySpark Migration Specification

## 1. Mapping Overview: `m_load_dim_customer_scd2`

* **Source:** `SalesOLTP.dbo.Customers` (Relational SQL Server)
* **Target:** `EDW_Sales.dbo.Dim_Customer_SCD2` (Relational SQL Server)
* **Target Lakehouse Table (Modernized):** `lakehouse.silver_dim_customer_scd2` (Delta Lake)
* **Transformation Type:** Slowly Changing Dimension Type 2 (SCD2)

---

## 2. Informatica PowerCenter Transformation Architecture

```
[SQ_Customers]
       │
       ▼
[EXP_Transform_Fields] ──► CONCAT(FirstName, ' ', LastName) AS FullName, UPPER(Email)
       │
       ▼
[LKP_DimCustomer]      ──► Look up CustomerCode against Dim_Customer_SCD2 WHERE IsCurrent = 1
       │
       ▼
[RTR_Check_Changes]
   ├── GROUP 1: INSERT_NEW_RECORD   (ISNULL(LKP_CustomerKey))
   ├── GROUP 2: UPDATE_EXPIRED_ROW  (NOT ISNULL(LKP_CustomerKey) AND (LKP_Email != IN_Email OR LKP_Address != IN_Address))
   └── GROUP 3: INSERT_NEW_VERSION  (NOT ISNULL(LKP_CustomerKey) AND (LKP_Email != IN_Email OR LKP_Address != IN_Address))
       │
       ├── [UPD_Insert] ──────► Target: Dim_Customer_SCD2 (Insert new current row)
       └── [UPD_Update] ──────► Target: Dim_Customer_SCD2 (Update ValidTo, set IsCurrent = 0)
```

---

## 3. Transformation Migration Matrix (Informatica ➔ PySpark Delta)

| Informatica Object | Legacy Implementation | Modern Databricks / PySpark Equivalent |
|---|---|---|
| **Source Qualifier (SQ)** | `SELECT * FROM Customers` | `spark.read.format("delta").table("bronze_customers")` |
| **Expression (EXP)** | Port formulas: `IIF`, `CONCAT`, `LTRIM/RTRIM` | PySpark functions: `concat_ws`, `trim`, `when/otherwise` |
| **Lookup (LKP)** | Cached lookup table in PowerCenter memory | Broadcast Join or Delta Lake `MERGE INTO` condition |
| **Router (RTR)** | Multi-condition output groups | PySpark DataFrame filter / conditional branching |
| **Update Strategy (UPD)** | `DD_INSERT` (0), `DD_UPDATE` (1) | Delta Lake `whenMatchedUpdate` & `whenNotMatchedInsert` |
| **Workflow / Session** | `pmcmd startworkflow -sv ...` | ADF Pipeline `DatabricksNotebook` activity or Databricks Workflow Job |
