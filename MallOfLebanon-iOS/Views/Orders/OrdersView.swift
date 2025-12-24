import SwiftUI

struct OrdersView: View {
    @StateObject private var viewModel = OrdersViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                if viewModel.isLoading {
                    VStack {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Loading orders...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 8)
                    }
                } else if viewModel.orders.isEmpty {
                    EmptyOrdersView()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(viewModel.orders, id: \.id) { order in
                                OrderCardView(
                                    order: order,
                                    viewModel: viewModel
                                )
                                .padding(.horizontal, 16)
                                .onAppear {
                                    print("🔍 [DEBUG] Displaying order: \(order.id) - \(order.orderNumber)")
                                }
                            }
                        }
                        .padding(.top, 16)
                        .padding(.bottom, 32)
                    }
                    .onAppear {
                        print("🔍 [DEBUG] OrdersView rendering \(viewModel.orders.count) orders")
                    }
                    .refreshable {
                        viewModel.refreshOrders()
                    }
                }
            }
            .navigationTitle("My Orders")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarBackButtonHidden()
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
            }
            .alert("Error", isPresented: $viewModel.showErrorAlert) {
                Button("OK") {
                    viewModel.clearError()
                }
                Button("Retry") {
                    viewModel.refreshOrders()
                }
            } message: {
                Text(viewModel.errorMessage ?? "Unknown error occurred")
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

struct OrderCardView: View {
    let order: Order
    let viewModel: OrdersViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with order number and status
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(order.orderNumber)
                        .font(.headline)
                        .fontWeight(.semibold)

                    Text("Ordered on \(viewModel.formatOrderDate(order.orderDate))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Status Badge
                if let status = order.status {
                    Text(status.displayName(for: order.deliveryMethod))
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(viewModel.getStatusColor(for: status).opacity(0.1))
                        .foregroundColor(viewModel.getStatusColor(for: status))
                        .cornerRadius(12)
                }
            }

            // Order Items
            if let items = order.items {
                VStack(spacing: 12) {
                    ForEach(items) { item in
                        OrderItemRowView(item: item)
                    }
                }
            }

            // Delivery Information
            if let deliveryMethod = order.deliveryMethod {
                HStack {
                    Image(systemName: deliveryMethod.icon)
                        .foregroundColor(.blue)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(deliveryMethod.title)
                            .font(.subheadline)
                            .fontWeight(.medium)

                        if deliveryMethod == .homeDelivery,
                           let shippingAddress = order.shippingAddress {
                            Text("\(shippingAddress.address), \(shippingAddress.city)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()

                    if order.status != .delivered && order.status != .cancelled {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Est. delivery")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(viewModel.getEstimatedDeliveryDate(for: order))
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }

            // Payment Information
            if let paymentMethod = order.paymentMethod,
               let deliveryMethod = order.deliveryMethod {
                HStack {
                    Image(systemName: "creditcard")
                        .foregroundColor(.green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Payment Method")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(paymentMethod.title(for: deliveryMethod))
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }

            // Order Summary
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Order Total")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Text(viewModel.formatPrice(order.totalAmount))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }

                if let itemsCount = order.items?.count, itemsCount > 0 {
                    HStack {
                        Text("\(viewModel.getTotalItemsCount(for: order)) item(s)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

struct OrderItemRowView: View {
    let item: OrderItem

    var body: some View {
        HStack(spacing: 12) {
            // Product Image
            AsyncImage(url: URL(string: item.image ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray5))
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.secondary)
                    )
            }
            .frame(width: 60, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Product Details
            VStack(alignment: .leading, spacing: 4) {
                Text(item.productName ?? "Unknown Product")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)

                if let sellerName = item.sellerName {
                    Text("by \(sellerName)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Qty: \(item.quantity ?? 0)")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    Text(formatPrice(item.price))
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }

            Spacer()

            // Total Price
            Text(formatPrice(item.total))
                .font(.subheadline)
                .fontWeight(.semibold)
        }
    }

    private func formatPrice(_ price: Double?) -> String {
        guard let price = price else { return "$0.00" }
        return String(format: "$%.2f", price)
    }
}

struct EmptyOrdersView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "bag")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            VStack(spacing: 8) {
                Text("No Orders Yet")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("When you place orders, they will appear here.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button("Start Shopping") {
                // This would navigate back to the main store
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(32)
    }
}

#Preview {
    OrdersView()
}