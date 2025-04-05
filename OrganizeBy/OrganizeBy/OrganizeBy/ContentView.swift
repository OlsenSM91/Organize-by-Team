import SwiftUI
import UniformTypeIdentifiers

// MARK: - Data Models
struct ProcessingSummary {
    var processedCount: Int = 0
    var skippedCount: Int = 0
    var missingPhotos: [String] = []
    var duplicatePhotos: [String] = []
    var errorMessages: [String] = []
}

enum OrganizeMode: String, CaseIterable, Identifiable {
    case move = "Move Files"
    case copy = "Copy Files"
    
    var id: String { self.rawValue }
    
    var description: String {
        switch self {
        case .move:
            return "Move original files to team folders"
        case .copy:
            return "Copy files to team folders (keep originals)"
        }
    }
    
    var systemImage: String {
        switch self {
        case .move:
            return "arrow.right"
        case .copy:
            return "doc.on.doc"
        }
    }
}

// MARK: - Main View
struct ContentView: View {
    // CSV and directory state
    @State private var csvURL: URL?
    @State private var imagesDirectoryURL: URL?
    @State private var outputDirectoryURL: URL? // New separate output directory option
    
    // CSV column mapping
    @State private var folderColumn = "Team"
    @State private var photoColumn = "Photo"
    @State private var loadedHeaders: [String] = []
    @State private var secondaryFolderColumn: String?
    @State private var useSecondaryFolder = false
    
    // UI State
    @State private var statusMessages: [String] = []
    @State private var processingStats = ProcessingSummary()
    @State private var isProcessing = false
    @State private var showProgressView = false
    @State private var progressValue: Double = 0
    @State private var totalFiles = 0
    @State private var organizeMode: OrganizeMode = .move
    @State private var showAdvancedOptions = false
    @State private var createMissingPhotosLog = true
    @State private var includeSubfolders = true
    @State private var overwriteExistingFiles = false
    
    // Validation states
    @State private var csvError: String?
    @State private var directoryError: String?
    
