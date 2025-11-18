# Clear the workspace
rm(list = ls())

# Functionality Description:
# Wind speeds are logged at a 5-second interval. This script is for combining and cleaning daily wind files from the 
# Adafruit Feather m0 adalogger, aka "Feather" microcontroller (MC). This datalogger intends to replace the existing HOBO logger.
# Data from the Feather unit differs in that 1.) Times are in UTC; and 2.) instead of one file, there are daily files created. 
# This script will combine the daily files, convert UTC to local time, and export data into a csv with the required naming convention. 


############################# START USER INPUT #######################
# Enter site name
site_name <- "OAK002" # Typically four letter park code and 3 digit numeric code. Sample dataset ex. (YOSE013) "your_site_code"
# Enter deployment start date
deploy <- "09242025" # Typically 8 digits representing the day of deployment in YYYYMMDD. Sample dataset ex. (20240618) "your_deployment_date"

serial <- "00000001" # eight character serial number on the metadata file "your_serial_number"

OlsonNames() # find time zone of deployment and copy into deploy_tzone

deploy_tzone <- "America/Denver"  #local time zone for data collection "your_time_zone"

# Daylight Saving Time adjustment
adjust_for_dst <- FALSE  # Set to FALSE to ignore DST and use standard time only


############################# LOAD PACKAGES ##########################
required_packages <- c(
  "lubridate", "readr", "dplyr", "tcltk", "data.table", "janitor"
)

load_packages <- function(packages) {
  lapply(packages, function(pkg) {
    if (!require(pkg, character.only = TRUE)) {
      install.packages(pkg, dependencies = TRUE)
      library(pkg, character.only = TRUE)
    }
  })
}
load_packages(required_packages)

############################# FUNCTIONS ##############################

# Prompt user to select files
select_met_files <- function() {
  choose.files()
}

# Read and combine CSV files
read_and_combine_files <- function(file_paths) {
  met_files_df <- lapply(file_paths, function(file) {
    read_delim(file = file, delim = ",", col_names = TRUE)
  })
  do.call(rbind, lapply(met_files_df, as.data.frame))
}

# Convert UTC to local time with or without DST
convert_utc_to_local <- function(utc_times, tz, adjust_dst = TRUE) {
  if (adjust_dst) {
    # Convert to local time zone with DST adjustment
    local_time <- with_tz(utc_times, tzone = tz)
  } else {
    # Force standard time (no DST)
    reference_date <- as.POSIXct("2025-01-01", tz = tz)
    standard_offset <- as.numeric(force_tz(reference_date, tzone = "UTC") - as.POSIXct(format(reference_date, tz = "UTC"), tz = "UTC"))
    local_time <- utc_times + standard_offset
    attr(local_time, "tzone") <- tz  # Assign time zone label
  }
  
  # Extract time zone abbreviation (e.g., MST, MDT)
  tz_abbr <- format(local_time, "%Z")
  
  list(local_time = local_time, tz_abbr = tz_abbr)
}



# Clean and format data
clean_and_format_data <- function(data, tz, adjust_dst) {
  data$UTC <- mdy_hms(data$`Date-Time (UTC)`, tz = "UTC")
  
  local_conversion <- convert_utc_to_local(data$UTC, tz, adjust_dst)
  data$local_time <- local_conversion$local_time
  data$tz_abbr <- local_conversion$tz_abbr
  
  data$local_time_char <- format(data$local_time, format = "%m/%d/%Y %H:%M:%S")
  
  # Reduce and reorder columns
  data <- data[, c(1, 3, 4, which(names(data) == "local_time_char"), which(names(data) == "tz_abbr"))]
  names(data)[4] <- "Date-Time (LOC)"
  names(data)[5] <- "Time Zone"
  data <- data[, c(1, 4, 2, 3, 5)]
  
  # Reformat columns
  data$`#` <- as.numeric(data$`#`)
  data$`Ch:1 - WindSpd - Speed  (m_s)` <- as.numeric(as.character(data$`Ch:1 - WindSpd - Speed  (m_s)`))
  data$`Ch:1 - WindSpd - SpeedMax : Max (m_s)` <- as.numeric(as.character(data$`Ch:1 - WindSpd - SpeedMax : Max (m_s)`))
  
  na.omit(data)
}


# Export cleaned data
export_data <- function(data, site_name, deploy, serial) {
  full_path <- file.path(getwd(), paste0(site_name, "_", deploy))
  dir.create(full_path, recursive = TRUE, showWarnings = FALSE)
  
  last_date <- tail(data[[2]], n = 1)
  formatted_date <- gsub(":", "", as.character(mdy_hms(last_date)))
  fname <- paste0(serial, " ", formatted_date, ".csv")
  
  write.csv(data, file.path(full_path, fname), row.names = FALSE, quote = FALSE)
}

############################# MAIN SCRIPT ############################

file_paths <- select_met_files()
raw_data <- read_and_combine_files(file_paths)
clean_data <- clean_and_format_data(raw_data, deploy_tzone, adjust_for_dst)
export_data(clean_data, site_name, deploy, serial)
