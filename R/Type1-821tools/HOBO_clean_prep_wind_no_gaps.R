# Clear the workspace
rm(list = ls())

########################### START USER INPUT ###########################
# Enter site name
site_name <- "your_site_code" # Typically four letter park code and 3 digit numeric code. Sample dataset ex. (CARE001)
# Enter deployment start date
deploy <- "your_deployment_date" # Typically 8 digits representing the day of deployment in YYYYMMDD. Sample dataset ex. (20241008)

############################# END USER INPUT ##########################

# List of required packages
packages <- c(
  "EnvStats", "reshape2", "ggplot2", "ggthemes",
  "pander", "dplyr", "lubridate", "readxl",
  "tcltk", "svDialogs", "tcltk2", "tidyverse",
  "vtable", "data.table", "ggpubr", "knitr",
  "readr", "sjmisc", "janitor", "plyr",
  "writexl","readr"
)

# Function to load or install required packages
lapply(packages, function(pkg) {
  if (!require(pkg, character.only = TRUE)) {
    install.packages(pkg, dependencies = TRUE)
    library(pkg, character.only = TRUE)
  }
})

############## START PROCESS #############################
# Create full path for the output directory
full_path <- file.path(getwd(), paste0(site_name, "_", deploy))
dir.create(full_path, recursive = TRUE)

# Choose files; only .csv from all HOBO exports for a given site/deployment
# Ensure the date/time format is: '%m/%d/%Y %H:%M:%S'
files <- choose.files()

# Read the files, assuming comma separator
data <- read_delim(file = files, delim = ",", col_select = c(1:4), col_names = FALSE, skip = 1) %>%
  as.data.frame()

# Store original X4 values for comparison later
original_X4 <- data$X4

# If max windspeed is missing, fill it with the 5 sec average from column 3
data <- data %>%
  mutate(X4 = ifelse(is.na(as.numeric(X4)), X3, X4))

# Check if most values are equal; define threshold for "most"
threshold_percentage <- 0.05  # 95%
total_values <- length(original_X4)
equal_values_count <- sum(original_X4 == data$X4, na.rm = TRUE)  # Count equal values, ignoring NAs

# Check if most values are equal
if (equal_values_count / total_values >= threshold_percentage) {
  print("It looks like max wind speed was collected; thus, no replacement was necessary.")
} else {
  # Get the current date and time
  current_time <- format(Sys.time(), "%m/%d/%Y %H:%M:%S")
  
  # Get the current username
  username <- Sys.getenv("USER")  # Use "USERNAME" for Windows if needed
  
  # Create message_text including the date and time of log creation and the username
  message_text <- paste(
    "Log created on:", current_time, "\n",
    "Created by:", username, "\n",
    "Values in max wind column (column 4) were replaced with values from the 5 second average (column 3).",
    "This indicates that non-numeric values were in the max wind speed column and likely presenting as NAs, which can happen during a deployment",
    "where max wind was not configured. Please note that this replacement will still have max wind speed in the column heading but",
    "it will represent the average 5 second wind speed. This will ensure downstream processing of the data set into NVSPL, metrics, and plotting in",
    "the Acoustic Monitoring Toolbox. Any reporting of this dataset should clarify that max wind speeds were replaced with the average wind speeds.",
    sep = "\n"
  )
  
  # Print message to console
  print(message_text)
  
  # Save message to a text file in the correct location
  log_file <- file.path(full_path, paste0(site_name, "_wind_replacement_log.txt"))
  writeLines(message_text, log_file)
  
  # Check if the log file was created successfully
  if (file.exists(log_file)) {
    dir_message <- paste("The wind replacement log has been saved to:", log_file)
    print(dir_message)  # Use print so it appears immediately in the console
    print("Confirmation: The log file has been successfully created indicating max wind speeds did not exist in the downloaded HOBO file.")
  } else {
    print("Warning: The log file could not be found after creating it.")
  }
}
# extract time zone
tzhobo <- substr(gsub(".*\\((.*)\\).*", "\\1", basename(files)), 6,8)


# Rename column 
names(data)[1] <- "#"
names(data)[2] <- paste0("Date-Time (",tzhobo,")")
names(data)[3] <- "Ch:1 - WindSpd - Speed  (m_s)"
names(data)[4] <- "Ch:1 - WindSpd - SpeedMax : Max (m_s)"
# RENAME COMBINED DATA SET
# Must be in the following format: 
# NEW: SERIALNUMBER YYYY-DD-MM HHmmss.csv 
# Using the last date of the SLM sample or the last download date of the HOBO
tzhobo <- substr(gsub(".*\\((.*)\\).*", "\\1", basename(files)), 6,8)
file_name <- basename(tail(files, n = 1))
serial_number <- substr(file_name, 1, 8)
date <- tail(data[2], n = 1)
print(date[[1]])
date <- mdy_hms(date[[1]])
formatted_date <- gsub(":", "", as.character(date))  # Remove colons for the filename
fname <- paste(serial_number," ", formatted_date, ".csv", sep = "")


# Export combined data to CSV; will be placed in the specified project folder
write.csv(data, file.path(full_path, fname), row.names = FALSE, quote = FALSE)

# Print confirmation message about the exported file
cat("Data has been exported to:", file.path(full_path, fname), "\n")



