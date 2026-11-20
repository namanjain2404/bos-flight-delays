# 01_download_data.R
# Downloads 12 months of BTS on-time data (Sep 2025 - Aug 2026),
# keeps only departures from Boston Logan (BOS), and saves one small
# CSV per month in data/raw/bts/. The large national files are deleted
# after filtering, so they never take up space in the project.
#
# Run from the project folder (the folder that contains bos-flight-delays.Rproj).

library(tidyverse)

dir.create("data/raw/bts", recursive = TRUE, showWarnings = FALSE)
dir.create("data/raw/weather", recursive = TRUE, showWarnings = FALSE)

options(timeout = 1200)  # monthly zip files are large; allow 20 minutes each

months <- seq(as.Date("2025-09-01"), as.Date("2026-08-01"), by = "month")

for (m in months) {
  m <- as.Date(m)
  year <- format(m, "%Y")
  month <- as.integer(format(m, "%m"))
  out_file <- sprintf("data/raw/bts/bos_%s_%02d.csv", year, month)

  if (file.exists(out_file)) {
    message("Already downloaded: ", out_file)
    next
  }

  url <- sprintf(paste0("https://transtats.bts.gov/PREZIP/",
                        "On_Time_Reporting_Carrier_On_Time_Performance_",
                        "1987_present_%s_%d.zip"), year, month)
  message("Downloading ", year, "-", month, " ...")

  zip_file <- tempfile(fileext = ".zip")
  download.file(url, zip_file, mode = "wb")

  extracted <- unzip(zip_file, exdir = tempdir())
  csv_file <- extracted[str_detect(extracted, "\\.csv$")]

  flights <- read_csv(csv_file, col_types = cols(.default = col_character()),
                      show_col_types = FALSE) %>%
    filter(Origin == "BOS")

  write_csv(flights, out_file)
  message("Saved ", nrow(flights), " BOS departures to ", out_file)

  unlink(c(zip_file, extracted))
}

# Quick check: number of BOS departures per month
list.files("data/raw/bts", full.names = TRUE) %>%
  set_names(basename(.)) %>%
  map_int(\(f) nrow(read_csv(f, col_select = 1, show_col_types = FALSE)))
