import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var csvURL: URL?
    @State private var imagesDirectoryURL: URL?
    @State private var teamColumn = "Team"
    @State private var photoColumn = "Photo"
    @State private var statusMessage = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("📸 OrganizeBy")
                .font(.largeTitle)
                .padding(.bottom, 5)

            Divider()

            GroupBox(label: Label("Data Sources", systemImage: "folder")) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("CSV File:")
                            .frame(width: 100, alignment: .trailing)
                        Text(csvURL?.lastPathComponent ?? "No file selected")
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        Spacer()
                        Button("Select...") { selectCSV() }
                    }

                    HStack {
                        Text("Images Folder:")
                            .frame(width: 100, alignment: .trailing)
                        Text(imagesDirectoryURL?.lastPathComponent ?? "No folder selected")
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        Spacer()
                        Button("Select...") { selectImagesDirectory() }
                    }
                }
                .padding(.vertical, 5)
            }

            GroupBox(label: Label("CSV Column Mapping", systemImage: "tablecells")) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Team:")
                            .frame(width: 100, alignment: .trailing)
                        Picker("", selection: $teamColumn) {
                            Text("Team").tag("Team")
                            Text("Division").tag("Division")
                            Text("Period").tag("Period")
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }

                    HStack {
                        Text("Photo:")
                            .frame(width: 100, alignment: .trailing)
                        Picker("", selection: $photoColumn) {
                            Text("Photo").tag("Photo")
                            Text("SPA").tag("SPA")
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                }
                .padding(.vertical, 5)
            }

            HStack {
                Spacer()
                Button(action: runOrganizer) {
                    Label("Run Organizer", systemImage: "play.fill")
                }
                .disabled(csvURL == nil || imagesDirectoryURL == nil)
            }
            .padding(.top, 5)

            if !statusMessage.isEmpty {
                Text(statusMessage)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(.top, 5)
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            Spacer()
        }
        .padding(20)
        .frame(width: 500, height: 320)
    }

    // MARK: - File Selection

    private func selectCSV() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.begin { response in
            if response == .OK { csvURL = panel.url }
        }
    }

    private func selectImagesDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.begin { response in
            if response == .OK { imagesDirectoryURL = panel.url }
        }
    }

    // MARK: - Organizer Logic

    private func runOrganizer() {
        guard let csvURL = csvURL, let imagesDir = imagesDirectoryURL else {
            updateStatus("❌ CSV file or images folder missing.")
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let content = try String(contentsOf: csvURL, encoding: .utf8)
                var rows = content.components(separatedBy: .newlines)
                    .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

                guard let headerRow = rows.first else {
                    updateStatus("❌ CSV file is empty or corrupted.")
                    return
                }

                let headers = headerRow.components(separatedBy: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

                guard let teamIndex = headers.firstIndex(where: { $0.caseInsensitiveCompare(teamColumn) == .orderedSame }),
                      let photoIndex = headers.firstIndex(where: { $0.caseInsensitiveCompare(photoColumn) == .orderedSame }) else {
                    updateStatus("❌ Columns '\(teamColumn)' or '\(photoColumn)' not found in CSV.")
                    return
                }

                rows.removeFirst()

                var missingPhotos = [String]()
                var processedCount = 0

                for (lineNumber, row) in rows.enumerated() {
                    let columns = row.components(separatedBy: ",")
                    guard columns.count > max(teamIndex, photoIndex) else {
                        updateStatus("⚠️ Skipped malformed line \(lineNumber + 2): insufficient columns.")
                        continue
                    }

                    let team = columns[teamIndex].trimmingCharacters(in: .whitespacesAndNewlines)
                    let photo = columns[photoIndex].trimmingCharacters(in: .whitespacesAndNewlines)

                    if team.isEmpty || photo.isEmpty {
                        updateStatus("⚠️ Skipped line \(lineNumber + 2): empty team or photo.")
                        continue
                    }

                    let teamFolder = imagesDir.appendingPathComponent(team, isDirectory: true)
                    try FileManager.default.createDirectory(at: teamFolder, withIntermediateDirectories: true)

                    let sourcePath = imagesDir.appendingPathComponent(photo)
                    let destinationPath = teamFolder.appendingPathComponent(photo)

                    if FileManager.default.fileExists(atPath: sourcePath.path) {
                        try FileManager.default.moveItem(at: sourcePath, to: destinationPath)
                        processedCount += 1
                    } else {
                        missingPhotos.append(photo)
                    }
                }

                var resultMessage = "✅ Completed: \(processedCount) images sorted."
                if !missingPhotos.isEmpty {
                    resultMessage += "\n⚠️ Missing photos:\n\(missingPhotos.joined(separator: ", "))"
                }

                updateStatus(resultMessage)

            } catch {
                updateStatus("❌ Error processing CSV: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Helper

    private func updateStatus(_ message: String) {
        DispatchQueue.main.async {
            self.statusMessage = message
        }
    }
}

#Preview {
    ContentView()
}
