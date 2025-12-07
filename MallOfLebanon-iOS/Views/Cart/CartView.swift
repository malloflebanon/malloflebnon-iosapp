import SwiftUI

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
            CheckoutView()
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
                // Subtotal
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

                // Total
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
            AsyncImage(url: URL(string: item.image)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.gray)
                    )
            }
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

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var address = ""
    @State private var city = ""
    @State private var country = ""
    @State private var postalCode = ""
    @State private var phone = ""
    @State private var paymentMethod = "Credit Card"
    @State private var notes = ""

    @State private var isProcessing = false
    @State private var showingError = false
    @State private var errorMessage = ""

    private let paymentMethods = ["Credit Card", "Debit Card", "PayPal", "Apple Pay"]

    var body: some View {
        NavigationView {
            Form {
                Section("Shipping Address") {
                    TextField("First Name", text: $firstName)
                    TextField("Last Name", text: $lastName)
                    TextField("Address", text: $address)
                    TextField("City", text: $city)
                    TextField("Country", text: $country)
                    TextField("Postal Code", text: $postalCode)
                    TextField("Phone (optional)", text: $phone)
                }

                Section("Payment Method") {
                    Picker("Payment Method", selection: $paymentMethod) {
                        ForEach(paymentMethods, id: \.self) { method in
                            Text(method).tag(method)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }

                Section("Order Notes") {
                    if #available(iOS 16.0, *) {
                        TextField("Special instructions (optional)", text: $notes, axis: .vertical)
                            .lineLimit(3...6)
                    } else {
                        TextField("Special instructions (optional)", text: $notes)
                            .lineLimit(3)
                    }
                }

                Section("Order Summary") {
                    ForEach(cartManager.cart.items) { item in
                        HStack {
                            Text(item.name)
                            Spacer()
                            Text("\(item.quantity) × $\(String(format: "%.2f", item.price))")
                                .foregroundColor(.secondary)
                        }
                    }

                    Divider()

                    HStack {
                        Text("Total")
                            .fontWeight(.bold)
                        Spacer()
                        Text("$\(String(format: "%.2f", cartManager.cart.subtotal))")
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                    }
                }
            }
            .navigationTitle("Checkout")
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Place Order") {
                    placeOrder()
                }
                .disabled(isProcessing || !isFormValid)
            )
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    private var isFormValid: Bool {
        !firstName.isEmpty && !lastName.isEmpty && !address.isEmpty && !city.isEmpty && !country.isEmpty
    }

    private func placeOrder() {
        isProcessing = true

        let shippingAddress = ShippingAddress(
            firstName: firstName,
            lastName: lastName,
            address: address,
            city: city,
            country: country,
            postalCode: postalCode.isEmpty ? nil : postalCode,
            phone: phone.isEmpty ? nil : phone
        )

        let checkoutItems = cartManager.cart.items.map { item in
            CheckoutItem(
                productId: item.productId,
                sellerId: item.sellerId,
                quantity: item.quantity,
                price: item.price,
                customizations: item.customizations
            )
        }

        let _ = CheckoutRequest(
            items: checkoutItems,
            shippingAddress: shippingAddress,
            paymentMethod: paymentMethod,
            notes: notes.isEmpty ? nil : notes
        )

        // TODO: Implement actual checkout API call
        // For now, simulate success after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.isProcessing = false
            // Clear cart and dismiss
            self.cartManager.clearCart()
            self.presentationMode.wrappedValue.dismiss()
        }
    }
}

struct CartView_Previews: PreviewProvider {
    static var previews: some View {
        CartView()
            .environmentObject(CartManager.shared)
    }
}