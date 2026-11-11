-- ==============================================================================
-- 02_legacy_dw_schema.sql
-- Target Database: EDW_Sales (SQL Server Enterprise Data Warehouse)
-- Kimball Star Schema with SCD Type 2 Customer Dimension
-- ==============================================================================

USE master;
GO

IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'EDW_Sales')
BEGIN
    CREATE DATABASE EDW_Sales;
END
GO

USE EDW_Sales;
GO

-- 1. Dim_Customer_SCD2 (Slowly Changing Dimension Type 2)
CREATE TABLE dbo.Dim_Customer_SCD2 (
    CustomerKey INT IDENTITY(1,1) PRIMARY KEY,
    CustomerCode VARCHAR(20) NOT NULL,
    FullName NVARCHAR(100) NOT NULL,
    Email VARCHAR(100) NOT NULL,
    Phone VARCHAR(20) NULL,
    AddressLine NVARCHAR(150) NULL,
    City NVARCHAR(50) NULL,
    StateCode VARCHAR(10) NULL,
    PostalCode VARCHAR(20) NULL,
    Country VARCHAR(50) NULL,
    -- SCD Type 2 Audit Columns
    ValidFrom DATETIME NOT NULL,
    ValidTo DATETIME NULL,
    IsCurrent BIT NOT NULL DEFAULT 1,
    CreatedBatchID VARCHAR(50) NOT NULL
);
CREATE NONCLUSTERED INDEX IX_DimCustomer_Code ON dbo.Dim_Customer_SCD2(CustomerCode, IsCurrent);
GO

-- 2. Dim_Product (SCD Type 1)
CREATE TABLE dbo.Dim_Product (
    ProductKey INT IDENTITY(1,1) PRIMARY KEY,
    ProductSKU VARCHAR(50) NOT NULL UNIQUE,
    ProductName NVARCHAR(100) NOT NULL,
    Category NVARCHAR(50) NOT NULL,
    SubCategory NVARCHAR(50) NULL,
    UnitPrice DECIMAL(18,2) NOT NULL,
    CostPrice DECIMAL(18,2) NOT NULL,
    IsActive BIT DEFAULT 1,
    LastUpdatedDate DATETIME DEFAULT GETUTCDATE()
);
GO

-- 3. Dim_Date
CREATE TABLE dbo.Dim_Date (
    DateKey INT PRIMARY KEY, -- YYYYMMDD
    FullDate DATE NOT NULL,
    DayNumberOfWeek TINYINT NOT NULL,
    DayName NVARCHAR(10) NOT NULL,
    DayNumberOfMonth TINYINT NOT NULL,
    MonthNumberOfYear TINYINT NOT NULL,
    MonthName NVARCHAR(10) NOT NULL,
    CalendarQuarter TINYINT NOT NULL,
    CalendarYear INT NOT NULL,
    IsWeekend BIT NOT NULL
);
GO

-- 4. Fact_SalesOrder
CREATE TABLE dbo.Fact_SalesOrder (
    SalesOrderKey BIGINT IDENTITY(1,1) PRIMARY KEY,
    OrderID INT NOT NULL,
    OrderDetailID INT NOT NULL,
    CustomerKey INT NOT NULL FOREIGN KEY REFERENCES dbo.Dim_Customer_SCD2(CustomerKey),
    ProductKey INT NOT NULL FOREIGN KEY REFERENCES dbo.Dim_Product(ProductKey),
    OrderDateKey INT NOT NULL FOREIGN KEY REFERENCES dbo.Dim_Date(DateKey),
    OrderNumber VARCHAR(30) NOT NULL,
    OrderStatus VARCHAR(20) NOT NULL,
    Quantity INT NOT NULL,
    UnitSalePrice DECIMAL(18,2) NOT NULL,
    DiscountAmount DECIMAL(18,2) NOT NULL,
    LineTotal DECIMAL(18,2) NOT NULL,
    ProfitAmount DECIMAL(18,2) NOT NULL,
    ETL_LoadTimestamp DATETIME DEFAULT GETUTCDATE()
);
CREATE NONCLUSTERED INDEX IX_FactSales_OrderDate ON dbo.Fact_SalesOrder(OrderDateKey);
CREATE NONCLUSTERED INDEX IX_FactSales_Customer ON dbo.Fact_SalesOrder(CustomerKey);
GO
