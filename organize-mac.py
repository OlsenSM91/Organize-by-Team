# I had to change the macOS version to use PyQt instead of tkinter in order to compile as dmg
import os
import shutil
import pandas as pd
from PyQt5.QtWidgets import QApplication, QMainWindow, QLabel, QLineEdit, QPushButton, QComboBox, QFileDialog

class PhotoOrganizer(QMainWindow):
    def __init__(self):
        super().__init__()

        self.setWindowTitle("Sort By Teams")
        self.setGeometry(100, 100, 600, 380)  # Adjusted window size

        self.initUI()

    def initUI(self):
        self.csv_label = QLabel("CSV Path (Columns needed: 'Team', 'Photo'):", self)
        self.csv_label.move(10, 10)
        self.csv_label.setFixedWidth(280)  # Adjusted label width

        self.csv_entry = QLineEdit(self)
        self.csv_entry.setGeometry(10, 40, 480, 25)  # Adjusted entry width

        self.csv_browse_button = QPushButton("Browse", self)
        self.csv_browse_button.setGeometry(500, 40, 80, 25)
        self.csv_browse_button.clicked.connect(self.browse_csv)

        self.dir_label = QLabel("Image Directory (Images to be sorted):", self)
        self.dir_label.move(10, 80)
        self.dir_label.setFixedWidth(280)  # Adjusted label width

        self.dir_entry = QLineEdit(self)
        self.dir_entry.setGeometry(10, 110, 480, 25)  # Adjusted entry width

        self.dir_browse_button = QPushButton("Browse", self)
        self.dir_browse_button.setGeometry(500, 110, 80, 25)
        self.dir_browse_button.clicked.connect(self.browse_dir)

        self.team_col_label = QLabel("Team Column Name:", self)
        self.team_col_label.move(10, 150)
        self.team_col_label.setFixedWidth(280)  # Adjusted label width

        self.team_col_combobox = QComboBox(self)
        self.team_col_combobox.setGeometry(10, 180, 570, 25)  # Adjusted combobox width
        self.team_col_combobox.addItems(["Team", "Division", "Period"])
        self.team_col_combobox.setCurrentText("Team")

        self.photo_col_label = QLabel("Photo Column Name:", self)
        self.photo_col_label.move(10, 220)
        self.photo_col_label.setFixedWidth(280)  # Adjusted label width

        self.photo_col_combobox = QComboBox(self)
        self.photo_col_combobox.setGeometry(10, 250, 570, 25)  # Adjusted combobox width
        self.photo_col_combobox.addItems(["Photo", "SPA"])
        self.photo_col_combobox.setCurrentText("Photo")

        self.run_button = QPushButton("Run Organizer", self)
        self.run_button.setGeometry(250, 290, 0, 40)  # Adjusted button position and width
        self.run_button.clicked.connect(self.run_organizer)
        self.run_button.setFixedWidth(self.run_button.sizeHint().width())  # Adjust width based on text

    def browse_csv(self):
        options = QFileDialog.Options()
        filename, _ = QFileDialog.getOpenFileName(self, "Open CSV File", "", "CSV files (*.csv)", options=options)
        self.csv_entry.setText(filename)

    def browse_dir(self):
        options = QFileDialog.Options()
        dirname = QFileDialog.getExistingDirectory(self, "Select Image Directory", options=options)
        self.dir_entry.setText(dirname)

    def run_organizer(self):
        csv_path = self.csv_entry.text()
        image_directory = self.dir_entry.text()
        team_col = self.team_col_combobox.currentText()
        photo_col = self.photo_col_combobox.currentText()

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


if __name__ == "__main__":
    import sys
    app = QApplication(sys.argv)
    window = PhotoOrganizer()
    window.show()
    sys.exit(app.exec_())
