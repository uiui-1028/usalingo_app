import SwiftUI

enum AppStyle {
    static let background = Color(red: 0.96, green: 0.96, blue: 0.98)
    static let surface = Color(.systemBackground)
    static let ink = Color.primary
    static let muted = Color.secondary
    static let accent = Color(red: 1.0, green: 0.36, blue: 0.59)
    static let line = Color.black.opacity(0.1)

    static func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(18)
            .background(surface)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: .black.opacity(0.08), radius: 14, y: 7)
    }
}

struct GridBackground: View {
    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 24
            var path = Path()

            var x: CGFloat = 0
            while x <= size.width {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                x += spacing
            }

            var y: CGFloat = 0
            while y <= size.height {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                y += spacing
            }

            context.stroke(path, with: .color(Color.black.opacity(0.035)), lineWidth: 1)
        }
        .background(AppStyle.background)
        .ignoresSafeArea()
    }
}
