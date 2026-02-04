import SwiftUI

struct RaffleSection: View {
    @StateObject private var raffleService = RaffleService.shared
    @EnvironmentObject var cartManager: CartManager

    @State private var showingAllRaffles = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            sectionHeader

            // Raffles Content
            if raffleService.isLoading && raffleService.raffles.isEmpty {
                loadingView
            } else if raffleService.raffles.isEmpty {
                emptyStateView
            } else {
                rafflesContent
            }
        }
        .padding(.horizontal, 16)
        .onAppear {
            raffleService.loadRaffles()
        }
        .sheet(isPresented: $showingAllRaffles) {
            AllRafflesView()
                .environmentObject(cartManager)
        }
    }

    private var sectionHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "gift.fill")
                        .foregroundColor(.orange)
                        .font(.title3)
                    Text("Active Raffles")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                Text("Win amazing prizes with every purchase!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if raffleService.raffles.count > 1 {
                Button(action: {
                    showingAllRaffles = true
                }) {
                    Text("View All")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                }
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading amazing prizes...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "gift.fill")
                .font(.system(size: 40))
                .foregroundColor(.gray)
            Text("No Active Raffles")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("Check back soon for exciting new raffles!")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var rafflesContent: some View {
        VStack(spacing: 12) {
            // Featured raffle (first one)
            if let featuredRaffle = raffleService.raffles.first {
                RaffleCard(raffle: featuredRaffle) {
                    handleBuyTicket(for: featuredRaffle)
                }
            }

            // Additional raffles horizontally if more than 1
            if raffleService.raffles.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(Array(raffleService.raffles.dropFirst()), id: \.id) { raffle in
                            RaffleCardCompact(raffle: raffle) {
                                handleBuyTicket(for: raffle)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.horizontal, -16) // Offset section padding
            }
        }
    }

    private func handleBuyTicket(for raffle: Raffle) {
        guard raffle.isActive && raffle.currentTickets < raffle.maxTickets else {
            // Show alert for inactive or sold out raffle
            return
        }

        // Create a raffle product and add to cart
        if let raffleProduct = raffleService.createRaffleProduct(from: raffle) {
            cartManager.addProduct(raffleProduct, quantity: 1)

            // Provide haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()

            print("🎫 Added raffle ticket for '\(raffle.title)' to cart")
        } else {
            print("❌ Failed to create raffle product for '\(raffle.title)'")
        }
    }
}

// MARK: - All Raffles View (Modal Sheet)

struct AllRafflesView: View {
    @StateObject private var raffleService = RaffleService.shared
    @EnvironmentObject var cartManager: CartManager
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(raffleService.raffles, id: \.id) { raffle in
                        RaffleCard(raffle: raffle) {
                            handleBuyTicket(for: raffle)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("All Raffles")
            .navigationBarItems(
                trailing: Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
        .onAppear {
            if raffleService.raffles.isEmpty {
                raffleService.loadRaffles()
            }
        }
    }

    private func handleBuyTicket(for raffle: Raffle) {
        guard raffle.isActive && raffle.currentTickets < raffle.maxTickets else {
            return
        }

        if let raffleProduct = raffleService.createRaffleProduct(from: raffle) {
            cartManager.addProduct(raffleProduct, quantity: 1)

            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()

            print("🎫 Added raffle ticket for '\(raffle.title)' to cart")
        }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 20) {
            RaffleSection()
                .environmentObject(CartManager.shared)

            // Other content to show context
            VStack(alignment: .leading) {
                Text("Other Content")
                    .font(.title2)
                    .fontWeight(.bold)
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 200)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
        }
    }
}