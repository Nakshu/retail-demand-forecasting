#!/usr/bin/env Rscript
# ==============================================================================
# Time series forecasting for retail demand planning.
#
# For each store, fits both an ARIMA and an ETS (Exponential Smoothing) model
# on a train/test split, forecasts the test period, and compares accuracy
# (MAPE, RMSE) to select the better-performing model per store -- mirroring
# how a real demand-planning workflow would evaluate candidate models before
# committing to one for production forecasting.
#
# Run: Rscript src/forecasting_model.R
# ==============================================================================

suppressMessages(library(dplyr))
suppressMessages(library(forecast))
suppressMessages(library(ggplot2))
suppressMessages(library(tidyr))

dir.create("report/figures", recursive = TRUE, showWarnings = FALSE)

clean <- read.csv("data/processed/retail_sales_clean.csv", stringsAsFactors = FALSE)
clean$date <- as.Date(clean$date)

# Test period: last 60 days held out for evaluation
test_horizon <- 60

stores <- unique(clean$store_id)
results <- list()
accuracy_summary <- data.frame()

for (s in stores) {
  store_data <- clean %>% filter(store_id == s) %>% arrange(date)

  n <- nrow(store_data)
  train <- store_data[1:(n - test_horizon), ]
  test <- store_data[(n - test_horizon + 1):n, ]

  # weekly seasonality (period = 7) captures the day-of-week pattern
  train_ts <- ts(train$units_sold, frequency = 7)

  # --- ARIMA model ---
  arima_fit <- auto.arima(train_ts, seasonal = TRUE, stepwise = TRUE, approximation = TRUE)
  arima_fc <- forecast(arima_fit, h = test_horizon)

  # --- ETS model ---
  ets_fit <- ets(train_ts)
  ets_fc <- forecast(ets_fit, h = test_horizon)

  # --- Accuracy metrics ---
  actual <- test$units_sold

  calc_metrics <- function(forecasted, actual) {
    errors <- actual - forecasted
    mape <- mean(abs(errors / actual), na.rm = TRUE) * 100
    rmse <- sqrt(mean(errors^2, na.rm = TRUE))
    mae <- mean(abs(errors), na.rm = TRUE)
    list(mape = mape, rmse = rmse, mae = mae)
  }

  arima_metrics <- calc_metrics(as.numeric(arima_fc$mean), actual)
  ets_metrics <- calc_metrics(as.numeric(ets_fc$mean), actual)

  best_model <- if (arima_metrics$mape <= ets_metrics$mape) "ARIMA" else "ETS"
  best_forecast <- if (best_model == "ARIMA") arima_fc else ets_fc

  accuracy_summary <- rbind(accuracy_summary, data.frame(
    store_id = s,
    arima_mape = round(arima_metrics$mape, 2),
    arima_rmse = round(arima_metrics$rmse, 1),
    ets_mape = round(ets_metrics$mape, 2),
    ets_rmse = round(ets_metrics$rmse, 1),
    best_model = best_model,
    best_mape = round(min(arima_metrics$mape, ets_metrics$mape), 2)
  ))

  results[[s]] <- list(
    train = train, test = test,
    arima_fc = arima_fc, ets_fc = ets_fc,
    best_model = best_model
  )

  # --- Plot: actual vs forecast for the best model ---
  plot_df <- data.frame(
    date = test$date,
    actual = actual,
    forecast = as.numeric(best_forecast$mean),
    lower = as.numeric(best_forecast$lower[, 2]),  # 95% CI
    upper = as.numeric(best_forecast$upper[, 2])
  )

  p <- ggplot(plot_df, aes(x = date)) +
    geom_ribbon(aes(ymin = lower, ymax = upper), fill = "steelblue", alpha = 0.2) +
    geom_line(aes(y = actual, color = "Actual"), linewidth = 1) +
    geom_line(aes(y = forecast, color = "Forecast"), linewidth = 1, linetype = "dashed") +
    scale_color_manual(values = c("Actual" = "black", "Forecast" = "steelblue")) +
    labs(
      title = sprintf("%s: %s Forecast vs Actual (Test Period)", s, best_model),
      subtitle = sprintf("MAPE: %.2f%%", min(arima_metrics$mape, ets_metrics$mape)),
      x = "Date", y = "Units Sold", color = ""
    ) +
    theme_minimal()

  ggsave(sprintf("report/figures/forecast_%s.png", s), p, width = 9, height = 5)
}

cat("--- Forecast Accuracy Summary (60-day holdout test) ---\n")
print(accuracy_summary)

write.csv(accuracy_summary, "report/forecast_accuracy_summary.csv", row.names = FALSE)

overall_mape <- round(mean(accuracy_summary$best_mape), 2)
cat(sprintf("\nOverall average MAPE across stores (best model per store): %.2f%%\n", overall_mape))
cat(sprintf("Overall average forecast accuracy: %.2f%%\n", 100 - overall_mape))
cat("\nSaved per-store forecast plots to report/figures/\n")
cat("Saved accuracy summary to report/forecast_accuracy_summary.csv\n")
