import SwiftUI

/// The Vaulta mark: a rounded shield with a keyhole, drawn in code so it scales
/// crisply anywhere in the UI (no asset dependency).
struct BrandMark: View {
    var size: CGFloat = 48

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.36, green: 0.40, blue: 0.98),
                                 Color(red: 0.55, green: 0.30, blue: 0.95)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .black.opacity(0.25), radius: size * 0.06, y: size * 0.03)

            Keyhole()
                .fill(.white)
                .frame(width: size * 0.42, height: size * 0.5)
        }
        .frame(width: size, height: size)
    }
}

/// A classic keyhole silhouette: a circle over a tapered slot.
private struct Keyhole: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let headDiameter = w * 0.62
        let headRect = CGRect(
            x: rect.midX - headDiameter / 2,
            y: rect.minY,
            width: headDiameter,
            height: headDiameter
        )
        p.addEllipse(in: headRect)

        let slotTopY = headRect.maxY - headDiameter * 0.18
        let bottomY = rect.maxY
        let topHalf = w * 0.12
        let bottomHalf = w * 0.26
        p.move(to: CGPoint(x: rect.midX - topHalf, y: slotTopY))
        p.addLine(to: CGPoint(x: rect.midX + topHalf, y: slotTopY))
        p.addLine(to: CGPoint(x: rect.midX + bottomHalf, y: bottomY))
        p.addLine(to: CGPoint(x: rect.midX - bottomHalf, y: bottomY))
        p.closeSubpath()
        return p
    }
}
