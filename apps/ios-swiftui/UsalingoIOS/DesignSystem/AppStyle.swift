import SwiftUI

enum AppStyle {
    // During feature development the app intentionally uses a low-fidelity,
    // monochrome wireframe theme. Hierarchy is expressed with borders and
    // spacing so product decisions are not coupled to final visual polish.
    static let background = Color(red: 0.96, green: 0.96, blue: 0.95)
    static let surface = Color.white
    static let elevatedSurface = Color(red: 0.985, green: 0.985, blue: 0.98)
    static let ink = Color(red: 0.08, green: 0.08, blue: 0.08)
    static let muted = Color(red: 0.36, green: 0.36, blue: 0.36)
    static let accent = ink
    static let accentDark = ink
    static let secondary = ink
    static let sun = ink
    static let coral = ink
    static let line = Color.black.opacity(0.58)
    static let shadow = Color.clear

    @MainActor
    static func accent(_ settings: DesignSettings) -> Color {
        ink
    }

    @MainActor
    static func cornerRadius(_ settings: DesignSettings) -> CGFloat {
        2
    }

    static func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(18)
            .background(surface)
            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .stroke(line, lineWidth: 1)
            }
    }

    static func pressedCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(16)
            .background(surface)
            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
            .overlay(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .stroke(line, lineWidth: 1)
            }
    }

    static func widgetTile<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .padding(14)
            .background(surface)
            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .stroke(line, lineWidth: 1)
            }
    }

    static func profileWidgetTile<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(14)
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fill)
            .background(surface)
            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .stroke(line, lineWidth: 1)
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

            context.stroke(path, with: .color(Color.black.opacity(0.045)), lineWidth: 1)
        }
        .background(AppStyle.background)
        .ignoresSafeArea()
    }
}
