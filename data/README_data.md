# 数据说明

## 数据源

NYC Taxi & Limousine Commission (TLC) Trip Record Data — Yellow Taxi。

官方页面：https://www.nyc.gov/site/tlc/about/tlc-trip-record-data.page

文件格式：Parquet（每月一个文件）。文件命名约定：
`yellow_tripdata_YYYY-MM.parquet`

约定下载根目录：

```
https://d37ci6vzurychx.cloudfront.net/trip-data/
```

## 目录约定

```
data/
├── raw/             原始 Parquet（git ignore，需手动下载）
├── processed/       北太天元用 CSV，由 Python 预处理生成
└── README_data.md
```

## 关键字段（Yellow Taxi v2024 schema）

| 字段 | 含义 |
| ---- | ---- |
| `tpep_pickup_datetime`   | 乘车开始时间 |
| `tpep_dropoff_datetime`  | 乘车结束时间 |
| `PULocationID`           | 上车 taxi zone id |
| `DOLocationID`           | 下车 taxi zone id |
| `trip_distance`          | 行程英里 |
| `fare_amount`            | 基础车费 |
| `total_amount`           | 总费用 |
| `passenger_count`        | 乘客数 |

## Taxi Zone Lookup

来自 TLC 提供的 `taxi_zone_lookup.csv`（包含 `LocationID`, `Borough`, `Zone`, `service_zone`）。

## 默认范围

| 配置 | MVP | 最终版 |
| --- | --- | --- |
| 月份 | 2024-01 ~ 2024-03 | 2024-01 ~ 2024-06 |
| 时间粒度 | 1 hour | 1 hour |
| Zone 数量 | top 30 | top 50 |
| Taxi 类型 | Yellow | Yellow |

top zones 从 **训练期** 的 pickup 总量中选取（避免 test 信息泄漏）。

## 预处理产物（processed/）

| 文件 | 用途 |
| ---- | ---- |
| `panel_numeric.csv`          | zone-hour 面板（带 header） |
| `panel_numeric_noheader.csv` | 同上，不带 header — 北太天元 csvread 兜底 |
| `panel_columns.txt`          | 列名清单（每行一个） |
| `zone_meta.csv`              | zone_id / zone_name / borough |
| `top_zones.csv`              | 入选 top K 的 zone_id |
| `cost_matrix_topK.csv`       | K × K OD median trip_distance |
| `test_hours.csv`             | 测试小时（每行一个 unix-hour 或 ISO 时间） |
| `cleaning_summary.csv`       | 清洗逐步样本数变化 |

## 清洗规则（落到代码中）

| 规则 | 说明 |
| ---- | ---- |
| pickup/dropoff 时间缺失 | drop |
| `PULocationID`/`DOLocationID` 缺失 | drop |
| `trip_distance <= 0` 或 `> 100` | drop（异常或离群） |
| `duration_min < 1` 或 `> 180` | drop |
| `fare_amount <= 0` | drop |
| `total_amount <= 0` | drop |
| pickup 时间不在目标月份 | drop |

每一步都记录剩余行数到 `cleaning_summary.csv`。

## 手动下载（脚本失败时）

进入 https://www.nyc.gov/site/tlc/about/tlc-trip-record-data.page

下载对应月份的 Yellow Taxi 文件，放到 `data/raw/`。例如：

```
data/raw/yellow_tripdata_2024-01.parquet
data/raw/yellow_tripdata_2024-02.parquet
data/raw/yellow_tripdata_2024-03.parquet
data/raw/taxi_zone_lookup.csv
```
