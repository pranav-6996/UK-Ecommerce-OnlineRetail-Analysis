# Online Retail Sales Analysis — UCI Online Retail II

**Author:** Pranav  
**Stack:** MySQL (ETL & cleaning) → SQL Server (data warehouse, star schema) → Power BI (hybrid model + dashboard)  
**Dataset:** UCI Online Retail II (Kaggle CSV) — cleaned ≈ 800k transaction rows (2010–2011)

---

## Project summary
This project demonstrates an end-to-end business intelligence workflow on a real e-commerce dataset:

1. Ingested raw CSV into **MySQL** and performed robust cleaning (NULL handling, returns handling).  
2. Exported cleaned data and loaded into **SQL Server**.  
3. Modeled a **star schema** with `FactSales` and dimensions (`DimProduct`, `DimCustomer`, `DimInvoice`).  
4. Built a **Power BI** report using hybrid storage (Fact in **Import**, dimension tables in **Dual**) and a `DimDate` created in Power BI.  
5. Implemented DAX measures for totals, time-intelligence (MTD/QTD/YTD), ratios and ranks, and created an interactive dashboard with drillthrough (Product Details & Customer Insights).  
6. Validated results against SQL aggregates, exported PDF/screenshots and published the repo.

This repo is optimized to showcase: SQL (ETL and warehousing), data modelling, DAX, and visualization best practices.

---

## Repo contents
/powerbi
└─ Ecommerce_Project.pbix # Power BI file (dashboard)
└─ measures.md # Documented DAX measures
/sql
├─ cleaning_mysql.sql # MySQL cleaning & LOAD DATA snippets
└─ create_tables.sql # SQL Server create/populate star schema
/screenshots
├─ overview.png
├─ product_details.png
└─ customer_insights.png
/pdf
└─ Ecommerce_Project_Report.pdf
README.md
LICENSE

pgsql
Copy code

---

## Data acquisition & cleaning (MySQL) — key steps
- **Source:** Downloaded *Online Retail II* (Kaggle / UCI).  
- **Bulk load:** `LOAD DATA INFILE` into staging table; used `NULLIF` for blank CustomerID to convert blanks to NULL.  
- **Data hygiene:**
  - Preserved negative `Quantity` values — these represent returns and are analytically useful.  
  - Converted `Quantity * UnitPrice` into `TotalAmount`.  
  - Created `ReturnsAmt = CASE WHEN Quantity < 0 THEN (Quantity * UnitPrice) ELSE 0 END`.  
  - Created `NetSales = TotalAmount` (returns are negative and naturally reduce NetSales).
- **Export:** exported cleaned table (`online_retail_clean`) as CSV from MySQL for SQL Server ingestion (or used migration tool).

