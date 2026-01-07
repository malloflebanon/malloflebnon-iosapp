import SwiftUI

// MARK: - Checkout Progress Indicator
struct CheckoutProgressIndicator: View {
    let currentStep: CheckoutStep
    let progressPercentage: Double
    let isInstallmentOrder: Bool

    private var visibleSteps: [CheckoutStep] {
        if isInstallmentOrder {
            return CheckoutStep.allCases
        } else {
            return CheckoutStep.allCases.filter { $0 != .documents }
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            // Progress Bar
            HStack {
                ForEach(visibleSteps, id: \.self) { step in
                    HStack {
                        // Step Circle
                        ZStack {
                            Circle()
                                .fill(stepColor(for: step))
                                .frame(width: 24, height: 24)

                            if step.rawValue < currentStep.rawValue {
                                Image(systemName: "checkmark")
                                    .font(.caption)
                                                    .foregroundColor(.white)
                            } else {
                                Text("\((visibleSteps.firstIndex(of: step) ?? 0) + 1)")
                                    .font(.caption)
                                                    .foregroundColor(step == currentStep ? .white : .secondary)
                            }
                        }

                        // Connecting Line
                        if step != visibleSteps.last {
                            Rectangle()
                                .fill(step.rawValue < currentStep.rawValue ? Color.blue : Color.gray.opacity(0.3))
                                .frame(height: 2)
                        }
                    }
                }
            }

            // Step Labels
            HStack {
                ForEach(visibleSteps, id: \.self) { step in
                    VStack(spacing: 4) {
                        Image(systemName: step.icon)
                            .font(.caption)
                            .foregroundColor(stepColor(for: step))

                        Group {
                        if step == currentStep {
                            Text(step.title)
                                .font(.caption)
                                .foregroundColor(.blue)
                                    } else {
                            Text(step.title)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.vertical, 8)
    }

    private func stepColor(for step: CheckoutStep) -> Color {
        if step.rawValue < currentStep.rawValue {
            return .green
        } else if step == currentStep {
            return .blue
        } else {
            return .gray.opacity(0.3)
        }
    }
}

// MARK: - Customer Info Step
struct CustomerInfoStepView: View {
    @ObservedObject var viewModel: CheckoutViewModel
    @EnvironmentObject var authManager: AuthenticationManager

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Customer Information")
                .font(.title2)
    
            VStack(spacing: 16) {
                // For logged-in users, show read-only fields
                if authManager.isAuthenticated {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Registered Account Information")
                            .font(.headline)
                            .foregroundColor(.primary)

                        // First Name - Read-only
                        VStack(alignment: .leading, spacing: 4) {
                            Text("First Name")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            HStack {
                                Text(authManager.currentUser?.firstName ?? viewModel.firstName)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                                    .foregroundColor(.secondary)
                                Image(systemName: "lock.fill")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                        }

                        // Last Name - Read-only
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Last Name")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            HStack {
                                Text(authManager.currentUser?.lastName ?? viewModel.lastName)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                                    .foregroundColor(.secondary)
                                Image(systemName: "lock.fill")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                        }

                        // Email - Read-only
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Email")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            HStack {
                                Text(authManager.currentUser?.email ?? viewModel.email)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                                    .foregroundColor(.secondary)
                                Image(systemName: "lock.fill")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                        }

                        // Phone - Editable (since not in User model)
                        TextField("Phone Number", text: $viewModel.phone)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.phonePad)
                    }
                } else {
                    // For guest users, show editable fields
                    HStack(spacing: 12) {
                        TextField("First Name", text: $viewModel.firstName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())

                        TextField("Last Name", text: $viewModel.lastName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }

                    TextField("Email", text: $viewModel.email)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)

                    TextField("Phone Number", text: $viewModel.phone)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.phonePad)
                }
            }

            if let validationError = viewModel.validateCustomerInfoForm() {
                Text(validationError)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
            }
        }
        .onAppear {
            prefillUserDataIfLoggedIn()
        }
    }

    private func prefillUserDataIfLoggedIn() {
        guard authManager.isAuthenticated, let currentUser = authManager.currentUser else { return }

        // Pre-fill customer information with logged-in user data
        viewModel.firstName = currentUser.firstName
        viewModel.lastName = currentUser.lastName
        viewModel.email = currentUser.email
        // Note: phone is not available in User model, so user must enter it manually
    }
}

// MARK: - Delivery Step
struct DeliveryStepView: View {
    @ObservedObject var viewModel: CheckoutViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Delivery Method")
                .font(.title2)
    
