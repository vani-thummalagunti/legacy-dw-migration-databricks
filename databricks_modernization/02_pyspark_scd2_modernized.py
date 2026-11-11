"""
Databricks Modernization: 02_pyspark_scd2_modernized
Direct PySpark replacement for Informatica Mapping: m_load_dim_customer_scd2
Replaces: SQ_Customers -> EXP_Clean_Fields -> LKP_DimCustomer -> RTR_Check_Changes -> Target
"""

from pyspark.sql import SparkSession
from pyspark.sql.functions import (
    col, trim, lower, concat_ws, current_timestamp, lit, sha2
)
from delta.tables import DeltaTable

def init_spark():
    return SparkSession.builder \
        .appName("Modernized_SCD2_Informatica_Replacement") \
        .config("spark.sql.extensions", "io.delta.sql.DeltaBaseAttributeParser") \
        .config("spark.sql.catalog.spark_catalog", "org.apache.spark.sql.delta.catalog.DeltaCatalog") \
        .getOrCreate()

def process_scd2_migration(spark, cdc_landing_path, delta_target_path):
    print(f"Reading incoming CDC records from: {cdc_landing_path}")
    df_incoming = spark.read.parquet(cdc_landing_path)

    # 1. Replicating EXP_Clean_Fields transformation logic from Informatica
    df_transformed = df_incoming \
        .withColumn("FullName", concat_ws(" ", trim(col("FirstName")), trim(col("LastName")))) \
        .withColumn("Email", lower(trim(col("Email")))) \
        .withColumn("AddressLine", trim(col("AddressLine"))) \
        .withColumn("CustomerKey", sha2(concat_ws("||", col("CustomerCode"), current_timestamp().cast("string")), 256))

    now = current_timestamp()

    # Check if target Delta table exists
    if not DeltaTable.isDeltaTable(spark, delta_target_path):
        print("Target table does not exist. Initializing Dim_Customer_SCD2 Delta table...")
        df_init = df_transformed \
            .withColumn("ValidFrom", now) \
            .withColumn("ValidTo", lit(None).cast("timestamp")) \
            .withColumn("IsCurrent", lit(True))
        df_init.write.format("delta").mode("overwrite").save(delta_target_path)
        return

    # 2. Modern Delta MERGE replacing Informatica LKP + RTR + UPD transformations
    delta_target = DeltaTable.forPath(spark, delta_target_path)

    # Staged new rows
    df_staged_updates = df_transformed \
        .withColumn("ValidFrom", now) \
        .withColumn("ValidTo", lit(None).cast("timestamp")) \
        .withColumn("IsCurrent", lit(True))

    join_condition = """
        target.CustomerCode = source.CustomerCode
        AND target.IsCurrent = true
        AND (
            target.Email != source.Email
            OR target.AddressLine != source.AddressLine
            OR target.City != source.City
            OR target.PostalCode != source.PostalCode
        )
    """

    # Expire old records in-place
    delta_target.alias("target").merge(
        source=df_staged_updates.alias("source"),
        condition=join_condition
    ).whenMatchedUpdate(
        set={
            "IsCurrent": lit(False),
            "ValidTo": now
        }
    ).execute()

    # Append new active versions
    df_staged_updates.write.format("delta").mode("append").save(delta_target_path)
    print("SCD Type 2 modernized merge finished successfully.")

if __name__ == "__main__":
    spark = init_spark()
    cdc_path = "data/sample_cdc/customers"
    target_path = "data/delta/dim_customer_scd2"
    process_scd2_migration(spark, cdc_path, target_path)
