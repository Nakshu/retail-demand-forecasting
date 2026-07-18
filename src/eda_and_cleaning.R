#!/usr/bin/env Rscript
# ==============================================================================
# Exploratory data analysis and cleaning for the retail sales dataset.
#
# - Profiles data quality issues (nulls, duplicates, negative values)
# - Cleans the dataset
# - Produces summary statistics and exploratory plots (saved as PNGs)
#
# Run: Rscript src/eda_and_cleaning.R
# ==============================================================================

suppressMessages(library(dplyr))
suppressMessages(library(ggplot2))
suppressMessages(library(lubridate))
suppressMessages(library(tidyr))

dir.create("report/figures", recursive = TRUE, showWarnings = FALSE)
dir.create("data/processed", recursive = TRUE, showWarnings = FALSE)

raw <- read.csv("data/raw/retail_sales.csv", stringsAsFactors = FALSE)
raw$date <- as.Date(raw$date)

cat("--- Data Quality Profile (raw) ---\n")
n_total <- nrow(raw)
n_na <- sum(is.na(raw$units_sold))
n_dupes <- sum(duplicated(raw))
n_negative <- sum(raw$units_sold < 0, na.rm = TRUE)

cat(sprintf("Total rows:          %d\n", n_total))
cat(sprintf("Missing units_sold:  %d (%.2f%%)\n", n_na, 100 * n_na / n_total))
cat(sprintf("Duplicate rows:      %d (%.2f%%)\n", n_dupes, 100 * n_dupes / n_total))
cat(sprintf("Negative values:     %d (%.2f%%)\n", n_negative, 100 * n_negative / n_total))

# --- Clean ---
clean <- raw %>%
  distinct() %>%
  filter(!is.na(units_sold), units_sold >= 0) %>%
  arrange(store_id, date)

n_clean <- nrow(clean)
cat(sprintf("\nRows after cleaning: %d (dropped %d, %.2f%%)\n",
            n_clean, n_total - n_clean, 100 * (n_total - n_clean) / n_total))

write.csv(clean, "data/processed/retail_sales_clean.csv", row.names = FALSE)
cat("Written cleaned data to data/processed/retail_sales_clean.csv\n\n")

# --- Summary statistics ---
cat("--- Summary Statistics by Store ---\n")
summary_stats <- clean %>%
  group_by(store_id) %>%
  summarise(
    mean_daily_sales = round(mean(units_sold), 1),
    median_daily_sales = median(units_sold),
    sd_daily_sales = round(sd(units_sold), 1),
    total_units = sum(units_sold),
    promo_days = sum(is_promo),
    .groups = "drop"
  )
print(summary_stats)
write.csv(summary_stats, "report/store_summary_stats.csv", row.names = FALSE)

# --- Plot 1: Daily sales trend across all stores ---
p1 <- ggplot(clean, aes(x = date, y = units_sold, color = store_id)) +
  geom_line(alpha = 0.6) +
  labs(title = "Daily Unit Sales by Store", x = "Date", y = "Units Sold") +
  theme_minimal()
ggsave("report/figures/daily_sales_trend.png", p1, width = 10, height = 5)

# --- Plot 2: Weekly seasonality (day-of-week boxplot) ---
clean$day_of_week <- factor(
  weekdays(clean$date),
  levels = c("Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday")
)
p2 <- ggplot(clean, aes(x = day_of_week, y = units_sold)) +
  geom_boxplot(fill = "steelblue", alpha = 0.6) +
  labs(title = "Sales Distribution by Day of Week", x = "", y = "Units Sold") +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))
ggsave("report/figures/weekly_seasonality.png", p2, width = 8, height = 5)

# --- Plot 3: Monthly seasonality (average by month) ---
clean$month_name <- factor(
  months(clean$date),
  levels = month.name
)
monthly_avg <- clean %>%
  group_by(month_name) %>%
  summarise(avg_sales = mean(units_sold), .groups = "drop")
p3 <- ggplot(monthly_avg, aes(x = month_name, y = avg_sales, group = 1)) +
  geom_line(color = "darkorange", linewidth = 1) +
  geom_point(color = "darkorange", size = 2) +
  labs(title = "Average Sales by Month (Seasonality)", x = "", y = "Avg Units Sold") +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))
ggsave("report/figures/monthly_seasonality.png", p3, width = 8, height = 5)

# --- Plot 4: Promo vs non-promo sales comparison ---
p4 <- ggplot(clean, aes(x = factor(is_promo, labels = c("No Promo", "Promo")), y = units_sold)) +
  geom_boxplot(fill = c("gray70", "tomato"), alpha = 0.7) +
  labs(title = "Sales Impact of Promotions", x = "", y = "Units Sold") +
  theme_minimal()
ggsave("report/figures/promo_impact.png", p4, width = 6, height = 5)

cat("\nSaved 4 exploratory plots to report/figures/\n")
cat("EDA and cleaning complete.\n")
