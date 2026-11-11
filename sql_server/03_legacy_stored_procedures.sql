-- ==============================================================================
-- 03_legacy_stored_procedures.sql
-- Legacy T-SQL batch ETL Stored Procedures
-- Demonstrates legacy on-premises ETL patterns prior to Cloud Lakehouse Migration
-- ==============================================================================

USE EDW_Sales;
GO

-- Stored Procedure to perform SCD Type 2 merge on Dim_Customer_SCD2
CREATE OR ALTER PROCEDURE dbo.sp_Legacy_Load_Customer_SCD2
    @BatchID VARCHAR(50) = 'LEGACY_BATCH_001'
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;

    BEGIN TRY
        DECLARE @CurrentTimestamp DATETIME = GETUTCDATE();

        -- Step 1: Expire previous records that have changed in OLTP
        UPDATE target
        SET 
            target.ValidTo = @CurrentTimestamp,
            target.IsCurrent = 0
        FROM dbo.Dim_Customer_SCD2 target
        INNER JOIN SalesOLTP.dbo.Customers source
            ON target.CustomerCode = source.CustomerCode
        WHERE target.IsCurrent = 1
          AND (
              target.Email <> source.Email
              OR target.AddressLine <> source.AddressLine
              OR target.City <> source.City
              OR target.PostalCode <> source.PostalCode
          );

        -- Step 2: Insert new versions for updated records OR brand new customers
        INSERT INTO dbo.Dim_Customer_SCD2 (
            CustomerCode, FullName, Email, Phone, AddressLine, City,
            StateCode, PostalCode, Country, ValidFrom, ValidTo, IsCurrent, CreatedBatchID
        )
        SELECT
            source.CustomerCode,
            CONCAT(source.FirstName, ' ', source.LastName),
            source.Email,
            source.Phone,
            source.AddressLine,
            source.City,
            source.StateCode,
            source.PostalCode,
            source.Country,
            @CurrentTimestamp,
            NULL,
            1,
            @BatchID
        FROM SalesOLTP.dbo.Customers source
        LEFT JOIN dbo.Dim_Customer_SCD2 target
            ON source.CustomerCode = target.CustomerCode AND target.IsCurrent = 1
        WHERE target.CustomerKey IS NULL;

        COMMIT TRANSACTION;
        PRINT 'Legacy Customer SCD2 Load Completed.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO
