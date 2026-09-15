import SwiftUI
import ClipboardCore
import MacClipCore

/// The SwiftUI content hosted inside `OverlayPanel`. Full keyboard
/// navigation (Up/Down/Enter/Escape) alongside plain mouse click — closes
/// automatically on selection (`copySelected` hides the overlay) or Escape.
struct OverlayContentView: View {
    @Bindable var model: AppModel
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "doc.on.clipboard")
                    .foregroundStyle(.secondary)
                Text("Clipboard History")
                    .font(.headline)
                Spacer()
                Text("\(model.historyStore.entries.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(12)

            Divider()

            if model.historyStore.entries.isEmpty {
                ContentUnavailableView("No Copies Yet", systemImage: "doc.on.clipboard")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(Array(model.historyStore.entries.enumerated()), id: \.element.id) { index, entry in
                                row(entry: entry, index: index)
                                    .id(index)
                            }
                        }
                        .padding(6)
                    }
                    .onChange(of: model.selectedIndex) { _, newValue in
                        withAnimation { proxy.scrollTo(newValue) }
                    }
                }
            }
        }
        .frame(width: 420, height: 360)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .focusable()
        .focused($isFocused)
        .onKeyPress(.upArrow) { model.selectPrevious(); return .handled }
        .onKeyPress(.downArrow) { model.selectNext(); return .handled }
        .onKeyPress(.return) { model.copySelected(); return .handled }
        .onKeyPress(.escape) { model.hideOverlay(); return .handled }
        .onChange(of: model.isOverlayVisible) { _, visible in
            // Re-claim focus on every open, not just the first — the
            // panel/content view are cached and reused, so `.onAppear`
            // alone would only fire once for the process's lifetime.
            if visible { isFocused = true }
        }
    }

    private func row(entry: ClipboardEntry, index: Int) -> some View {
        let isSelected = index == model.selectedIndex
        return HStack {
            Text(entry.text.replacingOccurrences(of: "\n", with: " "))
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer()
            Button {
                model.removeEntry(entry.id)
            } label: {
                Image(systemName: "xmark.circle.fill")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(isSelected ? Color.accentColor.opacity(0.25) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
        .animation(.easeOut(duration: 0.1), value: isSelected)
        .onTapGesture {
            model.selectedIndex = index
            model.copySelected()
        }
        .onHover { hovering in
            if hovering { model.selectedIndex = index }
        }
    }
}
