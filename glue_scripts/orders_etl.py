import logging
import sys

from awsglue.context import GlueContext
from awsglue.job import Job
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from pyspark.sql import functions as F
from pyspark.sql.types import DecimalType, LongType, TimestampType

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

args = getResolvedOptions(sys.argv, ["JOB_NAME", "SOURCE_BUCKET", "TARGET_BUCKET"])

glue_context = GlueContext(SparkContext.getOrCreate())
spark = glue_context.spark_session
job = Job(glue_context)
job.init(args["JOB_NAME"], args)

source = f"s3://{args['SOURCE_BUCKET']}/raw/orders/"
target = f"s3://{args['TARGET_BUCKET']}/processed/orders/"

logger.info("Reading Parquet from %s", source)
orders = spark.read.parquet(source)

logger.info("Casting types, filtering invalid records and removing duplicates")
orders = (
    orders.withColumn("order_id", F.col("order_id").cast(LongType()))
    .withColumn("total_amount", F.col("total_amount").cast(DecimalType(12, 2)))
    .withColumn("ordered_at", F.col("ordered_at").cast(TimestampType()))
    .filter(
        F.col("order_id").isNotNull()
        & F.col("ordered_at").isNotNull()
        & (F.col("total_amount") >= 0)
    )
    .dropDuplicates(["order_id"])
)

logger.info("Adding date columns and partition keys")
orders = (
    orders.withColumn("order_date", F.to_date("ordered_at"))
    .withColumn("order_year", F.year("order_date"))
    .withColumn("order_month", F.month("order_date"))
    .withColumn("processed_at", F.current_timestamp())
    .withColumn("etl_run_date", F.current_date())
    .withColumn("year", F.col("order_year"))
    .withColumn("month", F.date_format("order_date", "MM"))
)

logger.info("Writing partitioned Parquet to %s", target)
orders.write.mode("append").partitionBy("year", "month").parquet(target)
job.commit()
logger.info("ETL complete")