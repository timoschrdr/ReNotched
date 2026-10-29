import SwiftUI

// MARK: - Copied

struct CopiedContent: View {
    @ObservedObject var model: IslandModel

    /// Left edge of the copy symbol and of the preview line, clear of the rounded bottom corner.
    private static let inset: CGFloat = 14

    var body: some View {
        let (preview, symbol): (String, String) = {
            if case let .copied(p, s)? = model.transient { return (p, s) }
            return ("", "doc.on.doc")
        }()

        VStack(spacing: 0) {
            // The copy symbol lines up with the preview below it instead of hugging the notch
            SideLayout(notchWidth: model.notch.width, height: model.notch.height, leftAlignment: .leading) {
                Image(systemName: "doc.on.doc.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .symbolEffect(.bounce, options: .nonRepeating, value: preview)
                    .padding(.leading, Self.inset - SideLayout<EmptyView, EmptyView>.outer)
            } right: {
                HStack(spacing: 5) {
                    Text("Copied")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.green)
                        .symbolEffect(.bounce, options: .nonRepeating, value: preview)
                }
            }
            HStack(spacing: 6) {
                Image(systemName: symbol).font(.system(size: 11)).foregroundStyle(.white.opacity(0.5))
                Text(preview)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .padding(.horizontal, Self.inset)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 30)
        }
    }
}
