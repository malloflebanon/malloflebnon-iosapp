import Foundation

// MARK: - Installment Plan Models
struct InstallmentPlan: Codable, Identifiable, Equatable {
    let id: String
    let planName: String
    let duration: Int // in months
    let downPaymentPercentage: Double
    let interestRate: Double
    let processingFee: Double
    let processingFeeFixed: Double?
    let processingFeePercentage: Double?
    let minimumOrderAmount: Double
    let maximumOrderAmount: Double?
    let requiredDocuments: [RequiredDocumentType]
    let isActive: Bool
    let description: String?
    let terms: String?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, planName, duration, downPaymentPercentage, interestRate
        case processingFee, processingFeeFixed, processingFeePercentage
        case minimumOrderAmount, maximumOrderAmount, requiredDocuments
        case isActive, description, terms, createdAt
    }

    // Calculate installment details for a given product price
    func calculateDetails(for totalPrice: Double) -> InstallmentCalculationResult {
        let downPaymentAmount = (totalPrice * downPaymentPercentage) / 100
        let remainingAmount = totalPrice - downPaymentAmount

        // Calculate processing fee - match frontend logic
        var totalProcessingFee = processingFee
        if let fixedFee = processingFeeFixed {
            totalProcessingFee += fixedFee
        }
        if let percentageFee = processingFeePercentage, percentageFee > 0 {
            totalProcessingFee += (totalPrice * percentageFee) / 100
        }

        // Calculate interest if applicable
        var totalWithInterest = remainingAmount
        var totalInterest: Double = 0
        if interestRate > 0 {
            let monthlyRate = interestRate / 100 / 12
            totalInterest = remainingAmount * monthlyRate * Double(duration)
            totalWithInterest = remainingAmount + totalInterest
        }

        let monthlyPayment = totalWithInterest / Double(duration)
        let totalAmount = downPaymentAmount + totalWithInterest + totalProcessingFee

        return InstallmentCalculationResult(
            downPayment: roundToTwoDecimals(downPaymentAmount),
            monthlyPayment: roundToTwoDecimals(monthlyPayment),
            totalAmount: roundToTwoDecimals(totalAmount),
            totalInterest: roundToTwoDecimals(totalInterest),
            processingFee: roundToTwoDecimals(totalProcessingFee),
            savings: max(0, roundToTwoDecimals(totalPrice - totalAmount))
        )
    }

    private func roundToTwoDecimals(_ value: Double) -> Double {
        return (value * 100).rounded() / 100
    }
}

struct InstallmentCalculationResult {
    let downPayment: Double
    let monthlyPayment: Double
    let totalAmount: Double
    let totalInterest: Double
    let processingFee: Double
    let savings: Double
}

enum RequiredDocumentType: String, Codable, CaseIterable {
    case nationalID = "national_id"
    case salaryCertificate = "salary_certificate"
    case bankStatement = "bank_statement"
    case employmentLetter = "employment_letter"
    case other = "other"

    var displayName: String {
        switch self {
        case .nationalID: return "National ID"
        case .salaryCertificate: return "Salary Certificate"
        case .bankStatement: return "Bank Statement"
        case .employmentLetter: return "Employment Letter"
        case .other: return "Other"
        }
    }

    var description: String {
        switch self {
        case .nationalID: return "Clear photo or scan of your national ID (both sides if applicable)"
        case .salaryCertificate: return "Official salary certificate from your employer (not older than 3 months)"
        case .bankStatement: return "Recent bank statement showing your income (last 3 months)"
        case .employmentLetter: return "Your current employment contract or work agreement"
        case .other: return "Additional supporting documents"
        }
    }
}


// MARK: - Enhanced Cart Item with Installment Support
// Note: InstallmentPlanSelection is now defined in CartModels.swift

extension InstallmentPlanSelection {
    init(from plan: InstallmentPlan, calculation: InstallmentCalculationResult) {
        self.planId = plan.id
        self.planName = plan.planName
        self.duration = plan.duration
        self.downPaymentPercentage = plan.downPaymentPercentage
        self.interestRate = plan.interestRate
        self.minimumOrderAmount = plan.minimumOrderAmount
        self.downPayment = calculation.downPayment
        self.monthlyPayment = calculation.monthlyPayment
        self.totalAmount = calculation.totalAmount
        self.totalInterest = calculation.totalInterest
        self.processingFee = calculation.processingFee
        self.description = plan.description
    }
}

// MARK: - Installment Order Models
struct InstallmentOrder: Codable, Identifiable {
    let id: String
    let orderId: String
    let customerId: String
    let customerName: String
    let customerEmail: String
    let customerPhone: String

    // Product Information
    let productId: String
    let productName: String
    let productSku: String
    let sellerId: String
    let sellerName: String

    // Installment Details
    let planId: String
    let planName: String
    let duration: Int
    let downPaymentPercentage: Double
    let interestRate: Double
    let downPaymentAmount: Double
    let monthlyAmount: Double
    let totalAmount: Double
    let processingFee: Double

