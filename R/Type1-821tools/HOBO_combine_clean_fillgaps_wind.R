# Clear the workspace
rm(list = ls())

# Functionality Description:
# Wind speeds are logged at a 5-second interval. This script addresses missing data gaps by 
# filling them with NA values, enabling the combination of SPL data with MET data in AMT.
# The script can handle up to three data gaps during a standard 30-day monitoring period.

############################# START USER INPUT #######################
# Enter site name
site_name <- "your_site_code" # Typically four letter park code and 3 digit numeric code. Sample dataset ex. (YOSE013)
# Enter deployment start date
deploy <- "your_deployment_date" # Typically 8 digits representing the day of deployment in YYYYMMDD. Sample dataset ex. (20240618)


# Missing data input
# length of wind record must match the length of the SLM record. The time steps do not need to be equal.
# The date/time ranges of the SLM and final met output must be the same

# First data gap; USER input start and end times of data gap
sdate1 <- " "  # Start date-add 5 seconds to last sample in first fragmented record
edate1 <- " "     # End date-subtract 5 seconds from the next measured wind sample if there are two files 
                                  # or enter the last time step of the last slm record for this deployment

# Second data gap ("" if only one gap)
sdate2 <- " "    # Start date-add 5 seconds to last sample in the second fragmented record
edate2 <- " "   # End date-subtract 5 seconds from the next measured wind sample if there are three files 
                                  # or enter the last time step of the last slm record for this deployment 

# Third data gap ("" if only two gaps)
sdate3 <- " "                      # Start date -add 5 seconds to last sample in the second fragmented record
edate3 <- " "                      # End date-enter the last timestep of the last slm record for this deployment

############## END USER INPUT ############################################################

# List of required packages
packages <- c(
  "EnvStats", "reshape2", "ggplot2", "ggthemes", "pander", "dplyr",
  "lubridate", "readxl", "tcltk", "svDialogs", "tcltk2", "tidyverse",
  "vtable", "data.table", "ggpubr", "knitr", "readr", "sjmisc",
  "janitor", "plyr", "writexl"
)

# Load or install required packages
lapply(packages, function(pkg) {
  if (!require(pkg, character.only = TRUE)) {
    install.packages(pkg, dependencies = TRUE)
    library(pkg, character.only = TRUE)
  }
})

############## START PROCESS #############################

# Create gap intervals and dataframes
# Create gap 1
start_date1 <- mdy_hms(sdate1, tz = "America/Los_Angeles") 
end_date1 <- mdy_hms(edate1, tz = "America/Los_Angeles")   
gap1 <- data.frame(x = seq(start_date1, end_date1, by = '5 sec'))

# Create gap 2
start_date2 <- mdy_hms(sdate2, tz = "America/Los_Angeles") 
end_date2 <- mdy_hms(edate2, tz = "America/Los_Angeles")   
gap2 <- data.frame(x = seq(start_date2, end_date2, by = '5 sec'))

# Create gap 3
start_date3 <- mdy_hms(sdate3, tz = "America/Los_Angeles") 
end_date3 <- mdy_hms(edate3, tz = "America/Los_Angeles")   
gap3 <- data.frame(x = seq(start_date3, end_date3, by = '5 sec'))


# Choose files; only .csv from all HOBO exports for a given site/deployment
Files <- choose.files()
wind_files_df <- lapply(Files, function(x) { 
  read_delim(file = x, delim = ",", col_select = c(1:4), col_names = FALSE, skip = 1)
})
# extract time zone
tzhobo <- substr(gsub(".*\\((.*)\\).*", "\\1", basename(Files[1])), 6,8)


# Combine wind data into a single dataframe
data <- do.call(rbind, lapply(wind_files_df, as.data.frame))
names(data)[1] <- "#"
names(data)[2] <- paste0("Date-Time (",tzhobo,")")
names(data)[3] <- "Ch:1 - WindSpd - Speed  (m_s)"
names(data)[4] <- "Ch:1 - WindSpd - SpeedMax : Max (m_s)"


