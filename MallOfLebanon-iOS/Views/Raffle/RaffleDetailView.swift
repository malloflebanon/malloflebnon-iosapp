import SwiftUI

struct RaffleDetailView: View {
    let raffle: Raffle
    @EnvironmentObject var cartManager: CartManager
    @Environment(\.presentationMode) var presentationMode

    @State private var selectedProductIndex = 0
    @State private var showingTicketConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Prize Image and Info
                prizeSection

                // Raffle Details
                raffleDetailsSection

                // Progress Section
                progressSection

                // Entry Options
                entryOptionsSection

                // Terms & Rules
                termsSection
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100) // Space for buy button
        }
        .navigationTitle(raffle.title)
        .navigationBarTitleDisplayMode(.large)
        .overlay(alignment: .bottom) {
            buyTicketButton
        }
        .alert("Ticket Added!", isPresented: $showingTicketConfirmation) {
            Button("View Cart") {
                presentationMode.wrappedValue.dismiss()
                // Navigate to cart - this would need to be handled by parent view
            }
            Button("Continue Shopping", role: .cancel) {}
        } message: {
            Text("Your raffle ticket has been added to cart. Good luck!")
        }
    }

    private var prizeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Prize Image
            ZStack {
                CachedImageView(
                    url: URL(string: raffle.prizeImage),
                    placeholder: {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.gray.opacity(0.3))
                            .overlay(ProgressView().scaleEffect(1.2))
                    },
                    failureView: {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.blue.opacity(0.1))
                            .overlay(
                                VStack {
                                    Image(systemName: "gift.fill")
                                        .font(.system(size: 60))
                                        .foregroundColor(.blue)
                                    Text("Prize")
                                        .font(.title2)
                                        .foregroundColor(.blue)
                                }
                            )
                    }
                )
                .aspectRatio(1.5, contentMode: .fit)
                .clipped()
                .cornerRadius(16)

                // Floating Prize Badge
                VStack {
                    HStack {
                        Spacer()
                        HStack(spacing: 6) {
                            Image(systemName: "crown.fill")
                                .foregroundColor(.yellow)
                            Text("GRAND PRIZE")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.8))
                        )
                    }
                    Spacer()
                }
                .padding(12)
            }

            // Prize Value
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Prize Value")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    HStack {
                        Text(raffle.prizeCurrency)
                            .font(.title3)
                            .foregroundColor(.secondary)
                        Text(raffle.formattedPrizeValue)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 4)
        }
    }

    private var raffleDetailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("About This Raffle")
                .font(.headline)
                .fontWeight(.semibold)

            Text(raffle.description)
                .font(.body)
                .foregroundColor(.primary)

            // Key Details Grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                DetailCard(
                    icon: "clock.fill",
                    title: "Time Left",
                    value: raffle.timeLeftText,
                    color: .orange
                )

                DetailCard(
                    icon: "ticket.fill",
                    title: "Tickets Sold",
                    value: "\(raffle.currentTickets)/\(raffle.maxTickets)",
                    color: .blue
                )

                DetailCard(
                    icon: "calendar",
                    title: "Draw Date",
                    value: formatDrawDate(raffle.drawDate),
                    color: .purple
                )

                DetailCard(
                    icon: "person.3.fill",
                    title: "Participants",
                    value: "~\(raffle.currentTickets)",
                    color: .green
                )
            }
        }
    }

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Progress")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(raffle.percentageSold)% Complete")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
            }

            // Large Progress Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 12)

                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.blue,
                                    Color.purple,
                                    Color.pink
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(
                            width: geometry.size.width * (CGFloat(raffle.percentageSold) / 100.0),
                            height: 12
                        )
                        .animation(.easeInOut(duration: 0.5), value: raffle.percentageSold)
                }
            }
            .frame(height: 12)

            HStack {
                Text("\(raffle.currentTickets) sold")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(raffle.maxTickets - raffle.currentTickets) remaining")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var entryOptionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Entry Options")
                .font(.headline)
                .fontWeight(.semibold)

            if raffle.products.isEmpty {
                Text("No entry options available at the moment.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
            } else {
                VStack(spacing: 12) {
                    ForEach(Array(raffle.products.enumerated()), id: \.offset) { index, product in
                        EntryOptionCard(
                            product: product,
                            isSelected: selectedProductIndex == index,
                            onSelect: {
                                selectedProductIndex = index
                            }
                        )
                    }
                }
            }
        }
    }

    private var termsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Rules & Terms")
                .font(.headline)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 8) {
                RuleItem(text: "Must be 18+ to participate")
                RuleItem(text: "One entry per ticket purchased")
                RuleItem(text: "Winner will be randomly selected")
                RuleItem(text: "Winner has 7 days to claim prize")
                RuleItem(text: "No cash alternative available")
                RuleItem(text: "See full terms and conditions")
            }
            .padding()
            .background(Color.blue.opacity(0.05))
            .cornerRadius(12)
        }
    }

    private var buyTicketButton: some View {
        VStack(spacing: 0) {
            // Gradient overlay to fade content
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(.systemBackground).opacity(0),
                    Color(.systemBackground)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 20)

            // Button area
            HStack {
                if let selectedProduct = raffle.products.indices.contains(selectedProductIndex) ? raffle.products[selectedProductIndex] : nil {
                    Button(action: {
                        handleBuyTicket(product: selectedProduct)
                    }) {
                        HStack {
                            Image(systemName: "gift.fill")
                                .font(.title3)
                                .foregroundColor(.white)
                            Text("Buy Entry Ticket")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                            Spacer()
                            Text("$\(selectedProduct.formattedPrice)")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.blue,
                                    Color.purple
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(16)
                        .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .disabled(!raffle.isActive || raffle.currentTickets >= raffle.maxTickets)
                    .opacity((raffle.isActive && raffle.currentTickets < raffle.maxTickets) ? 1.0 : 0.6)
                } else {
                    Button(action: {}) {
                        Text("No Entry Options Available")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.gray)
                            .cornerRadius(16)
                    }
                    .disabled(true)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 34) // Account for safe area
        }
        .background(Color(.systemBackground))
    }

    private func handleBuyTicket(product: RaffleProduct) {
        guard raffle.isActive && raffle.currentTickets < raffle.maxTickets else {
            return
        }

        // Create raffle product and add to cart
        if let raffleProduct = RaffleService.shared.createRaffleProduct(from: raffle) {
            cartManager.addProduct(raffleProduct, quantity: 1)
            showingTicketConfirmation = true

            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()

            print("🎫 Added raffle ticket for '\(raffle.title)' to cart from detail view")
        }
    }

    private func formatDrawDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        guard let date = formatter.date(from: dateString) else {
            return "TBD"
        }

        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        displayFormatter.timeStyle = .short
        return displayFormatter.string(from: date)
    }
}

// MARK: - Supporting Views

struct DetailCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

struct EntryOptionCard: View {
    let product: RaffleProduct
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Product Image
                CachedImageView(
                    url: URL(string: product.mainImage),
                    placeholder: {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.3))
                            .overlay(ProgressView().scaleEffect(0.6))
                    },
                    failureView: {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.blue.opacity(0.1))
                            .overlay(
                                Image(systemName: "ticket.fill")
                                    .foregroundColor(.blue)
                            )
                    }
                )
                .frame(width: 50, height: 50)
                .cornerRadius(8)

                // Product Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    Text("$\(product.formattedPrice)")
                        .font(.caption)
                        .foregroundColor(.green)
                        .fontWeight(.semibold)
                }

                Spacer()

                // Selection Indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .gray)
                    .font(.title3)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color.gray.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct RuleItem: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.caption)
                .foregroundColor(.green)
                .padding(.top, 2)

            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()
        }
    }
}

#Preview {
    NavigationView {
        RaffleDetailView(raffle: Raffle.sampleRaffles[0])
            .environmentObject(CartManager.shared)
    }
}