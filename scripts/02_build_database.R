# 02_build_database.R
# Cleans the BOS flight files and the NOAA LCDv2 weather files, stores them
# in a SQLite database (data/bos_flights.sqlite), and joins every departure
# to the weather observed just before its scheduled departure hour.
#
# Inputs (created by 01_download_data.R and the manual LCDv2 download):
#   data/raw/bts/bos_YYYY_MM.csv
#   data/raw/weather/LCD_USW00014739_2025.csv
#   data/raw/weather/LCD_USW00014739_2026.csv
#
# Run from the project folder (the one with bos-flight-delays.Rproj).

library(tidyverse)
library(lubridate)
library(DBI)
library(RSQLite)

# -------------------------------------------------------------------------
# 1. Flights
# -------------------------------------------------------------------------
flight_cols <- c("FlightDate", "Month", "DayofMonth", "DayOfWeek",
                 "Reporting_Airline", "Tail_Number",
                 "Flight_Number_Reporting_Airline", "Origin", "Dest",
                 "DestCityName", "DestState", "CRSDepTime", "DepTime",
                 "DepDelay", "DepDelayMinutes", "DepDel15", "TaxiOut",
                 "CRSArrTime", "ArrDelay", "Cancelled", "CancellationCode",
                 "Diverted", "Distance", "CarrierDelay", "WeatherDelay",
                 "NASDelay", "SecurityDelay", "LateAircraftDelay")

flights_raw <- list.files("data/raw/bts", pattern = "^bos_.*\\.csv$",
                          full.names = TRUE) %>%
  map(\(f) read_csv(f, col_types = cols(.default = col_character()),
                    col_select = all_of(flight_cols))) %>%
  bind_rows()

flights <- flights_raw %>%
  mutate(
    flight_date = ymd(FlightDate),
    across(c(Month, DayofMonth, DayOfWeek, DepDelay, DepDelayMinutes,
             DepDel15, TaxiOut, ArrDelay, Cancelled, Diverted, Distance,
             CarrierDelay, WeatherDelay, NASDelay, SecurityDelay,
             LateAircraftDelay), as.numeric),
    # CRSDepTime is local clock time (hhmm), including daylight saving time
    crs_dep_hhmm = as.integer(CRSDepTime),
    crs_dep_hour = (crs_dep_hhmm %/% 100) %% 24,
    crs_dep_min = crs_dep_hhmm %% 100,
    sched_dep_local = make_datetime(year(flight_date), month(flight_date),
                                    day(flight_date), crs_dep_hour,
                                    crs_dep_min, tz = "America/New_York"),
    # NOAA reports weather in Local Standard Time (UTC-5 all year, no DST),
    # so convert the scheduled departure to the same clock before joining
    sched_dep_lst = with_tz(sched_dep_local, tzone = "Etc/GMT+5"),
    weather_hour = format(floor_date(sched_dep_lst, "hour"),
                          "%Y-%m-%d %H:00")
  ) %>%
  select(flight_date, month = Month, day_of_month = DayofMonth,
         day_of_week = DayOfWeek, carrier = Reporting_Airline,
         tail_number = Tail_Number,
         flight_number = Flight_Number_Reporting_Airline,
         origin = Origin, dest = Dest, crs_dep_time = crs_dep_hhmm,
         crs_dep_hour, dep_time = DepTime, dep_delay = DepDelay,
         dep_delay_minutes = DepDelayMinutes, dep_del15 = DepDel15,
         taxi_out = TaxiOut, crs_arr_time = CRSArrTime,
         arr_delay = ArrDelay, cancelled = Cancelled,
         cancellation_code = CancellationCode, diverted = Diverted,
         distance = Distance, carrier_delay = CarrierDelay,
         weather_delay = WeatherDelay, nas_delay = NASDelay,
         security_delay = SecurityDelay,
         late_aircraft_delay = LateAircraftDelay, weather_hour) %>%
  mutate(flight_date = as.character(flight_date))

# -------------------------------------------------------------------------
# 2. Lookup tables (carriers and destination airports)
# -------------------------------------------------------------------------
carrier_names <- c(
  "9E" = "Endeavor Air", "AA" = "American Airlines",
  "AS" = "Alaska Airlines", "B6" = "JetBlue Airways",
  "DL" = "Delta Air Lines", "F9" = "Frontier Airlines",
  "G4" = "Allegiant Air", "HA" = "Hawaiian Airlines",
  "MQ" = "Envoy Air", "NK" = "Spirit Airlines", "OH" = "PSA Airlines",
  "OO" = "SkyWest Airlines", "UA" = "United Airlines",
  "WN" = "Southwest Airlines", "YX" = "Republic Airways")

carriers <- tibble(carrier = sort(unique(flights$carrier))) %>%
  mutate(carrier_name = coalesce(carrier_names[carrier], carrier))

airports <- flights_raw %>%
  distinct(dest = Dest, city = DestCityName, state = DestState) %>%
  group_by(dest) %>%
  slice(1) %>%
  ungroup()

# -------------------------------------------------------------------------
# 3. Weather (NOAA LCDv2, Boston Logan, metric units)
# -------------------------------------------------------------------------
weather_raw <- list.files("data/raw/weather", pattern = "^LCD_.*\\.csv$",
                          full.names = TRUE) %>%
  map(\(f) read_csv(f, col_types = cols(.default = col_character()))) %>%
  bind_rows()