**Representative MySQL load snippet**
```sql
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/OnlineRetail.csv'
INTO TABLE online_retail_raw
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n' IGNORE 1 ROWS
(InvoiceNo, StockCode, Description, Quantity, InvoiceDate, UnitPrice, @CustomerID, Country)
SET CustomerID = NULLIF(@CustomerID, '');
SQL Server — star schema & ETL
Staging: Imported cleaned CSV into ONLINE_RETAIL staging table.

Dimensions created:

DimCustomer(CustomerKey PK, CustomerID, Country) — deduplicated by most frequent country for each CustomerID.

DimProduct(ProductKey PK, StockCode, Descriptionn, UnitPrice) — used latest description per StockCode.

DimInvoice(InvoiceKey PK, InvoiceNo, InvoiceDate) — one row per invoice.

Fact: FactSales(FactKey PK, InvoiceKey FK, CustomerKey FK, ProductKey FK, Quantity, TotalSales, ReturnsAmt, NetSales) (line-item grain).

Representative SQL Server create snippet

sql
Copy code
CREATE TABLE DimCustomer (
  CustomerKey INT IDENTITY(1,1) PRIMARY KEY,
  CustomerID INT UNIQUE,
  Country VARCHAR(100)
);

CREATE TABLE DimProduct (
  ProductKey INT IDENTITY(1,1) PRIMARY KEY,
  StockCode VARCHAR(20),
  Descriptionn VARCHAR(255),
  UnitPrice DECIMAL(10,2)
);

CREATE TABLE DimInvoice (
  InvoiceKey INT IDENTITY(1,1) PRIMARY KEY,
  InvoiceNo VARCHAR(20),
  InvoiceDate DATE
);

CREATE TABLE FactSales (
  FactKey INT IDENTITY(1,1) PRIMARY KEY,
  InvoiceKey INT,
  CustomerKey INT,
  ProductKey INT,
  Quantity INT,
  TotalSales DECIMAL(18,2),
  ReturnsAmt DECIMAL(18,2),
  NetSales DECIMAL(18,2)
);
Power BI modeling & choices
Connection mode: started with DirectQuery to show enterprise connectivity, then optimized to hybrid:

FactSales → Import (fast aggregations).

Dim* tables → Dual (keeps flexibility + good performance).

Date table: created in Power BI via DAX CALENDAR() and marked as the report date table.

Relationships:

DimDate[Date] → DimInvoice[InvoiceDate] (one-to-many)

DimInvoice[InvoiceKey] → FactSales[InvoiceKey]

FactSales to DimCustomer and DimProduct via surrogate keys.

Why hybrid? Importing the large fact table makes visuals snappy while Dual dimensions let Power BI choose best query route and demonstrate hybrid modeling ability.

Key DAX measures (high value list)
Copy of main measures used in the report:

DAX
Copy code
Total Sales (Gross) = SUM(FactSales[TotalSales])
Total Returns (Absolute) = SUMX(FactSales, ABS(FactSales[ReturnsAmt]))
Net Sales = SUM(FactSales[NetSales])
Total Quantity = SUM(FactSales[Quantity])
Orders Count = DISTINCTCOUNT(FactSales[InvoiceKey])
Customer Count = DISTINCTCOUNT(FactSales[CustomerKey])

-- Time intelligence:
Net Sales MTD = CALCULATE([Net Sales], DATESMTD(DimDate[Date]))
Net Sales QTD = CALCULATE([Net Sales], DATESQTD(DimDate[Date]))
Net Sales YTD = CALCULATE([Net Sales], DATESYTD(DimDate[Date]))
Net Sales Prev Month = CALCULATE([Net Sales], DATEADD(DimDate[Date], -1, MONTH))
Net Sales MoM % = DIVIDE([Net Sales] - [Net Sales Prev Month], [Net Sales Prev Month], 0)

-- Product rank:
Product Rank = RANKX(ALLSELECTED(DimProduct[ProductKey]), [Net Sales],, DESC, DENSE)
(Full measures list is in /powerbi/measures.md)

Dashboard pages & interactions
Executive Overview: KPIs (Total Sales, Net Sales, Returns, Customer Count), Sales trend, Top Products (bar), Sales by Country (map). Slicers: Year, Country.

Product Details (drillthrough): Product-level matrix (Product Rank, Net Sales, Quantity, Avg Unit Price), product trend, top invoices. Drillthrough is enabled from product visuals.

Customer Insights (drillthrough): Lifetime net sales, trend by InvoiceDate, top products purchased by customer. Drillthrough is enabled from a customer table on Overview.

Validation & testing
Always validate Power BI totals against SQL Server:

sql
Copy code
-- Total net sales
SELECT SUM(NetSales) AS TotalNetSales FROM FactSales;

-- Total returns
SELECT SUM(ReturnsAmt) AS TotalReturns FROM FactSales;

-- Orders & unique customers
SELECT COUNT(DISTINCT InvoiceKey) Orders, COUNT(DISTINCT CustomerKey) Customers FROM FactSales;
Match these values with corresponding cards in Power BI. If mismatch appears, check report filters/slicers and date context.

Performance & deployment notes
For publishing to Power BI Service from on-prem SQL Server: install & configure an On-premises data gateway and register it with your workspace.

Schedule import refreshes for FactSales (Import mode). For DirectQuery parts, ensure the gateway stays online.

If a report page is slow, consider pre-aggregating monthly summaries in SQL and importing the aggregated table for the slow page.

How to reproduce (short)
Download data from Kaggle/UCI.

Load & clean in MySQL (scripts in /sql/cleaning_mysql.sql).

Export cleaned CSV and import into SQL Server (or use SSMA).

Run /sql/create_tables.sql to create dims & fact and populate them.

Open powerbi/Ecommerce_Project.pbix (or connect from a new PBIX to your SQL Server) and adjust the data source.

Verify DAX measures and visuals, export PDF & screenshots.

Files to download / view
Power BI report: /powerbi/Ecommerce_Project.pbix

PDF export: /pdf/Ecommerce_Project_Report.pdf

Screenshots: /screenshots/overview.png, /screenshots/product_details.png, /screenshots/customer_insights.png

SQL scripts: /sql/cleaning_mysql.sql, /sql/create_tables.sql

Notes & design decisions (what to mention in interviews)
Kept negative Quantity values (returns) — modelled returns separately so Net Sales reflects real business performance.

Deduplicated customers by choosing the most frequent country per CustomerID (resolves data quality issues).

Used hybrid model (Import fact, Dual dims) to balance speed and flexibility — explicitly optimized for desktop and service publishing.

Implemented drillthrough & bookmarks for exploratory storytelling.

Contact
If you want to discuss this project or see a walkthrough demo, contact me: pranavdheer6@gmail.com

This repository is an attributed extension of the original project. The supplied Power BI report, PDF, screenshots, and baseline project materials were obtained from the original public repository linked below. The underlying dataset is credited to UCI/Kaggle in the original project; this repository does not claim ownership of that dataset or of the original report/dashboard.
