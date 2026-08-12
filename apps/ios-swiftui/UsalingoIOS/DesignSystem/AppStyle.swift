import SwiftUI

enum AppStyle {
    static let background = Color(red: 0.96, green: 0.985, blue: 0.95)
    static let surface = Color.white
    static let elevatedSurface = Color(red: 0.995, green: 1.0, blue: 0.985)
    static let ink = Color(red: 0.11, green: 0.15, blue: 0.12)
    static let muted = Color(red: 0.47, green: 0.54, blue: 0.50)
    static let accent = Color(red: 0.34, green: 0.78, blue: 0.22)
    static let accentDark = Color(red: 0.18, green: 0.55, blue: 0.13)
    static let secondary = Color(red: 0.13, green: 0.55, blue: 0.91)
    static let sun = Color(red: 1.0, green: 0.78, blue: 0.20)
    static let coral = Color(red: 1.0, green: 0.33, blue: 0.33)
    static let line = Color(red: 0.82, green: 0.89, blue: 0.80)
    static let shadow = Color(red: 0.08, green: 0.28, blue: 0.10).opacity(0.14)

    @MainActor
    static func accent(_ settings: DesignSettings) -> Color {
        settings.accentColor
    }

    @MainActor
    static func cornerRadius(_ settings: DesignSettings) -> CGFloat {
        CGFloat(settings.cardCornerRadius)
    }

    static func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(18)
            .background(surface)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(line, lineWidth: 1)
            }
            .shadow(color: shadow, radius: 12, y: 7)
    }

    static func pressedCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(16)
            .background(surface)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(line, lineWidth: 1)
            }
            .shadow(color: shadow, radius: 0, y: 5)
    }

    static func widgetTile<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .padding(14)
            .background(surface)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(line, lineWidth: 1)
            }
            .background(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(shadow)
                    .frame(height: 12)
                    .padding(.horizontal, 12)
                    .offset(y: 7)
            }
    }

    static func profileWidgetTile<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(14)
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fill)
            .background(surface)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(line, lineWidth: 1)
            }
            .background(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(shadow)
                    .frame(height: 12)
                    .padding(.horizontal, 12)
                    .offset(y: 7)
            }
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
        .background(
            LinearGradient(
                colors: [
                    AppStyle.background,
                    Color(red: 0.90, green: 0.97, blue: 1.0)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .ignoresSafeArea()
    }
}
