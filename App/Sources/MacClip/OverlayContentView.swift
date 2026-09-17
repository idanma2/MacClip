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
                Text("\(model.visibleEntries.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(12)

            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search", text: $model.searchText)
                    .textFieldStyle(.plain)
                    .focused($isFocused)
            }
            .padding(8)
            .background(.quaternary.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
            .onSubmit { model.copySelected() }

            Divider()

            if model.historyStore.entries.isEmpty {
                ContentUnavailableView("No Copies Yet", systemImage: "doc.on.clipboard")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if model.visibleEntries.isEmpty {
                ContentUnavailableView.search(text: model.searchText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(Array(model.visibleEntries.enumerated()), id: \.element.id) { index, entry in
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
        .onChange(of: model.searchText) { _, _ in
            // The filtered list shrinks/reorders as you type — keep the
            // selection anchored to the top match instead of pointing at
            // whatever row happens to still exist at the old index.
            model.selectedIndex = 0
        }
    }

    private func row(entry: ClipboardEntry, index: Int) -> some View {
        let isSelected = index == model.selectedIndex
        return HStack(spacing: 8) {
            Button {
                model.selectedIndex = index
                model.copySelected()
            } label: {
                Text(entry.text.replacingOccurrences(of: "\n", with: " "))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // A sibling Button, not nested inside the row's own tap
            // handling — a plain `.onTapGesture` on the row and a `Button`
            // inside it compete for the same tap and make the button
            // register unreliably. Two independent Buttons side by side
            // hit-test cleanly with no ambiguity.
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
        .animation(.easeOut(duration: 0.1), value: isSelected)
        .onHover { hovering in
            if hovering { model.selectedIndex = index }
        }
    }
}
