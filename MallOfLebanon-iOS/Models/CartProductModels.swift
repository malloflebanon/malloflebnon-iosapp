import Foundation

// MARK: - Cart Product Models for Product Detail View

struct CartProductItem {
    let product: Product
    let selectedCustomizations: [CustomizationSelection]
    let calculatedPrice: Double
}

struct CustomizationSelection: Codable {
    let customizationId: String
    let customizationName: String
    let optionId: String
    let optionLabel: String
    let optionValue: String
    let priceModifier: Double
}