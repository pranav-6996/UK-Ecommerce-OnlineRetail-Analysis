CREATE DATABASE IF NOT EXISTS online_retail;
USE online_retail;

CREATE TABLE IF NOT EXISTS online_retail_raw (
    InvoiceNo        VARCHAR(30)  NULL,
    StockCode        VARCHAR(50)  NULL,
    DescriptionText  VARCHAR(255) NULL,
    QuantityText     VARCHAR(30)  NULL,
    InvoiceDateText  VARCHAR(50)  NULL,
    UnitPriceText    VARCHAR(40)  NULL,
    CustomerIDText   VARCHAR(30)  NULL,
    Country          VARCHAR(100) NULL
) ENGINE=InnoDB CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;

TRUNCATE TABLE online_retail_raw;

LOAD DATA LOCAL INFILE 'C:/PATH/TO/OnlineRetail.csv'
INTO TABLE online_retail_raw
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(
    InvoiceNo,
    StockCode,
    DescriptionText,
    QuantityText,
    InvoiceDateText,
    UnitPriceText,
    CustomerIDText,
    Country
);

CREATE OR REPLACE VIEW online_retail_rejected_rows AS
SELECT
    r.*,
    CASE
        WHEN NULLIF(TRIM(r.InvoiceNo), '') IS NULL THEN 'Missing InvoiceNo'
        WHEN NULLIF(TRIM(r.StockCode), '') IS NULL THEN 'Missing StockCode'
        WHEN COALESCE(TRIM(r.QuantityText), '') NOT REGEXP '^-?[0-9]+$' THEN 'Invalid Quantity'
        WHEN CAST(TRIM(r.QuantityText) AS SIGNED) = 0 THEN 'Zero Quantity'
        WHEN COALESCE(
            STR_TO_DATE(NULLIF(TRIM(r.InvoiceDateText), ''), '%m/%d/%Y %H:%i'),
            STR_TO_DATE(NULLIF(TRIM(r.InvoiceDateText), ''), '%m/%d/%Y %H:%i:%s'),
            STR_TO_DATE(NULLIF(TRIM(r.InvoiceDateText), ''), '%Y-%m-%d %H:%i:%s'),
            STR_TO_DATE(NULLIF(TRIM(r.InvoiceDateText), ''), '%Y-%m-%d %H:%i')
        ) IS NULL THEN 'Invalid InvoiceDate'
        WHEN COALESCE(TRIM(r.UnitPriceText), '') NOT REGEXP '^[+-]?[0-9]+([.][0-9]+)?$' THEN 'Invalid UnitPrice'
        WHEN CAST(TRIM(r.UnitPriceText) AS DECIMAL(18,4)) < 0 THEN 'Negative UnitPrice'
        ELSE 'Other invalid row'
    END AS RejectionReason
FROM online_retail_raw AS r
WHERE
       NULLIF(TRIM(r.InvoiceNo), '') IS NULL
    OR NULLIF(TRIM(r.StockCode), '') IS NULL
    OR COALESCE(TRIM(r.QuantityText), '') NOT REGEXP '^-?[0-9]+$'
    OR (TRIM(r.QuantityText) REGEXP '^-?[0-9]+$' AND CAST(TRIM(r.QuantityText) AS SIGNED) = 0)
    OR COALESCE(
        STR_TO_DATE(NULLIF(TRIM(r.InvoiceDateText), ''), '%m/%d/%Y %H:%i'),
        STR_TO_DATE(NULLIF(TRIM(r.InvoiceDateText), ''), '%m/%d/%Y %H:%i:%s'),
        STR_TO_DATE(NULLIF(TRIM(r.InvoiceDateText), ''), '%Y-%m-%d %H:%i:%s'),
        STR_TO_DATE(NULLIF(TRIM(r.InvoiceDateText), ''), '%Y-%m-%d %H:%i')
    ) IS NULL
    OR COALESCE(TRIM(r.UnitPriceText), '') NOT REGEXP '^[+-]?[0-9]+([.][0-9]+)?$'
    OR (TRIM(r.UnitPriceText) REGEXP '^[+-]?[0-9]+([.][0-9]+)?$'
        AND CAST(TRIM(r.UnitPriceText) AS DECIMAL(18,4)) < 0);