# Create a numeric date/time field for sorting later
data <- data %>% mutate(sort = as.numeric(mdy_hms(data[[2]], tz = "America/Los_Angeles")))

# Combine all gap data into a single dataframe
gapdata <- rbind(
  if (exists("gap1")) gap1 else NULL,
  if (exists("gap2")) gap2 else NULL,
  if (exists("gap3")) gap3 else NULL
)

# Create new columns to match incoming "real data"
gapdata <- gapdata %>%
  mutate(
    x1 = "",
    x2 = 0.0000,
    x3 = 0.0000
  ) %>% relocate(x1, .before = 1)  # Ensure x1 is the first column

# Rename column names with the column heading template

names(gapdata)[1] <- "#"
names(gapdata)[2] <- paste0("Date-Time (",tzhobo,")")
names(gapdata)[3] <- "Ch:1 - WindSpd - Speed  (m_s)"
names(gapdata)[4] <- "Ch:1 - WindSpd - SpeedMax : Max (m_s)"
# Create a numeric date/time field for sorting combined data frames later
gapdata <- gapdata %>%
  mutate(sort = as.numeric(gapdata[[2]]))

# Reformat date/time field to match real data from HOBO loggers
gapdata[[2]] <- format(gapdata[[2]], '%m/%d/%Y %H:%M:%S', tz = "America/Los_Angeles")

#### CREATE and EXPORT LOG OF GAP DATES

# Gather start and end dates for missing observations
startdates <- c(if (exists("start_date1")) start_date1, 
                if (exists("start_date2")) start_date2, 
                if (exists("start_date3")) start_date3)

enddates <- c(if (exists("end_date1")) end_date1, 
              if (exists("end_date2")) end_date2, 
              if (exists("end_date3")) end_date3)

missing_observations <- c(if (exists("gap1")) nrow(gap1),
                          if (exists("gap2")) nrow(gap2),
                          if (exists("gap3")) nrow(gap3))

# Ensure missing observations has the same length as start dates
length(missing_observations) <- length(startdates)

# Create data frame for gap log
gaplog <- data.frame(site_name, startdates, enddates, missing_observations)

# Create full path for the output directory
full_path <- file.path(getwd(), paste0(site_name, "_", deploy))
dir.create(full_path, recursive = TRUE)
gapfname <- paste0(site_name,"_", deploy, "_Gap_WS_DataLog.csv")
# Export combined data to CSV; will be placed in specified project folder
write.csv(gaplog, file.path(full_path, gapfname), row.names = FALSE, quote = FALSE)


# Combine real data from HOBO loggers with dummy gap data
data <- rbind(data, gapdata)

# Sort combined data by numeric date/time field to order dataset for AMT
data <- data %>% arrange(sort)

# Create a sequence of numbers for each data record to match HOBO formatting into AMT
data$`#` <- seq.int(nrow(data))

# Reduce dataset to necessary fields - adjust based on required columns
data <- data[1:4]  

# Reformat columns to match HOBO output formatting
data$`#` <- as.numeric(data$`#`)
data$`Ch:1 - WindSpd - Speed  (m_s)` <- as.numeric(as.character(data$`Ch:1 - WindSpd - Speed  (m_s)`))
data$`Ch:1 - WindSpd - SpeedMax : Max (m_s)` <- as.numeric(as.character(data$`Ch:1 - WindSpd - SpeedMax : Max (m_s)`))

# RENAME COMBINED DATA SET
file <- basename(tail(Files, n = 1))
sn <- substr(file, 1, 8)
date <- tail(data[[2]], n = 1)
date <- mdy_hms(date)
formatted_date <- gsub(':', '', as.character(date))
fname <- paste(sn," ", formatted_date, ".csv", sep = "")


# Export combined data to CSV; will be placed in specified project folder
write.csv(data, file.path(full_path, fname), row.names = FALSE, quote = FALSE)

