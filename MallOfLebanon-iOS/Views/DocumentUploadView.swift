import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct DocumentUploadView: View {
    let installmentOrderId: String
    let onUploadComplete: () -> Void

    @State private var selectedDocuments: [DocumentFile] = []
    @State private var isUploading = false
    @State private var uploadProgress: Double = 0.0
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var showingDocumentPicker = false
    @State private var showingImagePicker = false
    @State private var currentDocumentType: RequiredDocumentType = .nationalID

    private let requiredDocuments: [DocumentRequirement] = [
        DocumentRequirement(
            type: .nationalID,
            label: "National ID",
            description: "Clear photo or scan of your national ID (both sides if applicable)",
            maxSize: "5MB",
            formats: ["JPG", "PNG", "PDF"],
            isOptional: false
        ),
        DocumentRequirement(
            type: .salaryCertificate,
            label: "Salary Certificate",
            description: "Official salary certificate from your employer (not older than 3 months)",
            maxSize: "5MB",
            formats: ["PDF", "JPG", "PNG"],
            isOptional: false
        ),
        DocumentRequirement(
            type: .bankStatement,
            label: "Bank Statement",
            description: "Recent bank statement showing your income (last 3 months)",
            maxSize: "10MB",
            formats: ["PDF", "JPG", "PNG"],
            isOptional: false
        ),
        DocumentRequirement(
            type: .employmentLetter,
            label: "Employment Letter (Optional)",
            description: "Your current employment contract or work agreement",
            maxSize: "5MB",
            formats: ["PDF", "JPG", "PNG"],
            isOptional: true
        )
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                requirementsSection
                uploadedDocumentsSection
                uploadActionsSection

                if isUploading {
                    uploadProgressSection
                }

                messageSection
            }
            .padding()
        }
        .navigationTitle("Upload Documents")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingDocumentPicker) {
            DocumentPicker(
                allowedTypes: [.pdf, .jpeg, .png],
                onDocumentPicked: { url in
                    handleDocumentSelected(url: url, type: currentDocumentType)
                }
            )
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(
                onImagePicked: { image in
                    handleImageSelected(image: image, type: currentDocumentType)
                }
            )
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Upload") {
                    uploadDocuments()
                }
                .disabled(selectedDocuments.isEmpty || isUploading || !areRequiredDocumentsUploaded())
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Upload Required Documents")
                .font(.title2)
                .fontWeight(.bold)

            Text("Please upload the following documents for installment approval. All documents should be clear and legible.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    private var requirementsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Required Documents:")
                .font(.headline)
                .fontWeight(.semibold)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(requiredDocuments, id: \.type) { requirement in
                    requirementCard(requirement)
                }
            }
        }
    }

    private func requirementCard(_ requirement: DocumentRequirement) -> some View {
        let isUploaded = selectedDocuments.contains { $0.documentType == requirement.type }

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(requirement.label)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(isUploaded ? .green : .primary)

                Spacer()

                if requirement.isOptional {
                    Text("Optional")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.2))
                        .foregroundColor(.orange)
                        .cornerRadius(4)
                } else if isUploaded {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 16))
                }
            }

            Text(requirement.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(nil)

            HStack {
                Text("Max: \(requirement.maxSize)")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Spacer()

                Text(requirement.formats.joined(separator: ", "))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Button(action: {
                currentDocumentType = requirement.type
                showDocumentUploadOptions()
            }) {
                HStack {
                    Image(systemName: isUploaded ? "arrow.2.circlepath" : "plus")
                    Text(isUploaded ? "Replace" : "Upload")
                }
                .font(.caption)
                .foregroundColor(.blue)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(6)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isUploaded ? Color.green.opacity(0.05) : Color(UIColor.systemGray6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isUploaded ? Color.green.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }

    private var uploadedDocumentsSection: some View {
        Group {
            if !selectedDocuments.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Uploaded Documents (\(selectedDocuments.count))")
                        .font(.headline)
                        .fontWeight(.semibold)

                    ForEach(selectedDocuments, id: \.fileName) { document in
                        documentRow(document)
                    }
                }
            }
        }
    }

    private func documentRow(_ document: DocumentFile) -> some View {
        HStack(spacing: 12) {
            Image(systemName: iconForFileType(document.mimeType))
                .foregroundColor(.blue)
                .font(.title2)
                .frame(width: 40, height: 40)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 2) {
                Text(document.fileName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Text(document.documentType.displayName)
                    .font(.caption)
                    .foregroundColor(.blue)

                Text(formatFileSize(document.file.count))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: {
                removeDocument(document)
            }) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
                    .font(.system(size: 16))
            }
            .disabled(isUploading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(UIColor.systemGray6))
        .cornerRadius(8)
    }

    private var uploadActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Upload Your Documents")
                .font(.headline)
                .fontWeight(.semibold)

            Button(action: {
                showDocumentUploadOptions()
            }) {
                HStack {
                    Image(systemName: "doc.badge.plus")
                    Text("Add Document")
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .foregroundColor(.blue)
                .cornerRadius(8)
            }
            .disabled(isUploading)
        }
    }

    private var uploadProgressSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Uploading Documents...")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                Text("\(Int(uploadProgress * 100))%")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
            }

            ProgressView(value: uploadProgress)
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(8)
    }

    private var messageSection: some View {
        VStack(spacing: 12) {
            if let errorMessage = errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundColor(.red)
                    Spacer()
                }
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            }

            if let successMessage = successMessage {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(successMessage)
                        .font(.subheadline)
                        .foregroundColor(.green)
                    Spacer()
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }

    private func showDocumentUploadOptions() {
        let alert = UIAlertController(title: "Select Document", message: "Choose how you'd like to upload your document", preferredStyle: .actionSheet)

        alert.addAction(UIAlertAction(title: "Camera", style: .default) { _ in
            showingImagePicker = true
        })

        alert.addAction(UIAlertAction(title: "Photo Library", style: .default) { _ in
            // You can implement photo library picker here
        })

        alert.addAction(UIAlertAction(title: "Files", style: .default) { _ in
            showingDocumentPicker = true
        })

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(alert, animated: true)
        }
    }

    private func handleDocumentSelected(url: URL, type: RequiredDocumentType) {
        guard url.startAccessingSecurityScopedResource() else {
            errorMessage = "Unable to access selected file"
            return
        }

        defer {
            url.stopAccessingSecurityScopedResource()
        }

        do {
            let data = try Data(contentsOf: url)
            let fileName = url.lastPathComponent
            let mimeType = getMimeType(for: url)

            if !validateFileSize(data.count, for: type) {
                errorMessage = "File is too large for \(type.displayName)"
                return
            }

            let documentFile = DocumentFile(
                file: data,
                fileName: fileName,
                mimeType: mimeType,
                documentType: type
            )

            // Remove existing document of same type
            selectedDocuments.removeAll { $0.documentType == type }
            selectedDocuments.append(documentFile)

            errorMessage = nil
        } catch {
            errorMessage = "Unable to read selected file: \(error.localizedDescription)"
        }
    }

    private func handleImageSelected(image: UIImage, type: RequiredDocumentType) {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            errorMessage = "Unable to process selected image"
            return
        }

        if !validateFileSize(imageData.count, for: type) {
            errorMessage = "Image is too large for \(type.displayName)"
            return
        }

        let fileName = "\(type.rawValue)_\(Date().timeIntervalSince1970).jpg"
        let documentFile = DocumentFile(
            file: imageData,
            fileName: fileName,
            mimeType: "image/jpeg",
            documentType: type
        )

        // Remove existing document of same type
        selectedDocuments.removeAll { $0.documentType == type }
        selectedDocuments.append(documentFile)

        errorMessage = nil
    }

    private func removeDocument(_ document: DocumentFile) {
        selectedDocuments.removeAll { $0.fileName == document.fileName }
    }

    private func areRequiredDocumentsUploaded() -> Bool {
        let requiredTypes = requiredDocuments.filter { !$0.isOptional }.map { $0.type }
        let uploadedTypes = selectedDocuments.map { $0.documentType }

        return requiredTypes.allSatisfy { uploadedTypes.contains($0) }
    }

    private func validateFileSize(_ size: Int, for type: RequiredDocumentType) -> Bool {
        let maxSize: Int
        switch type {
        case .bankStatement:
            maxSize = 10 * 1024 * 1024 // 10MB
        default:
            maxSize = 5 * 1024 * 1024  // 5MB
        }
        return size <= maxSize
    }

    private func getMimeType(for url: URL) -> String {
        let pathExtension = url.pathExtension.lowercased()
        switch pathExtension {
        case "pdf":
            return "application/pdf"
        case "jpg", "jpeg":
            return "image/jpeg"
        case "png":
            return "image/png"
        default:
            return "application/octet-stream"
        }
    }

    private func iconForFileType(_ mimeType: String) -> String {
        if mimeType.starts(with: "image/") {
            return "photo.fill"
        } else if mimeType == "application/pdf" {
            return "doc.fill"
        } else {
            return "doc.fill"
        }
    }

    private func formatFileSize(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }

    private func uploadDocuments() {
        guard !selectedDocuments.isEmpty && areRequiredDocumentsUploaded() else {
            errorMessage = "Please upload all required documents"
            return
        }

        isUploading = true
        uploadProgress = 0.0
        errorMessage = nil

        // Simulate upload progress
        let progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            uploadProgress += 0.05
            if uploadProgress >= 1.0 {
                timer.invalidate()
                completeUpload()
            }
        }

        // TODO: Replace with actual API call
        // uploadDocumentsToAPI()
    }

    private func completeUpload() {
        isUploading = false
        uploadProgress = 1.0
        successMessage = "Documents uploaded successfully! Our team will review your application within 24-48 hours."

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            onUploadComplete()
        }
    }
}

// MARK: - Supporting Models
struct DocumentRequirement {
    let type: RequiredDocumentType
    let label: String
    let description: String
    let maxSize: String
    let formats: [String]
    let isOptional: Bool
}

// MARK: - Document Picker
struct DocumentPicker: UIViewControllerRepresentable {
    let allowedTypes: [UTType]
    let onDocumentPicked: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: allowedTypes)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onDocumentPicked: onDocumentPicked)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onDocumentPicked: (URL) -> Void

        init(onDocumentPicked: @escaping (URL) -> Void) {
            self.onDocumentPicked = onDocumentPicked
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            onDocumentPicked(url)
        }
    }
}

// MARK: - Image Picker
struct ImagePicker: UIViewControllerRepresentable {
    let onImagePicked: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        picker.allowsEditing = true
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImagePicked: onImagePicked)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImagePicked: (UIImage) -> Void

        init(onImagePicked: @escaping (UIImage) -> Void) {
            self.onImagePicked = onImagePicked
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage {
                onImagePicked(image)
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

// MARK: - Preview
struct DocumentUploadView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            DocumentUploadView(
                installmentOrderId: "sample_order_id",
                onUploadComplete: {
                    print("Upload completed")
                }
            )
        }
    }
}