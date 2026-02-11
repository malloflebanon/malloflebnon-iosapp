import SwiftUI
import Combine

// MARK: - Seller Info Header Component

struct SellerInfoHeader: View {
    let auctionId: String

    @StateObject private var vendorService = VendorService.shared
    @State private var vendor: Vendor?
    @State private var isLoading = true
    @State private var cancellables = Set<AnyCancellable>()

    var body: some View {
        HStack(spacing: 12) {
            // Seller Profile Image (Placeholder)
            sellerProfileImage

            // Seller Info Section
            VStack(alignment: .leading, spacing: 2) {
                // Seller Name
                sellerNameView

                // Rating Section
                ratingView

                // Shipping Info
                shippingView

                // Follow Button
                followButton
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.7))
                .blur(radius: 8)
        )
        .onAppear {
            loadVendorData()
        }
    }

    // MARK: - Seller Profile Image

    private var sellerProfileImage: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 60, height: 60)
            .overlay(
                // Placeholder icon
                Image(systemName: "person.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
            )
            .shadow(radius: 4)
    }

    // MARK: - Seller Name

    private var sellerNameView: some View {
        Group {
            if isLoading {
                // Loading placeholder
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 120, height: 16)
            } else {
                HStack(spacing: 4) {
                    Text(vendor?.displayName ?? "Unknown Seller")
                        .font(.system(.headline, design: .default).weight(.bold))
                        .foregroundColor(.white)

                    // Verification badge
                    if vendor?.isVerified == true {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
            }
        }
    }

    // MARK: - Rating Section

    private var ratingView: some View {
        HStack(spacing: 4) {
            if isLoading {
                // Loading placeholder
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 60, height: 14)
            } else {
                // Star icon
                Image(systemName: "star.fill")
                    .font(.caption)
                    .foregroundColor(.yellow)

                // Rating number
                Text(String(format: "%.1f", vendor?.displayRating ?? 0.0))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)

                // Review count (optional)
                if let vendor = vendor, vendor.hasReviews {
                    Text("(\(vendor.stats.totalReviews))")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
    }

    // MARK: - Shipping Info

    private var shippingView: some View {
        HStack(spacing: 4) {
            // Truck icon
            Image(systemName: "shippingbox.fill")
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))

            // Shipping days (hardcoded as requested)
            Text("3d")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white)
        }
    }

    // MARK: - Follow Button

    private var followButton: some View {
        Button(action: {
            // TODO: Implement follow functionality
            print("🔔 [SellerInfoHeader] Follow button tapped for vendor: \(vendor?.displayName ?? "Unknown")")
        }) {
            Text("Follow")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.black)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.yellow)
                )
        }
    }

    // MARK: - Data Loading

    private func loadVendorData() {
        print("🏪 [SellerInfoHeader] Loading vendor data for auction: \(auctionId)")

        isLoading = true

        vendorService.fetchVendorByAuction(auctionId: auctionId)
            .sink(
                receiveCompletion: { completion in
                    DispatchQueue.main.async {
                        self.isLoading = false
                        switch completion {
                        case .finished:
                            print("✅ [SellerInfoHeader] Successfully loaded vendor data")
                        case .failure(let error):
                            print("❌ [SellerInfoHeader] Failed to load vendor: \(error)")
                            // Show placeholder data or error state
                            self.vendor = nil
                        }
                    }
                },
                receiveValue: { vendor in
                    DispatchQueue.main.async {
                        print("🎯 [SellerInfoHeader] Received vendor: \(vendor.businessName)")
                        self.vendor = vendor
                        self.isLoading = false
                    }
                }
            )
            .store(in: &cancellables)
    }
}

// MARK: - Preview

struct SellerInfoHeader_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            SellerInfoHeader(auctionId: "sample-auction-id")
                .padding()
        }
        .previewDisplayName("Seller Info Header")
    }
}