            VStack(spacing: 12) {
                ForEach(DeliveryMethod.allCases, id: \.self) { method in
                    DeliveryMethodCard(
                        method: method,
                        isSelected: viewModel.checkoutState.deliveryMethod == method,
                        onSelect: {
                            viewModel.selectDeliveryMethod(method)
                        }
                    )
                }
            }

            // Address Form (only for home delivery)
            if viewModel.checkoutState.deliveryMethod == .homeDelivery {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Delivery Address")
                        .font(.headline)

                    TextField("Street Address", text: $viewModel.address)
                        .textFieldStyle(RoundedBorderTextFieldStyle())

                    HStack(spacing: 12) {
                        TextField("City", text: $viewModel.city)
                            .textFieldStyle(RoundedBorderTextFieldStyle())

                        TextField("State", text: $viewModel.state)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }

                    HStack(spacing: 12) {
                        TextField("Postal Code", text: $viewModel.postalCode)
                            .textFieldStyle(RoundedBorderTextFieldStyle())

                        TextField("Country", text: $viewModel.country)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }

                    TextField("Additional Info (optional)", text: $viewModel.additionalInfo)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }

                if let validationError = viewModel.validateAddressForm() {
                    Text(validationError)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                }
            }

            // Store Pickup Configuration
            if viewModel.checkoutState.deliveryMethod == .storePickup {
                VStack(alignment: .leading, spacing: 20) {
                    // Seller Selection (for multi-seller carts)
                    if viewModel.showSellerSelection {
                        SellerSelectionSection(viewModel: viewModel)
                    }

                    // Remaining Items Options (for multi-seller pickup)
                    if viewModel.showRemainingItemsOptions {
                        RemainingItemsOptionsSection(viewModel: viewModel)
                    }

                    // Branch Selection (only shown after seller is selected)
                    if viewModel.selectedPickupSeller != nil && !viewModel.showSellerSelection && !viewModel.showRemainingItemsOptions {
                        VStack(alignment: .leading, spacing: 12) {
                            if let selectedSeller = viewModel.selectedPickupSeller,
                               let sellerGroup = viewModel.getSellersInCart().first(where: { $0.sellerId == selectedSeller }) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Selected Seller")
                                        .font(.headline)
                                    HStack {
                                        Text("Picking up from:")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                        Text(sellerGroup.sellerName)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                    }
                                    Text("\(sellerGroup.itemCount) item(s)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(12)
                            }
                        }

                        BranchSelectionSection(viewModel: viewModel)
                    }
                }
            }
        }
    }
}

struct DeliveryMethodCard: View {
    let method: DeliveryMethod
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(systemName: method.icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .blue : .gray)

                VStack(alignment: .leading, spacing: 4) {
                    Text(method.title)
                        .font(.headline)
                            .foregroundColor(.primary)

                    Text(method.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text("Estimated: \(method.estimatedDays) day\(method.estimatedDays > 1 ? "s" : "")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing) {
                    if method.fee > 0 {
                        Text("$\(String(format: "%.2f", method.fee))")
                            .font(.headline)
                                    .foregroundColor(.blue)
                    } else {
                        Text("FREE")
                            .font(.headline)
                                    .foregroundColor(.green)
                    }

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? .blue : .gray)
                }
            }
            .padding()
            .background(isSelected ? Color.blue.opacity(0.1) : Color.gray.opacity(0.05))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Documents Step
struct DocumentsStepView: View {
    @ObservedObject var viewModel: CheckoutViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Required Documents")
                .font(.title2)

            Text("Upload at least one document to proceed. Additional documents improve approval chances.")
                .font(.subheadline)
                .foregroundColor(.secondary)

            // Document Upload Information
            VStack(spacing: 16) {
                Text("Document Upload Required")
                    .font(.headline)
                    .padding()

                VStack(alignment: .leading, spacing: 12) {
                    Text("Please prepare the following documents:")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "doc.text")
                                .foregroundColor(.blue)
                            Text("National ID or Passport")
                        }

                        HStack {
                            Image(systemName: "doc.text")
                                .foregroundColor(.blue)
                            Text("Salary Certificate (last 3 months)")
                        }

                        HStack {
                            Image(systemName: "doc.text")
                                .foregroundColor(.blue)
                            Text("Bank Statement (last 3 months)")
                        }
                    }
                    .font(.subheadline)
                    .padding(.leading)
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)

                if viewModel.checkoutState.uploadedDocumentsCount >= viewModel.checkoutState.requiredDocumentsCount {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("All required documents have been uploaded!")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.green)
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                }
            }
        }
    }
}

