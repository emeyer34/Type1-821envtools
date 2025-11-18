import os
import pandas as pd
from tkinter import Tk, filedialog
from datetime import datetime
import pytz

# ---------------- USER INPUT ----------------
site_name = "OAK002"
deploy = "09242025"
serial = "00000001"
deploy_tzone = "America/Denver"
adjust_for_dst = False  # Set to True to adjust for DST

# ---------------- FILE SELECTION ----------------
def select_met_files():
    root = Tk()
    root.withdraw()
    file_paths = filedialog.askopenfilenames(title="Select CSV files", filetypes=[("CSV files", "*.csv")])
    return list(file_paths)

# ---------------- READ AND COMBINE ----------------
def read_and_combine_files(file_paths):
    dfs = [pd.read_csv(file) for file in file_paths]
    combined_df = pd.concat(dfs, ignore_index=True)
    return combined_df

# ---------------- TIME CONVERSION ----------------
def convert_utc_to_local(utc_series, tz_name, adjust_dst=True):
    utc = pytz.utc
    local_tz = pytz.timezone(tz_name)

    if adjust_dst:
        local_times = utc_series.dt.tz_localize('UTC').dt.tz_convert(local_tz)
        tz_abbr = local_times.dt.strftime('%Z')
    else:
        # Force standard time (no DST)
        standard_offset = local_tz.utcoffset(datetime(2025, 1, 1))
        local_times = utc_series + standard_offset
        local_times = local_times.dt.tz_localize(None)
        # Manually assign standard time abbreviation
        tz_abbr = [local_tz.localize(datetime(2025, 1, 1)).tzname()] * len(local_times)

    return local_times, tz_abbr

# ---------------- CLEAN AND FORMAT ----------------
def clean_and_format_data(df, tz, adjust_dst):
    df['UTC'] = pd.to_datetime(df['Date-Time (UTC)'], errors='coerce')
    df = df.dropna(subset=['UTC']).copy()

    local_time, tz_abbr = convert_utc_to_local(df['UTC'], tz, adjust_dst)
    df['Date-Time (LOC)'] = local_time.dt.strftime('%m/%d/%Y %H:%M:%S')
    df['Time Zone'] = tz_abbr

    # Rename columns to match R output
    df.rename(columns={
        '#': '#',
        'Ch:1 - WindSpd - Speed  (m_s)': 'Ch:1 - WindSpd - Speed  (m_s)',
        'Ch:1 - WindSpd - SpeedMax : Max (m_s)': 'Ch:1 - WindSpd - SpeedMax : Max (m_s)'
    }, inplace=True)

    # Select and reorder columns
    df = df[['#', 'Date-Time (LOC)', 'Ch:1 - WindSpd - Speed  (m_s)', 'Ch:1 - WindSpd - SpeedMax : Max (m_s)', 'Time Zone']]

    # Ensure numeric types
    df['#'] = pd.to_numeric(df['#'], errors='coerce')
    df['Ch:1 - WindSpd - Speed  (m_s)'] = pd.to_numeric(df['Ch:1 - WindSpd - Speed  (m_s)'], errors='coerce')
    df['Ch:1 - WindSpd - SpeedMax : Max (m_s)'] = pd.to_numeric(df['Ch:1 - WindSpd - SpeedMax : Max (m_s)'], errors='coerce')

    return df.dropna()

# ---------------- EXPORT ----------------
def export_data(df, site_name, deploy, serial):
    output_dir = os.path.join(os.getcwd(), f"{site_name}_{deploy}")
    os.makedirs(output_dir, exist_ok=True)

    last_date_str = df['Date-Time (LOC)'].iloc[-1]
    last_dt = datetime.strptime(last_date_str, "%m/%d/%Y %H:%M:%S")
    formatted_date = last_dt.strftime("%Y-%m-%d %H%M%S")
    filename = f"{serial} {formatted_date}.csv"

    output_path = os.path.join(output_dir, filename)
    df.to_csv(output_path, index=False)
    print(f"Exported to: {output_path}")

# ---------------- MAIN ----------------
if __name__ == "__main__":
    file_paths = select_met_files()
    raw_data = read_and_combine_files(file_paths)
    clean_data = clean_and_format_data(raw_data, deploy_tzone, adjust_for_dst)
    export_data(clean_data, site_name, deploy, serial)
