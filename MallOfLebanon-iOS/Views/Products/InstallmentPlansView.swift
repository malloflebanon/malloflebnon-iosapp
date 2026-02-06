import SwiftUI

// Simple InstallmentPlan struct for UI purposes
struct SimpleInstallmentPlan: Identifiable {
    let id: String
    let planName: String
    let duration: Int
    let downPaymentPercentage: Double
    let interestRate: Double
    let minimumOrderAmount: Double
    let processingFeePercentage: Double
    let processingFeeFixed: Double?
    let description: String?

    func calculatePayments(orderAmount: Double) -> InstallmentCalculation {
        let downPayment = (orderAmount * downPaymentPercentage) / 100
        let remainingAmount = orderAmount - downPayment

        // Calculate processing fee - use fixed fee if available, otherwise percentage
        var processingFee = orderAmount * (processingFeePercentage / 100)
        if let fixedFee = processingFeeFixed {
            processingFee += fixedFee
        }

        // Calculate interest using frontend logic: annual rate / 12 months * duration
        var totalWithInterest = remainingAmount
        var totalInterest: Double = 0
        if interestRate > 0 {
            let monthlyRate = interestRate / 100 / 12
            totalInterest = remainingAmount * monthlyRate * Double(duration)
            totalWithInterest = remainingAmount + totalInterest
        }

        let monthlyPayment = totalWithInterest / Double(duration)
        let totalAmount = downPayment + totalWithInterest + processingFee

        return InstallmentCalculation(
            downPayment: round(downPayment * 100) / 100,
            monthlyPayment: round(monthlyPayment * 100) / 100,
            totalAmount: round(totalAmount * 100) / 100,
            totalInterest: round(totalInterest * 100) / 100,
            processingFee: round(processingFee * 100) / 100
        )
    }
}

struct InstallmentCalculation {
    let downPayment: Double
    let monthlyPayment: Double
    let totalAmount: Double
    let totalInterest: Double
    let processingFee: Double
}

struct InstallmentPlansView: View {
    let product: Product
    let calculatedPrice: Double
    @Binding var selectedInstallmentPlan: InstallmentPlanSelection?
    @Binding var showInstallmentPlans: Bool

    private var eligiblePlans: [SimpleInstallmentPlan] {
        // Get installment plans from product API data instead of hardcoded values
        guard let apiPlans = product.installmentPlans else {
            return []
        }

        return apiPlans.compactMap { planDict in
            // Extract values from the dictionary
            guard let id = planDict["id"] as? String,
                  let planName = planDict["planName"] as? String,
                  let duration = planDict["duration"] as? Int,
                  let isActive = planDict["isActive"] as? Bool else {
                return nil
            }

            // Handle numeric fields that could be Int or Double
            let downPaymentPercentage: Double = {
                if let doubleValue = planDict["downPaymentPercentage"] as? Double {
                    return doubleValue
                } else if let intValue = planDict["downPaymentPercentage"] as? Int {
                    return Double(intValue)
                }
                return 0.0
            }()

            let interestRate: Double = {
                if let doubleValue = planDict["interestRate"] as? Double {
                    return doubleValue
                } else if let intValue = planDict["interestRate"] as? Int {
                    return Double(intValue)
                }
                return 0.0
            }()

            let minimumOrderAmount: Double = {
                if let doubleValue = planDict["minimumOrderAmount"] as? Double {
                    return doubleValue
                } else if let intValue = planDict["minimumOrderAmount"] as? Int {
                    return Double(intValue)
                }
                return 0.0
            }()

            // Only show plans that are active and meet minimum order requirements
            guard isActive && calculatedPrice >= minimumOrderAmount else {
                return nil
            }

            // Also check maximum order amount if it exists - handle Int or Double
            if let maxAmountDouble = planDict["maximumOrderAmount"] as? Double, calculatedPrice > maxAmountDouble {
                return nil
            } else if let maxAmountInt = planDict["maximumOrderAmount"] as? Int, calculatedPrice > Double(maxAmountInt) {
                return nil
            }

            // Handle processing fee fields that could be Int or Double
            let processingFeePercentage: Double = {
                if let doubleValue = planDict["processingFeePercentage"] as? Double {
                    return doubleValue
                } else if let intValue = planDict["processingFeePercentage"] as? Int {
                    return Double(intValue)
                }
                return 0.0
            }()

            let processingFeeFixed: Double? = {
                if let doubleValue = planDict["processingFee"] as? Double {
                    return doubleValue
                } else if let intValue = planDict["processingFee"] as? Int {
                    return Double(intValue)
                }
                // Also try processingFeeFixed field for compatibility
                if let doubleValue = planDict["processingFeeFixed"] as? Double {
                    return doubleValue
                } else if let intValue = planDict["processingFeeFixed"] as? Int {
                    return Double(intValue)
                }
                return nil
            }()

            // Debug logging for installment plan data
            print("🛠️ [InstallmentPlan Debug] Plan: \(planName)")
            print("  Duration: \(duration) months")
            print("  Down Payment %: \(downPaymentPercentage)%")
            print("  Interest Rate: \(interestRate)%")
            print("  Processing Fee Fixed: \(processingFeeFixed ?? 0)")
            print("  Processing Fee %: \(processingFeePercentage)%")
            print("  For Product Price: $\(calculatedPrice)")

            return SimpleInstallmentPlan(
                id: id,
                planName: planName,
                duration: duration,
                downPaymentPercentage: downPaymentPercentage,
                interestRate: interestRate,
                minimumOrderAmount: minimumOrderAmount,
                processingFeePercentage: processingFeePercentage,
                processingFeeFixed: processingFeeFixed,
                description: planDict["description"] as? String
            )
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "creditcard.fill")
                    .foregroundColor(.blue)
                Text("Installment Plans Available")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()

                Button(action: {
                    showInstallmentPlans.toggle()
                }) {
                    Image(systemName: showInstallmentPlans ? "chevron.up" : "chevron.down")
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal)
            .contentShape(Rectangle())
            .onTapGesture {
                showInstallmentPlans.toggle()
            }

            if showInstallmentPlans {
                VStack(spacing: 12) {
                    ForEach(eligiblePlans) { plan in
                        InstallmentPlanRow(
                            plan: plan,
                            calculatedPrice: calculatedPrice,
                            isSelected: selectedInstallmentPlan?.planId == plan.id,
                            onSelect: {
                                selectPlan(plan)
                            }
                        )
                    }

                    if eligiblePlans.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                                .font(.title2)
                            Text("No installment plans available for this amount")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            Text("Minimum order amount: $500.00")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }

    private func selectPlan(_ plan: SimpleInstallmentPlan) {
        let calculation = plan.calculatePayments(orderAmount: calculatedPrice)

        selectedInstallmentPlan = InstallmentPlanSelection(
            planId: plan.id,
            planName: plan.planName,
            duration: plan.duration,
            downPaymentPercentage: plan.downPaymentPercentage,
            interestRate: plan.interestRate,
            minimumOrderAmount: plan.minimumOrderAmount,
            downPayment: calculation.downPayment,
            monthlyPayment: calculation.monthlyPayment,
            totalAmount: calculation.totalAmount,
            totalInterest: calculation.totalInterest,
            processingFee: calculation.processingFee,
            description: plan.description
        )
    }
}

struct InstallmentPlanRow: View {
    let plan: SimpleInstallmentPlan
    let calculatedPrice: Double
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        let calculation = plan.calculatePayments(orderAmount: calculatedPrice)

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(plan.planName)
                        .font(.headline)
                        .fontWeight(.semibold)

                    Text("\(plan.duration) months • \(plan.interestRate, specifier: "%.1f")% interest")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("$\(calculation.monthlyPayment, specifier: "%.2f")")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)

                    Text("per month")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                InstallmentDetailRow(
                    title: "Down Payment",
                    value: "$\(calculation.downPayment, specifier: "%.2f")",
                    subtitle: "(\(plan.downPaymentPercentage, specifier: "%.0f")% of total)"
                )

                InstallmentDetailRow(
                    title: "Total Amount",
                    value: "$\(calculation.totalAmount, specifier: "%.2f")",
                    subtitle: "includes $\(calculation.totalInterest, specifier: "%.2f") interest"
                )

                if calculation.processingFee > 0 {
                    InstallmentDetailRow(
                        title: "Processing Fee",
                        value: "$\(calculation.processingFee, specifier: "%.2f")",
                        subtitle: "one-time fee"
                    )
                }
            }
            .padding(.leading, 8)