// MARK: - Payment Step
struct PaymentStepView: View {
    @ObservedObject var viewModel: CheckoutViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Payment & Review")
                .font(.title2)
    
            // Payment Method
            VStack(alignment: .leading, spacing: 12) {
                Text("Payment Method")
                    .font(.headline)

                PaymentMethodCard(
                    method: .cashOnDelivery,
                    deliveryMethod: viewModel.checkoutState.deliveryMethod,
                    isSelected: true,
                    onSelect: { }
                )
            }

            // Gift Card Section
            GiftCardSection(viewModel: viewModel)

            // Order Summary
            OrderSummarySection(viewModel: viewModel)

            // Order Notes
            VStack(alignment: .leading, spacing: 8) {
                Text("Order Notes (Optional)")
                    .font(.headline)

                if #available(iOS 16.0, *) {
                    TextField("Special instructions...", text: $viewModel.checkoutState.notes, axis: .vertical)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .lineLimit(3...6)
                } else {
                    TextField("Special instructions...", text: $viewModel.checkoutState.notes)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
            }
        }
    }
}

struct PaymentMethodCard: View {
    let method: PaymentMethod
    let deliveryMethod: DeliveryMethod
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(systemName: method.icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .blue : .gray)

                VStack(alignment: .leading, spacing: 4) {
                    Text(method.title(for: deliveryMethod))
                        .font(.headline)
                            .foregroundColor(.primary)

                    Text(method.description(for: deliveryMethod))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .gray)
            }
            .padding()
            .background(isSelected ? Color.blue.opacity(0.1) : Color.gray.opacity(0.05))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Gift Card Section
struct GiftCardSection: View {
    @ObservedObject var viewModel: CheckoutViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Gift Card")
                .font(.headline)
    
            if let appliedGiftCard = viewModel.checkoutState.appliedGiftCard {
                // Applied Gift Card Display
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Applied: \(appliedGiftCard.code)")
                            .font(.subheadline)
                            
                        Text("Discount: -$\(String(format: "%.2f", appliedGiftCard.discountAmount))")
                            .font(.caption)
                            .foregroundColor(.green)

                        if appliedGiftCard.remainingBalance > 0 {
                            Text("Remaining: $\(String(format: "%.2f", appliedGiftCard.remainingBalance))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    Button("Remove") {
                        viewModel.removeGiftCard()
                    }
                    .foregroundColor(.red)
                    .font(.caption)
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
            } else {
                // Gift Card Input
                VStack(spacing: 12) {
                    HStack {
                        TextField("Sanipa-XXXX-XXXX-XXXX-XXXX", text: $viewModel.giftCardCode)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.allCharacters)

                        Button(action: {
                            if viewModel.validatedGiftCard != nil {
                                viewModel.applyGiftCard()
                            } else {
                                viewModel.validateGiftCard()
                            }
                        }) {
                            if viewModel.isValidatingGiftCard {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else if viewModel.validatedGiftCard != nil {
                                Text("Apply")
                                            } else {
                                Text("Validate")
                                            }
                        }
                        .disabled(viewModel.giftCardCode.isEmpty || viewModel.isValidatingGiftCard)
                        .buttonStyle(.bordered)
                    }

                    if let message = viewModel.giftCardValidationMessage {
                        Text(message)
                            .font(.caption)
                            .foregroundColor(viewModel.validatedGiftCard != nil ? .green : .red)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background((viewModel.validatedGiftCard != nil ? Color.green : Color.red).opacity(0.1))
                            .cornerRadius(8)
                    }
                }
            }
        }
    }
}

// MARK: - Order Summary Section
struct OrderSummarySection: View {
    @ObservedObject var viewModel: CheckoutViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Order Summary")
                .font(.headline)
    
