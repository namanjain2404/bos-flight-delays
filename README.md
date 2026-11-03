# Predicting Departure Delays at Boston Logan International Airport

DS 5110 – Essentials of Data Science, Northeastern University (Fall 2026)

**Team:** Naman Jain, Yash Rahul Kava, Sanket Kothari, Jinam Shah, Sai Rishin Bussa

## Project summary

Flight delays impose substantial costs on airlines, airports and passengers, and departures from
congested hubs such as Boston Logan International Airport (BOS) are particularly exposed to weather
disruptions and to delays that propagate through the day. This project aims to (1) characterize when
and why departures from BOS are delayed, (2) quantify the effect of weather conditions on the
likelihood of delay, and (3) predict whether a scheduled departure will be delayed by 15 minutes or
more using only information available before departure.

*The final project abstract will be added here when the report is complete.*

## Data sources

- **Flights:** Bureau of Transportation Statistics (BTS), *Reporting Carrier On-Time Performance
  (1987–present)* – https://www.transtats.bts.gov
- **Weather:** NOAA National Centers for Environmental Information, *Local Climatological Data (LCD)*
  for Boston Logan – https://www.ncei.noaa.gov/products/land-based-station/local-climatological-data

Raw data files are **not** stored in this repository. They are downloaded into a local `data/`
folder, which is excluded by `.gitignore`.

## Methods (planned)

- Store flights, weather, carrier and airport tables in a SQLite database
- Clean and join flights to hourly weather; reshape delay-cause columns
- Exploratory analysis of delay patterns by time of day, carrier, destination and weather
- Statistical inference: tests of proportions and logistic regression for weather and carrier effects
- Prediction with tidymodels: baseline, regularized logistic regression, random forest and XGBoost,
  using a time-based train/test split and ROC-AUC, precision and recall

## Repository structure (planned)

- `data/` – local only, not tracked (raw BTS and NOAA files, SQLite database)
- `scripts/` – R scripts for downloading, cleaning and loading data
- `analysis/` – R Markdown files for EDA, inference and modeling
- `report/` – final report and presentation slides

## Tools

R (tidyverse, tidymodels, DBI/RSQLite), SQLite, R Markdown, Git/GitHub
