import Foundation
import SwiftUI
import Combine

@MainActor
class CheckoutViewModel: ObservableObject {
    @Published var checkoutState = CheckoutState()
    @Published var orderSummary: OrderSummary?
    @Published var giftCardCode = ""
    @Published var isValidatingGiftCard = false
    @Published var giftCardValidationMessage: String?
    @Published var validatedGiftCard: GiftCard?
    @Published var showingOrderSuccess = false
    @Published var placedOrder: Order?
    @Published var orderEmailSent = false
    @Published var showEmailConfirmation = false
    @Published var showingDocumentUpload = false

    private var authManager: AuthenticationManager

    // Customer Info Form Fields
    @Published var firstName = ""
    @Published var lastName = ""
    @Published var email = ""
    @Published var phone = ""

    // Address Form Fields (for home delivery)
    @Published var address = ""
    @Published var city = ""
    @Published var state = ""
    @Published var postalCode = ""
    @Published var country = ""
    @Published var additionalInfo = ""

    // Branch Selection (for store pickup)
    @Published var availableBranches: [Branch] = []
    @Published var selectedBranch: Branch?
    @Published var isLoadingBranches = false
    @Published var branchLoadingError: String?

    // Seller Selection (for multi-seller pickup)
    @Published var showSellerSelection = false
    @Published var selectedPickupSeller: String?
    @Published var showRemainingItemsOptions = false
    @Published var remainingItemsAction: RemainingItemsAction?

    private let apiService = APIService.shared
    var cartManager: CartManager {
        didSet {
            updateOrderSummary()
        }
    }
    private var cancellables = Set<AnyCancellable>()

    init(cartManager: CartManager, authManager: AuthenticationManager = AuthenticationManager()) {
        self.cartManager = cartManager
        self.authManager = authManager
        setupObservers()
        updateOrderSummary()
        checkForInstallmentOrder()
    }

    private func setupObservers() {
        // Update order summary when delivery method or gift card changes
        $checkoutState
            .sink { [weak self] _ in
                self?.updateOrderSummary()
            }
            .store(in: &cancellables)

        // Update order summary when shipping cost changes
        cartManager.$shippingCost
            .sink { [weak self] _ in
                self?.updateOrderSummary()
            }
            .store(in: &cancellables)

        // Update customer info when form fields change
        Publishers.CombineLatest4($firstName, $lastName, $email, $phone)
            .sink { [weak self] firstName, lastName, email, phone in
                if !firstName.isEmpty && !lastName.isEmpty && !email.isEmpty && !phone.isEmpty {
                    self?.checkoutState.customerInfo = CustomerInfo(
                        firstName: firstName,
                        lastName: lastName,
                        email: email,
                        phone: phone
                    )
                } else {
                    self?.checkoutState.customerInfo = nil
                }
            }
            .store(in: &cancellables)
    }

    private func updateOrderSummary() {
        let giftCardDiscount = checkoutState.appliedGiftCard?.discountAmount ?? 0
        orderSummary = OrderSummary(
            items: cartManager.items,
            deliveryMethod: checkoutState.deliveryMethod,
            giftCardDiscount: giftCardDiscount,
            dynamicShippingCost: cartManager.shippingCost
        )
    }

    // MARK: - Installment Management

    private func checkForInstallmentOrder() {
        let hasInstallmentItems = cartManager.items.contains { $0.installmentPlan != nil }
        checkoutState.isInstallmentOrder = hasInstallmentItems

        if hasInstallmentItems {
            // Get required documents from the first installment item's plan
            if let firstInstallmentItem = cartManager.items.first(where: { $0.installmentPlan != nil }),
               let _ = firstInstallmentItem.installmentPlan {
                // In a real app, you'd get this from the installment plan, but for now use common requirements
                // checkoutState.requiredDocumentTypes = [.nationalID, .salaryCertificate, .bankStatement]
                checkoutState.requiredDocumentsCount = 1 // Only 1 document required to proceed
            }
        }
    }

    // MARK: - Step Navigation

