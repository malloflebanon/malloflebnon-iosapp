import SwiftUI

struct ProductImageViewer: View {
    let images: [String]
    @Binding var selectedIndex: Int
    @Binding var isPresented: Bool

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button("Done") {
                        isPresented = false
                    }
                    .foregroundColor(.white)
                    .padding()

                    Spacer()

                    Text("\(selectedIndex + 1) of \(images.count)")
                        .foregroundColor(.white)
                        .font(.caption)
                        .padding()
                }

                Spacer()

                // Image Content
                GeometryReader { geometry in
                    TabView(selection: $selectedIndex) {
                        ForEach(Array(images.enumerated()), id: \.offset) { index, imageUrl in
                            ZoomableImageView(
                                imageUrl: imageUrl,
                                scale: $scale,
                                lastScale: $lastScale,
                                offset: $offset,
                                lastOffset: $lastOffset,
                                geometry: geometry
                            )
                            .tag(index)
                        }
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                    .onAppear {
                        NSLog("📱 [MallOfLebanon] ProductImageViewer TabView appeared - images count: \(images.count), selectedIndex: \(selectedIndex)")
                    }
                    .onChange(of: selectedIndex) { newIndex in
                        NSLog("📱 [MallOfLebanon] ProductImageViewer selectedIndex changed to: \(newIndex)")
                    }
                }

                Spacer()

                // Page Indicator
                if images.count > 1 {
                    HStack(spacing: 8) {
                        ForEach(0..<images.count, id: \.self) { index in
                            Circle()
                                .fill(selectedIndex == index ? Color.white : Color.white.opacity(0.5))
                                .frame(width: 8, height: 8)
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
        }
        .onChange(of: selectedIndex) { _ in
            // Reset zoom when changing images
            withAnimation(.easeInOut(duration: 0.3)) {
                scale = 1.0
                lastScale = 1.0
                offset = .zero
                lastOffset = .zero
            }
        }
    }
}

struct ZoomableImageView: View {
    let imageUrl: String
    @Binding var scale: CGFloat
    @Binding var lastScale: CGFloat
    @Binding var offset: CGSize
    @Binding var lastOffset: CGSize
    let geometry: GeometryProxy

    var body: some View {
        CachedImageView(
            url: URL(string: imageUrl),
            placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        ProgressView()
                            .foregroundColor(.white)
                    )
            },
            failureView: {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.white)
                    )
            }
        )
            .scaleEffect(scale)
            .offset(offset)
            .gesture(
                // Zoom gesture
                MagnificationGesture()
                    .onChanged { value in
                        let delta = value / lastScale
                        lastScale = value
                        let newScale = scale * delta
                        scale = max(1.0, min(newScale, 5.0))
                    }
                    .onEnded { _ in
                        lastScale = 1.0
                        if scale < 1.0 {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                scale = 1.0
                                offset = .zero
                                lastOffset = .zero
                            }
                        }
                    }
            )
            .gesture(
                // Pan gesture - only when zoomed
                scale > 1.0 ?
                DragGesture()
                    .onChanged { value in
                        let newOffset = CGSize(
                            width: lastOffset.width + value.translation.width,
                            height: lastOffset.height + value.translation.height
                        )
                        offset = limitOffset(newOffset)
                    }
                    .onEnded { _ in
                        lastOffset = offset
                    } : nil
            )
            .onTapGesture(count: 2) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    if scale > 1.0 {
                        scale = 1.0
                        offset = .zero
                        lastOffset = .zero
                    } else {
                        scale = 2.0
                    }
                }
            }
    }

    private func limitOffset(_ offset: CGSize) -> CGSize {
        let maxOffsetX = max(0, (geometry.size.width * (scale - 1)) / 2)
        let maxOffsetY = max(0, (geometry.size.height * (scale - 1)) / 2)

        return CGSize(
            width: max(-maxOffsetX, min(maxOffsetX, offset.width)),
            height: max(-maxOffsetY, min(maxOffsetY, offset.height))
        )
    }
}