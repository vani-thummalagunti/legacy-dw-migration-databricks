-- ==============================================================================
-- 01_legacy_oltp_schema.sql
-- Source Database: SalesOLTP (SQL Server)
-- Demonstrates transactional schema, constraints, indexes, and Change Tracking
-- ==============================================================================

USE master;
GO

IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'SalesOLTP')
BEGIN
    CREATE DATABASE SalesOLTP;
END
GO

USE SalesOLTP;
GO

-- Enable Change Tracking at database level
ALTER DATABASE SalesOLTP
SET CHANGE_TRACKING = ON
(CHANGE_RETENTION = 7 DAYS, AUTO_CLEANUP = ON);
GO

-- 1. Customers Table
CREATE TABLE dbo.Customers (
    CustomerID INT IDENTITY(1,1) PRIMARY KEY,
    CustomerCode VARCHAR(20) NOT NULL UNIQUE,
    FirstName NVARCHAR(50) NOT NULL,
    LastName NVARCHAR(50) NOT NULL,
    Email VARCHAR(100) NOT NULL,
    Phone VARCHAR(20) NULL,
    AddressLine NVARCHAR(150) NULL,
    City NVARCHAR(50) NULL,
    StateCode VARCHAR(10) NULL,
    PostalCode VARCHAR(20) NULL,
    Country VARCHAR(50) DEFAULT 'USA',
    CreatedAt DATETIME DEFAULT GETUTCDATE(),
    UpdatedAt DATETIME DEFAULT GETUTCDATE()
);
GO

ALTER TABLE dbo.Customers
ENABLE CHANGE_TRACKING
WITH (TRACK_COLUMNS_UPDATED = ON);
GO

-- 2. Products Table
CREATE TABLE dbo.Products (
    ProductID INT IDENTITY(1,1) PRIMARY KEY,
    ProductSKU VARCHAR(50) NOT NULL UNIQUE,
    ProductName NVARCHAR(100) NOT NULL,
    Category NVARCHAR(50) NOT NULL,
    SubCategory NVARCHAR(50) NULL,
    UnitPrice DECIMAL(18,2) NOT NULL,
    CostPrice DECIMAL(18,2) NOT NULL,
    IsActive BIT DEFAULT 1,
    CreatedAt DATETIME DEFAULT GETUTCDATE(),
    UpdatedAt DATETIME DEFAULT GETUTCDATE()
);
GO

-- 3. Orders Header Table
CREATE TABLE dbo.Orders (
    OrderID INT IDENTITY(1,1) PRIMARY KEY,
    OrderNumber VARCHAR(30) NOT NULL UNIQUE,
    CustomerID INT NOT NULL FOREIGN KEY REFERENCES dbo.Customers(CustomerID),
    OrderDate DATETIME NOT NULL,
    OrderStatus VARCHAR(20) NOT NULL, -- Pending, Shipped, Delivered, Cancelled
    PaymentMethod VARCHAR(30) NULL,
    TotalAmount DECIMAL(18,2) NOT NULL,
    CreatedAt DATETIME DEFAULT GETUTCDATE(),
    UpdatedAt DATETIME DEFAULT GETUTCDATE()
);
GO

ALTER TABLE dbo.Orders
ENABLE CHANGE_TRACKING
WITH (TRACK_COLUMNS_UPDATED = ON);
GO

-- 4. Order Details Table
CREATE TABLE dbo.OrderDetails (
    OrderDetailID INT IDENTITY(1,1) PRIMARY KEY,
    OrderID INT NOT NULL FOREIGN KEY REFERENCES dbo.Orders(OrderID),
    ProductID INT NOT NULL FOREIGN KEY REFERENCES dbo.Products(ProductID),
    Quantity INT NOT NULL,
    UnitSalePrice DECIMAL(18,2) NOT NULL,
    DiscountAmount DECIMAL(18,2) DEFAULT 0.00,
    LineTotal AS (Quantity * UnitSalePrice - DiscountAmount) PERSISTED
);
GO
