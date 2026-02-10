import SwiftUI

struct RaffleCard: View {
    let raffle: Raffle
    let onBuyTicket: () -> Void

    @State private var showingDetail = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Prize Image Section
            prizeImageSection

            // Content Section
            raffleInfoSection

            // Action Section
            actionSection
        }
        .padding(20)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(.systemBackground),
                    Color.blue.opacity(0.02)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.blue.opacity(0.3),
                            Color.purple.opacity(0.2)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }

    private var prizeImageSection: some View {
        ZStack {
            // Prize Image
            CachedImageView(
                url: URL(string: raffle.prizeImage),
                placeholder: {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            ProgressView()
                                .scaleEffect(0.8)
                        )
                },
                failureView: {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.blue.opacity(0.1))
                        .overlay(
                            VStack {
                                Image(systemName: "gift.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.blue)
                                Text("Prize")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        )
                }
            )
            .aspectRatio(contentMode: .fill)
            .frame(height: 180)
            .clipped()
            .cornerRadius(12)

            // Prize Badge
            VStack {
                HStack {
                    Spacer()
                    prizeBadge
                }
                Spacer()
            }
            .padding(8)

            // Glow Effect Overlay
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.yellow.opacity(0.1),
                            Color.clear,
                            Color.purple.opacity(0.1)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .sheet(isPresented: $showingDetail) {
            NavigationView {
                RaffleDetailView(raffle: raffle)
            }
        }
    }

    private var prizeBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "crown.fill")
                .font(.caption)
                .foregroundColor(.yellow)
            Text("PRIZE")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.7))
        )
    }

    private var raffleInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title
            Text(raffle.title)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .lineLimit(2)

            // Prize Value
            HStack {
                Text(raffle.prizeCurrency)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                Text(raffle.formattedPrizeValue)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
                Text("VALUE")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                Spacer()
            }

            // Stats Row
            HStack {
                // Time Left
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "clock.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Text(raffle.timeLeftText)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.orange)
                    }
                    Text("Time Left")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Tickets Progress
                VStack(alignment: .trailing, spacing: 4) {
                    Text(raffle.progressText)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                    Text("\(raffle.percentageSold)% Sold")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            // Progress Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.blue,
                                    Color.purple
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(
                            width: geometry.size.width * (CGFloat(raffle.percentageSold) / 100.0),
                            height: 6
                        )
                        .animation(.easeInOut(duration: 0.3), value: raffle.percentageSold)
                }
            }
            .frame(height: 6)
        }
    }

    private var actionSection: some View {
        VStack(spacing: 8) {
            // Entry Products Info
            if raffle.productCount > 0 {
                HStack {
                    Image(systemName: "ticket.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Text("\(raffle.productCount) entry option\(raffle.productCount > 1 ? "s" : "") available")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }

            // Action Buttons
            HStack(spacing: 8) {
                Button(action: {
                    showingDetail = true
                }) {
                    HStack {
                        Image(systemName: "info.circle")
                            .font(.subheadline)
                        Text("Details")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.blue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }

                Button(action: onBuyTicket) {
                    HStack {
                        Image(systemName: "gift.fill")
                            .font(.subheadline)
                            .foregroundColor(.white)
                        Text("Enter Raffle")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        if let product = raffle.products.first {
                            Text("$\(product.formattedPrice)")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
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
                    .cornerRadius(10)
                }
                .disabled(!raffle.isActive || raffle.currentTickets >= raffle.maxTickets)
                .opacity((raffle.isActive && raffle.currentTickets < raffle.maxTickets) ? 1.0 : 0.6)
            }
        }
    }
}

// MARK: - Compact Raffle Card (for horizontal scrolls)

struct RaffleCardCompact: View {
    let raffle: Raffle
    let onBuyTicket: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Prize Image
            CachedImageView(
                url: URL(string: raffle.prizeImage),
                placeholder: {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))
                        .overlay(ProgressView().scaleEffect(0.6))
                },
                failureView: {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue.opacity(0.1))
                        .overlay(
                            Image(systemName: "gift.fill")
                                .foregroundColor(.blue)
                                .font(.title3)
                        )
                }
            )
            .aspectRatio(contentMode: .fill)
            .frame(height: 100)
            .clipped()
            .cornerRadius(8)

            // Info
            VStack(alignment: .leading, spacing: 6) {
                Text(raffle.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(2)

                Text("\(raffle.prizeCurrency)\(raffle.formattedPrizeValue)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.green)

                Text(raffle.timeLeftText)
                    .font(.caption2)
                    .foregroundColor(.orange)
            }

            // Button
            Button(action: onBuyTicket) {
                Text("Enter")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(Color.blue)
                    .cornerRadius(6)
            }
        }
        .padding(12)
        .frame(width: 140)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 16) {
            RaffleCard(raffle: Raffle.sampleRaffles[0]) {
                print("Buy ticket tapped")
            }

            HStack {
                RaffleCardCompact(raffle: Raffle.sampleRaffles[0]) {
                    print("Compact buy ticket tapped")
                }
                RaffleCardCompact(raffle: Raffle.sampleRaffles[1]) {
                    print("Compact buy ticket 2 tapped")
                }
                Spacer()
            }
        }
        .padding()
    }
}