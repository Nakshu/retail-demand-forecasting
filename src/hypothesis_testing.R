#!/usr/bin/env Rscript
# ==============================================================================
# Statistical hypothesis testing: does running a promotion significantly
# increase daily unit sales?
#
# Uses Welch's t-test (unequal variances assumed) to compare promo vs
# non-promo days, plus a linear regression controlling for store and day-of-
# week effects, to answer the business question with statistical rigor
# rather than just eyeballing a chart.
#
# Run: Rscript src/hypothesis_testing.R
# ==============================================================================

suppressMessages(library(dplyr))

clean <- read.csv("data/processed/retail_sales_clean.csv", stringsAsFactors = FALSE)
clean$date <- as.Date(clean$date)
clean$day_of_week <- factor(weekdays(clean$date))
clean$store_id <- factor(clean$store_id)

cat("=== Hypothesis Test: Do Promotions Increase Sales? ===\n\n")
cat("H0: Mean units sold is the same on promo vs non-promo days\n")
cat("H1: Mean units sold is higher on promo days\n\n")

promo_sales <- clean$units_sold[clean$is_promo == 1]
non_promo_sales <- clean$units_sold[clean$is_promo == 0]

cat(sprintf("Promo days:     n = %d, mean = %.1f, sd = %.1f\n",
            length(promo_sales), mean(promo_sales), sd(promo_sales)))
cat(sprintf("Non-promo days: n = %d, mean = %.1f, sd = %.1f\n\n",
            length(non_promo_sales), mean(non_promo_sales), sd(non_promo_sales)))

t_test_result <- t.test(promo_sales, non_promo_sales, alternative = "greater")

cat("--- Welch's t-test ---\n")
cat(sprintf("t-statistic:      %.3f\n", t_test_result$statistic))
cat(sprintf("p-value:          %.6f\n", t_test_result$p.value))
cat(sprintf("95%% CI (lower):   %.1f\n", t_test_result$conf.int[1]))

alpha <- 0.05
if (t_test_result$p.value < alpha) {
  cat(sprintf("\nResult: Reject H0 (p < %.2f). Promotions are associated with\n", alpha))
  cat("a statistically significant increase in daily unit sales.\n")
} else {
  cat(sprintf("\nResult: Fail to reject H0 (p >= %.2f).\n", alpha))
}

pct_lift <- round(100 * (mean(promo_sales) - mean(non_promo_sales)) / mean(non_promo_sales), 1)
cat(sprintf("\nObserved lift: promo days sell %.1f%% more units on average than non-promo days.\n", pct_lift))

# --- Linear regression controlling for store and day-of-week ---
cat("\n\n=== Linear Regression: Promo Effect Controlling for Store & Day-of-Week ===\n\n")

model <- lm(units_sold ~ is_promo + store_id + day_of_week, data = clean)
model_summary <- summary(model)
print(round(coef(model_summary)["is_promo", , drop = FALSE], 4))

promo_coef <- coef(model)["is_promo"]
promo_pvalue <- coef(model_summary)["is_promo", "Pr(>|t|)"]

cat(sprintf("\nAfter controlling for store and day-of-week effects, running a\n"))
cat(sprintf("promotion is associated with an average increase of %.1f units sold\n", promo_coef))
cat(sprintf("per day (p = %.6f, %s).\n",
            promo_pvalue,
            ifelse(promo_pvalue < 0.05, "statistically significant", "not statistically significant")))

cat(sprintf("\nModel R-squared: %.3f\n", model_summary$r.squared))

# Save results to file for the report
sink("report/hypothesis_test_results.txt")
cat("=== Promotional Impact Analysis ===\n\n")
cat(sprintf("T-test p-value: %.6f\n", t_test_result$p.value))
cat(sprintf("Observed lift: %.1f%%\n", pct_lift))
cat(sprintf("Regression-adjusted effect: +%.1f units/day (p = %.6f)\n", promo_coef, promo_pvalue))
cat(sprintf("Model R-squared: %.3f\n", model_summary$r.squared))
sink()

cat("\nSaved results to report/hypothesis_test_results.txt\n")