    func goToNextStep() {
        print("🚀 [DEBUG] goToNextStep() called - current step: \(checkoutState.currentStep), can proceed: \(checkoutState.canProceedToNextStep), isInstallment: \(checkoutState.isInstallmentOrder)")

        if !checkoutState.canProceedToNextStep {
            print("⚠️ [DEBUG] Cannot proceed to next step from \(checkoutState.currentStep)")
            return
        }

        let currentIndex = checkoutState.currentStep.rawValue
        let oldStep = checkoutState.currentStep

        // Normal step progression for all cases
        if currentIndex == 1 && !checkoutState.isInstallmentOrder { // delivery step for non-installment
            checkoutState.currentStep = .payment
        } else if currentIndex < CheckoutStep.allCases.count - 1 {
            checkoutState.currentStep = CheckoutStep(rawValue: currentIndex + 1) ?? .payment
        }
        print("🚀 [DEBUG] Step transition: \(oldStep) -> \(checkoutState.currentStep)")
    }

    func goToPreviousStep() {
        let currentIndex = checkoutState.currentStep.rawValue
        let oldStep = checkoutState.currentStep

        print("⬅️ [DEBUG] goToPreviousStep() called - current step: \(checkoutState.currentStep), index: \(currentIndex), isInstallment: \(checkoutState.isInstallmentOrder)")

        if currentIndex > 0 {
            // Skip documents step for non-installment orders when going back
            if currentIndex == 3 && !checkoutState.isInstallmentOrder { // payment step
                checkoutState.currentStep = .delivery
            } else {
                checkoutState.currentStep = CheckoutStep(rawValue: currentIndex - 1) ?? .customerInfo
            }

            print("⬅️ [DEBUG] Step transition: \(oldStep) -> \(checkoutState.currentStep)")
        } else {
            print("⚠️ [DEBUG] Cannot go to previous step from \(checkoutState.currentStep)")
        }
    }

    func goToStep(_ step: CheckoutStep) {
        // Only allow going to previous steps or next step if current step is valid
        if step.rawValue <= checkoutState.currentStep.rawValue || checkoutState.canProceedToNextStep {
            checkoutState.currentStep = step
        }
    }

    // MARK: - Delivery Method

    func selectDeliveryMethod(_ method: DeliveryMethod) {
        checkoutState.deliveryMethod = method
        selectedBranch = nil
        availableBranches = []

        if method == .storePickup {
            let sellers = getSellersInCart()
            if sellers.count > 1 {
                // Multiple sellers - show seller selection
                showSellerSelection = true
                selectedPickupSeller = nil
            } else if sellers.count == 1 {
                // Single seller - select automatically
                selectedPickupSeller = sellers[0].sellerId
                showSellerSelection = false
                loadBranches()
            }
        } else {
            // Reset pickup-specific states
            resetPickupStates()
        }
    }

    // MARK: - Payment Method

    func selectPaymentMethod(_ method: PaymentMethod) {
        checkoutState.paymentMethod = method
    }

    // MARK: - Branch Management

