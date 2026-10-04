-- =====================================================================
-- Real Estate & Housing Market Intelligence System
-- Database: realestate_db
-- Target Table: house_prices
-- =====================================================================

-- Switch to real estate intelligence database
CREATE DATABASE IF NOT EXISTS realestate_db;
USE realestate_db;

-- ---------------------------------------------------------------------
-- Table Schema Definition: house_prices
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS house_prices (
    Id INT PRIMARY KEY,
    SalePrice FLOAT,
    Total_SF FLOAT,
    House_Age INT,
    OverallQual INT,
    OverallCond INT,
    GrLivArea FLOAT,
    GarageArea FLOAT,
    TotalBsmtSF FLOAT,
    Total_Bathrooms FLOAT,
    Has_Pool INT,
    Has_Garage INT,
    Has_Basement INT,
    Has_Fireplace INT,
    Quality_Score INT,
    Neighborhood VARCHAR(50),
    BldgType VARCHAR(50),
    HouseStyle VARCHAR(50),
    SaleCondition VARCHAR(50),
    Season_Sold VARCHAR(20),
    BedroomAbvGr INT,
    Price_Per_SF FLOAT,
    Is_New INT,
    Predicted_Price_RF FLOAT,
    Predicted_Price_XGB FLOAT
);

-- =====================================================================
-- QUERY 1: Average Price and Property Count by Neighborhood
-- OBJECTIVE: Identify top-performing residential enclaves and assess market liquidity
-- TECHNIQUE: GROUP BY, ORDER BY, LIMIT (Top 15 Neighborhoods)
-- =====================================================================
SELECT 
    Neighborhood, 
    COUNT(*) AS Total_Houses_Sold, 
    ROUND(AVG(SalePrice), 2) AS Avg_Sale_Price,
    ROUND(MIN(SalePrice), 2) AS Min_Sale_Price,
    ROUND(MAX(SalePrice), 2) AS Max_Sale_Price,
    ROUND(AVG(Price_Per_SF), 2) AS Avg_Price_Per_SF,
    ROUND(AVG(Total_SF), 2) AS Avg_Square_Footage
FROM house_prices
GROUP BY Neighborhood
ORDER BY Avg_Sale_Price DESC
LIMIT 15;


-- =====================================================================
-- QUERY 2: Housing Price Segmentation & Inventory Distribution
-- OBJECTIVE: Classify properties into structured tiers and compute spatial profiles
-- SEGMENTS:
--   - Budget: under $100,000
--   - Affordable: $100,000 to $200,000
--   - Mid Range: $200,000 to $300,000
--   - High End: above $300,000 (Max price in dataset is ~$340k)
-- TECHNIQUE: CASE WHEN conditional classification with aggregate metrics
-- =====================================================================
SELECT 
    CASE 
        WHEN SalePrice < 100000 THEN 'Budget (< $100k)'
        WHEN SalePrice BETWEEN 100000 AND 200000 THEN 'Affordable ($100k - $200k)'
        WHEN SalePrice > 200000 AND SalePrice <= 300000 THEN 'Mid Range ($200k - $300k)'
        ELSE 'High End (above $300k)'
    END AS Price_Segment,
    COUNT(*) AS Property_Count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM house_prices), 2) AS Inventory_Share_Pct,
    ROUND(AVG(SalePrice), 2) AS Avg_Sale_Price,
    ROUND(AVG(Total_SF), 2) AS Avg_Total_SF,
    ROUND(AVG(GrLivArea), 2) AS Avg_Living_Area,
    ROUND(AVG(Price_Per_SF), 2) AS Avg_Price_Per_SF
FROM house_prices
GROUP BY 
    CASE 
        WHEN SalePrice < 100000 THEN 'Budget (< $100k)'
        WHEN SalePrice BETWEEN 100000 AND 200000 THEN 'Affordable ($100k - $200k)'
        WHEN SalePrice > 200000 AND SalePrice <= 300000 THEN 'Mid Range ($200k - $300k)'
        ELSE 'High End (above $300k)'
    END
ORDER BY Avg_Sale_Price ASC;


-- =====================================================================
-- QUERY 3: Price Premium and ML Prediction Variance by Quality Rating
-- OBJECTIVE: Evaluate how physical build rating impacts valuation and ML model error
-- TECHNIQUE: GROUP BY OverallQual with Mean Absolute Error (MAE) derivation
-- =====================================================================
SELECT 
    OverallQual AS Quality_Rating,
    COUNT(*) AS Property_Count,
    ROUND(AVG(SalePrice), 2) AS Avg_Sale_Price,
    ROUND(AVG(Price_Per_SF), 2) AS Avg_Price_Per_SF,
    ROUND(AVG(ABS(SalePrice - Predicted_Price_XGB)), 2) AS XGBoost_MAE,
    ROUND(AVG(ABS(SalePrice - Predicted_Price_RF)), 2) AS RandomForest_MAE,
    ROUND(AVG(ABS(SalePrice - Predicted_Price_XGB)) / AVG(SalePrice) * 100, 2) AS Prediction_Error_Pct
FROM house_prices
GROUP BY OverallQual
ORDER BY Quality_Rating ASC;


-- =====================================================================
-- QUERY 4: Seasonal Sales Analysis with Cumulative Volume & Running Averages
-- OBJECTIVE: Detect real estate seasonality, transaction spikes, and pricing trends
-- TECHNIQUE: Subquery aggregation combined with Window Functions (OVER, SUM, AVG)
-- =====================================================================
SELECT 
    Season_Sold,
    Sales_Count,
    ROUND(Season_Avg_Price, 2) AS Season_Avg_Price,
    SUM(Sales_Count) OVER (
        ORDER BY FIELD(Season_Sold, 'Winter', 'Spring', 'Summer', 'Fall')
    ) AS Cumulative_Sales_Count,
    ROUND(AVG(Season_Avg_Price) OVER (
        ORDER BY FIELD(Season_Sold, 'Winter', 'Spring', 'Summer', 'Fall')
    ), 2) AS Running_Avg_Price
FROM (
    SELECT 
        Season_Sold,
        COUNT(*) AS Sales_Count,
        AVG(SalePrice) AS Season_Avg_Price
    FROM house_prices
    GROUP BY Season_Sold
) AS Seasonal_Summary
ORDER BY FIELD(Season_Sold, 'Winter', 'Spring', 'Summer', 'Fall');


-- =====================================================================
-- QUERY 5: High-Value Property Profile (Top 10% High-End Decile)
-- OBJECTIVE: Profile architectural attributes and amenity packages of top high-end tier
-- TECHNIQUE: Common Table Expression (CTE) utilizing PERCENT_RANK() analytic window function
-- =====================================================================
WITH RankedProperties AS (
    SELECT 
        Id,
        Neighborhood,
        SalePrice,
        Total_SF,
        GrLivArea,
        OverallQual,
        House_Age,
        Total_Bathrooms,
        GarageArea,
        Has_Fireplace,
        Has_Pool,
        Price_Per_SF,
        PERCENT_RANK() OVER (ORDER BY SalePrice DESC) AS Price_Percentile
    FROM house_prices
)
SELECT 
    Id,
    Neighborhood,
    SalePrice,
    Total_SF,
    GrLivArea,
    OverallQual,
    House_Age,
    Total_Bathrooms,
    GarageArea,
    Has_Fireplace,
    Has_Pool,
    Price_Per_SF
FROM RankedProperties
WHERE Price_Percentile <= 0.10
ORDER BY SalePrice DESC;
