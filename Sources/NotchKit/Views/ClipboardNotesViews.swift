import SwiftUI

// MARK: Clipboard

/// Recently copied text as a row of cards. Click one to copy it again.
struct ClipboardBody: View {
    let model: IslandModel
    @Environment(\.notchScale) private var s

    var body: some View {
        let entries = model.clipboard.history.entries
        if entries.isEmpty {
            ZStack {
                RoundedRectangle(cornerRadius: 16 * s, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.2), style: StrokeStyle(lineWidth: 1.2, dash: [5, 4]))
                VStack(spacing: 6 * s) {
                    Image(systemName: "doc.on.clipboard.fill")
                        .font(.system(size: 20 * s, weight: .semibold))
                    Text("Text you copy shows up here")
                        .font(.system(size: 12 * s, weight: .medium))
                    Text("Passwords are skipped and nothing is saved to disk.")
                        .font(.system(size: 10 * s))
                        .foregroundStyle(NotchColor.secondaryText.opacity(0.8))
                }
                .foregroundStyle(NotchColor.secondaryText)
            }
            .padding(.bottom, 2 * s)
        } else {
            HStack(alignment: .center, spacing: 8 * s) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8 * s) {
                        ForEach(entries) { entry in
                            ClipboardCard(model: model, entry: entry)
                        }
                    }
                }
                Button {
                    model.clipboard.removeAll()
                } label: {
                    Image(systemName: "xmark.bin.fill")
                        .font(.system(size: 12 * s, weight: .semibold))
                        .foregroundStyle(NotchColor.secondaryText)
                        .frame(width: 28 * s, height: 28 * s)
                        .background(Circle().fill(NotchColor.buttonFill))
                }
                .buttonStyle(PressableButtonStyle())
                .help("Clear the history")
                .accessibilityLabel(Text("Clear the clipboard history"))
            }
            .frame(maxHeight: .infinity)
            .padding(.bottom, 2 * s)
        }
    }
}

private struct ClipboardCard: View {
    let model: IslandModel
    let entry: ClipboardHistory.Entry
    @State private var isHovering = false
    @Environment(\.notchScale) private var s

    var body: some View {
        let copied = model.clipboard.justCopied == entry.id
        Button {
            model.clipboard.copy(entry)
        } label: {
            VStack(alignment: .leading, spacing: 6 * s) {
                Text(ClipboardHistory.preview(entry.text))
                    .font(.system(size: 12 * s, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(4)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                HStack(spacing: 4 * s) {
                    if copied {
                        Image(systemName: "checkmark")
                        Text("Copied")
                    } else {
                        if let app = entry.appName {
                            Text(app).lineLimit(1)
                            Text("·")
                        }
                        Text(entry.copiedAt, style: .relative)
                            .lineLimit(1)
                    }
                }
                .font(.system(size: 10 * s, weight: .medium))
                .foregroundStyle(copied ? NotchColor.green : NotchColor.secondaryText)
            }
            .padding(10 * s)
            .frame(width: 150 * s)
            .frame(maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14 * s, style: .continuous)
                    .fill(Color.white.opacity(isHovering ? 0.13 : 0.07))
            )
            .contentShape(RoundedRectangle(cornerRadius: 14 * s, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle())
        .overlay(alignment: .topTrailing) {
            if isHovering {
                Button { model.clipboard.remove(entry.id) } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14 * s))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, Color(white: 0.35))
                }
                .buttonStyle(PressableButtonStyle())
                .offset(x: 4 * s, y: -4 * s)
                .accessibilityLabel(Text("Remove from history"))
            }
        }
        .onHover { isHovering = $0 }
        .help("Click to copy")
        .accessibilityLabel(Text("Copy \(ClipboardHistory.preview(entry.text, limit: 60))"))
    }
}

// MARK: Notes

/// A quick scratchpad. Saved as you type; Escape or a click outside closes it.
struct NotesBody: View {
    let model: IslandModel
    @FocusState private var isFocused: Bool
    @Environment(\.notchScale) private var s

    var body: some View {
        @Bindable var notes = model.notes
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 16 * s, style: .continuous)
                .fill(Color.white.opacity(0.07))
            if notes.text.isEmpty {
                Text("Jot something down…")
                    .font(.system(size: 13 * s))
                    .foregroundStyle(NotchColor.secondaryText)
                    .padding(.horizontal, 12 * s)
                    .padding(.vertical, 9 * s)
                    .allowsHitTesting(false)
            }
            TextEditor(text: $notes.text)
                .font(.system(size: 13 * s))
                .foregroundStyle(.white)
                .scrollContentBackground(.hidden)
                .scrollIndicators(.never)
                .padding(.horizontal, 7 * s)
                .padding(.vertical, 9 * s)
                .focused($isFocused)
                .onKeyPress(.escape) {
                    model.collapse()
                    return .handled
                }
                .accessibilityLabel(Text("Notes"))
        }
        .padding(.bottom, 2 * s)
        .onAppear {
            // The panel takes the keyboard a moment after the tab opens.
            Task { @MainActor in isFocused = true }
        }
    }
}