            if let description = plan.description, !description.isEmpty {
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 8)
            }

            Button(action: onSelect) {
                HStack {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? .blue : .gray)

                    Text(isSelected ? "Selected" : "Select Plan")
                        .fontWeight(isSelected ? .semibold : .medium)

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(isSelected ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding()
        .background(isSelected ? Color.blue.opacity(0.05) : Color(.systemGray6))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
        )
    }
}

struct InstallmentDetailRow: View {
    let title: String
    let value: String
    let subtitle: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
    }
}

#Preview {
    let sampleProduct = Product(
        id: "1",
        name: "Sample Product",
        price: 1200.0,
        originalPrice: nil,
        description: "A sample product",
        shortDescription: nil,
        images: [],
        category: "Electronics",
        subcategory: nil,
        brand: "Brand",
        sku: "SKU001",
        inStock: true,
        quantity: 10,
        sellerId: "seller1",
        sellerName: "Sample Seller",
        rating: 4.5,
        reviewCount: 10,
        tags: [],
        customizationOptions: nil,
        specifications: nil,
        shippingInfo: nil,
        returnPolicy: nil,
        warranty: nil,
        metaTitle: nil,
        metaDescription: nil,
        metaKeywords: nil,
        createdAt: Date(),
        updatedAt: Date(),
        isActive: true,
        isFeatured: false,
        costPrice: nil,
        isApproved: true,
        views: nil,
        soldCount: nil,
        variants: nil,
        reviews: nil,
        hasInstallmentPlans: true,
        installmentSettings: nil,
        installmentPlansRaw: [
            AnyCodable([
                "id": "plan_6m",
                "planName": "6 Month Plan",
                "duration": 6,
                "downPaymentPercentage": 60.0,
                "interestRate": 10.0,
                "processingFee": 20.0,
                "processingFeeFixed": 20.0,
                "minimumOrderAmount": 500.0,
                "isActive": true,
                "description": "Perfect for short-term financing"
            ])
        ],
        taxRate: nil
    )

    InstallmentPlansView(
        product: sampleProduct,
        calculatedPrice: 1200.0,
        selectedInstallmentPlan: .constant(nil),
        showInstallmentPlans: .constant(true)
    )
    .padding()
}