    // MARK: - View Body
    var body: some View {
        VStack(spacing: 0) {
    // Header
            HStack {
                Text("📸 OrganizeBy CSV")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button(action: {
                    showAdvancedOptions.toggle()
                }) {
                    Label("Advanced Options", systemImage: showAdvancedOptions ? "chevron.up" : "chevron.down")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
                .keyboardShortcut("a", modifiers: .command)
                .help("Toggle advanced options")
            }
            .padding([.horizontal, .top])
            
            Divider()
                .padding(.vertical, 8)
            
            // Main content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // MARK: - File Selection
                    Group {
                        fileSelectionSection
                        
                        // Advanced options section
                        if showAdvancedOptions {
                            advancedOptionsSection
                        }
                    }
                    
                    // MARK: - Column Mapping
                    columnMappingSection
                    
                    // MARK: - Process Button
                    HStack {
                        Spacer()
                        if isProcessing {
                            Button(action: { cancelProcessing() }) {
                                Label("Cancel", systemImage: "stop.fill")
                                    .foregroundColor(.red)
                            }
                            .keyboardShortcut(.escape, modifiers: .command)
                        } else {
                            Button(action: runOrganizer) {
                                Label("Run Organizer", systemImage: "play.fill")
                                    .padding(.horizontal, 10)
                            }
                            .keyboardShortcut(.return, modifiers: .command)
                        }
                    }
                    .disabled(!canRunOrganizer)
                    .padding(.top, 5)
                    
                    // MARK: - Progress Section
                    if showProgressView {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Processing...")
                                Spacer()
                                Text("\(Int(progressValue * 100))%")
                            }
                            
                            ProgressView(value: progressValue)
                                .progressViewStyle(LinearProgressViewStyle())
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    // MARK: - Status Messages
                    if !statusMessages.isEmpty || processingStats.processedCount > 0 {
                        statusSection
                    }
                }
                .padding()
            }
        }
        .frame(minWidth: 600, minHeight: 550)
        .onAppear {
            loadDefaults()
        }
    }
    
    // MARK: - File Selection Section
    private var fileSelectionSection: some View {
        GroupBox(label: Label("Data Sources", systemImage: "folder")) {
            VStack(alignment: .leading, spacing: 15) {
                // CSV File
                HStack(alignment: .top) {
                    Text("CSV File:")
                        .frame(width: 100, alignment: .trailing)
                    
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            if let csvURL = csvURL {
                                Text(csvURL.lastPathComponent)
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                            } else {
                                Text("No file selected")
                                    .foregroundColor(.secondary)
                                    .italic()
                            }
                            
                            Spacer()
                            
                            Button("Select...") { selectCSV() }
                                .buttonStyle(.bordered)
                                .help("Select CSV file containing organization data")
                                .keyboardShortcut("o", modifiers: [.command, .shift])
                        }
                        
                        if let error = csvError {
                            Text(error)
                                .font(.footnote)
                                .foregroundColor(.red)
                                .padding(.top, 2)
                        }
                    }
                }
                
                // Images Folder
                HStack(alignment: .top) {
                    Text("Images Folder:")
                        .frame(width: 100, alignment: .trailing)
                    
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            if let imagesDirectoryURL = imagesDirectoryURL {
                                Text(imagesDirectoryURL.lastPathComponent)
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                            } else {
                                Text("No folder selected")
                                    .foregroundColor(.secondary)
                                    .italic()
                            }
                            
                            Spacer()
                            
                            Button("Select...") { selectImagesDirectory() }
                                .buttonStyle(.bordered)
                                .help("Select folder containing images to organize")
                                .keyboardShortcut("i", modifiers: [.command, .shift])
                        }
                        
                        if let error = directoryError {
                            Text(error)
                                .font(.footnote)
                                .foregroundColor(.red)
                                .padding(.top, 2)
                        }
                    }
                }
                
                // Output Folder (only shown in advanced mode)
                if showAdvancedOptions {
                    HStack(alignment: .top) {
                        Text("Output Folder:")
                            .frame(width: 100, alignment: .trailing)
                        
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                if let outputURL = outputDirectoryURL {
                                    Text(outputURL.lastPathComponent)
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                } else {
                                    Text("Same as Images Folder")
                                        .foregroundColor(.secondary)
                                        .italic()
                                }
                                
                                Spacer()
                                
                                Button("Select...") { selectOutputDirectory() }
                                    .buttonStyle(.bordered)
                                    .help("Select a different output folder (optional)")
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 5)
        }
    }
    
    // MARK: - Advanced Options Section
    private var advancedOptionsSection: some View {
        GroupBox(label: Label("Advanced Options", systemImage: "gearshape")) {
            VStack(alignment: .leading, spacing: 12) {
                // Processing Mode
                Picker("Mode:", selection: $organizeMode) {
                    ForEach(OrganizeMode.allCases) { mode in
                        Label(mode.rawValue, systemImage: mode.systemImage)
                            .tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.bottom, 5)
                
                // Include subfolders option
                Toggle(isOn: $includeSubfolders) {
                    Text("Search for images in subfolders")
                        .font(.subheadline)
                }
                
                // Overwrite existing files option
                Toggle(isOn: $overwriteExistingFiles) {
                    Text("Overwrite existing files in destination")
                        .font(.subheadline)
                }
                
                // Create missing photos log
                Toggle(isOn: $createMissingPhotosLog) {
                    Text("Create log file for missing photos")
                        .font(.subheadline)
                }
            }
            .padding(.vertical, 5)
        }
    }
    
    // MARK: - Column Mapping Section
    private var columnMappingSection: some View {
        GroupBox(label: Label("CSV Column Mapping", systemImage: "tablecells")) {
            VStack(alignment: .leading, spacing: 15) {
                // Primary Folder Column
                HStack {
                    Text("Create folders from:")
                        .frame(width: 130, alignment: .trailing)
                    
                    if loadedHeaders.isEmpty {
                        Text("No CSV loaded")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        Picker("", selection: $folderColumn) {
                            ForEach(loadedHeaders, id: \.self) { header in
                                Text(header).tag(header)
                            }
                        }
                        .labelsHidden()
                    }
                }
                
                // Secondary Folder Option (Hierarchical organization)
                if showAdvancedOptions {
                    HStack(alignment: .center) {
                        Toggle("Use Subfolder:", isOn: $useSecondaryFolder)
                            .frame(width: 140, alignment: .trailing)
                        
                        if useSecondaryFolder {
                            if loadedHeaders.isEmpty {
                                Text("Load CSV first")
                                    .foregroundColor(.secondary)
                                    .italic()
                            } else {
                                Picker("", selection: Binding(
                                    get: { secondaryFolderColumn ?? loadedHeaders.first ?? "" },
                                    set: { secondaryFolderColumn = $0 }
                                )) {
                                    ForEach(loadedHeaders, id: \.self) { header in
                                        Text(header).tag(header)
                                    }
                                }
                                .labelsHidden()
                                .disabled(loadedHeaders.isEmpty)
                            }
                        }
                    }
                    .padding(.bottom, 5)
                }
                
                // Photo Column
                HStack {
                    Text("Filename column:")
                        .frame(width: 130, alignment: .trailing)
                    
                    if loadedHeaders.isEmpty {
                        Text("No CSV loaded")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        Picker("", selection: $photoColumn) {
                            ForEach(loadedHeaders, id: \.self) { header in
                                Text(header).tag(header)
                            }
                        }
                        .labelsHidden()
                    }
                }
                
                // Help text
                Text("The 'Create folders from' column values will be used as folder names. The 'Filename column' values should match your image filenames.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 5)
            }
            .padding(.vertical, 5)
        }
    }
    
    // MARK: - Status Section
    private var statusSection: some View {
        GroupBox(label: Label("Status", systemImage: "info.circle")) {
            VStack(alignment: .leading, spacing: 5) {
                // Show processing stats if any
                if processingStats.processedCount > 0 || processingStats.skippedCount > 0 {
                    HStack(spacing: 20) {
                        Label("\(processingStats.processedCount) processed", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        
                        if processingStats.skippedCount > 0 {
                            Label("\(processingStats.skippedCount) skipped", systemImage: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                        }
                        
                        if !processingStats.missingPhotos.isEmpty {
                            Label("\(processingStats.missingPhotos.count) missing", systemImage: "questionmark.circle.fill")
                                .foregroundColor(.red)
                        }
                        
                        if !processingStats.duplicatePhotos.isEmpty {
                            Label("\(processingStats.duplicatePhotos.count) duplicates", systemImage: "doc.on.doc.fill")
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.vertical, 5)
                }
                
                // Scrollable status messages
                ScrollView {
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(statusMessages.indices, id: \.self) { index in
                            Text(statusMessages[index])
                                .font(.callout)
                                .foregroundColor(messageColor(for: statusMessages[index]))
                                .textSelection(.enabled)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 200)
            }
            .padding(.vertical, 5)
        }
    }
    
    // MARK: - Helper Functions
    
    private var canRunOrganizer: Bool {
        return csvURL != nil && imagesDirectoryURL != nil && !isProcessing
    }
    
    private func messageColor(for message: String) -> Color {
        if message.contains("✅") {
            return .green
        } else if message.contains("⚠️") {
            return .orange
        } else if message.contains("❌") {
            return .red
        } else {
            return .primary
        }
    }
    
    private func loadDefaults() {
        // Load any saved defaults or preferences here
    }
    
    // MARK: - File Selection Methods
    
    private func selectCSV() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType.commaSeparatedText]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Select a CSV file with image organization data"
        panel.prompt = "Select CSV"
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                self.csvURL = url
                self.csvError = nil
                parseHeaders(from: url)
            }
        }
    }
    
    private func parseHeaders(from url: URL) {
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            let lines = content.components(separatedBy: .newlines)
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            
            guard let firstLine = lines.first else {
                csvError = "CSV file is empty or corrupted"
                addStatusMessage("❌ CSV file is empty or corrupted.")
                return
            }
            
            // Parse CSV headers properly, handling quoted fields
            let csvColumns = parseCSVLine(firstLine)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            
            // Store all headers
            loadedHeaders = csvColumns
            
            // Check if we have at least some headers
            if csvColumns.isEmpty {
                addStatusMessage("⚠️ No columns found in CSV file.")
                csvError = "No columns found"
                return
            }
            
            // Set default selections to first column for folder and second for photo (if available)
            if !loadedHeaders.isEmpty {
                folderColumn = loadedHeaders[0]
                if loadedHeaders.count > 1 {
                    photoColumn = loadedHeaders[1]
                } else {
                    photoColumn = loadedHeaders[0]
                }
            }
            
            addStatusMessage("✅ Loaded CSV headers: \(csvColumns.joined(separator: ", "))")
            csvError = nil
            
            // Count total rows as a preview
            let dataRows = lines.count - 1
            addStatusMessage("ℹ️ Found \(dataRows) data rows in the CSV.")
            
        } catch {
            csvError = "Failed to read CSV: \(error.localizedDescription)"
            addStatusMessage("❌ Failed to read CSV: \(error.localizedDescription)")
        }
    }
    
    private func parseCSVLine(_ line: String) -> [String] {
        var columns: [String] = []
        var currentColumn = ""
        var insideQuotes = false
        
        for char in line {
            if char == "\"" {
                insideQuotes = !insideQuotes
            } else if char == "," && !insideQuotes {
                columns.append(currentColumn)
                currentColumn = ""
            } else {
                currentColumn.append(char)
            }
        }
        
        // Add the last column
        columns.append(currentColumn)
        return columns
    }
    
    private func selectImagesDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Select the folder containing images to organize"
        panel.prompt = "Select Folder"
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                self.imagesDirectoryURL = url
                self.directoryError = nil
                
                // Count images in the directory as a preview
                Task {
                    await validateImagesDirectory(url)
                }
            }
        }
    }
    
    private func selectOutputDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Select where to create team folders (optional)"
        panel.prompt = "Select Output Folder"
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                self.outputDirectoryURL = url
                addStatusMessage("ℹ️ Output directory set to: \(url.lastPathComponent)")
            }
        }
    }
    
    private func validateImagesDirectory(_ url: URL) async {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            await MainActor.run {
                directoryError = "Cannot access directory contents"
                addStatusMessage("❌ Cannot access directory contents")
            }
            return
        }
        
        var imageCount = 0
        let imageExtensions = ["jpg", "jpeg", "png", "gif", "tiff", "bmp", "heic"]
        
        for case let fileURL as URL in enumerator {
            if !includeSubfolders && fileURL.deletingLastPathComponent() != url {
                continue
            }
            
            let fileExtension = fileURL.pathExtension.lowercased()
            if imageExtensions.contains(fileExtension) {
                imageCount += 1
            }
            
            // Stop if we find too many images (just for preview purposes)
            if imageCount > 1000 {
                break
            }
        }
        
        await MainActor.run {
            if imageCount == 0 {
                directoryError = "No image files found in directory"
                addStatusMessage("⚠️ No image files found in directory.")
            } else if imageCount > 1000 {
                addStatusMessage("ℹ️ Found over 1000 image files in directory.")
                directoryError = nil
            } else {
                addStatusMessage("ℹ️ Found \(imageCount) image files in directory.")
                directoryError = nil
            }
        }
    }
    
    // MARK: - Status Messages
    
    private func addStatusMessage(_ message: String) {
        DispatchQueue.main.async {
            self.statusMessages.insert(message, at: 0)
            
            // Keep a reasonable number of messages
            if self.statusMessages.count > 50 {
                self.statusMessages.removeLast()
            }
        }
    }
    
    // MARK: - Processing
    
    private func runOrganizer() {
        guard let csvURL = csvURL, let imagesDir = imagesDirectoryURL else {
            addStatusMessage("❌ CSV file or images folder missing.")
            return
        }
        
        // Reset status
        isProcessing = true
        showProgressView = true
        progressValue = 0
        statusMessages = []
        processingStats = ProcessingSummary()
        
        // Determine output directory
        let outputDir = outputDirectoryURL ?? imagesDir
        
        addStatusMessage("ℹ️ Starting organization process...")
        addStatusMessage("ℹ️ Mode: \(organizeMode.rawValue)")
        
        Task {
            await processCSV(csvURL: csvURL, imagesDir: imagesDir, outputDir: outputDir)
        }
    }
    
    private func cancelProcessing() {
        isProcessing = false
        showProgressView = false
        addStatusMessage("❌ Processing cancelled by user.")
    }
    
    private func processCSV(csvURL: URL, imagesDir: URL, outputDir: URL) async {
        do {
            let content = try String(contentsOf: csvURL, encoding: .utf8)
            var rows = content.components(separatedBy: .newlines)
                .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            
            guard let headerRow = rows.first else {
                await MainActor.run {
                    addStatusMessage("❌ CSV file is empty or corrupted.")
                }
                return
            }
            
            let headers = parseCSVLine(headerRow)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            
            guard let folderIndex = headers.firstIndex(where: {
                $0.caseInsensitiveCompare(folderColumn) == .orderedSame
            }) else {
                await MainActor.run {
                    addStatusMessage("❌ Column '\(folderColumn)' not found in CSV.")
                }
                return
            }
            
            guard let photoIndex = headers.firstIndex(where: {
                $0.caseInsensitiveCompare(photoColumn) == .orderedSame
            }) else {
                await MainActor.run {
                    addStatusMessage("❌ Column '\(photoColumn)' not found in CSV.")
                }
                return
            }
            
            // Get secondary folder index if using subfolder option
            var secondaryFolderIndex: Int? = nil
            if useSecondaryFolder, let secondaryColumn = secondaryFolderColumn {
                secondaryFolderIndex = headers.firstIndex(where: {
                    $0.caseInsensitiveCompare(secondaryColumn) == .orderedSame
                })
                
                if secondaryFolderIndex == nil {
                    await MainActor.run {
                        addStatusMessage("⚠️ Secondary folder column '\(secondaryColumn)' not found, continuing without subfolders.")
                    }
                }
            }
            
            // Remove header row
            rows.removeFirst()
            
            // Pre-scan images directory to get a map of all image files
            await MainActor.run {
                addStatusMessage("ℹ️ Scanning image files...")
            }
            let imageFiles = await scanImageFiles(in: imagesDir)
            
            // Set total for progress tracking
            totalFiles = rows.count
            await MainActor.run {
                addStatusMessage("ℹ️ Processing \(totalFiles) entries from CSV...")
            }
            
            // Process each row
            for (rowIndex, row) in rows.enumerated() {
                // Check if user cancelled
                if !isProcessing {
                    return
                }
                
                // Update progress
                await updateProgress(Double(rowIndex) / Double(totalFiles))
                
                // Skip empty rows
                if row.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    continue
                }
                
                // Parse the CSV line properly
                let columns = parseCSVLine(row)
                
                // Validate row has enough columns
                guard columns.count > max(folderIndex, photoIndex) else {
                    processingStats.skippedCount += 1
                    processingStats.errorMessages.append("Line \(rowIndex + 2): Invalid row format")
                    continue
                }
                
                // Get folder and photo values
                let folder = columns[folderIndex].trimmingCharacters(in: .whitespacesAndNewlines)
                let photo = columns[photoIndex].trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Skip if essential values are empty
                if folder.isEmpty || photo.isEmpty {
                    processingStats.skippedCount += 1
                    if folder.isEmpty && photo.isEmpty {
                        processingStats.errorMessages.append("Line \(rowIndex + 2): Empty folder and photo")
                    } else if folder.isEmpty {
                        processingStats.errorMessages.append("Line \(rowIndex + 2): Empty folder for photo '\(photo)'")
                    } else {
                        processingStats.errorMessages.append("Line \(rowIndex + 2): Empty photo for folder '\(folder)'")
                    }
                    continue
                }
                
                // Get secondary folder if applicable
                var targetFolder = folder
                if let secondaryIdx = secondaryFolderIndex, secondaryIdx < columns.count {
                    let secondaryFolder = columns[secondaryIdx].trimmingCharacters(in: .whitespacesAndNewlines)
                    if !secondaryFolder.isEmpty {
                        targetFolder = "\(folder)/\(secondaryFolder)"
                    }
                }
                
                // Ensure target directory exists
                let teamFolder = outputDir.appendingPathComponent(targetFolder, isDirectory: true)
                do {
                    try FileManager.default.createDirectory(at: teamFolder, withIntermediateDirectories: true, attributes: nil)
                } catch {
                    processingStats.skippedCount += 1
                    processingStats.errorMessages.append("Line \(rowIndex + 2): Failed to create folder '\(targetFolder)': \(error.localizedDescription)")
                    continue
                }
                
                // Add extension if needed (common image extensions if none specified)
                var photoFilename = photo
                if !photoFilename.contains(".") {
                    // Try to find a matching file with various extensions
                    var foundFile = false
                    let possibleExtensions = ["jpg", "jpeg", "png", "gif", "tiff", "heic"]
                    
                    for ext in possibleExtensions {
                        let testName = "\(photoFilename).\(ext)"
                        if imageFiles.contains(testName.lowercased()) {
                            photoFilename = testName
                            foundFile = true
                            break
                        }
                    }
                    
                    if !foundFile {
                        // If we couldn't find the file with an extension, try case-insensitive matching
                        let photoLower = photoFilename.lowercased()
                        if let matchingFile = imageFiles.first(where: { $0.lowercased().hasPrefix(photoLower) && $0.contains(".") }) {
                            photoFilename = matchingFile
                        } else {
                            processingStats.missingPhotos.append(photoFilename)
                            continue
                        }
                    }
                }
                
                // Find the full path to the source file
                guard let sourcePath = findImageFile(named: photoFilename, in: imagesDir, imageFiles: imageFiles) else {
                    processingStats.missingPhotos.append(photoFilename)
                    continue
                }
                
                let fileName = sourcePath.lastPathComponent
                let destinationPath = teamFolder.appendingPathComponent(fileName)
                
                // Check if destination already exists
                if FileManager.default.fileExists(atPath: destinationPath.path) && !overwriteExistingFiles {
                    processingStats.duplicatePhotos.append(fileName)
                    continue
                }
                
                // Perform the file operation based on selected mode
                do {
                    if organizeMode == .copy {
                        try FileManager.default.copyItem(at: sourcePath, to: destinationPath)
                    } else {
                        try FileManager.default.moveItem(at: sourcePath, to: destinationPath)
                    }
                    processingStats.processedCount += 1
                } catch {
                    processingStats.errorMessages.append("Failed to \(organizeMode == .copy ? "copy" : "move") '\(fileName)': \(error.localizedDescription)")
                    processingStats.skippedCount += 1
                }
            }
            
            // Complete progress and show summary
            await updateProgress(1.0)
            
            // Create log file for missing photos if needed
            if createMissingPhotosLog && !processingStats.missingPhotos.isEmpty {
                await createMissingPhotosLogFile(outputDir)
            }
            
            // Generate final status message
            var resultMessage = "✅ Organization completed!"
            resultMessage += "\n✅ Processed: \(processingStats.processedCount) images"
            
            if processingStats.skippedCount > 0 {
                resultMessage += "\n⚠️ Skipped: \(processingStats.skippedCount) entries"
            }
            
            if !processingStats.missingPhotos.isEmpty {
                resultMessage += "\n⚠️ Missing photos: \(processingStats.missingPhotos.count)"
                if createMissingPhotosLog {
                    resultMessage += " (see missing_photos.txt)"
                }
            }
            
            if !processingStats.duplicatePhotos.isEmpty {
                resultMessage += "\n⚠️ Duplicate photos: \(processingStats.duplicatePhotos.count)"
            }
            
            await MainActor.run {
                addStatusMessage(resultMessage)
            }
            
            // Show error details if any
            if !processingStats.errorMessages.isEmpty {
                let errorCount = min(processingStats.errorMessages.count, 5)
                await MainActor.run {
                    addStatusMessage("⚠️ \(processingStats.errorMessages.count) errors occurred. First \(errorCount) errors:")
                    
                    for i in 0..<errorCount {
                        addStatusMessage("  - \(processingStats.errorMessages[i])")
                    }
                    
                    if processingStats.errorMessages.count > errorCount {
                        addStatusMessage("  - ... and \(processingStats.errorMessages.count - errorCount) more")
                    }
                }
            }
            
        } catch {
            await MainActor.run {
                addStatusMessage("❌ Error processing CSV: \(error.localizedDescription)")
            }
        }
        
        // Reset processing state
        await MainActor.run {
            isProcessing = false
            // Keep progress view visible for user to see the results
        }
    }
    
    private func updateProgress(_ value: Double) async {
        await MainActor.run {
            self.progressValue = value
        }
    }
    
    // MARK: - Helper Functions for Processing
    
    private func scanImageFiles(in directory: URL) async -> Set<String> {
        var imageFiles = Set<String>()
        let fileManager = FileManager.default
        
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return imageFiles
        }
        
        let imageExtensions = ["jpg", "jpeg", "png", "gif", "tiff", "bmp", "heic"]
        
        for case let fileURL as URL in enumerator {
            if !includeSubfolders && fileURL.deletingLastPathComponent() != directory {
                continue
            }
            
            let fileExtension = fileURL.pathExtension.lowercased()
            if imageExtensions.contains(fileExtension) {
                imageFiles.insert(fileURL.lastPathComponent)
                
                // Also add the path relative to the images directory
                if fileURL.deletingLastPathComponent() != directory {
                    let relativePath = fileURL.path.replacingOccurrences(of: directory.path, with: "")
                        .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                    imageFiles.insert(relativePath)
                }
            }
        }
        
        return imageFiles
    }
    
    private func findImageFile(named filename: String, in directory: URL, imageFiles: Set<String>) -> URL? {
        let fileManager = FileManager.default
        
        // First, try direct path
        let directPath = directory.appendingPathComponent(filename)
        if fileManager.fileExists(atPath: directPath.path) {
            return directPath
        }
        
        // Try case-insensitive search
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }
        
        let lowercaseFilename = filename.lowercased()
        
        for case let fileURL as URL in enumerator {
            if !includeSubfolders && fileURL.deletingLastPathComponent() != directory {
                continue
            }
            
            if fileURL.lastPathComponent.lowercased() == lowercaseFilename {
                return fileURL
            }
        }
        
        return nil
    }
    
    private func createMissingPhotosLogFile(_ directory: URL) async {
        guard !processingStats.missingPhotos.isEmpty else { return }
        
        let logURL = directory.appendingPathComponent("missing_photos.txt")
        
        do {
            var logContent = "Missing Photos Report - \(Date().formatted())\n"
            logContent += "----------------------------------------\n\n"
            logContent += "The following \(processingStats.missingPhotos.count) photos were referenced in the CSV but not found:\n\n"
            
            for photo in processingStats.missingPhotos.sorted() {
                logContent += "- \(photo)\n"
            }
            
            try logContent.write(to: logURL, atomically: true, encoding: .utf8)
            await MainActor.run {
                addStatusMessage("ℹ️ Created missing photos log at: \(logURL.lastPathComponent)")
            }
        } catch {
            await MainActor.run {
                addStatusMessage("⚠️ Failed to create missing photos log: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - SwiftUI Preview
#Preview {
    ContentView()
}
