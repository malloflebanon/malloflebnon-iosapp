import SwiftUI

struct CartConflictModal: View {
    let conflictInfo: CartConflictInfo
    let isBuyNow: Bool
    let onClearCartAndAdd: () -> Void
    let onContinueToCheckout: () -> Void
    let onCancel: () -> Void

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background overlay
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        onCancel()
                    }

                // Modal content
                VStack(spacing: 0) {
                    modalContent
                }
                .background(Color.white)
                .cornerRadius(16)
                .padding(.horizontal, 20)
                .frame(maxWidth: min(400, geometry.size.width - 40))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: true)
    }

    private var modalContent: some View {
        VStack(spacing: 0) {
            // Header
            header

            // Content
            content

            // Actions
            actions
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Cart Payment Type Conflict")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                Spacer()

                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .foregroundColor(.gray)
                        .font(.system(size: 16, weight: .medium))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            Divider()
                .padding(.horizontal, 20)
        }
    }

    private var content: some View {
        VStack(spacing: 16) {
            // Warning icon
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundColor(.orange)
                .padding(.top, 16)

            // Conflict message
            VStack(spacing: 12) {
                Text("Your cart currently contains **\(conflictInfo.currentCartType.displayName)** items, but you're trying to add an **\(conflictInfo.attemptingToAdd.displayName)** item.")
                    .multilineTextAlignment(.center)
                    .font(.body)
                    .foregroundColor(.primary)

                Text("To maintain order clarity, you cannot mix different payment methods in the same order.")
                    .multilineTextAlignment(.center)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)

            // Conflict details
            VStack(spacing: 12) {
                HStack {
                    Text("Current Cart:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Spacer()

                    Text(conflictInfo.currentCartType.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(currentCartTypeColor.opacity(0.15))
                        .foregroundColor(currentCartTypeColor)
                        .cornerRadius(8)
                }

                HStack {
                    Text("Trying to Add:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Spacer()

                    Text(conflictInfo.attemptingToAdd.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(attemptingCartTypeColor.opacity(0.15))
                        .foregroundColor(attemptingCartTypeColor)
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color(UIColor.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal, 20)
        }
    }

    private var actions: some View {
        VStack(spacing: 16) {
            Text("What would you like to do?")
                .font(.headline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .padding(.top, 20)

            VStack(spacing: 12) {
                // Complete current order first
                actionButton(
                    icon: "cart.fill",
                    title: "Complete Current Order First",
                    description: "Proceed to checkout with your current \(conflictInfo.currentCartType.displayName.lowercased()) items, then come back to add the new item.",
                    backgroundColor: .blue,
                    action: onContinueToCheckout
                )

                // Or divider
                HStack {
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(.gray.opacity(0.3))

                    Text("OR")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.horizontal, 8)

                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(.gray.opacity(0.3))
                }
                .padding(.vertical, 8)

                // Clear cart and add new item
                actionButton(
                    icon: "arrow.triangle.2.circlepath",
                    title: isBuyNow ? "Clear Cart & Buy Now" : "Clear Cart & Add New Item",
                    description: isBuyNow
                        ? "Remove all current items and proceed to checkout with this \(conflictInfo.attemptingToAdd.displayName.lowercased()) item."
                        : "Remove all current items and add this new \(conflictInfo.attemptingToAdd.displayName.lowercased()) item instead.",
                    backgroundColor: .orange,
                    action: onClearCartAndAdd
                )

                // Or divider
                HStack {
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(.gray.opacity(0.3))

                    Text("OR")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.horizontal, 8)

                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(.gray.opacity(0.3))
                }
                .padding(.vertical, 8)

                // Cancel and keep current cart
                actionButton(
                    icon: "xmark.circle",
                    title: "Cancel & Keep Current Cart",
                    description: "Don't add the new item and keep your current cart as is.",
                    backgroundColor: .gray,
                    action: onCancel
                )
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }

    private func actionButton(
        icon: String,
        title: String,
        description: String,
        backgroundColor: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 24, height: 24)

                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)

                    Spacer()
                }

                Text(description)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.leading)
                    .lineLimit(nil)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(backgroundColor)
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var currentCartTypeColor: Color {
        switch conflictInfo.currentCartType {
        case .normal:
            return .green
        case .installment:
            return .blue
        case .empty:
            return .gray
        }
    }

    private var attemptingCartTypeColor: Color {
        switch conflictInfo.attemptingToAdd {
        case .normal:
            return .green
        case .installment:
            return .blue
        case .empty:
            return .gray
        }
    }
}

// MARK: - Preview
struct CartConflictModal_Previews: PreviewProvider {
    static var previews: some View {
        CartConflictModal(
            conflictInfo: CartConflictInfo(
                hasConflict: true,
                currentCartType: .normal,
                attemptingToAdd: .installment
            ),
            isBuyNow: false,
            onClearCartAndAdd: {
                print("Clear cart and add")
            },
            onContinueToCheckout: {
                print("Continue to checkout")
            },
            onCancel: {
                print("Cancel")
            }
        )
        .background(Color.blue.opacity(0.3))
    }
}