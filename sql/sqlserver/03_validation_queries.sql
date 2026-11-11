USE ONLINE_RETAIL;
GO

SELECT
    COUNT_BIG(*) AS FactRows,
    SUM(TotalSales) AS GrossSales,
    SUM(ABS(ReturnsAmt)) AS ReturnsAbsolute,
    SUM(ReturnsAmt) AS ReturnsSigned,
    SUM(NetSales) AS NetSales,
    SUM(Quantity) AS NetQuantity,
    SUM(CASE WHEN Quantity > 0 THEN Quantity ELSE 0 END) AS GrossQuantitySold,
    SUM(CASE WHEN Quantity < 0 THEN ABS(Quantity) ELSE 0 END) AS ReturnedQuantity,
    COUNT(DISTINCT InvoiceNo) AS DistinctInvoicesIncludingCredits,
    COUNT(DISTINCT CASE WHEN InvoiceNo NOT LIKE N'C%' THEN InvoiceNo END) AS SalesInvoicesExcludingCredits,
    COUNT(DISTINCT CASE WHEN InvoiceNo LIKE N'C%' THEN InvoiceNo END) AS CreditInvoices,
    COUNT(DISTINCT CustomerKey) AS CustomersWithCustomerID,
    COUNT(DISTINCT ProductKey) AS Products,
    MIN(InvoiceDate) AS FirstInvoiceDate,
    MAX(InvoiceDate) AS LastInvoiceDate
FROM dbo.FactSales;
GO

SELECT COUNT_BIG(*) AS RowsWithAmountMismatch
FROM dbo.FactSales
WHERE ABS(NetSales - (TotalSales + ReturnsAmt)) > 0.01;
GO

SELECT
    SUM(CASE WHEN CustomerKey IS NULL THEN 1 ELSE 0 END) AS RowsWithoutCustomerKey,
    SUM(CASE WHEN ProductKey IS NULL THEN 1 ELSE 0 END) AS MissingProductKeyRows
FROM dbo.FactSales;
GO

SELECT
    COUNT_BIG(*) AS CreditInvoiceLines,
    COUNT(DISTINCT InvoiceNo) AS CreditInvoices,
    SUM(ReturnsAmt) AS SignedCreditAmount,
    SUM(ABS(ReturnsAmt)) AS AbsoluteCreditAmount
FROM dbo.FactSales
WHERE InvoiceNo LIKE N'C%';
GO

SELECT YEAR(InvoiceDate) AS [Year], MONTH(InvoiceDate) AS MonthNo,
       SUM(ABS(ReturnsAmt)) AS ReturnsAbsolute,
       COUNT_BIG(*) AS ReturnLineCount
FROM dbo.FactSales
WHERE Quantity < 0
GROUP BY YEAR(InvoiceDate), MONTH(InvoiceDate)
ORDER BY [Year], MonthNo;
GO

SELECT TOP (10) p.StockCode, p.Descriptionn, SUM(f.NetSales) AS NetSales
FROM dbo.FactSales AS f
JOIN dbo.DimProduct AS p ON p.ProductKey = f.ProductKey
GROUP BY p.StockCode, p.Descriptionn
ORDER BY NetSales DESC;
GO

SELECT TOP (10) c.CustomerID, c.Country, SUM(f.NetSales) AS NetSales
FROM dbo.FactSales AS f
JOIN dbo.DimCustomer AS c ON c.CustomerKey = f.CustomerKey
GROUP BY c.CustomerID, c.Country
ORDER BY NetSales DESC;
GO

SELECT
    COUNT_BIG(*) AS FactRows,
    SUM(CASE WHEN c.CustomerKey IS NOT NULL THEN 1 ELSE 0 END) AS MatchedCustomerRows,
    SUM(CASE WHEN p.ProductKey IS NOT NULL THEN 1 ELSE 0 END) AS MatchedProductRows
FROM dbo.FactSales AS f
LEFT JOIN dbo.DimCustomer AS c ON c.CustomerKey = f.CustomerKey
LEFT JOIN dbo.DimProduct AS p ON p.ProductKey = f.ProductKey;
GO
