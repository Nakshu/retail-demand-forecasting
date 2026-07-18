# Pipeline Architecture

```
┌─────────────────────────────────┐
│  Synthetic Sales Data Generator  │   3 years, 5 stores, seasonality +
│  (data/generate_synthetic_       │   promo calendar + injected DQ issues
│   sales_data.R)                  │
└────────────────┬──────────────────┘
                 │  data/raw/retail_sales.csv
                 ▼
┌─────────────────────────────────┐
│  EDA & Cleaning                   │   Profile nulls/dupes/negatives,
│  (src/eda_and_cleaning.R)         │   clean, generate exploratory plots
└────────────────┬──────────────────┘
                 │  data/processed/retail_sales_clean.csv
                 ├───────────────────────────────┐
                 ▼                                 ▼
┌─────────────────────────────────┐   ┌─────────────────────────────────┐
│  Forecasting                      │   │  Hypothesis Testing               │
│  (src/forecasting_model.R)        │   │  (src/hypothesis_testing.R)       │
│  ARIMA vs ETS, 60-day holdout,     │   │  T-test + regression on promo     │
│  per-store model selection         │   │  effect, controlling for          │
│                                    │   │  store/day-of-week                │
└────────────────┬──────────────────┘   └────────────────┬──────────────────┘
                 │                                          │
                 ▼                                          ▼
        report/figures/*.png                    report/hypothesis_test_results.txt
        report/forecast_accuracy_summary.csv
```
