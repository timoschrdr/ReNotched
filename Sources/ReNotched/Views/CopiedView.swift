import SwiftUI

// MARK: - Copied

struct CopiedContent: View {
    @ObservedObject var model: IslandModel

    var body: some View {
        let (preview, symbol): (String, String) = {
            if case let .copied(p, s)? = model.transient { return (p, s) }
            return ("", "doc.on.doc")
        }()

        VStack(spacing: 0) {
            SideLayout(notchWidth: model.notch.width, height: model.notch.height) {
                Image(systemName: "doc.on.doc.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .symbolEffect(.bounce, options: .nonRepeating, value: preview)
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
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 30)
        }
    }
}