    func loadBranches() {
        guard let selectedSeller = selectedPickupSeller else { return }

        isLoadingBranches = true
        branchLoadingError = nil

        // Load all branches from public endpoint (matching frontend)
        apiService.getBranches()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoadingBranches = false
                    if case .failure(let error) = completion {
                        self?.branchLoadingError = error.localizedDescription
                        print("❌ Failed to load branches: \(error.localizedDescription)")
                    }
                },
                receiveValue: { [weak self] response in
                    if response.success {
                        // Filter branches matching frontend logic: isActive && hasPickup && sellerId matches selected seller
                        let filteredBranches = response.branches.filter { branch in
                            branch.isActive &&
                            branch.features.hasPickup &&
                            branch.sellerId == selectedSeller
                        }
                        self?.availableBranches = filteredBranches
                        print("✅ Loaded \(filteredBranches.count) available branches for seller: \(selectedSeller)")
                    } else {
                        self?.branchLoadingError = response.message ?? "Failed to load branches"
                        print("❌ API error: \(response.message ?? "Failed to load branches")")
                    }
                }
            )
            .store(in: &cancellables)
    }

    func selectBranch(_ branch: Branch) {
        selectedBranch = branch
        print("📍 Selected branch: \(branch.displayName)")
    }

    func clearBranchSelection() {
        selectedBranch = nil
    }

    // Computed property to check if branch selection is valid
    var isValidBranchSelection: Bool {
        if checkoutState.deliveryMethod == .storePickup {
            return selectedBranch != nil
        }
        return true // Not needed for home delivery
    }

    // MARK: - Seller Management

    func getSellersInCart() -> [SellerGroup] {
        let sellerMap = Dictionary(grouping: cartManager.items) { $0.sellerId }
        return sellerMap.map { sellerId, items in
            SellerGroup(
                sellerId: sellerId,
                sellerName: items.first?.sellerName ?? "Unknown Seller",
                items: items
            )
        }.sorted { $0.sellerName < $1.sellerName }
    }

    func selectSeller(_ sellerId: String) {
        selectedPickupSeller = sellerId
        showSellerSelection = false

        let sellers = getSellersInCart()
        if sellers.count > 1 {
            // Show options for remaining items
            showRemainingItemsOptions = true
        } else {
            loadBranches()
        }
    }

    func selectRemainingItemsAction(_ action: RemainingItemsAction) {
        remainingItemsAction = action
        showRemainingItemsOptions = false
        loadBranches()
    }

    func getPickupItems() -> [CartItem] {
        guard let selectedSeller = selectedPickupSeller else { return cartManager.items }
        return cartManager.items.filter { $0.sellerId == selectedSeller }
    }

    func getRemainingItems() -> [CartItem] {
        guard let selectedSeller = selectedPickupSeller else { return [] }
        return cartManager.items.filter { $0.sellerId != selectedSeller }
    }

    func getPickupSubtotal() -> Double {
        return getPickupItems().reduce(0) { $0 + $1.total }
    }

    private func resetPickupStates() {
        selectedPickupSeller = nil
        showSellerSelection = false
        showRemainingItemsOptions = false
        remainingItemsAction = nil
        selectedBranch = nil
        availableBranches = []
    }

    // MARK: - Gift Card Management

    func validateGiftCard() {
        guard !giftCardCode.isEmpty else { return }

        Task {
            await validateGiftCardAsync()
        }
    }

    private func validateGiftCardAsync() async {
        isValidatingGiftCard = true
        giftCardValidationMessage = nil

        do {
            let response = try await apiService.validateGiftCardAsync(code: giftCardCode)

            await MainActor.run {
                isValidatingGiftCard = false

                if response.success, let giftCard = response.giftCard, giftCard.isValid {
                    validatedGiftCard = giftCard
                    giftCardValidationMessage = "Gift card valid! Balance: $\(String(format: "%.2f", giftCard.balance))"
                } else {
                    validatedGiftCard = nil
                    giftCardValidationMessage = response.message
                }
            }
        } catch {
            await MainActor.run {
                isValidatingGiftCard = false
                validatedGiftCard = nil
                giftCardValidationMessage = "Failed to validate gift card: \(error.localizedDescription)"
            }
        }
    }

    func applyGiftCard() {
        guard let giftCard = validatedGiftCard,
              let orderSummary = orderSummary else { return }

        // Calculate discount amount (cannot exceed total)
        let maxDiscount = orderSummary.subtotal + orderSummary.deliveryFee
        let discountAmount = min(giftCard.balance, maxDiscount)
        let remainingBalance = giftCard.balance - discountAmount

        checkoutState.appliedGiftCard = AppliedGiftCard(
            code: giftCard.code,
            discountAmount: discountAmount,
            remainingBalance: remainingBalance
        )

        // Clear the input fields
        giftCardCode = ""
        validatedGiftCard = nil
        giftCardValidationMessage = "Gift card applied successfully!"

        // Auto-hide message after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.giftCardValidationMessage = nil
        }
    }

    func removeGiftCard() {
        checkoutState.appliedGiftCard = nil
        giftCardCode = ""
        validatedGiftCard = nil
        giftCardValidationMessage = nil
    }

    // MARK: - Order Placement

    func placeOrder() {
        print("\n🚀 ===== PLACE ORDER BUTTON CLICKED =====")
        print("📊 Checkout State:")
        print("   - Current Step: \(checkoutState.currentStep)")
        print("   - Can Place Order: \(checkoutState.canPlaceOrder)")
        print("   - Delivery Method: \(checkoutState.deliveryMethod)")
        print("   - Payment Method: \(checkoutState.paymentMethod)")
        print("   - Is Processing: \(checkoutState.isProcessing)")
        print("   - Is Installment Order: \(checkoutState.isInstallmentOrder)")

        print("🛒 Cart Information:")
        print("   - Total Items: \(cartManager.itemCount)")
        print("   - Cart Total: $\(cartManager.total)")
        print("   - Subtotal: $\(cartManager.subtotal)")

        // Log all cart items with their product IDs
        print("🛒 Cart Items for Order:")
        for (index, item) in cartManager.items.enumerated() {
            print("   Item \(index + 1):")
            print("     - Product ID: \(item.productId)")
            print("     - Name: \(item.name)")
            print("     - Price: $\(item.price)")
            print("     - Quantity: \(item.quantity)")
            print("     - Total: $\(item.total)")
            print("     - Seller ID: \(item.sellerId)")
            print("     - Is Raffle Ticket: \(item.isRaffleTicket)")
            if item.isRaffleTicket, let raffleInfo = item.raffleInfo {
                print("     - Raffle ID: \(raffleInfo.raffleId)")
                print("     - Raffle Title: \(raffleInfo.raffleTitle ?? "nil")")
            }
        }

        guard checkoutState.canPlaceOrder else {
            print("❌ CANNOT PLACE ORDER - Requirements not met")
            print("   - Check all required fields are filled")
            print("   - Check delivery/payment method selected")
            return
        }

        print("✅ Order validation passed, proceeding to async order placement...")
        Task {
            await placeOrderAsync()
        }
        print("🚀 ===== PLACE ORDER INITIATED =====\n")
    }

    private func placeOrderAsync() async {
        print("\n🔄 ===== ASYNC ORDER PLACEMENT STARTED =====")
        checkoutState.isProcessing = true
        checkoutState.errorMessage = nil
        print("📝 Processing state set to true, error message cleared")

        do {
            if checkoutState.isInstallmentOrder {
                print("💳 Processing INSTALLMENT ORDER...")
                let success = await createInstallmentOrder()
                print("💳 Installment order result: \(success)")

                await MainActor.run {
                    checkoutState.isProcessing = false
                    if success {
                        print("✅ Installment order successful - showing success screen")
                        showingOrderSuccess = true
                        orderEmailSent = true
                        showEmailConfirmation = true
                        cartManager.clearCart()
                        resetCheckoutState()
                    } else {
                        print("❌ Installment order failed")
                    }
                }
            } else {
                print("🛒 Processing REGULAR ORDER...")

                // Ensure shipping is calculated before creating order request
                if checkoutState.deliveryMethod == .homeDelivery {
                    print("📦 Calculating shipping for delivery...")
                    await cartManager.calculateShipping()
                    print("📦 Shipping calculated: $\(cartManager.shippingCost)")
                }

                // Create order request and log it
                let orderRequest = createOrderRequest()
                print("📦 Order Request Created:")
                print("   - Customer Email: \(orderRequest.customer.email)")
                print("   - Customer Name: \(orderRequest.customer.name)")
                print("   - Delivery Method: \(orderRequest.deliveryMethod)")
                print("   - Payment Method: \(orderRequest.paymentMethod)")
                print("   - Items Count: \(orderRequest.items.count)")
                print("   - Total Amount: $\(Double(orderRequest.totalCents) / 100.0)")
                print("   - Shipping: $\(Double(orderRequest.shippingCents) / 100.0)")
                print("   - Tax: $\(Double(orderRequest.taxCents) / 100.0)")
                print("   - Client Order Ref: \(orderRequest.clientOrderRef)")

                // Log each item in the order request
                print("📦 Order Request Items:")
                for (index, item) in orderRequest.items.enumerated() {
                    print("   Item \(index + 1):")
                    print("     - Product ID: \(item.productId)")
                    print("     - Title: \(item.title)")
                    print("     - SKU: \(item.sku)")
                    print("     - Vendor ID: \(item.vendorId)")
                    print("     - Unit Price: $\(Double(item.unitPriceCents) / 100.0)")
                    print("     - Quantity: \(item.quantity)")
                    print("     - Total: $\(Double(item.unitPriceCents * item.quantity) / 100.0)")
                    if !item.customizations.isEmpty {
                        print("     - Customizations: \(item.customizations.count)")
                    }
                }

                print("🌐 Sending order request to API...")
                let response = try await apiService.createOrderAsync(orderRequest)
                print("📨 API Response received")

                await MainActor.run {
                    checkoutState.isProcessing = false
                    print("📝 Processing state set to false")

                    // Enhanced debug logging
                    print("\n📋 ===== ORDER RESPONSE DETAILS =====")
                    print("✅ Success: \(response.success)")
                    print("💬 Message: \(response.message)")
                    print("📦 Order Present: \(response.order != nil ? "YES" : "NO")")
                    print("🆔 Order Number: \(response.orderNumber ?? "nil")")

                    if let order = response.order {
                        print("📄 Order Details:")
                        print("   - ID: \(order.id)")
                        print("   - Status: \(order.status)")
                        print("   - Total: $\(order.totalAmount)")
                        print("   - Customer Email: \(order.customerInfo?.email ?? "nil")")
                        print("   - Items Count: \(order.items?.count ?? 0)")
                    }
                    print("===== ORDER RESPONSE DETAILS END =====\n")

                    if response.success, let order = response.order {
                        print("✅ ORDER SUCCESSFUL - Processing success flow...")
                        placedOrder = order
                        showingOrderSuccess = true
                        orderEmailSent = true
                        showEmailConfirmation = true

                        // Handle remaining items for pickup orders
                        if checkoutState.deliveryMethod == .storePickup && selectedPickupSeller != nil && getRemainingItems().count > 0 {
                            print("🏪 Handling pickup order with remaining items...")
                            if remainingItemsAction == .remove {
                                print("🗑️ Removing all items from cart")
                                cartManager.clearCart()
                            } else if remainingItemsAction == .delivery {
                                print("🚚 Removing only pickup items, keeping delivery items")
                                let pickupItems = getPickupItems()
                                pickupItems.forEach { item in
                                    cartManager.removeItem(item.id)
                                }
                            }
                        } else {
                            print("🧹 Clearing all items from cart (regular order)")
                            cartManager.clearCart()
                        }

                        print("♻️ Resetting checkout state")
                        resetCheckoutState()
                        print("✅ Order success flow completed")
                    } else {
                        print("❌ ORDER FAILED")
                        print("💬 Error Message: \(response.message)")
                        checkoutState.errorMessage = response.message
                        print("📝 Error message set in checkout state")
                    }
                }
            }
        } catch {
            print("\n🚨 ===== ORDER PLACEMENT EXCEPTION =====")
            print("❌ Exception caught: \(error)")
            print("🔍 Error Type: \(type(of: error))")
            print("📋 Error Description: \(error.localizedDescription)")
            if let apiError = error as? APIError {
                print("🌐 API Error Details: \(apiError)")
            }
            print("===== ORDER PLACEMENT EXCEPTION END =====\n")

            await MainActor.run {
                checkoutState.isProcessing = false
                let errorMessage = "Failed to place order: \(error.localizedDescription)"
                checkoutState.errorMessage = errorMessage
                print("📝 Error state updated: \(errorMessage)")
            }
        }

        print("🔄 ===== ASYNC ORDER PLACEMENT COMPLETED =====\n")
    }

    private func generateClientOrderRef() -> String {
        return "client-\(Date().timeIntervalSince1970)-\(UUID().uuidString.prefix(8))"
    }

    private func createOrderRequest() -> CreateOrderRequest {
        // Get appropriate items based on delivery method and seller selection
        let itemsToOrder = (checkoutState.deliveryMethod == .storePickup && selectedPickupSeller != nil) ? getPickupItems() : cartManager.items

        let items = itemsToOrder.map { item in
            // Customizations are already in the correct format
            let customizations = item.customizations ?? []

            // Debug logging
            print("🚚 [DEBUG] Order item: \(item.name)")
            print("🚚 [DEBUG] Item customizations count: \(customizations.count)")
            for customization in customizations {
                print("🚚 [DEBUG] - Customization: \(customization.customizationName)")
                print("🚚 [DEBUG] - Option: \(customization.optionLabel)")
                print("🚚 [DEBUG] - Value: \(customization.optionValue)")
                print("🚚 [DEBUG] - Price modifier: \(customization.priceModifier)")
            }

            return OrderItemRequest(
                productId: item.productId,
                sku: item.sku,
                title: item.name,
                vendorId: item.sellerId,
                unitPriceCents: Int(item.price * 100), // Convert to cents
                quantity: item.quantity,
                customizations: customizations
            )
        }

        let shippingAddressRequest: ShippingAddressRequest?
        if checkoutState.deliveryMethod == .homeDelivery {
            shippingAddressRequest = ShippingAddressRequest(
                country: country,
                city: city,
                street: address,
                postcode: postalCode,
                notes: additionalInfo.isEmpty ? nil : additionalInfo
            )
        } else {
            shippingAddressRequest = nil
        }

        let pickupBranchRequest: PickupBranchRequest?
        if checkoutState.deliveryMethod == .storePickup, let selectedBranch = selectedBranch {
            pickupBranchRequest = PickupBranchRequest(
                branchId: selectedBranch.id,
                branchName: selectedBranch.displayName,
                branchAddress: selectedBranch.fullAddress
            )
        } else {
            pickupBranchRequest = nil
        }

        let giftCardRequest: GiftCardRequest?
        if let appliedGiftCard = checkoutState.appliedGiftCard {
            giftCardRequest = GiftCardRequest(
                code: appliedGiftCard.code,
                amountUsed: appliedGiftCard.discountAmount,
                remainingBalance: appliedGiftCard.remainingBalance
            )
        } else {
            giftCardRequest = nil
        }

        let subtotal = itemsToOrder.reduce(0) { $0 + $1.total }

        // Use dynamic shipping calculation matching frontend logic
        let shippingCost = checkoutState.deliveryMethod == .storePickup ? 0.0 : cartManager.shippingCost

        // Calculate tax based on item tax rates matching frontend logic (Lebanon VAT rate 11%)
        let taxCost = itemsToOrder.reduce(0.0) { totalTax, item in
            let productTaxRate = item.taxRate ?? 11.0 // Default to Lebanon's VAT rate
            let itemSubtotal = item.price * Double(item.quantity)
            let itemTax = (itemSubtotal * productTaxRate) / 100.0
            return totalTax + itemTax
        }

        let giftCardDiscount = checkoutState.appliedGiftCard?.discountAmount ?? 0
        let total = max(0, subtotal + shippingCost + taxCost - giftCardDiscount)

        print("💰 ORDER CALCULATION DEBUG:")
        print("   - Subtotal: $\(subtotal)")
        print("   - Shipping Cost (dynamic): $\(shippingCost)")
        print("   - Tax Cost (calculated): $\(taxCost)")
        print("   - Gift Card Discount: $\(giftCardDiscount)")
        print("   - Final Total: $\(total)")

        // Convert CustomerInfo to match frontend format (name instead of firstName/lastName)
        guard let customerInfo = checkoutState.customerInfo else {
            print("❌ CRITICAL: Customer info is nil in checkout state!")
            fatalError("Customer info is required for order creation")
        }

        print("👤 Creating frontend customer info:")
        print("   - Full Name: \(customerInfo.fullName)")
        print("   - Email: \(customerInfo.email)")
        print("   - Phone: \(customerInfo.phone)")

        let frontendCustomerInfo = FrontendCustomerInfo(
            name: customerInfo.fullName,
            email: customerInfo.email,
            phone: customerInfo.phone
        )

        print("📤 Frontend customer object created:")
        print("   - Name: \(frontendCustomerInfo.name)")
        print("   - Email: \(frontendCustomerInfo.email)")
        print("   - Phone: \(frontendCustomerInfo.phone)")

        return CreateOrderRequest(
            clientOrderRef: generateClientOrderRef(),
            userId: authManager.currentUser?.id, // Use authenticated user ID if available
            customer: frontendCustomerInfo,
            deliveryMethod: checkoutState.deliveryMethod == .homeDelivery ? "delivery" : "pickup",
            shippingAddress: shippingAddressRequest,
            pickupBranch: pickupBranchRequest,
            items: items,
            shippingCents: Int(shippingCost * 100),
            taxCents: Int(taxCost * 100),
            totalCents: Int(total * 100),
            paymentMethod: checkoutState.paymentMethod.rawValue.uppercased(), // Convert to "COD"
            giftCard: giftCardRequest
        )
    }

    private func resetCheckoutState() {
        checkoutState = CheckoutState()
        firstName = ""
        lastName = ""
        email = ""
        phone = ""
        address = ""
        city = ""
        state = ""
        postalCode = ""
        country = ""
        additionalInfo = ""
        giftCardCode = ""
        validatedGiftCard = nil
        giftCardValidationMessage = nil

        // Clear branch selection data
        availableBranches = []
        selectedBranch = nil
        isLoadingBranches = false
        branchLoadingError = nil

        // Clear email confirmation data
        orderEmailSent = false
        showEmailConfirmation = false
    }

    // MARK: - Validation

    var canProceedFromCustomerInfo: Bool {
        return checkoutState.customerInfo != nil
    }

    var canProceedFromDelivery: Bool {
        if checkoutState.deliveryMethod == .homeDelivery {
            return !address.isEmpty && !city.isEmpty && !country.isEmpty
        } else {
            // Store pickup needs branch selection and remaining items handling (if applicable)
            let hasValidBranchSelection = isValidBranchSelection
            let hasHandledRemainingItems = getRemainingItems().isEmpty || remainingItemsAction != nil
            return hasValidBranchSelection && hasHandledRemainingItems
        }
    }

    var canProceedFromDocuments: Bool {
        guard checkoutState.isInstallmentOrder else { return true }
        // For installment orders, require at least one document to be uploaded
        // TODO: Implement actual document upload tracking
        // For now, we'll require that the user has interacted with the upload area
        return true // Temporarily allowing progress until document upload is implemented
    }

    var canPlaceOrderFromPayment: Bool {
        return checkoutState.canPlaceOrder && canProceedFromDelivery
    }

    // MARK: - Computed Properties

    var progressPercentage: Double {
        let totalSteps = Double(CheckoutStep.allCases.count)
        let currentStepIndex = Double(checkoutState.currentStep.rawValue)
        return (currentStepIndex + 1) / totalSteps
    }

    var isFirstStep: Bool {
        return checkoutState.currentStep == .customerInfo
    }

    var isLastStep: Bool {
        return checkoutState.currentStep == .payment
    }

    // MARK: - Error Handling

    func clearError() {
        checkoutState.errorMessage = nil
    }

    func dismissOrderSuccess() {
        showingOrderSuccess = false
        placedOrder = nil
        showEmailConfirmation = false
        orderEmailSent = false
    }

    func setAuthManager(_ authManager: AuthenticationManager) {
        self.authManager = authManager
    }

    // MARK: - Form Validation

    func validateCustomerInfoForm() -> String? {
        if firstName.isEmpty { return "First name is required" }
        if lastName.isEmpty { return "Last name is required" }
        if email.isEmpty { return "Email is required" }
        if !isValidEmail(email) { return "Please enter a valid email" }
        if phone.isEmpty { return "Phone number is required" }
        return nil
    }

    func validateAddressForm() -> String? {
        guard checkoutState.deliveryMethod == .homeDelivery else { return nil }

        if address.isEmpty { return "Address is required" }
        if city.isEmpty { return "City is required" }
        if country.isEmpty { return "Country is required" }
        return nil
    }

    private func isValidEmail(_ email: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
    }

    // MARK: - Multi-Seller Helper Methods

    func handleRemainingItemsSelection(_ action: RemainingItemsAction) {
        remainingItemsAction = action
        showRemainingItemsOptions = false

        // Proceed with checkout - go to payment step
        goToStep(.payment)
    }

    // MARK: - Document Upload Methods

    func uploadDocuments() {
        print("📄 [DEBUG] uploadDocuments() called - current step: \(checkoutState.currentStep)")

        // Show the document upload interface
        showingDocumentUpload = true
    }

    func onDocumentUploadComplete() {
        print("📄 [DEBUG] Document upload completed successfully")

        // Mark documents as uploaded
        checkoutState.uploadedDocumentsCount = checkoutState.requiredDocumentsCount

        // Dismiss the upload view
        showingDocumentUpload = false

        // Move to next step
        goToNextStep()
    }

    func simulateDocumentUpload() {
        print("📄 [DEBUG] Starting document upload simulation...")

        // Simulate upload delay
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds

            await MainActor.run {
                print("📄 [DEBUG] Document upload simulation completed")
                onDocumentUploadComplete()
            }
        }
    }

    func createInstallmentOrder() async -> Bool {
        guard checkoutState.isInstallmentOrder else { return true }

        do {
            // Create installment order request
            let installmentOrderRequest = createInstallmentOrderRequest()
            // Create shipping address request if needed
            let shippingAddressRequest: ShippingAddressRequest?
            if checkoutState.deliveryMethod == .homeDelivery {
                shippingAddressRequest = ShippingAddressRequest(
                    country: country,
                    city: city,
                    street: address,
                    postcode: postalCode,
                    notes: additionalInfo.isEmpty ? nil : additionalInfo
                )
            } else {
                shippingAddressRequest = nil
            }

            let response = try await apiService.createInstallmentOrderAsync(installmentOrderRequest, deliveryMethod: checkoutState.deliveryMethod, shippingAddress: shippingAddressRequest, userId: authManager.currentUser?.id)

            let success = await MainActor.run {
                if response.success {
                    // Use actual installment order ID from response
                    checkoutState.installmentOrderId = response.installmentOrderId
                    print("✅ [DEBUG] Installment order created successfully with ID: \(response.installmentOrderId ?? "none")")
                    return true
                } else {
                    checkoutState.errorMessage = response.message.isEmpty ? "Failed to create installment order" : response.message
                    print("❌ [DEBUG] Installment order creation failed: \(response.message)")
                    return false
                }
            }
            return success
        } catch {
            await MainActor.run {
                checkoutState.errorMessage = "Failed to create installment order: \(error.localizedDescription)"
                print("❌ [DEBUG] Installment order creation error: \(error.localizedDescription)")
            }
            return false
        }
    }

    func uploadDocument(data: Data, fileName: String, documentType: String) async -> Bool {
        // Temporarily commented for build - will be implemented with proper types
        // guard let installmentOrderId = checkoutState.installmentOrderId else { return false }

        // do {
        //     let documentFile = DocumentFile(
        //         file: data,
        //         fileName: fileName,
        //         mimeType: mimeTypeForFile(fileName),
        //         documentType: documentType
        //     )

        //     let uploadRequest = DocumentUploadRequest(
        //         installmentOrderId: installmentOrderId,
        //         documents: [documentFile]
        //     )

        //     let response = try await apiService.uploadDocumentsAsync(uploadRequest)

        //     await MainActor.run {
        //         if response.success, let uploadedDocs = response.uploadedDocuments {
        //             checkoutState.uploadedDocuments.append(contentsOf: uploadedDocs)
        //             return true
        //         } else {
        //             checkoutState.errorMessage = response.message ?? "Failed to upload document"
        //             return false
        //         }
        //     }
        // } catch {
        //     await MainActor.run {
        //         checkoutState.errorMessage = "Failed to upload document: \(error.localizedDescription)"
        //     }
        //     return false
        // }

        return false
    }

    private func createInstallmentOrderRequest() -> CreateInstallmentOrderRequest {
        guard let customerInfo = checkoutState.customerInfo,
              let firstInstallmentItem = cartManager.items.first(where: { $0.installmentPlan != nil }),
              let installmentPlan = firstInstallmentItem.installmentPlan else {
            fatalError("Missing required data for installment order creation")
        }

        return CreateInstallmentOrderRequest(
            customer: CustomerInfoRequest(
                name: customerInfo.fullName,
                email: customerInfo.email,
                phone: customerInfo.phone
            ),
            productId: firstInstallmentItem.productId,
            productName: firstInstallmentItem.name,
            productSku: firstInstallmentItem.sku,
            sellerId: firstInstallmentItem.sellerId,
            sellerName: firstInstallmentItem.sellerName,
            planId: installmentPlan.planId,
            planName: installmentPlan.planName,
            quantity: firstInstallmentItem.quantity,
            unitPrice: firstInstallmentItem.price,
            totalPrice: firstInstallmentItem.total,
            downPaymentAmount: installmentPlan.downPayment,
            monthlyAmount: installmentPlan.monthlyPayment,
            totalAmount: installmentPlan.totalAmount,
            processingFee: installmentPlan.processingFee
        )
    }

    private func mimeTypeForFile(_ fileName: String) -> String {
        let fileExtension = (fileName as NSString).pathExtension.lowercased()
        switch fileExtension {
        case "jpg", "jpeg": return "image/jpeg"
        case "png": return "image/png"
        case "pdf": return "application/pdf"
        case "doc": return "application/msword"
        case "docx": return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        default: return "application/octet-stream"
        }
    }
}