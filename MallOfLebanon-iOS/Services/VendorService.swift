import Foundation
import Combine

class VendorService: ObservableObject {
    static let shared = VendorService()

    private let baseURL = "https://malloflebanon.com/api"
    private let session = URLSession.shared

    @Published var isLoading = false
    @Published var error: String?

    private init() {}

    // MARK: - Public Methods

    func fetchVendor(vendorId: String) -> AnyPublisher<Vendor, Error> {
        guard !vendorId.isEmpty else {
            return Fail(error: VendorServiceError.invalidVendorId)
                .eraseToAnyPublisher()
        }

        let url = URL(string: "\(baseURL)/vendors/\(vendorId)")!

        print("🏪 [VendorService] Fetching vendor: \(vendorId)")
        print("🌐 [VendorService] URL: \(url)")

        return session.dataTaskPublisher(for: url)
            .map(\.data)
            .decode(type: VendorResponse.self, decoder: JSONDecoder())
            .map { response in
                print("✅ [VendorService] Successfully fetched vendor: \(response.data.businessName)")
                print("⭐ [VendorService] Rating: \(response.data.stats.averageRating)/5 (\(response.data.stats.totalReviews) reviews)")
                return response.data
            }
            .catch { error in
                print("❌ [VendorService] Error fetching vendor: \(error)")
                return Fail(error: error)
            }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    func fetchVendorByAuction(auctionId: String) -> AnyPublisher<Vendor, Error> {
        // For now, we'll need to determine vendor ID from auction data
        // This might require additional API calls or auction data structure
        // For demo purposes, using a placeholder vendor ID

        print("🎯 [VendorService] Fetching vendor for auction: \(auctionId)")

        // TODO: Implement proper auction -> vendor mapping
        // For now, using a demo vendor ID
        let demoVendorId = "60d5ec49f1a2c8b1f8b4c8a1" // Replace with actual mapping

        return fetchVendor(vendorId: demoVendorId)
    }
}

// MARK: - Error Types

enum VendorServiceError: Error, LocalizedError {
    case invalidVendorId
    case vendorNotFound
    case networkError(String)
    case decodingError(String)

    var errorDescription: String? {
        switch self {
        case .invalidVendorId:
            return "Invalid vendor ID provided"
        case .vendorNotFound:
            return "Vendor not found"
        case .networkError(let message):
            return "Network error: \(message)"
        case .decodingError(let message):
            return "Data parsing error: \(message)"
        }
    }
}

// MARK: - Extensions

extension VendorService {
    func clearError() {
        error = nil
    }

    func setLoading(_ loading: Bool) {
        isLoading = loading
    }
}