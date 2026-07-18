# Retail Demand Forecasting & Promotional Impact Analysis (R)

Time series forecasting and statistical analysis of multi-store retail sales
data, built in R. Demonstrates forecasting model selection (ARIMA vs ETS),
accuracy evaluation, and hypothesis testing to answer a real business
question: do promotions actually move the needle on sales?

## 1. Problem

A retail demand planning team needs two things: (1) reliable forecasts of
future demand for inventory and staffing decisions, and (2) statistical
evidence — not just a hunch — about whether promotions are worth running.

This project simulates that workflow using 3 years of synthetic daily sales
data across 5 stores, with realistic weekly/yearly seasonality, a
promotional calendar, and injected data-quality issues.

## 2. Approach

| Stage | Tool | What it does |
|---|---|---|
| Data generation | R (`dplyr`, `lubridate`) | Synthetic daily sales with seasonality, trend, promo effects, and intentional data-quality issues |
| EDA & cleaning | `dplyr`, `ggplot2`, `tidyr` | Profiles nulls/duplicates/negative values, cleans the dataset, visualizes seasonality patterns |
| Forecasting | `forecast` (ARIMA, ETS) | Fits both model families per store, evaluates on a 60-day holdout, picks the better model per store |
| Hypothesis testing | Base R (`t.test`, `lm`) | Welch's t-test and a regression controlling for store/day-of-week to quantify the promotional lift |

## 3. Repo Structure

```
retail-demand-forecasting/
├── data/
│   ├── generate_synthetic_sales_data.R   # Creates data/raw/retail_sales.csv
│   └── processed/                        # Created by eda_and_cleaning.R
├── src/
│   ├── eda_and_cleaning.R                # Data quality profiling + cleaning + plots
│   ├── forecasting_model.R               # ARIMA/ETS forecasting + accuracy eval
│   └── hypothesis_testing.R              # T-test + regression on promo effect
├── report/
│   ├── figures/                          # Generated plots (created on run)
│   ├── store_summary_stats.csv
│   ├── forecast_accuracy_summary.csv
│   └── hypothesis_test_results.txt
├── architecture/
│   └── pipeline_diagram.md
└── README.md
```

## 4. How to Run

```bash
# From the project root
Rscript data/generate_synthetic_sales_data.R
Rscript src/eda_and_cleaning.R
Rscript src/forecasting_model.R
Rscript src/hypothesis_testing.R
```

Each script prints its results to the console and writes outputs to
`data/processed/` or `report/`.

## 5. Results

**Data quality (raw → cleaned):**
- 5,485 rows generated across 5 stores, 3 years of daily data
- 16 missing values, 5 duplicate rows, 3 negative-value anomalies detected and removed
- 5,461 clean rows retained (99.56%)

**Forecasting (60-day holdout test, best model per store):**

| Store | Best Model | MAPE | Forecast Accuracy |
|---|---|---|---|
| Store 1 | ETS | 20.89% | 79.11% |
| Store 2 | ARIMA | 20.33% | 79.67% |
| Store 3 | ETS | 23.00% | 77.00% |
| Store 4 | ETS | 30.49% | 69.51% |
| Store 5 | ETS | 22.52% | 77.48% |
| **Average** | — | **23.45%** | **76.55%** |

**Promotional impact (statistical significance):**
- Promo days averaged 37.8% higher unit sales than non-promo days (raw comparison)
- Welch's t-test: p < 0.001 — the lift is statistically significant, not noise
- After controlling for store and day-of-week effects (linear regression): promotions are associated with **+592.9 units/day** on average (p < 0.001, R² = 0.538)

## 6. Why This Project

Built to demonstrate R-based statistical analysis and time series
forecasting end-to-end — model comparison and selection (not just fitting
one model and reporting it), holdout-based accuracy evaluation, and
hypothesis testing that goes beyond a raw average to control for confounding
variables. This mirrors the kind of forecasting and promotional-lift
analysis used in retail/consumer lending demand planning and marketing
analytics roles.