# helper: numeric value with NOAA flags removed ("0.402s" -> 0.402).
# Codes that are not numbers ("T" = trace precipitation, handled separately;
# "VRB" = variable wind direction) become NA, so their warnings are silenced.
num <- function(x) suppressWarnings(parse_number(x, na = c("", "NA", "*")))

weather_obs <- weather_raw %>%
  # FM-15 = routine hourly METAR report (taken at about HH:54)
  filter(str_trim(REPORT_TYPE) == "FM-15") %>%
  mutate(
    obs_time = ymd_hms(DATE, tz = "Etc/GMT+5"),
    # an observation at 13:54 describes conditions at about 14:00
    obs_hour = round_date(obs_time, "hour"),
    precip_trace = str_trim(HourlyPrecipitation) == "T",
    precip_mm = if_else(precip_trace, 0, num(HourlyPrecipitation)),
    wx = coalesce(HourlyPresentWeatherType, ""),
    # lowest broken/overcast/obscured layer = ceiling (in hundreds of m)
    ceiling_m = map_dbl(coalesce(HourlySkyConditions, ""), \(s) {
      layers <- str_match_all(s, "(BKN|OVC|VV):\\d+ ([0-9.]+)")[[1]]
      if (nrow(layers) == 0) NA_real_ else min(as.numeric(layers[, 3])) * 100
    })
  ) %>%
  transmute(
    obs_hour,
    temp_c = num(HourlyDryBulbTemperature),
    dew_point_c = num(HourlyDewPointTemperature),
    rel_humidity = num(HourlyRelativeHumidity),
    visibility_km = num(HourlyVisibility),
    wind_speed_ms = num(HourlyWindSpeed),
    wind_gust_ms = coalesce(num(HourlyWindGustSpeed), 0),
    wind_dir = num(HourlyWindDirection),
    precip_mm = coalesce(precip_mm, 0),
    precip_trace = coalesce(precip_trace, FALSE),
    ceiling_m,
    rain = str_detect(wx, "RA|DZ"),
    snow = str_detect(wx, "SN|PL|SG|GS"),
    fog_mist = str_detect(wx, "FG|BR"),
    thunder = str_detect(wx, "TS"),
    any_precip = rain | snow | precip_mm > 0 | precip_trace
  ) %>%
  arrange(obs_hour) %>%
  # keep one observation per hour (the latest one)
  group_by(obs_hour) %>%
  slice_tail(n = 1) %>%
  ungroup()

# complete hourly grid for the study period; a missing hour takes the
# previous hour's conditions
hour_grid <- tibble(obs_hour = seq(ymd_hms("2025-09-01 00:00:00",
                                           tz = "Etc/GMT+5"),
                                   ymd_hms("2026-09-01 00:00:00",
                                           tz = "Etc/GMT+5"),
                                   by = "hour"))

weather <- hour_grid %>%
  left_join(weather_obs, by = "obs_hour") %>%
  mutate(was_missing = is.na(temp_c)) %>%
  fill(-obs_hour, -was_missing, -ceiling_m, .direction = "down") %>%
  mutate(weather_hour = format(obs_hour, "%Y-%m-%d %H:00")) %>%
  select(weather_hour, everything(), -obs_hour)

# -------------------------------------------------------------------------
# 4. SQLite database and SQL join
# -------------------------------------------------------------------------
con <- dbConnect(SQLite(), "data/bos_flights.sqlite")

dbWriteTable(con, "flights", flights, overwrite = TRUE)
dbWriteTable(con, "weather", weather, overwrite = TRUE)
dbWriteTable(con, "carriers", carriers, overwrite = TRUE)
dbWriteTable(con, "airports", airports, overwrite = TRUE)

dbExecute(con, "DROP TABLE IF EXISTS flights_weather")
dbExecute(con, "
  CREATE TABLE flights_weather AS
  SELECT f.*, c.carrier_name, a.city AS dest_city, a.state AS dest_state,
         w.temp_c, w.dew_point_c, w.rel_humidity, w.visibility_km,
         w.wind_speed_ms, w.wind_gust_ms, w.wind_dir, w.precip_mm,
         w.precip_trace, w.ceiling_m, w.rain, w.snow, w.fog_mist,
         w.thunder, w.any_precip, w.was_missing AS weather_filled
  FROM flights f
  LEFT JOIN carriers c ON f.carrier = c.carrier
  LEFT JOIN airports a ON f.dest = a.dest
  LEFT JOIN weather  w ON f.weather_hour = w.weather_hour
")

# -------------------------------------------------------------------------
# 5. Quick checks
# -------------------------------------------------------------------------
dbListTables(con)

dbGetQuery(con, "
  SELECT COUNT(*) AS flights,
         SUM(temp_c IS NULL) AS flights_without_weather,
         ROUND(AVG(cancelled) * 100, 2) AS pct_cancelled,
         ROUND(AVG(CASE WHEN cancelled = 0 AND diverted = 0
                        THEN dep_del15 END) * 100, 2) AS pct_delayed_15
  FROM flights_weather
")

dbGetQuery(con, "
  SELECT SUM(was_missing) AS hours_filled, COUNT(*) AS hours
  FROM weather
")

# flights without weather fall in NOAA's data gap at the start of the period
# (no hourly reports from 2025-08-29 17:54 to 2025-09-02 12:54 LST)
dbGetQuery(con, "
  SELECT MIN(weather_hour) AS first_hour, MAX(weather_hour) AS last_hour,
         COUNT(*) AS flights
  FROM flights_weather
  WHERE temp_c IS NULL
")

dbDisconnect(con)
