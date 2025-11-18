import os
import pandas as pd
from datetime import datetime
import tkinter as tk
from tkinter import filedialog
import csv  # Import csv module


# globals().clear()

########################### START USER INPUT ###########################
# Enter site name
site_name = "DENACATH"  # Typically four letter park code and 3 digit numeric code. Sample dataset ex. (CARE001)
# Enter deployment start date
deploy = "20250821"  # Typically 8 digits representing the day of deployment in YYYYMMDD. Sample dataset ex. (20241008)
############################# END USER INPUT ##########################

# Create full path for the output directory
full_path = os.path.join(os.getcwd(), f"{site_name}_{deploy}")
os.makedirs(full_path, exist_ok=True)

# Choose files; only .csv from all HOBO exports for a given site/deployment
# Prompt user to select files
root = tk.Tk()
root.withdraw()  # Hide the root window
files = filedialog.askopenfilenames(title="Select CSV files", filetypes=[("CSV files", "*.csv")])

# Read the files, assuming comma separator
data = pd.concat([pd.read_csv(file, skiprows=1, usecols=[0, 1, 2, 3]) for file in files], ignore_index=True)

# Store original X4 values for comparison later
original_X4 = data.iloc[:, 3].copy()

# If max windspeed is missing, fill it with the 5 sec average from column 2
data.iloc[:, 3] = data.iloc[:, 3].where(data.iloc[:, 3].notnull(), data.iloc[:, 2])

# Check if most values are equal; define threshold for "most"
threshold_percentage = 0.05  # 95%
total_values = len(original_X4)
equal_values_count = (original_X4 == data.iloc[:, 3]).sum()  # Count equal values

# Check if most values are equal
if (equal_values_count / total_values) >= threshold_percentage:
    print("It looks like max wind speed was collected; thus, no replacement was necessary.")
else:
    # Get the current date and time
    current_time = datetime.now().strftime("%m/%d/%Y %H:%M:%S")
    
    # Get the current username
    username = os.getlogin()
    
    # Create message_text including the date and time of log creation and the username
    message_text = (
        f"Log created on: {current_time}\n"
        f"Created by: {username}\n"
        "Values in max wind column (column 4) were replaced with values from the 5 second average (column 3).\n"
        "This indicates that non-numeric values were in the max wind speed column and likely presenting as NAs, which can happen during a deployment\n"
        "where max wind was not configured. Please note that this replacement will still have max wind speed in the column heading but\n"
        "it will represent the average 5 second wind speed. This will ensure downstream processing of the data set into NVSPL, metrics, and plotting in\n"
        "the Acoustic Monitoring Toolbox. Any reporting of this dataset should clarify that max wind speeds were replaced with the average wind speeds."
    )
    
    # Print message to console
    print(message_text)
    
    # Save message to a text file in the correct location
    log_file = os.path.join(full_path, f"{site_name}_wind_replacement_log.txt")
    with open(log_file, 'w') as f:
        f.write(message_text)
    
    # Check if the log file was created successfully
    if os.path.exists(log_file):
        print(f"The wind replacement log has been saved to: {log_file}")
        print("Confirmation: The log file has been successfully created indicating max wind speeds did not exist in the downloaded HOBO file.")
    else:
        print("Warning: The log file could not be found after creating it.")

# Extract time zone from filenames
tzhobo = [file.split('(')[1].split(')')[0].strip() for file in files]
tzhobo = tzhobo[0][6:8] if tzhobo else "UTC"  # Handle case where no timezone found

# Rename columns 
data.columns = ["#", f"Date-Time ({tzhobo})", "Ch:1 - WindSpd - Speed  (m_s)", "Ch:1 - WindSpd - SpeedMax : Max (m_s)"]

# RENAME COMBINED DATA SET
# Must be in the following format: NEW: SERIALNUMBER YYYY-DD-MM HHmmss.csv 
file_name = os.path.basename(files[-1])
serial_number = file_name[:8]
date_str = data.iloc[-1, 1]  # Last date-time entry
date = pd.to_datetime(date_str)
formatted_date = date.strftime("%Y-%m-%d %H%M%S").replace(":", "")  # Formatting for the filename

# Combine filename 
fname = f"{serial_number} {formatted_date}.csv"

# Export combined data to CSV; will be placed in the specified project folder
data.to_csv(os.path.join(full_path, fname), index=False, quoting=csv.QUOTE_NONE)

# Print confirmation message about the exported file
print(f"Data has been exported to: {os.path.join(full_path, fname)}")