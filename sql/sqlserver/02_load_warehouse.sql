USE ONLINE_RETAIL;
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @StagingRows BIGINT = (SELECT COUNT_BIG(*) FROM stg.OnlineRetailClean);
IF @StagingRows = 0
BEGIN
    THROW 50001, 'Staging table is empty. Import the cleaned CSV before loading the warehouse.', 1;
END;

IF EXISTS
(
    SELECT 1
    FROM stg.OnlineRetailClean
    WHERE NULLIF(LTRIM(RTRIM(InvoiceNo)), N'') IS NULL
       OR NULLIF(LTRIM(RTRIM(StockCode)), N'') IS NULL
       OR Quantity = 0
       OR InvoiceDate IS NULL
       OR UnitPrice < 0
)
BEGIN
    THROW 50002, 'Staging contains invalid required values. Fix the staging data before loading.', 1;
END;

BEGIN TRY
    BEGIN TRANSACTION;

    DELETE FROM dbo.FactSales;
    DELETE FROM dbo.DimCustomer;
    DELETE FROM dbo.DimProduct;

    DBCC CHECKIDENT ('dbo.DimCustomer', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('dbo.DimProduct', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('dbo.FactSales', RESEED, 0) WITH NO_INFOMSGS;

    ;WITH CustomerCountryCounts AS
    (
        SELECT
            TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(CustomerID)), N'')) AS CustomerID,
            COALESCE(
                NULLIF(LTRIM(RTRIM(REPLACE(REPLACE(Country, CHAR(13), N''), CHAR(10), N''))), N''),
                N'Unknown'
            ) AS Country,
            COUNT_BIG(*) AS CountryRows
        FROM stg.OnlineRetailClean
        WHERE TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(CustomerID)), N'')) IS NOT NULL
        GROUP BY
            TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(CustomerID)), N'')),
            COALESCE(
                NULLIF(LTRIM(RTRIM(REPLACE(REPLACE(Country, CHAR(13), N''), CHAR(10), N''))), N''),
                N'Unknown'
            )
    ),
    RankedCustomerCountries AS
    (
        SELECT CustomerID, Country,
               ROW_NUMBER() OVER
               (PARTITION BY CustomerID ORDER BY CountryRows DESC, Country ASC) AS rn
        FROM CustomerCountryCounts
    )
    INSERT INTO dbo.DimCustomer (CustomerID, Country)
    SELECT CustomerID, Country
    FROM RankedCustomerCountries
    WHERE rn = 1;

    ;WITH RankedProductDescriptions AS
    (
        SELECT
            LTRIM(RTRIM(StockCode)) AS StockCode,
            NULLIF(LTRIM(RTRIM(Descriptionn)), N'') AS Descriptionn,
            ROW_NUMBER() OVER
            (
                PARTITION BY LTRIM(RTRIM(StockCode))
                ORDER BY
                    CASE WHEN NULLIF(LTRIM(RTRIM(Descriptionn)), N'') IS NULL THEN 1 ELSE 0 END,
                    InvoiceDate DESC,
                    Descriptionn ASC
            ) AS rn
        FROM stg.OnlineRetailClean
        WHERE NULLIF(LTRIM(RTRIM(StockCode)), N'') IS NOT NULL
    ),
    ProductPrices AS
    (
        SELECT LTRIM(RTRIM(StockCode)) AS StockCode,
               AVG(NULLIF(UnitPrice, 0)) AS UnitPrice
        FROM stg.OnlineRetailClean
        WHERE NULLIF(LTRIM(RTRIM(StockCode)), N'') IS NOT NULL
        GROUP BY LTRIM(RTRIM(StockCode))
    )
    INSERT INTO dbo.DimProduct (StockCode, Descriptionn, UnitPrice)
    SELECT d.StockCode,
           COALESCE(d.Descriptionn, N'(No description)'),
           p.UnitPrice
    FROM RankedProductDescriptions AS d
    LEFT JOIN ProductPrices AS p ON p.StockCode = d.StockCode
    WHERE d.rn = 1;

    INSERT INTO dbo.FactSales
    (
        InvoiceNo, InvoiceDate, CustomerKey, ProductKey,
        Quantity, UnitPrice, TotalSales, ReturnsAmt, NetSales
    )
    SELECT
        LTRIM(RTRIM(s.InvoiceNo)),
        CAST(s.InvoiceDate AS DATE),
        c.CustomerKey,
        p.ProductKey,
        s.Quantity,
        s.UnitPrice,
        CAST(CASE WHEN s.Quantity > 0 THEN s.Quantity * s.UnitPrice ELSE 0 END AS DECIMAL(18,2)),
        CAST(CASE WHEN s.Quantity < 0 THEN s.Quantity * s.UnitPrice ELSE 0 END AS DECIMAL(18,2)),
        CAST(s.Quantity * s.UnitPrice AS DECIMAL(18,2))
    FROM stg.OnlineRetailClean AS s
    INNER JOIN dbo.DimProduct AS p
        ON p.StockCode = LTRIM(RTRIM(s.StockCode))
    LEFT JOIN dbo.DimCustomer AS c
        ON c.CustomerID = TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(s.CustomerID)), N''))
    WHERE NULLIF(LTRIM(RTRIM(s.InvoiceNo)), N'') IS NOT NULL
      AND s.Quantity <> 0
      AND s.UnitPrice >= 0;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

SELECT
    COUNT_BIG(*) AS FactRows,
    COUNT(DISTINCT InvoiceNo) AS DistinctInvoicesIncludingCredits,
    COUNT(DISTINCT CASE WHEN InvoiceNo NOT LIKE N'C%' THEN InvoiceNo END) AS SalesInvoicesExcludingCredits,
    COUNT(DISTINCT CustomerKey) AS CustomersWithCustomerID,
    COUNT(DISTINCT ProductKey) AS Products,
    SUM(TotalSales) AS GrossSales,
    SUM(ReturnsAmt) AS SignedReturns,
    SUM(NetSales) AS NetSales
FROM dbo.FactSales;
GO
