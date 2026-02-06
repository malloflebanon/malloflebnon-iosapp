import SwiftUI
import Combine

// MARK: - Auction Notifications View
// Displays in-app auction alerts and notifications (matching frontend NotificationsPanel)

struct AuctionNotificationsView: View {
    @StateObject private var notificationService = AuctionNotificationService.shared
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if notificationService.inAppAlerts.isEmpty {
                    emptyStateView
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(notificationService.inAppAlerts) { alert in
                                AuctionAlertRow(
                                    alert: alert,
                                    onTap: {
                                        notificationService.markAlertAsRead(alert.id)
                                        handleAlertTap(alert)
                                    },
                                    onDismiss: {
                                        notificationService.removeAlert(alert.id)
                                    }
                                )
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top)
                    }
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    if !notificationService.inAppAlerts.isEmpty {
                        Button("Clear All") {
                            notificationService.clearAllAlerts()
                        }
                        .foregroundColor(.red)
                    }
                }
            }
        }
        .onAppear {
            // Mark all as read when view appears
            for alert in notificationService.inAppAlerts {
                notificationService.markAlertAsRead(alert.id)
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "bell.slash")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            VStack(spacing: 8) {
                Text("No Notifications")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("You're all caught up! New auction notifications will appear here.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Button("Test Notification") {
                notificationService.testNotification()
            }
            .foregroundColor(.blue)

            Spacer()
        }
    }

    private func handleAlertTap(_ alert: AuctionAlert) {
        // Handle navigation based on alert type
        if let auctionId = alert.auctionId {
            // Post notification for main app to handle navigation
            NotificationCenter.default.post(
                name: NSNotification.Name("AuctionNotificationTapped"),
                object: nil,
                userInfo: [
                    "auctionId": auctionId,
                    "alertType": alert.type.rawValue
                ]
            )

            // Dismiss this view
            presentationMode.wrappedValue.dismiss()
        }
    }
}

// MARK: - Alert Row Component

struct AuctionAlertRow: View {
    let alert: AuctionAlert
    let onTap: () -> Void
    let onDismiss: () -> Void

    private var alertColor: Color {
        switch alert.type.color {
        case "red": return .red
        case "green": return .green
        case "blue": return .blue
        case "gold": return .yellow
        case "purple": return .purple
        default: return .gray
        }
    }

    private var timeAgo: String {
        let now = Date()
        let interval = now.timeIntervalSince(alert.timestamp)

        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        }
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Alert Icon
                Image(systemName: alert.type.icon)
                    .font(.title2)
                    .foregroundColor(alertColor)
                    .frame(width: 24)

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(alert.title)
                            .font(.headline)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)

                        Spacer()

                        // Priority indicator
                        if alert.priority == .high {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                        }
                    }

                    Text(alert.message)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)

                    HStack {
                        Text(timeAgo)
                            .font(.caption)
                            .foregroundColor(.tertiary)

                        Spacer()

                        if !alert.isRead {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 6, height: 6)
                        }
                    }
                }

                // Dismiss Button
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .font(.title3)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(alert.isRead ? Color(.systemGray6) : Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(alert.isRead ? Color.clear : alertColor.opacity(0.3), lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Notification Badge Component

struct NotificationBadge: View {
    @StateObject private var notificationService = AuctionNotificationService.shared

    private var unreadCount: Int {
        notificationService.getUnreadAlertsCount()
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(systemName: "bell")
                .font(.title2)
                .foregroundColor(.primary)

            if unreadCount > 0 {
                ZStack {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 18, height: 18)

                    Text(unreadCount > 99 ? "99+" : "\(unreadCount)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                }
                .offset(x: 8, y: -8)
            }
        }
    }
}

// MARK: - In-App Alert Overlay

struct InAppAlertOverlay: View {
    let alert: AuctionAlert
    let onDismiss: () -> Void

    @State private var offset: CGFloat = -200
    @State private var opacity: Double = 0

    private var alertColor: Color {
        switch alert.type.color {
        case "red": return .red
        case "green": return .green
        case "blue": return .blue
        case "gold": return .yellow
        case "purple": return .purple
        default: return .gray
        }
    }

    var body: some View {
        VStack {
            HStack(spacing: 12) {
                Image(systemName: alert.type.icon)
                    .font(.title3)
                    .foregroundColor(alertColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text(alert.title)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(alert.message)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
            )
            .padding(.horizontal)

            Spacer()
        }
        .offset(y: offset)
        .opacity(opacity)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                offset = 60
                opacity = 1
            }

            // Auto-dismiss after 4 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                dismissAlert()
            }
        }
        .onTapGesture {
            // Handle tap to navigate
            NotificationCenter.default.post(
                name: NSNotification.Name("AuctionNotificationTapped"),
                object: nil,
                userInfo: [
                    "auctionId": alert.auctionId ?? "",
                    "alertType": alert.type.rawValue
                ]
            )
            dismissAlert()
        }
        .gesture(
            DragGesture()
                .onEnded { value in
                    if value.translation.y < -50 {
                        dismissAlert()
                    }
                }
        )
    }

    private func dismissAlert() {
        withAnimation(.easeInOut(duration: 0.3)) {
            offset = -200
            opacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onDismiss()
        }
    }
}

// MARK: - Preview

struct AuctionNotificationsView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            AuctionNotificationsView()
                .previewDisplayName("Notifications")

            NotificationBadge()
                .previewDisplayName("Badge")

            InAppAlertOverlay(
                alert: AuctionAlert(
                    id: "test",
                    type: .outbid,
                    title: "You've Been Outbid!",
                    message: "Your bid on Vintage Watch has been exceeded.",
                    timestamp: Date(),
                    auctionId: "test-auction",
                    itemId: "test-item",
                    priority: .high
                ),
                onDismiss: {}
            )
            .previewDisplayName("In-App Alert")
        }
    }
}