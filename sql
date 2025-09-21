-- 1. Создание базы данных
USE master;
GO

IF EXISTS(SELECT name FROM sys.databases WHERE name = 'PartnerDB')
    DROP DATABASE PartnerDB;
GO

CREATE DATABASE PartnerDB;
GO

USE PartnerDB;
GO


CREATE TABLE dbo.TempProductTypes (
    TypeName NVARCHAR(100),
    TypeCoefficient NVARCHAR(50)
);
GO

CREATE TABLE dbo.TempPartners (
    PartnerType NVARCHAR(50),
    PartnerName NVARCHAR(255),
    Director NVARCHAR(255),
    Email NVARCHAR(100),
    Phone NVARCHAR(20),
    LegalAddress NVARCHAR(500),
    INN NVARCHAR(12),
    Rating NVARCHAR(10)
);
GO

CREATE TABLE dbo.TempProducts (
    ProductType NVARCHAR(100),
    ProductName NVARCHAR(255),
    Article NVARCHAR(50),
    MinPartnerPrice NVARCHAR(50)
);
GO

CREATE TABLE dbo.TempSales (
    ProductName NVARCHAR(255),
    PartnerName NVARCHAR(255),
    Quantity NVARCHAR(50),
    SaleDate NVARCHAR(50)
);
GO

-- 3. Импорт данных во временные таблицы
BULK INSERT dbo.TempProductTypes
FROM 'E:\Ресурсы\csv\Product_type_import.csv'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = ';',
    ROWTERMINATOR = '\n',
    CODEPAGE = '65001'
);
GO

BULK INSERT dbo.TempPartners
FROM 'E:\Ресурсы\csv\Partners_import.csv'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = ';',
    ROWTERMINATOR = '\n',
    CODEPAGE = '65001'
);
GO

BULK INSERT dbo.TempProducts
FROM 'E:\Ресурсы\csv\Products_import.csv'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = ';',
    ROWTERMINATOR = '\n',
    CODEPAGE = '65001'
);
GO

BULK INSERT dbo.TempSales
FROM 'E:\Ресурсы\csv\Partner_products_import.csv'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = ';',
    ROWTERMINATOR = '\n',
    CODEPAGE = '65001'
);
GO

-- 4. Создание финальных таблиц
CREATE TABLE dbo.ProductTypes (
    ProductTypeID INT IDENTITY(1,1) PRIMARY KEY,
    TypeName NVARCHAR(100) NOT NULL,
    TypeCoefficient DECIMAL(10, 2) NOT NULL
);
GO

CREATE TABLE dbo.Partners (
    PartnerID INT IDENTITY(1,1) PRIMARY KEY,
    PartnerType NVARCHAR(50) NOT NULL,
    Name NVARCHAR(255) NOT NULL UNIQUE,
    Director NVARCHAR(255) NULL,
    Email NVARCHAR(100) NULL,
    Phone NVARCHAR(20) NULL,
    LegalAddress NVARCHAR(500) NULL,
    INN NVARCHAR(12) NULL,
    Rating INT NULL
);
GO

CREATE TABLE dbo.Products (
    ProductID INT IDENTITY(1,1) PRIMARY KEY,
    ProductTypeID INT NOT NULL,
    Name NVARCHAR(255) NOT NULL UNIQUE,
    Article NVARCHAR(50) NULL,
    MinPartnerPrice DECIMAL(15, 2) NULL,
    
    CONSTRAINT FK_Products_ProductTypes FOREIGN KEY (ProductTypeID)
    REFERENCES dbo.ProductTypes(ProductTypeID)
);
GO

CREATE TABLE dbo.Sales (
    SaleID INT IDENTITY(1,1) PRIMARY KEY,
    PartnerID INT NOT NULL,
    ProductID INT NOT NULL,
    Quantity INT NOT NULL CHECK (Quantity > 0),
    SaleDate DATE NOT NULL,
    
    CONSTRAINT FK_Sales_Partners FOREIGN KEY (PartnerID)
    REFERENCES dbo.Partners(PartnerID),
    
    CONSTRAINT FK_Sales_Products FOREIGN KEY (ProductID)
    REFERENCES dbo.Products(ProductID)
);
GO

-- 5. Перенос данных из временных таблиц в финальные с преобразованием типов
-- Типы продукции
INSERT INTO dbo.ProductTypes (TypeName, TypeCoefficient)
SELECT 
    TypeName,
    CAST(REPLACE(TypeCoefficient, ',', '.') AS DECIMAL(10, 2))
FROM dbo.TempProductTypes
WHERE TypeName IS NOT NULL;
GO

-- Партнеры
INSERT INTO dbo.Partners (PartnerType, Name, Director, Email, Phone, LegalAddress, INN, Rating)
SELECT 
    PartnerType,
    PartnerName,
    Director,
    Email,
    Phone,
    LegalAddress,
    INN,
    CAST(Rating AS INT)
FROM dbo.TempPartners
WHERE PartnerName IS NOT NULL;
GO

-- Продукция (сначала добавляем, потом связываем с типами)
INSERT INTO dbo.Products (Name, Article, MinPartnerPrice, ProductTypeID)
SELECT 
    ProductName,
    Article,
    CAST(REPLACE(REPLACE(MinPartnerPrice, ',', '.'), ' ', '') AS DECIMAL(15, 2)),
    pt.ProductTypeID
FROM dbo.TempProducts tp
INNER JOIN dbo.ProductTypes pt ON tp.ProductType = pt.TypeName
WHERE tp.ProductName IS NOT NULL;
GO

-- Продажи
INSERT INTO dbo.Sales (PartnerID, ProductID, Quantity, SaleDate)
SELECT 
    p.PartnerID,
    pr.ProductID,
    CAST(REPLACE(Quantity, ' ', '') AS INT),
    CAST(SaleDate AS DATE)
FROM dbo.TempSales ts
INNER JOIN dbo.Partners p ON ts.PartnerName = p.Name
INNER JOIN dbo.Products pr ON ts.ProductName = pr.Name
WHERE ts.ProductName IS NOT NULL AND ts.PartnerName IS NOT NULL;
GO

-- 6. Очистка временных таблиц
DROP TABLE dbo.TempProductTypes;
DROP TABLE dbo.TempPartners;
DROP TABLE dbo.TempProducts;
DROP TABLE dbo.TempSales;
GO

-- 7. Проверочные запросы
-- Просмотр списка партнеров
SELECT * FROM dbo.Partners ORDER BY Name;
GO

-- Просмотр истории реализации для партнера
SELECT 
    p.Name AS PartnerName,
    pr.Name AS ProductName,
    s.Quantity,
    s.SaleDate,
    (s.Quantity * pr.MinPartnerPrice) AS TotalAmount
FROM dbo.Sales s
INNER JOIN dbo.Partners p ON s.PartnerID = p.PartnerID
INNER JOIN dbo.Products pr ON s.ProductID = pr.ProductID
WHERE p.PartnerID = 1
ORDER BY s.SaleDate DESC;
GO

PRINT 'Module success';
GO
