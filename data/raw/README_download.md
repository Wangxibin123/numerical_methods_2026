# 原始数据下载

Parquet 文件较大（每月约 50–60 MB），不入 git。

## 自动方式

```bash
python code/python/01_download_tlc.py --year 2024 --months 1 2 3 --taxi-type yellow
```

## 手动方式（脚本失败 / 网络受限时）

1. 访问 https://www.nyc.gov/site/tlc/about/tlc-trip-record-data.page
2. 下载 Yellow Taxi 对应月份的 Parquet
3. 同时下载 `taxi_zone_lookup.csv`
4. 全部放到本目录 `data/raw/`

文件命名必须保持原样：

```
yellow_tripdata_YYYY-MM.parquet
taxi_zone_lookup.csv
```

## 直链格式（CloudFront）

```
https://d37ci6vzurychx.cloudfront.net/trip-data/yellow_tripdata_2024-01.parquet
https://d37ci6vzurychx.cloudfront.net/misc/taxi_zone_lookup.csv
```
