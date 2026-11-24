# Predicting Departure Delays at Boston Logan International Airport

DS 5110 – Essentials of Data Science, Northeastern University (Fall 2026)

**Team:** Naman Jain, Yash Rahul Kava, Sanket Kothari, Jinam Shah, Sai Rishin Bussa

## Abstract

Flight delays impose substantial costs on airlines, airports and passengers, and departures from
congested hubs such as Boston Logan International Airport (BOS) are exposed both to weather and to
delays that build up over the day. This project set out to describe when and why departures from BOS
are delayed, to measure how much weather increases the risk of a delay, and to predict delays before
departure. We combined official U.S. on-time records for all 144,174 scheduled BOS departures between
September 2025 and August 2026 with hourly weather observations at the airport. About one in four
operated departures left at least 15 minutes late, and the risk rose sharply over the day, from under
10% in the early morning to over 40% in the evening. Precipitation increased the delay rate from 22%
to 36%, an effect that remained after accounting for time of day, season and airline. Machine
learning models trained on earlier months identified about half of the delayed flights in the
following summer, with a simple regularized logistic regression performing almost as well as
gradient-boosted trees. The time of day was by far the most important predictor.

## Data sources

- **Flights:** Bureau of Transportation Statistics (BTS), *Reporting Carrier On-Time Performance
  (1987–present)*, https://www.transtats.bts.gov
- **Weather:** NOAA National Centers for Environmental Information, *Local Climatological Data
  Version 2 (LCDv2)*, station USW00014739 (Boston Logan),
  https://www.ncei.noaa.gov/products/land-based-station/local-climatological-data

Raw data files are **not** stored in this repository. They are downloaded into a local `data/`
folder, which is excluded by `.gitignore`.

## Repository structure

- `scripts/01_download_data.R` – downloads 12 months of BTS data and keeps only BOS departures
- `scripts/02_build_database.R` – cleans flights and weather, builds the SQLite database
  (`data/bos_flights.sqlite`) and joins flights to the weather at their scheduled departure hour
- `analysis/03_eda_inference.Rmd` – exploratory analysis and statistical inference
- `analysis/04_modeling.Rmd` – predictive modeling with tidymodels and evaluation
- `data/` – local only, not tracked

## How to reproduce

1. Clone the repository and open `bos-flight-delays.Rproj` in RStudio.
2. Install the required packages:

   ```r
   install.packages(c("tidyverse", "lubridate", "DBI", "RSQLite", "broom",
                      "tidymodels", "glmnet", "ranger", "xgboost", "rmarkdown"))
   ```

3. Run `scripts/01_download_data.R` to download the flight data (September 2025 to August 2026).
4. Download the NOAA LCDv2 files `LCD_USW00014739_2025.csv` and `LCD_USW00014739_2026.csv`
   (Bulk Download → Access Files on the NOAA LCD page above) into `data/raw/weather/`.
5. Run `scripts/02_build_database.R` to build the database.
6. Knit `analysis/03_eda_inference.Rmd` and `analysis/04_modeling.Rmd`.

## Main results

| Model | CV ROC-AUC (grouped by date) | Test ROC-AUC | Test PR-AUC |
|---|---|---|---|
| XGBoost | 0.742 | 0.745 | 0.543 |
| Lasso logistic regression | 0.723 | 0.743 | 0.524 |
| Random forest | 0.740 | 0.733 | 0.522 |
| Majority-class baseline | | 0.500 | 0.266 |

## Limitations

- Month cannot be used as a predictor with a time-based split, and the summer test months had a
  higher delay rate (26.6%) than the training months (23.3%).
- The models do not use the delay of each aircraft's previous (inbound) flight, although late
  aircraft cause almost half of all delay minutes.
- Weather is measured only at BOS, and the study covers one airport and one year.
- NOAA's hourly weather data has a gap from 2025-08-29 to 2025-09-02, so 646 early-September flights
  have no weather data and are excluded from the weather analysis and models.

## Tools

R (tidyverse, tidymodels, glmnet, ranger, xgboost, DBI/RSQLite), SQLite, R Markdown, Git/GitHub

## License

MIT License (see `LICENSE`).
