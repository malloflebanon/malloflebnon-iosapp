import SwiftUI

// MARK: - Viewer Controls Header Component

struct ViewerControlsHeader: View {
    @State private var viewerCount: Int = 462 // Demo data, can be made dynamic
    @Binding var isMinimized: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Viewer Count Section
            viewerCountView

            // Minimize/Expand Button
            minimizeButton
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.clear)
        )
    }

    // MARK: - Viewer Count Display

    private var viewerCountView: some View {
        HStack(spacing: 6) {
            // Eye/Viewer icon with red live indicator
            ZStack {
                // Red live background
                Circle()
                    .fill(Color.red)
                    .frame(width: 32, height: 32)

                // Viewer icon
                Image(systemName: "eye.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
            }

            // Viewer count
            Text("\(viewerCount)")
                .font(.system(.headline, design: .default).weight(.bold))
                .foregroundColor(.white)
        }
    }

    // MARK: - Minimize Button

    private var minimizeButton: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.3)) {
                isMinimized.toggle()
            }
            print("📱 [ViewerControlsHeader] Minimize button tapped - isMinimized: \(isMinimized)")
        }) {
            Image(systemName: isMinimized ? "chevron.up" : "chevron.down")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(Color.clear)
                )
        }
        .scaleEffect(isMinimized ? 0.9 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isMinimized)
    }
}

// MARK: - Extensions for Dynamic Data

extension ViewerControlsHeader {
    // Update viewer count dynamically
    func updateViewerCount(_ count: Int) {
        withAnimation(.easeInOut(duration: 0.3)) {
            viewerCount = max(0, count)
        }
    }

    // Animate viewer count changes
    private func animateViewerCountChange() {
        // Add pulse animation for viewer count updates
        withAnimation(.easeInOut(duration: 0.5)) {
            // Animation logic here
        }
    }
}

// MARK: - Preview

struct ViewerControlsHeader_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.gray
                .ignoresSafeArea()

            ViewerControlsHeader(isMinimized: .constant(false))
                .padding()
        }
        .previewDisplayName("Viewer Controls Header")
    }
}