            if let summary = viewModel.orderSummary {
                VStack(spacing: 8) {
                    // Items
                    ForEach(viewModel.cartManager.items) { item in
                        HStack {
                            Text("\(item.quantity)× \(item.name)")
                                .font(.subheadline)
                                .lineLimit(1)
                            Spacer()
                            Text("$\(String(format: "%.2f", item.total))")
                                .font(.subheadline)
                                                        }
                    }

                    Divider()

                    // Subtotal
                    HStack {
                        Text("Subtotal")
                            .font(.subheadline)
                        Spacer()
                        Text("$\(String(format: "%.2f", summary.subtotal))")
                            .font(.subheadline)
                    }

                    // Delivery Fee
                    HStack {
                        Text(viewModel.checkoutState.deliveryMethod.title)
                            .font(.subheadline)
                        Spacer()
                        Text(summary.deliveryFee > 0 ? "$\(String(format: "%.2f", summary.deliveryFee))" : "FREE")
                            .font(.subheadline)
                            .foregroundColor(summary.deliveryFee > 0 ? .primary : .green)
                    }

                    // Gift Card Discount
                    if summary.giftCardDiscount > 0 {
                        HStack {
                            Text("Gift Card Discount")
                                .font(.subheadline)
                            Spacer()
                            Text("-$\(String(format: "%.2f", summary.giftCardDiscount))")
                                .font(.subheadline)
                                .foregroundColor(.green)
                        }
                    }

                    Divider()

                    // Total
                    HStack {
                        Text("Total")
                            .font(.headline)
                                Spacer()
                        Text("$\(String(format: "%.2f", summary.total))")
                            .font(.headline)
                                    .foregroundColor(.blue)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.05))
                .cornerRadius(12)
            }
        }
    }
}

// MARK: - Navigation Buttons
struct CheckoutNavigationButtons: View {
    @ObservedObject var viewModel: CheckoutViewModel

    var body: some View {
        HStack(spacing: 12) {
            // Back Button
            if !viewModel.isFirstStep {
                Button(action: {
                    viewModel.goToPreviousStep()
                }) {
                    Text("Back")
                            .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                }
            }

            // Next/Place Order Button
            Button(action: {
                if viewModel.checkoutState.currentStep == .documents {
                    if viewModel.checkoutState.uploadedDocumentsCount >= viewModel.checkoutState.requiredDocumentsCount {
                        // Documents already uploaded, proceed to payment
                        print("➡️ [DEBUG] Documents uploaded, continuing to payment - current step: \(viewModel.checkoutState.currentStep)")
                        viewModel.goToNextStep()
                    } else {
                        // Need to upload documents
                        print("📄 [DEBUG] Upload Documents button pressed - current step: \(viewModel.checkoutState.currentStep)")
                        viewModel.uploadDocuments()
                    }
                } else if viewModel.isLastStep {
                    print("🛒 [DEBUG] Place Order button pressed - current step: \(viewModel.checkoutState.currentStep)")
                    viewModel.placeOrder()
                } else {
                    print("➡️ [DEBUG] Continue button pressed - current step: \(viewModel.checkoutState.currentStep)")
                    viewModel.goToNextStep()
                }
            }) {
                HStack {
                    if viewModel.checkoutState.isProcessing {
                        ProgressView()
                            .scaleEffect(0.8)
                            .foregroundColor(.white)
                    } else {
                        Text(buttonText)
                            }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(canProceed ? Color.blue : Color.gray)
                .cornerRadius(8)
            }
            .disabled(!canProceed || viewModel.checkoutState.isProcessing)
        }
    }

    private var buttonText: String {
        switch viewModel.checkoutState.currentStep {
        case .documents:
            if viewModel.checkoutState.uploadedDocumentsCount >= viewModel.checkoutState.requiredDocumentsCount {
                return "Continue"
            } else {
                return viewModel.checkoutState.isInstallmentOrder ? "Upload Documents" : "Create Installment Order"
            }
        case .payment:
            return "Place Order"
        default:
            return "Continue"
        }
    }

    private var canProceed: Bool {
        switch viewModel.checkoutState.currentStep {
        case .customerInfo:
            return viewModel.canProceedFromCustomerInfo
        case .delivery:
            return viewModel.canProceedFromDelivery
        case .documents:
            // Always allow the Upload Documents button to be enabled
            return true
        case .payment:
            return viewModel.canPlaceOrderFromPayment
        }
    }
}

// MARK: - Order Success View
struct OrderSuccessView: View {
    let order: Order?
    let onDismiss: () -> Void

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Spacer()

                // Success Icon
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.green)

