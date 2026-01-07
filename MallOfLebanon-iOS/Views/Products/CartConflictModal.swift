import SwiftUI

struct CartConflictModal: View {
    let conflictInfo: CartConflictInfo
    let isBuyNow: Bool
    let onClearCartAndAdd: () -> Void
    let onContinueToCheckout: () -> Void
    let onCancel: () -> Void

    private var conflictingCartType: String {
        switch conflictInfo.cartType {
        case .regular:
            return "regular items"
        case .installment:
            return "installment items"
        case .empty:
            return "empty"
        }
    }

    private var attemptingToAddType: String {
        return isBuyNow ? "this item" : "new items"
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    onCancel()
                }

            VStack(spacing: 0) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.orange)

                    Text("Cart Conflict")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text(conflictInfo.message)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 24)
                .padding(.horizontal, 20)

                Divider()
                    .padding(.vertical, 20)

                // Details
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "cart.fill")
                            .foregroundColor(.blue)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Current Cart")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text("Contains \(conflictingCartType)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }

                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.orange)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Attempting to Add")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text(isBuyNow ? "Buy now with different payment method" : "Items with different payment method")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                }
                .padding(.horizontal, 20)

                Spacer(minLength: 20)

                // Action Buttons
                VStack(spacing: 12) {
                    // Primary action - Clear cart and add
                    Button(action: {
                        if isBuyNow {
                            onClearCartAndAdd() // This will handle buy now
                        } else {
                            onClearCartAndAdd()
                        }
                    }) {
                        HStack {
                            Image(systemName: "trash")
                            Text(isBuyNow ? "Clear Cart & Buy Now" : "Clear Cart & Add Items")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }

                    // Secondary action - Continue to checkout (only if not buy now and cart has items)
                    if !isBuyNow && conflictInfo.cartType != .empty {
                        Button(action: onContinueToCheckout) {
                            HStack {
                                Image(systemName: "creditcard")
                                Text("Continue to Checkout")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                    }

                    // Cancel action
                    Button(action: onCancel) {
                        Text("Cancel")
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemGray5))
                            .foregroundColor(.primary)
                            .cornerRadius(10)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
            .padding(.horizontal, 24)
        }
    }
}

// MARK: - Cart Conflict Actions
enum CartConflictAction {
    case clearCartAndAdd
    case clearCartAndBuyNow
    case continueToCheckout
    case cancel
}

#Preview {
    let sampleConflictInfo = CartConflictInfo(
        hasConflict: true,
        cartType: .regular,
        conflictingItem: nil,
        message: "Cannot mix regular and installment items in the same cart"
    )

    CartConflictModal(
        conflictInfo: sampleConflictInfo,
        isBuyNow: false,
        onClearCartAndAdd: { print("Clear cart and add") },
        onContinueToCheckout: { print("Continue to checkout") },
        onCancel: { print("Cancel") }
    )
}

#Preview("Buy Now Conflict") {
    let sampleConflictInfo = CartConflictInfo(
        hasConflict: true,
        cartType: .installment,
        conflictingItem: nil,
        message: "Cannot mix regular and installment items in the same cart"
    )

    CartConflictModal(
        conflictInfo: sampleConflictInfo,
        isBuyNow: true,
        onClearCartAndAdd: { print("Clear cart and buy now") },
        onContinueToCheckout: { print("Continue to checkout") },
        onCancel: { print("Cancel") }
    )
}