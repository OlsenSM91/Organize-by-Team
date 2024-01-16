import os
import shutil
import pandas as pd
import tkinter as tk
from tkinter import filedialog, ttk  # Import ttk from tkinter for Combobox

def organize_photos_by_team(csv_path, image_directory, team_col, photo_col):
    df = pd.read_csv(csv_path)
    for index, row in df.iterrows():
        team_name = str(row[team_col]).strip()
        photo_name = str(row[photo_col]).strip()
        team_directory = os.path.join(image_directory, team_name)
        if not os.path.exists(team_directory):
            os.makedirs(team_directory)
        source_path = os.path.join(image_directory, photo_name)
        destination_path = os.path.join(team_directory, photo_name)
        if os.path.exists(source_path):
            shutil.move(source_path, destination_path)

def browse_csv():
    filename = filedialog.askopenfilename(filetypes=[("CSV files", "*.csv")])
    csv_entry.delete(0, tk.END)
    csv_entry.insert(0, filename)

def browse_dir():
    dirname = filedialog.askdirectory()
    dir_entry.delete(0, tk.END)
    dir_entry.insert(0, dirname)

def run_organizer():
    csv_path = csv_entry.get()
    image_directory = dir_entry.get()
    team_col = team_col_combobox.get()
    photo_col = photo_col_combobox.get()
    organize_photos_by_team(csv_path, image_directory, team_col, photo_col)

# Create the main window
window = tk.Tk()
window.title("Sort By Teams")

# Create labels, entries, and buttons
csv_label = tk.Label(window, text="CSV Path (Columns needed: 'Team', 'Photo'):")
csv_label.pack(anchor=tk.W)

csv_entry = tk.Entry(window, width=50)
csv_entry.pack(anchor=tk.W)

csv_browse_button = tk.Button(window, text="Browse", command=browse_csv)
csv_browse_button.pack(anchor=tk.W)

dir_label = tk.Label(window, text="Image Directory (Images to be sorted):")
dir_label.pack(anchor=tk.W)

dir_entry = tk.Entry(window, width=50)
dir_entry.pack(anchor=tk.W)

dir_browse_button = tk.Button(window, text="Browse", command=browse_dir)
dir_browse_button.pack(anchor=tk.W)

# Create comboboxes for column selection
team_col_label = tk.Label(window, text="Team Column Name:")
team_col_label.pack(anchor=tk.W)

team_col_combobox = ttk.Combobox(window, values=["Team", "Division", "Period"], width=47)
team_col_combobox.set("Team")  # Set default value
team_col_combobox.pack(anchor=tk.W)

photo_col_label = tk.Label(window, text="Photo Column Name:")
photo_col_label.pack(anchor=tk.W)

photo_col_combobox = ttk.Combobox(window, values=["Photo", "SPA"], width=47)
photo_col_combobox.set("Photo")  # Set default value
photo_col_combobox.pack(anchor=tk.W)

run_button = tk.Button(window, text="Run Organizer", command=run_organizer)
run_button.pack()

# Add some padding around each widget
for widget in window.winfo_children():
    widget.pack(padx=10, pady=5)

# Start the Tkinter event loop
window.mainloop()