# Clear the workspace
rm(list = ls())

################ START USER INPUT ##################
# Enter site name
site_name <- "OAK002" #"your_site_code" # "your_site_code" Typically four letter park code and 3 digit numeric code. Sample dataset ex. (YOSE013)
# Enter deployment start date
deploy <-  "20250924" # "your_deployment_date" # "your_deployment_date" Typically 8 digits representing the day of deployment in YYYYMMDD. Sample dataset ex. (20240618)
######### END USER INPUT ###################################

# List of required packages
packages <- c(
  "EnvStats", "reshape2", "ggplot2", "ggthemes",
  "pander", "dplyr", "lubridate", "readxl",
  "tcltk", "svDialogs", "tcltk2", "tidyverse",
  "vtable", "data.table", "ggpubr", "knitr",
  "readr", "sjmisc", "janitor", "plyr",
  "writexl"
)

# Function to check and load required packages
lapply(packages, function(pkg) {
  if (!require(pkg, character.only = TRUE)) {
    install.packages(pkg, dependencies = TRUE)
    library(pkg, character.only = TRUE)
  }
})

# Navigate to the SLM files
# Assuming the deployment produces files with specific suffixes
Files <- choose.files()

# Read the files into a list, assuming comma separator
spl_files_df <- lapply(Files, function(file) {
  read_delim(file = file, delim = ",", col_names = TRUE)
})

# Bind the data together into one data frame
data <- do.call(rbind, lapply(spl_files_df, as.data.frame))

# Store the first date/time value
oldvalue <- data[1, 2]
print(oldvalue)  # Print for verification

# Determine the length of the old date/time string
oldvalue_datelength <- nchar(oldvalue)
print(oldvalue_datelength)

# Get the number of files
file_num <- length(Files)

# Store temporary new value if needed
newvalue <- paste0(substr(oldvalue, 1, 10), "  0:00:00")
nchar(newvalue)  # Print character length to confirm

# Check if the date needs to be changed
datechange <- ifelse(oldvalue_datelength == 20, "Y", "N")

# Extract basename from the last file
fname <- basename(Files[file_num])

# Update the date if needed
if (datechange == "Y") {
  data[1, 2] <- newvalue
}

data$Overload[is.na(data$Overload)] <- ""
data$Invalid[is.na(data$Invalid)] <- ""
data$`    Markers    `[is.na(data$`    Markers    `)] <- ""

full_path <- file.path(getwd(), paste0(site_name,"_",deploy))

dir.create(full_path, recursive = TRUE)

# Create the final file path name
fullname <- paste0(site_name, "_", fname)

# Write the data to a CSV file
write.csv(data, file.path(full_path, fullname), row.names = FALSE, quote = FALSE)

