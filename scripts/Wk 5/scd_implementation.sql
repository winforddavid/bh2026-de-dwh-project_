-- Setup: Create source table for initial customer data
CREATE TABLE CustomerSource (
    CustomerID VARCHAR(10) PRIMARY KEY,
    Name VARCHAR(50),
    Region VARCHAR(50),
    EffectiveDate DATE
);

-- Insert initial data into the source table
INSERT INTO CustomerSource (CustomerID, Name, Region, EffectiveDate) VALUES
('C001', 'Alice Smith', 'North', '2023-01-01'),
('C002', 'Bob Johnson', 'East', '2023-01-01'),
('C003', 'Carol White', 'West', '2023-01-01'),
('C004', 'David Green', 'North', '2023-01-01'),
('C005', 'Eve Black', 'South', '2023-01-01'),
('C006', 'Frank Miller', 'East', '2023-01-01'),
('C007', 'Grace Lee', 'West', '2023-01-01'),
('C008', 'Henry Wilson', 'North', '2023-01-01'),
('C009', 'Ivy Davis', 'South', '2023-01-01'),
('C010', 'Jack Brown', 'East', '2023-01-01');

-- Scenario: Alice Smith changes her region from 'North' to 'South' on '2023-06-15'.
-- We will simulate this change for each SCD type.


-- SCD Type 1: Overwrite the existing record
-- This type does not preserve history; it only reflects the current state.

-- Create a target table for SCD Type 1
CREATE TABLE Customer_SCD1 (
    CustomerID VARCHAR(10) PRIMARY KEY,
    Name VARCHAR(50),
    Region VARCHAR(50),
    LastUpdatedDate DATE
);

-- Initial load for SCD Type 1 table from CustomerSource
INSERT INTO Customer_SCD1 (CustomerID, Name, Region, LastUpdatedDate)
SELECT CustomerID, Name, Region, EffectiveDate FROM CustomerSource;

-- Apply SCD Type 1 logic for Alice's region change
-- Using MERGE (or UPSERT) for a common approach to update/insert
MERGE INTO Customer_SCD1 AS target
USING (SELECT 'C001' AS CustomerID, 'Alice Smith' AS Name, 'South' AS Region, '2023-06-15' AS LastUpdatedDate) AS source
ON target.CustomerID = source.CustomerID
WHEN MATCHED THEN
    UPDATE SET
        Region = source.Region,
        LastUpdatedDate = source.LastUpdatedDate
WHEN NOT MATCHED THEN
    INSERT (CustomerID, Name, Region, LastUpdatedDate)
    VALUES (source.CustomerID, source.Name, source.Region, source.LastUpdatedDate);

-- Verify the result for Alice in SCD Type 1 table
SELECT 'SCD Type 1 Result for Alice:' AS Scenario, * FROM Customer_SCD1 WHERE CustomerID = 'C001';
SELECT 'All SCD Type 1 Customers:' AS Scenario, * FROM Customer_SCD1;


-- SCD Type 2: Track historical changes by adding new rows
-- This type preserves full history by creating new records for changes and marking old ones as inactive.

-- Create a target table for SCD Type 2
CREATE TABLE Customer_SCD2 (
    CustomerSK INT IDENTITY(1,1) PRIMARY KEY, -- Surrogate Key for unique identification
    CustomerID VARCHAR(10),
    Name VARCHAR(50),
    Region VARCHAR(50),
    StartDate DATE,
    EndDate DATE,
    IsCurrent BOOLEAN -- Flag to indicate if this is the current record
);

-- Initial load for SCD Type 2 table from CustomerSource
INSERT INTO Customer_SCD2 (CustomerID, Name, Region, StartDate, EndDate, IsCurrent)
SELECT CustomerID, Name, Region, EffectiveDate, '9999-12-31', TRUE FROM CustomerSource;

-- Apply SCD Type 2 logic for Alice's region change
-- Step 1: Invalidate the old record for Alice
UPDATE Customer_SCD2
SET EndDate = '2023-06-14', IsCurrent = FALSE
WHERE CustomerID = 'C001' AND IsCurrent = TRUE;

-- Step 2: Insert the new record for Alice with the updated region
INSERT INTO Customer_SCD2 (CustomerID, Name, Region, StartDate, EndDate, IsCurrent)
VALUES ('C001', 'Alice Smith', 'South', '2023-06-15', '9999-12-31', TRUE);

-- Verify the result for Alice in SCD Type 2 table
SELECT 'SCD Type 2 Result for Alice:' AS Scenario, * FROM Customer_SCD2 WHERE CustomerID = 'C001' ORDER BY StartDate;
SELECT 'All SCD Type 2 Customers:' AS Scenario, * FROM Customer_SCD2;


-- SCD Type 3: Track limited history using additional columns
-- This type preserves a limited history (e.g., current and previous state) within the same row.

-- Create a target table for SCD Type 3
CREATE TABLE Customer_SCD3 (
    CustomerID VARCHAR(10) PRIMARY KEY,
    Name VARCHAR(50),
    CurrentRegion VARCHAR(50),
    PreviousRegion VARCHAR(50), -- New column to store the previous region
    LastUpdatedDate DATE
);

-- Initial load for SCD Type 3 table from CustomerSource
INSERT INTO Customer_SCD3 (CustomerID, Name, CurrentRegion, PreviousRegion, LastUpdatedDate)
SELECT CustomerID, Name, Region, NULL, EffectiveDate FROM CustomerSource;

-- Apply SCD Type 3 logic for Alice's region change
-- Update Alice's record: move CurrentRegion to PreviousRegion, then set new CurrentRegion
UPDATE Customer_SCD3
SET
    PreviousRegion = CurrentRegion,
    CurrentRegion = 'South',
    LastUpdatedDate = '2023-06-15'
WHERE CustomerID = 'C001';

-- Verify the result for Alice in SCD Type 3 table
SELECT 'SCD Type 3 Result for Alice:' AS Scenario, * FROM Customer_SCD3 WHERE CustomerID = 'C001';
SELECT 'All SCD Type 3 Customers:' AS Scenario, * FROM Customer_SCD3;

-- Optional: Clean up created tables
-- DROP TABLE CustomerSource;
-- DROP TABLE Customer_SCD1;
-- DROP TABLE Customer_SCD2;
-- DROP TABLE Customer_SCD3;