    // Status and Tracking
    let status: InstallmentOrderStatus
    let reviewedBy: String?
    let reviewedAt: Date?
    let reviewerRole: String?
    let approvalNotes: String?
    let rejectionReason: String?

    // Payment Schedule
    let paymentScheduleGenerated: Bool
    let firstPaymentDate: Date?
    let lastPaymentDate: Date?

    // Documents
    let uploadedDocuments: [UploadedDocument]

    let createdAt: Date
    let updatedAt: Date
}

enum InstallmentOrderStatus: String, Codable, CaseIterable {
    case pendingDocuments = "pending_documents"
    case documentsUploaded = "documents_uploaded"
    case underReview = "under_review"
    case approved = "approved"
    case rejected = "rejected"
    case active = "active"
    case completed = "completed"
    case cancelled = "cancelled"

    var displayName: String {
        switch self {
        case .pendingDocuments: return "Pending Documents"
        case .documentsUploaded: return "Documents Uploaded"
        case .underReview: return "Under Review"
        case .approved: return "Approved"
        case .rejected: return "Rejected"
        case .active: return "Active"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        }
    }

    var description: String {
        switch self {
        case .pendingDocuments: return "Waiting for required documents to be uploaded"
        case .documentsUploaded: return "Documents have been uploaded and are pending review"
        case .underReview: return "Application is being reviewed by our team"
        case .approved: return "Application approved, ready for delivery"
        case .rejected: return "Application was not approved"
        case .active: return "Installment plan is active"
        case .completed: return "All payments completed"
        case .cancelled: return "Order was cancelled"
        }
    }
}

struct UploadedDocument: Codable, Identifiable {
    let id: String
    let type: RequiredDocumentType
    let originalName: String
    let filename: String
    let path: String
    let mimeType: String
    let fileSize: Int
    let uploadedAt: Date
    let verifiedAt: Date?
    let verifiedBy: String?
    let verificationNotes: String?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case type, originalName, filename, path, mimeType, fileSize
        case uploadedAt, verifiedAt, verifiedBy, verificationNotes
    }
}

// MARK: - Document Upload Models
// Note: DocumentUploadRequest is defined in APIModels.swift

struct DocumentFile {
    let file: Data
    let fileName: String
    let mimeType: String
    let documentType: RequiredDocumentType
}

// Note: DocumentUploadResponse is defined in APIModels.swift
struct LocalDocumentUploadResponse: Codable {
    let success: Bool
    let message: String
    let uploadedDocuments: [UploadedDocument]?
    let installmentOrder: InstallmentOrder?
}

// MARK: - API Response Models
struct InstallmentOrderResponse: Codable {
    let success: Bool
    let installmentOrder: InstallmentOrder?
    let message: String?
}

struct InstallmentOrdersResponse: Codable {
    let success: Bool
    let installmentOrders: [InstallmentOrder]
    let pagination: PaginationInfo?
    let message: String?
}

struct InstallmentPlanEligibilityResponse: Codable {
    let success: Bool
    let eligiblePlans: [InstallmentPlan]
    let message: String?
}

// MARK: - Installment Payment Models
struct InstallmentPayment: Codable, Identifiable {
    let id: String
    let installmentOrderId: String
    let paymentNumber: Int
    let amount: Double
    let dueDate: Date
    let paidAt: Date?
    let paidAmount: Double?
    let status: PaymentStatus
    let paymentMethod: String?
    let transactionId: String?
    let notes: String?
    let createdAt: Date
    let updatedAt: Date
}

enum PaymentStatus: String, Codable, CaseIterable {
    case pending = "pending"
    case paid = "paid"
    case late = "late"
    case failed = "failed"
    case cancelled = "cancelled"

    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .paid: return "Paid"
        case .late: return "Late"
        case .failed: return "Failed"
        case .cancelled: return "Cancelled"
        }
    }
}

// MARK: - Installment Statistics
struct InstallmentStatistics: Codable {
    let totalOrders: Int
    let pendingReview: Int
    let approved: Int
    let active: Int
    let completed: Int
    let rejected: Int
    let totalValue: Double
    let averageOrderValue: Double
}

struct InstallmentStatisticsResponse: Codable {
    let success: Bool
    let statistics: InstallmentStatistics?
    let message: String?
}

// MARK: - Simple Installment Plan for UI
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

        // Calculate processing fee - match frontend logic
        var processingFee: Double = 0
        if let fixedFee = processingFeeFixed {
            processingFee += fixedFee
        }
        if processingFeePercentage > 0 {
            processingFee += (orderAmount * processingFeePercentage) / 100
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

        // Debug logging for calculation
        print("💰 [Calculation Debug] \(planName) for $\(orderAmount)")
        print("  Down Payment: \(downPaymentPercentage)% = $\(downPayment)")
        print("  Remaining: $\(remainingAmount)")
        print("  Interest Rate: \(interestRate)% annually")
        print("  Monthly Rate: \(interestRate / 100 / 12)")
        print("  Total Interest: $\(totalInterest)")
        print("  Processing Fee: $\(processingFee)")
        print("  Monthly Payment: $\(monthlyPayment)")
        print("  TOTAL AMOUNT: $\(totalAmount)")

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