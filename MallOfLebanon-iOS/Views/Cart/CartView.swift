import SwiftUI
import PhotosUI
import UniformTypeIdentifiers


struct CartView: View {
    @EnvironmentObject var cartManager: CartManager
    @State private var showingCheckout = false

    var body: some View {
        NavigationView {
            Group {
                if cartManager.cart.isEmpty {
                    emptyCartView
                } else {
                    cartContentView
                }
            }
            .navigationTitle("Shopping Cart")
            .navigationBarItems(
                trailing: cartManager.cart.isEmpty ? nil : clearCartButton
            )
        }
        .sheet(isPresented: $showingCheckout) {
            CheckoutView(cartManager: cartManager)
                .environmentObject(cartManager)
        }
    }

    private var emptyCartView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "cart")
                .font(.system(size: 64))
                .foregroundColor(.gray)

            Text("Your cart is empty")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            Text("Add some products to get started")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    private var cartContentView: some View {
        VStack(spacing: 0) {
            // Cart Type Indicator
            if cartManager.cartType != .empty {
                cartTypeIndicator
                    .padding(.horizontal)
                    .padding(.top, 8)
            }

            ScrollView {
                LazyVStack(spacing: 16) {
                    // Cart Items by Seller
                    ForEach(cartManager.cart.getSellerNames(), id: \.self) { sellerName in
                        sellerSection(sellerName: sellerName)
                    }
                }
                .padding()
            }

            // Cart Summary
            cartSummaryView
        }
        .background(Color(.systemGroupedBackground))
    }

    private var cartTypeIndicator: some View {
        HStack(spacing: 8) {
            Image(systemName: cartManager.cartType == .installment ? "creditcard.fill" : "dollarsign.circle.fill")
                .foregroundColor(cartManager.cartType == .installment ? .blue : .green)

            Text("\(cartManager.cartType.displayName) Cart")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(cartManager.cartType == .installment ? .blue : .green)

            if cartManager.cartType == .installment {
                Text("• Documents will be required during checkout")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill((cartManager.cartType == .installment ? Color.blue : Color.green).opacity(0.1))
        )
    }

    private func sellerSection(sellerName: String) -> some View {
        let sellerItems = cartManager.cart.items.filter { $0.sellerName == sellerName }

        return VStack(alignment: .leading, spacing: 12) {
            // Seller Header
            HStack {
                Image(systemName: "storefront")
                    .foregroundColor(.blue)
                Text(sellerName)
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            // Seller's Items
            VStack(spacing: 12) {
                ForEach(sellerItems) { item in
                    CartItemRow(
                        item: item,
                        onQuantityChange: { newQuantity in
                            cartManager.updateItemQuantity(itemId: item.id, quantity: newQuantity)
                        },
                        onRemove: {
                            cartManager.removeItem(item.id)
                        }
                    )
                    .padding(.horizontal, 16)

                    if item.id != sellerItems.last?.id {
                        Divider()
                            .padding(.horizontal, 16)
                    }
                }
            }

            // Seller Subtotal
            HStack {
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Subtotal: $\(String(format: "%.2f", sellerItems.reduce(0) { $0 + $1.total }))")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    if sellerItems.contains(where: { $0.hasDiscount }) {
                        Text("You saved: $\(String(format: "%.2f", sellerItems.reduce(0) { $0 + $1.savings }))")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }

    private var cartSummaryView: some View {
        VStack(spacing: 16) {
            Divider()

            VStack(spacing: 8) {
                // Different summary for installment vs regular carts
                if cartManager.cartType == .installment {
                    // Installment cart summary
                    HStack {
                        Text("Total Due Today (\(cartManager.cart.totalItems) items)")
                            .font(.subheadline)
                        Spacer()
                        Text("$\(String(format: "%.2f", cartManager.cart.subtotal))")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }

                    // Show installment breakdown
                    if let installmentItems = cartManager.cart.items.first(where: { $0.hasInstallmentPlan })?.installmentPlan {
                        HStack {
                            Text("Monthly Payment")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("$\(String(format: "%.2f", installmentItems.monthlyPayment))")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.orange)
                        }

                        HStack {
                            Text("Total Amount")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("$\(String(format: "%.2f", installmentItems.totalAmount))")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                        }
                    }

                    Divider()

                    HStack {
                        Text("Pay Today")
                            .font(.headline)
                            .fontWeight(.bold)
                        Spacer()
                        Text("$\(String(format: "%.2f", cartManager.cart.subtotal))")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                    }
                } else {
                    // Regular cart summary
                    HStack {
                        Text("Subtotal (\(cartManager.cart.totalItems) items)")
                            .font(.subheadline)
                        Spacer()
                        Text("$\(String(format: "%.2f", cartManager.cart.subtotal))")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }

                    // Savings
                    if cartManager.cart.hasSavings {
                        HStack {
                            Text("Total Savings")
                                .font(.subheadline)
                                .foregroundColor(.green)
                            Spacer()
                            Text("-$\(String(format: "%.2f", cartManager.cart.totalSavings))")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.green)
                        }
                    }

                    Divider()

                    HStack {
                        Text("Total")
                            .font(.headline)
                            .fontWeight(.bold)
                        Spacer()
                        Text("$\(String(format: "%.2f", cartManager.cart.subtotal))")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                    }
                }
            }
            .padding(.horizontal)

            // Checkout Button
            Button(action: {
                showingCheckout = true
            }) {
                Text("Proceed to Checkout")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .background(Color(.systemBackground))
    }

    private var clearCartButton: some View {
        Button(action: {
            cartManager.clearCart()
        }) {
            Text("Clear")
                .foregroundColor(.red)
        }
    }
}

struct CartItemRow: View {
    let item: CartItem
    let onQuantityChange: (Int) -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Product Image
            CachedImageView(
                url: URL(string: item.image),
                placeholder: {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            ProgressView()
                                .scaleEffect(0.8)
                        )
                },
                failureView: {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(.gray)
                        )
                }
            )
            .aspectRatio(contentMode: .fill)
            .frame(width: 60, height: 60)
            .cornerRadius(8)

            // Product Details
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)

                Text("SKU: \(item.sku)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                // Installment Plan Info
                if let installmentPlan = item.installmentPlan {
                    HStack(spacing: 4) {
                        Image(systemName: "creditcard.fill")
                            .font(.caption2)
                            .foregroundColor(.blue)
                        Text("\(installmentPlan.planName)")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(4)
                }

                // Price Display
                if item.hasInstallmentPlan {
                    // For installment items, show down payment
                    HStack(spacing: 4) {
                        Text("Down Payment:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("$\(String(format: "%.2f", item.price))")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                    }

                    if let installmentPlan = item.installmentPlan {
                        HStack(spacing: 4) {
                            Text("Monthly:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("$\(String(format: "%.2f", installmentPlan.monthlyPayment))")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.orange)
                        }
                    }
                } else {
                    // Regular price display
                    if item.hasDiscount {
                        HStack(spacing: 8) {
                            Text("$\(String(format: "%.2f", item.price))")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)

                            if let originalPrice = item.originalPrice {
                                Text("$\(String(format: "%.2f", originalPrice))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .strikethrough()
                            }
                        }
                    } else {
                        Text("$\(String(format: "%.2f", item.price))")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                    }
                }
            }

            Spacer()

            // Quantity and Total
            VStack(alignment: .trailing, spacing: 8) {
                // Quantity Controls
                HStack(spacing: 8) {
                    Button(action: {
                        if item.quantity > 1 {
                            onQuantityChange(item.quantity - 1)
                        }
                    }) {
                        Image(systemName: "minus.circle")
                            .foregroundColor(item.quantity > 1 ? .blue : .gray)
                    }
                    .disabled(item.quantity <= 1)

                    Text("\(item.quantity)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .frame(minWidth: 20)

                    Button(action: {
                        if item.quantity < item.maxStock {
                            onQuantityChange(item.quantity + 1)
                        }
                    }) {
                        Image(systemName: "plus.circle")
                            .foregroundColor(item.quantity < item.maxStock ? .blue : .gray)
                    }
                    .disabled(item.quantity >= item.maxStock)
                }

                // Total Price
                Text("$\(String(format: "%.2f", item.total))")
                    .font(.subheadline)
                    .fontWeight(.bold)

                // Remove Button
                Button(action: onRemove) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct CheckoutView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var cartManager: CartManager
    @EnvironmentObject var authManager: AuthenticationManager
    @StateObject private var viewModel: CheckoutViewModel

    init(cartManager: CartManager = CartManager.shared) {
        self._viewModel = StateObject(wrappedValue: CheckoutViewModel(cartManager: cartManager))
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Progress Indicator
                CheckoutProgressIndicator(
                    currentStep: viewModel.checkoutState.currentStep,
                    progressPercentage: viewModel.progressPercentage,
                    isInstallmentOrder: viewModel.checkoutState.isInstallmentOrder
                )
                .padding(.horizontal)
                .padding(.top)

                // Step Content
                ScrollView {
                    VStack(spacing: 20) {
                        switch viewModel.checkoutState.currentStep {
                        case .customerInfo:
                            CustomerInfoStepView(viewModel: viewModel)
                        case .delivery:
                            DeliveryStepView(viewModel: viewModel)
                        case .documents:
                            DocumentsStepView(viewModel: viewModel)
                        case .payment:
                            PaymentStepView(viewModel: viewModel)
                        }
                    }
                    .padding()
                }

                Divider()

                // Navigation Buttons
                CheckoutNavigationButtons(viewModel: viewModel)
                    .padding()
            }
            .navigationTitle("Checkout")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
            .onAppear {
                viewModel.cartManager = cartManager
                viewModel.setAuthManager(authManager)
            }
            .alert("Error", isPresented: .constant(viewModel.checkoutState.errorMessage != nil)) {
                Button("OK") {
                    viewModel.clearError()
                }
            } message: {
                Text(viewModel.checkoutState.errorMessage ?? "")
            }
            .sheet(isPresented: $viewModel.showingOrderSuccess) {
                OrderSuccessView(
                    order: viewModel.placedOrder,
                    onDismiss: {
                        viewModel.dismissOrderSuccess()
                        presentationMode.wrappedValue.dismiss()
                    }
                )
            }
            .sheet(isPresented: $viewModel.showingDocumentUpload) {
                NavigationView {
                    DocumentUploadModal(viewModel: viewModel)
                }
            }
        }
    }
}

// MARK: - Document Upload Interface
struct DocumentUploadInterfaceView: View {
    @ObservedObject var viewModel: CheckoutViewModel

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    Image(systemName: "doc.badge.plus")
                        .font(.system(size: 64))
                        .foregroundColor(.blue)

                    Text("Upload Required Documents")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Please upload the following documents for installment approval:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(alignment: .leading, spacing: 12) {
                    DocumentRequirementRow(icon: "doc.text", title: "National ID or Passport", subtitle: "Clear photo of both sides")
                    DocumentRequirementRow(icon: "doc.text", title: "Salary Certificate", subtitle: "Latest 3 months from employer")
                    DocumentRequirementRow(icon: "doc.text", title: "Bank Statement", subtitle: "Latest 3 months showing income")
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)

                Spacer()

                VStack(spacing: 16) {
                    Button(action: {
                        // Simulate document upload process
                        viewModel.simulateDocumentUpload()
                    }) {
                        HStack {
                            Image(systemName: "camera.fill")
                            Text("Upload Documents")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                    }

                    Text("Note: This is a demo version. In production, you would upload actual documents.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
            .padding()
            .navigationTitle("Document Upload")
            .navigationBarItems(
                leading: Button("Cancel") {
                    viewModel.showingDocumentUpload = false
                }
            )
        }
    }
}

struct DocumentRequirementRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .font(.title3)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }
}

// MARK: - Document Upload Modal
struct DocumentUploadModal: View {
    @ObservedObject var viewModel: CheckoutViewModel
    @State private var selectedDocuments: [String] = []
    @State private var showingDocumentPicker = false
    @State private var showingImagePicker = false
    @State private var showingPhotosPicker = false
    @State private var showingActionSheet = false
    @State private var currentDocumentType = ""

    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Text("Upload Required Documents")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Upload at least one document to proceed. Additional documents may improve approval chances.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()

            // Required Documents List
            VStack(alignment: .leading, spacing: 16) {
                Text("Required Documents:")
                    .font(.headline)
                    .padding(.horizontal)

                VStack(spacing: 12) {
                    DocumentRequirementCard(
                        title: "National ID or Passport (REQUIRED)",
                        subtitle: "Clear photo or scan of both sides - Required to proceed",
                        icon: "person.text.rectangle",
                        isUploaded: selectedDocuments.contains("nationalID"),
                        onUpload: {
                            currentDocumentType = "nationalID"
                            showingActionSheet = true
                        }
                    )

                    DocumentRequirementCard(
                        title: "Salary Certificate (Optional)",
                        subtitle: "Official certificate from employer (last 3 months)",
                        icon: "doc.text.fill",
                        isUploaded: selectedDocuments.contains("salary"),
                        onUpload: {
                            currentDocumentType = "salary"
                            showingActionSheet = true
                        }
                    )

                    DocumentRequirementCard(
                        title: "Bank Statement (Optional)",
                        subtitle: "Recent statement showing income (last 3 months)",
                        icon: "building.columns.fill",
                        isUploaded: selectedDocuments.contains("bank"),
                        onUpload: {
                            currentDocumentType = "bank"
                            showingActionSheet = true
                        }
                    )
                }
                .padding(.horizontal)
            }

            Spacer()

            // Upload Status
            if selectedDocuments.count > 0 {
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("\(selectedDocuments.count)/1 document uploaded (minimum required)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                }
                .padding(.horizontal)
            }

            // Action Buttons
            VStack(spacing: 12) {
                if selectedDocuments.count >= 1 {
                    Button(action: {
                        viewModel.onDocumentUploadComplete()
                    }) {
                        Text("Continue to Payment")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                } else {
                    Button(action: {
                        currentDocumentType = "general"
                        showingActionSheet = true
                    }) {
                        HStack {
                            Image(systemName: "doc.badge.plus")
                            Text("Add Document")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Upload Documents")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    viewModel.showingDocumentUpload = false
                }
            }
        }
        .actionSheet(isPresented: $showingActionSheet) {
            ActionSheet(
                title: Text("Select Document Source"),
                message: Text("Choose how you'd like to upload your document"),
                buttons: [
                    .default(Text("Camera")) {
                        showingImagePicker = true
                    },
                    .default(Text("Photo Library")) {
                        showingPhotosPicker = true
                    },
                    .default(Text("Files")) {
                        showingDocumentPicker = true
                    },
                    .cancel()
                ]
            )
        }
        .sheet(isPresented: $showingDocumentPicker) {
            RealDocumentPicker { success in
                if success {
                    addDocument(type: currentDocumentType)
                }
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            RealImagePicker { success in
                if success {
                    addDocument(type: currentDocumentType)
                }
            }
        }
        .sheet(isPresented: $showingPhotosPicker) {
            RealPhotosPicker { success in
                if success {
                    addDocument(type: currentDocumentType)
                }
            }
        }
    }

    private func addDocument(type: String) {
        if !selectedDocuments.contains(type) {
            selectedDocuments.append(type)
        }
    }
}

// MARK: - Document Requirement Card
struct DocumentRequirementCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let isUploaded: Bool
    let onUpload: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(isUploaded ? .green : .blue)
                .frame(width: 40, height: 40)
                .background(isUploaded ? Color.green.opacity(0.1) : Color.blue.opacity(0.1))
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(isUploaded ? .green : .primary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            if isUploaded {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title2)
            } else {
                Button(action: onUpload) {
                    Image(systemName: "plus.circle")
                        .foregroundColor(.blue)
                        .font(.title2)
                }
            }
        }
        .padding()
        .background(isUploaded ? Color.green.opacity(0.05) : Color.gray.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isUploaded ? Color.green.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }
}

// MARK: - Real Document Picker
struct RealDocumentPicker: UIViewControllerRepresentable {
    let onDocumentSelected: (Bool) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf, .jpeg, .png], asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onDocumentSelected: onDocumentSelected)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onDocumentSelected: (Bool) -> Void

        init(onDocumentSelected: @escaping (Bool) -> Void) {
            self.onDocumentSelected = onDocumentSelected
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            onDocumentSelected(true)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onDocumentSelected(false)
        }
    }
}

// MARK: - Real Image Picker (Camera)
struct RealImagePicker: UIViewControllerRepresentable {
    let onImageSelected: (Bool) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        picker.allowsEditing = true
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImageSelected: onImageSelected)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImageSelected: (Bool) -> Void

        init(onImageSelected: @escaping (Bool) -> Void) {
            self.onImageSelected = onImageSelected
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            onImageSelected(true)
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onImageSelected(false)
            picker.dismiss(animated: true)
        }
    }
}

// MARK: - Real Photos Picker (Photo Library)
struct RealPhotosPicker: UIViewControllerRepresentable {
    let onPhotoSelected: (Bool) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPhotoSelected: onPhotoSelected)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onPhotoSelected: (Bool) -> Void

        init(onPhotoSelected: @escaping (Bool) -> Void) {
            self.onPhotoSelected = onPhotoSelected
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            onPhotoSelected(!results.isEmpty)
            picker.dismiss(animated: true)
        }
    }
}

struct CartView_Previews: PreviewProvider {
    static var previews: some View {
        CartView()
            .environmentObject(CartManager.shared)
    }
}