                // Success Message
                VStack(spacing: 8) {
                    Text("Order Placed Successfully!")
                        .font(.title)
    
                    if let order = order {
                        Text("Order #\(order.orderNumber)")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        Text("Total: $\(String(format: "%.2f", order.totalAmount ?? 0.0))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                // Additional Info
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "envelope")
                            .foregroundColor(.blue)
                        Text("Confirmation sent to your email")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Image(systemName: "truck")
                            .foregroundColor(.blue)
                        Text("We'll notify you when your order ships")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Done Button
                Button(action: onDismiss) {
                    Text("Done")
                        .font(.headline)
                            .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
            }
            .padding()
            .navigationTitle("Success")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Seller Selection Section
struct SellerSelectionSection: View {
    @ObservedObject var viewModel: CheckoutViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Choose Seller for Pickup")
                .font(.headline)

            Text("Store pickup is available per seller. Choose which seller's items you'd like to pick up:")
                .font(.subheadline)
                .foregroundColor(.secondary)

            LazyVStack(spacing: 12) {
                ForEach(viewModel.getSellersInCart(), id: \.sellerId) { seller in
                    SellerCard(
                        seller: seller,
                        onSelect: {
                            viewModel.selectSeller(seller.sellerId)
                        }
                    )
                }
            }
        }
    }
}

// MARK: - Seller Card
struct SellerCard: View {
    let seller: SellerGroup
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(seller.sellerName)
                            .font(.headline)
                            .foregroundColor(.primary)

                        Text("\(seller.itemCount) item(s) - $\(String(format: "%.2f", seller.subtotal))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .foregroundColor(.blue)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.05))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
            )
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Remaining Items Options Section
struct RemainingItemsOptionsSection: View {
    @ObservedObject var viewModel: CheckoutViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What would you like to do with the remaining items?")
                .font(.headline)

            Text("You have \(viewModel.getRemainingItems().count) item(s) from other sellers:")
                .font(.subheadline)
                .foregroundColor(.secondary)

            LazyVStack(spacing: 12) {
                ForEach(RemainingItemsAction.allCases, id: \.rawValue) { action in
                    RemainingItemsActionCard(
                        action: action,
                        onSelect: {
                            viewModel.selectRemainingItemsAction(action)
                        }
                    )
                }
            }
        }
    }
}

// MARK: - Remaining Items Action Card
struct RemainingItemsActionCard: View {
    let action: RemainingItemsAction
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(action.title)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(action.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.blue)
            }
            .padding()
            .background(Color.gray.opacity(0.05))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
            )
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Branch Selection Section
struct BranchSelectionSection: View {
    @ObservedObject var viewModel: CheckoutViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Select Pickup Branch")
                    .font(.headline)

                Spacer()

                if viewModel.isLoadingBranches {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }

            if let error = viewModel.branchLoadingError {
                HStack {
                    Image(systemName: "exclamationmark.circle")
                        .foregroundColor(.red)
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.red)
                }
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            } else if viewModel.availableBranches.isEmpty && !viewModel.isLoadingBranches {
                VStack(spacing: 16) {
                    Image(systemName: "storefront")
                        .font(.title)
                        .foregroundColor(.gray)

                    Text("No pickup locations available for this seller.")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)

                    Button(action: {
                        viewModel.selectDeliveryMethod(.homeDelivery)
                    }) {
                        Text("Choose Home Delivery Instead")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.availableBranches) { branch in
                        BranchCard(
                            branch: branch,
                            isSelected: viewModel.selectedBranch?.id == branch.id,
                            onSelect: {
                                viewModel.selectBranch(branch)
                            }
                        )
                    }
                }
            }

            if !viewModel.isValidBranchSelection && viewModel.checkoutState.deliveryMethod == .storePickup {
                Text("Please select a pickup branch to continue")
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
            }
        }
    }
}

// MARK: - Branch Card
struct BranchCard: View {
    let branch: Branch
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(branch.displayName)
                            .font(.headline)
                            .foregroundColor(.primary)

                        Text(branch.fullAddress)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer()

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundColor(isSelected ? .blue : .gray)
                }

                if let phone = branch.contact.phone, !phone.isEmpty {
                    HStack {
                        Image(systemName: "phone")
                            .foregroundColor(.blue)
                            .font(.caption)
                        Text(phone)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                let hours = branch.operatingHoursArray
                if !hours.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Operating Hours:")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)

                        let todayHours = hours.first { $0.day.lowercased() == todayDayName() }
                        if let todayHours = todayHours {
                            Text(todayHours.displayText)
                                .font(.caption)
                                .foregroundColor(todayHours.isOpen ? .green : .red)
                        } else {
                            Text("Hours not available")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            .padding()
            .background(isSelected ? Color.blue.opacity(0.1) : Color.gray.opacity(0.05))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func todayDayName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: Date()).lowercased()
    }
}