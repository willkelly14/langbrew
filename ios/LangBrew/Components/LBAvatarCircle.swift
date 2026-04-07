import SwiftUI

/// A circular avatar that displays an image or falls back to user initials.
struct LBAvatarCircle: View {
    /// Optional image URL (not loaded in this implementation -- placeholder for AsyncImage).
    let imageURL: URL?
    /// User's display name, used to derive initials as fallback.
    let name: String
    /// Diameter of the circle.
    let size: CGFloat
    /// Whether to show a border.
    let showBorder: Bool

    init(
        imageURL: URL? = nil,
        name: String,
        size: CGFloat = 40,
        showBorder: Bool = false
    ) {
        self.imageURL = imageURL
        self.name = name
        self.size = size
        self.showBorder = showBorder
    }

    var body: some View {
        Group {
            if let imageURL {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        initialsView
                    case .empty:
                        initialsView
                            .overlay {
                                ProgressView()
                                    .tint(.lbG400)
                            }
                    @unknown default:
                        initialsView
                    }
                }
            } else {
                initialsView
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay {
            if showBorder {
                Circle()
                    .strokeBorder(Color.lbG200, lineWidth: 2)
            }
        }
    }

    private var initialsView: some View {
        ZStack {
            Circle()
                .fill(Color.lbG100)

            Text(initials)
                .font(.system(size: size * 0.38, weight: .medium))
                .foregroundStyle(Color.lbNearBlack)
        }
    }

    private var initials: String {
        let parts = name.split(separator: " ")
        let first = parts.first?.prefix(1) ?? ""
        let last = parts.count > 1 ? parts.last?.prefix(1) ?? "" : ""
        return "\(first)\(last)".uppercased()
    }
}

#Preview {
    HStack(spacing: LBTheme.Spacing.md) {
        LBAvatarCircle(name: "Will Kelly", size: 48, showBorder: true)
        LBAvatarCircle(name: "Maria", size: 36)
        LBAvatarCircle(name: "A", size: 32, showBorder: true)
    }
    .padding()
    .background(Color.lbLinen)
}
