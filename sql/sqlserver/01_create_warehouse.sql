IF DB_ID(N'ONLINE_RETAIL') IS NULL
    EXEC(N'CREATE DATABASE ONLINE_RETAIL;');
GO
USE ONLINE_RETAIL;
GO

IF SCHEMA_ID(N'stg') IS NULL EXEC(N'CREATE SCHEMA stg;');
GO

IF OBJECT_ID(N'stg.OnlineRetailClean', N'U') IS NULL
BEGIN
    CREATE TABLE stg.OnlineRetailClean
    (
        InvoiceNo     NVARCHAR(30)  NOT NULL,
        StockCode     NVARCHAR(50)  NOT NULL,
        Descriptionn  NVARCHAR(255) NULL,
        Quantity      INT           NOT NULL,
        InvoiceDate   DATETIME2(0)  NOT NULL,
        UnitPrice     DECIMAL(18,4) NOT NULL,
        CustomerID    NVARCHAR(30)  NULL,
        Country       NVARCHAR(100) NULL
    );
END;
GO

IF OBJECT_ID(N'dbo.DimCustomer', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.DimCustomer
    (
        CustomerKey INT IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_DimCustomer PRIMARY KEY,
        CustomerID  INT NOT NULL,
        Country     NVARCHAR(100) NULL,
        CONSTRAINT UQ_DimCustomer_CustomerID UNIQUE (CustomerID)
    );
END;
GO

IF OBJECT_ID(N'dbo.DimProduct', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.DimProduct
    (
        ProductKey   INT IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_DimProduct PRIMARY KEY,
        StockCode    NVARCHAR(50) NOT NULL,
        Descriptionn NVARCHAR(255) NULL,
        UnitPrice    DECIMAL(18,4) NULL,
        CONSTRAINT UQ_DimProduct_StockCode UNIQUE (StockCode)
    );
END;
GO

IF OBJECT_ID(N'dbo.FactSales', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.FactSales
    (
        FactKey     BIGINT IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_FactSales PRIMARY KEY,
        InvoiceNo   NVARCHAR(30) NOT NULL,
        InvoiceDate DATE NOT NULL,
        CustomerKey INT NULL,
        ProductKey  INT NOT NULL,
        Quantity    INT NOT NULL,
        UnitPrice   DECIMAL(18,4) NOT NULL,
        TotalSales  DECIMAL(18,2) NOT NULL,
        ReturnsAmt  DECIMAL(18,2) NOT NULL,
        NetSales    DECIMAL(18,2) NOT NULL,
        CONSTRAINT FK_FactSales_DimCustomer FOREIGN KEY (CustomerKey)
            REFERENCES dbo.DimCustomer(CustomerKey),
        CONSTRAINT FK_FactSales_DimProduct FOREIGN KEY (ProductKey)
            REFERENCES dbo.DimProduct(ProductKey),
        CONSTRAINT CK_FactSales_AmountIdentity
            CHECK (ABS(NetSales - (TotalSales + ReturnsAmt)) <= 0.01)
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_FactSales_InvoiceDate' AND object_id = OBJECT_ID(N'dbo.FactSales'))
    CREATE NONCLUSTERED INDEX IX_FactSales_InvoiceDate ON dbo.FactSales(InvoiceDate);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_FactSales_CustomerKey' AND object_id = OBJECT_ID(N'dbo.FactSales'))
    CREATE NONCLUSTERED INDEX IX_FactSales_CustomerKey ON dbo.FactSales(CustomerKey);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_FactSales_ProductKey' AND object_id = OBJECT_ID(N'dbo.FactSales'))
    CREATE NONCLUSTERED INDEX IX_FactSales_ProductKey ON dbo.FactSales(ProductKey);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_FactSales_InvoiceNo' AND object_id = OBJECT_ID(N'dbo.FactSales'))
    CREATE NONCLUSTERED INDEX IX_FactSales_InvoiceNo ON dbo.FactSales(InvoiceNo);
GO