DROP TABLE IF EXISTS online_retail_clean;
CREATE TABLE online_retail_clean (
    InvoiceNo    VARCHAR(30)  NOT NULL,
    StockCode    VARCHAR(50)  NOT NULL,
    Descriptionn VARCHAR(255) NULL,
    Quantity     INT          NOT NULL,
    InvoiceDate  DATETIME     NOT NULL,
    UnitPrice    DECIMAL(18,4) NOT NULL,
    CustomerID   INT          NULL,
    Country      VARCHAR(100) NULL,
    INDEX ix_clean_invoice_date (InvoiceDate),
    INDEX ix_clean_customer (CustomerID),
    INDEX ix_clean_stock_code (StockCode)
) ENGINE=InnoDB CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;

INSERT INTO online_retail_clean
    (InvoiceNo, StockCode, Descriptionn, Quantity, InvoiceDate,
     UnitPrice, CustomerID, Country)
SELECT
    p.InvoiceNo,
    p.StockCode,
    NULLIF(p.DescriptionText, '') AS Descriptionn,
    p.Quantity,
    p.InvoiceDate,
    p.UnitPrice,
    p.CustomerID,
    NULLIF(p.Country, '') AS Country
FROM (
    SELECT
        NULLIF(TRIM(InvoiceNo), '') AS InvoiceNo,
        NULLIF(TRIM(StockCode), '') AS StockCode,
        NULLIF(TRIM(DescriptionText), '') AS DescriptionText,
        CASE WHEN TRIM(QuantityText) REGEXP '^-?[0-9]+$'
             THEN CAST(TRIM(QuantityText) AS SIGNED) ELSE NULL END AS Quantity,
        COALESCE(
            STR_TO_DATE(NULLIF(TRIM(InvoiceDateText), ''), '%m/%d/%Y %H:%i'),
            STR_TO_DATE(NULLIF(TRIM(InvoiceDateText), ''), '%m/%d/%Y %H:%i:%s'),
            STR_TO_DATE(NULLIF(TRIM(InvoiceDateText), ''), '%Y-%m-%d %H:%i:%s'),
            STR_TO_DATE(NULLIF(TRIM(InvoiceDateText), ''), '%Y-%m-%d %H:%i')
        ) AS InvoiceDate,
        CASE WHEN TRIM(UnitPriceText) REGEXP '^[+-]?[0-9]+([.][0-9]+)?$'
             THEN CAST(TRIM(UnitPriceText) AS DECIMAL(18,4)) ELSE NULL END AS UnitPrice,
        CASE WHEN TRIM(CustomerIDText) REGEXP '^[0-9]+$'
             THEN CAST(TRIM(CustomerIDText) AS UNSIGNED) ELSE NULL END AS CustomerID,
        TRIM(REPLACE(REPLACE(COALESCE(Country, ''), CHAR(13), ''), CHAR(10), '')) AS Country
    FROM online_retail_raw
) AS p
WHERE p.InvoiceNo IS NOT NULL
  AND p.StockCode IS NOT NULL
  AND p.Quantity IS NOT NULL
  AND p.Quantity <> 0
  AND p.InvoiceDate IS NOT NULL
  AND p.UnitPrice IS NOT NULL
  AND p.UnitPrice >= 0;

SELECT
    (SELECT COUNT(*) FROM online_retail_raw) AS RawRows,
    (SELECT COUNT(*) FROM online_retail_rejected_rows) AS RejectedRows,
    COUNT(*) AS CleanRows,
    SUM(CASE WHEN Quantity < 0 THEN 1 ELSE 0 END) AS ReturnLines,
    SUM(CASE WHEN InvoiceNo LIKE 'C%' THEN 1 ELSE 0 END) AS CancellationInvoiceLines,
    SUM(CASE WHEN CustomerID IS NULL THEN 1 ELSE 0 END) AS RowsWithoutCustomerID,
    MIN(InvoiceDate) AS FirstInvoiceDate,
    MAX(InvoiceDate) AS LastInvoiceDate
FROM online_retail_clean;

SELECT RejectionReason, COUNT(*) AS RejectedRows
FROM online_retail_rejected_rows
GROUP BY RejectionReason
ORDER BY RejectedRows DESC;

SELECT *
FROM online_retail_clean
WHERE Quantity < 0
ORDER BY InvoiceDate DESC
LIMIT 25;
