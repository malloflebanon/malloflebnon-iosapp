import Foundation
import SwiftUI
import Combine

@MainActor
class OrdersViewModel: ObservableObject {
    @Published var orders: [Order] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showErrorAlert = false

    private let apiService = APIService.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        loadOrders()
    }

    func loadOrders() {
        isLoading = true
        errorMessage = nil

        apiService.getOrders()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false

                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                        self?.showErrorAlert = true
                        print("❌ Failed to load orders: \(error.localizedDescription)")
                    }
                },
                receiveValue: { [weak self] response in
                    if response.success {
                        let orders = response.orders

                        // Debug: Print detailed order information
                        print("🔍 [DEBUG] Loaded \(orders.count) orders:")
                        for (index, order) in orders.enumerated() {
                            print("🔍 [DEBUG] Order \(index + 1):")
                            print("  - ID: \(order.id)")
                            print("  - Order Number: \(order.orderNumber)")
                            print("  - Delivery Method: \(order.deliveryMethod?.rawValue ?? "nil")")
                            print("  - Payment Method: \(order.paymentMethod?.rawValue ?? "nil")")
                            print("  - Status: \(order.status?.rawValue ?? "nil")")
                            print("  - Date: \(order.orderDate ?? "nil")")

                            if let deliveryMethod = order.deliveryMethod, let paymentMethod = order.paymentMethod {
                                print("  - Payment Display: \(paymentMethod.title(for: deliveryMethod))")
                            }
                        }

                        // Check for duplicate IDs
                        let orderIDs = orders.map { $0.id }
                        let uniqueIDs = Set(orderIDs)
                        print("🔍 [DEBUG] Order IDs: \(orderIDs)")
                        print("🔍 [DEBUG] Unique IDs count: \(uniqueIDs.count), Total orders: \(orders.count)")
                        if uniqueIDs.count != orders.count {
                            print("⚠️ [WARNING] Duplicate order IDs detected!")
                        }

                        self?.orders = orders.sorted { order1, order2 in
                            guard let date1 = order1.orderDate,
                                  let date2 = order2.orderDate else {
                                return false
                            }
                            return date1 > date2
                        }
                        print("✅ Successfully loaded \(orders.count) orders")
                    } else {
                        self?.errorMessage = "Failed to load orders"
                        self?.showErrorAlert = true
                        print("❌ API error: Failed to load orders")
                    }
                }
            )
            .store(in: &cancellables)
    }

    func refreshOrders() {
        loadOrders()
    }

    func clearError() {
        errorMessage = nil
        showErrorAlert = false
    }

    // Helper computed properties
    var hasOrders: Bool {
        return !orders.isEmpty
    }

    var pendingOrdersCount: Int {
        return orders.filter { $0.status == .pending }.count
    }

    var recentOrders: [Order] {
        return Array(orders.prefix(5))
    }

    // Format order date for display
    func formatOrderDate(_ dateString: String?) -> String {
        guard let dateString = dateString else { return "Unknown date" }

        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"

        if let date = inputFormatter.date(from: dateString) {
            let outputFormatter = DateFormatter()
            outputFormatter.dateFormat = "MMM dd, yyyy"
            return outputFormatter.string(from: date)
        }

        return dateString
    }

    // Calculate order total items count
    func getTotalItemsCount(for order: Order) -> Int {
        return order.items?.reduce(0) { $0 + ($1.quantity ?? 0) } ?? 0
    }

    // Format currency
    func formatPrice(_ price: Double?) -> String {
        guard let price = price else { return "$0.00" }
        return String(format: "$%.2f", price)
    }

    // Get order status color
    func getStatusColor(for status: OrderStatus?) -> Color {
        guard let status = status else { return .gray }

        switch status.color {
        case "orange": return .orange
        case "blue": return .blue
        case "purple": return .purple
        case "indigo": return .indigo
        case "green": return .green
        case "red": return .red
        default: return .gray
        }
    }

    // Get estimated delivery date
    func getEstimatedDeliveryDate(for order: Order) -> String {
        guard let orderDateString = order.orderDate,
              let deliveryMethod = order.deliveryMethod else {
            return "Unknown"
        }

        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"

        if let orderDate = inputFormatter.date(from: orderDateString) {
            let estimatedDays = deliveryMethod.estimatedDays
            let deliveryDate = Calendar.current.date(byAdding: .day, value: estimatedDays, to: orderDate)

            let outputFormatter = DateFormatter()
            outputFormatter.dateFormat = "MMM dd"

            if let deliveryDate = deliveryDate {
                return outputFormatter.string(from: deliveryDate)
            }
        }

        return "Unknown"
    }
}