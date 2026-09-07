import sys
import boto3
import pandas as pd
from io import StringIO
from awsglue.utils import getResolvedOptions

args = getResolvedOptions(sys.argv, ["INPUT_BUCKET", "OUTPUT_BUCKET"])
INPUT_BUCKET = args["INPUT_BUCKET"]
OUTPUT_BUCKET = args["OUTPUT_BUCKET"]

s3 = boto3.client("s3")


def read_csv_from_s3(bucket, key):
    obj = s3.get_object(Bucket=bucket, Key=key)
    return pd.read_csv(obj["Body"])


# Read source files
movies_df = read_csv_from_s3(INPUT_BUCKET, "raw/movies/movies.csv")
ratings_df = read_csv_from_s3(INPUT_BUCKET, "raw/ratings/ratings.csv")

# Sanity check column names before transforming
print("movies columns:", movies_df.columns.tolist())
print("ratings columns:", ratings_df.columns.tolist())

# Transform: average rating and rating count per movie
avg_ratings = (
    ratings_df.groupby("movieId")["rating"]
    .agg(avg_rating="mean", num_ratings="count")
    .reset_index()
)

# Join movie metadata with aggregated ratings
merged = movies_df.merge(avg_ratings, on="movieId", how="left")

# Write result back to S3
csv_buffer = StringIO()
merged.to_csv(csv_buffer, index=False)
s3.put_object(
    Bucket=OUTPUT_BUCKET,
    Key="transformed/movies_with_ratings.csv",
    Body=csv_buffer.getvalue(),
)

print(f"Wrote {len(merged)} rows to s3://{OUTPUT_BUCKET}/transformed/movies_with_ratings.csv")
