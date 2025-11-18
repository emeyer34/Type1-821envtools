
################ START USER INPUT ##################
# Set site parameters
# Incorrect name
site_from <- "your_site_code" # "your_site_code" Typically four letter park code and 3 digit numeric code. Sample dataset ex. (CARE010)
# Correct name
site_to <- "your_deployment_date" # "your_deployment_date" Typically four letter park code and 3 digit numeric code. Sample dataset ex. (CARE001)

# Specify the file type to change (.wav, .jpeg, .pdf, etc.)
filetype <- "\\.txt$"  # Adjusted pattern to ensure it matches file extension

######### END USER INPUT ###################################


# Function to choose a directory
choose_directory <- function() {
  # Open a directory selection dialog
  return(tclvalue(tkchooseDirectory()))
}

# Navigate to the folder where files need to be changed
path <- choose_directory()
cat("Selected directory:", path, "\n")  # Changed from `selected_directory` to `path`

# Set the working directory
setwd(path)

# List files with the specified extension
Files <- list.files(pattern = filetype, full.names = TRUE)

# Change the part that needs to be changed (From: site_from to: site_to)
newNames <- sub(site_from, site_to, Files)

# Rename all files in the directory
file.rename(Files, newNames)

# Verify the changes
NewFiles <- list.files(pattern = filetype, full.names = TRUE)

# Print the new file names to verify changes
cat("New file names:\n")
print(NewFiles)
