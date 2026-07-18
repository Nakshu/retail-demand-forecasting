#!/usr/bin/env Rscript
# ==============================================================================
# Generates synthetic multi-store daily retail sales data for the forecasting
# project. Includes realistic patterns: weekly seasonality, yearly seasonality,
# a promotional calendar, and store-level differences -- so the forecasting
# models have real signal (and real noise) to work with.
#
# Output: data/raw/retail_sales.csv
# ==============================================================================

suppressMessages(library(dplyr))
suppressMessages(library(lubridate))

set.seed(42)

n_stores <- 5
start_date <- as.Date("2023-01-01")
end_date <- as.Date("2025-12-31")
dates <- seq(start_date, end_date, by = "day")

generate_store_sales <- function(store_id, dates) {
  n <- length(dates)

  # Base demand level, varies by store
  base_level <- 800 + store_id * 150

  # Yearly growth trend (2-6% per year depending on store)
  growth_rate <- 0.02 + store_id * 0.008
  days_elapsed <- as.numeric(dates - min(dates))
  trend <- base_level * (1 + growth_rate) ^ (days_elapsed / 365)

  # Weekly seasonality: weekends higher than weekdays
  dow <- wday(dates)  # 1 = Sunday ... 7 = Saturday
  weekly_effect <- case_when(
    dow %in% c(1, 7) ~ 1.35,   # Sat/Sun
    dow == 6 ~ 1.15,           # Friday
    TRUE ~ 1.0
  )

  # Yearly seasonality: holiday bump in Nov/Dec, summer dip in Jul/Aug
  month_num <- month(dates)
  yearly_effect <- case_when(
    month_num %in% c(11, 12) ~ 1.45,
    month_num %in% c(7, 8) ~ 0.85,
    month_num == 1 ~ 0.80,     # post-holiday slump
    TRUE ~ 1.0
  )

  # Random promotional days (~8% of days), boosting sales 20-60%
  is_promo <- rbinom(n, 1, 0.08)
  promo_effect <- ifelse(is_promo == 1, runif(n, 1.2, 1.6), 1.0)

  # Noise
  noise <- rnorm(n, mean = 1, sd = 0.08)

  sales <- trend * weekly_effect * yearly_effect * promo_effect * noise
  sales <- pmax(round(sales), 0)

  data.frame(
    store_id = paste0("STORE_", store_id),
    date = dates,
    units_sold = sales,
    is_promo = is_promo
  )
}

all_sales <- bind_rows(lapply(1:n_stores, generate_store_sales, dates = dates))

# Inject a few realistic data-quality issues, similar in spirit to the
# credit-card-pipeline project, so the EDA step has something to catch.
n_rows <- nrow(all_sales)

# 1. A handful of missing values (~0.3%)
na_idx <- sample(1:n_rows, size = round(n_rows * 0.003))
all_sales$units_sold[na_idx] <- NA

# 2. A few duplicate rows (~0.1%)
dup_idx <- sample(1:n_rows, size = round(n_rows * 0.001))
all_sales <- bind_rows(all_sales, all_sales[dup_idx, ])

# 3. A few negative-value anomalies from a hypothetical returns glitch (~0.05%)
neg_idx <- sample(1:nrow(all_sales), size = round(nrow(all_sales) * 0.0005))
all_sales$units_sold[neg_idx] <- -abs(all_sales$units_sold[neg_idx])

dir.create("data/raw", recursive = TRUE, showWarnings = FALSE)
write.csv(all_sales, "data/raw/retail_sales.csv", row.names = FALSE)

cat(sprintf("Generated %d rows across %d stores (%s to %s)\n",
            nrow(all_sales), n_stores, start_date, end_date))
cat("Written to data/raw/retail_sales.csv\n")
