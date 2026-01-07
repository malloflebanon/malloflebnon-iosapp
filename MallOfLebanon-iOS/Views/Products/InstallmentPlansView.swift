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
    let description: String?

    func calculatePayments(orderAmount: Double) -> InstallmentCalculation {
        let downPayment = orderAmount * (downPaymentPercentage / 100)
        let remainingAmount = orderAmount - downPayment
        let processingFee = orderAmount * (processingFeePercentage / 100)
        let totalInterest = remainingAmount * (interestRate / 100) * Double(duration) / 12
        let totalAmount = orderAmount + totalInterest + processingFee
        let monthlyPayment = (remainingAmount + totalInterest) / Double(duration)

        return InstallmentCalculation(
            downPayment: downPayment,
            monthlyPayment: monthlyPayment,
            totalAmount: totalAmount,
            totalInterest: totalInterest,
            processingFee: processingFee
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
        // Sample installment plans - in production this would come from the product or API
        let allPlans = [
            SimpleInstallmentPlan(
                id: "plan_3m",
                planName: "3 Month Plan",
                duration: 3,
                downPaymentPercentage: 30.0,
                interestRate: 3.0,
                minimumOrderAmount: 200.0,
                processingFeePercentage: 1.5,
                description: "Quick payment plan for smaller purchases"
            ),
            SimpleInstallmentPlan(
                id: "plan_6m",
                planName: "6 Month Plan",
                duration: 6,
                downPaymentPercentage: 20.0,
                interestRate: 5.0,
                minimumOrderAmount: 500.0,
                processingFeePercentage: 2.0,
                description: "Perfect for short-term financing"
            ),
            SimpleInstallmentPlan(
                id: "plan_12m",
                planName: "12 Month Plan",
                duration: 12,
                downPaymentPercentage: 15.0,
                interestRate: 8.0,
                minimumOrderAmount: 1000.0,
                processingFeePercentage: 2.5,
                description: "Popular choice for larger purchases"
            ),
            SimpleInstallmentPlan(
                id: "plan_24m",
                planName: "24 Month Plan",
                duration: 24,
                downPaymentPercentage: 10.0,
                interestRate: 12.0,
                minimumOrderAmount: 2000.0,
                processingFeePercentage: 3.0,
                description: "Extended payment plan for premium items"
            )
        ]

        return allPlans.filter { $0.minimumOrderAmount <= calculatedPrice }
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
        installmentSettings: nil
    )

    InstallmentPlansView(
        product: sampleProduct,
        calculatedPrice: 1200.0,
        selectedInstallmentPlan: .constant(nil),
        showInstallmentPlans: .constant(true)
    )
    .padding()
}