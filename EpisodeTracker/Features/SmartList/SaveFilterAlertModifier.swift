import SwiftUI

private struct SaveFilterAlertModifier: ViewModifier {
    @Environment(SavedFilterStore.self) private var savedFilterStore
    @Binding var isPresented: Bool
    @Binding var filterName: String
    let controls: EpisodeListControlsState

    func body(content: Content) -> some View {
        content.alert(
            String(localized: "EpisodeList.Filter.SaveAlert.Title", defaultValue: "Liste speichern"),
            isPresented: $isPresented
        ) {
            TextField(
                String(localized: "EpisodeList.Filter.SaveAlert.Placeholder", defaultValue: "Name"),
                text: $filterName
            )
            Button(String(localized: "EpisodeList.Filter.SaveAlert.Save", defaultValue: "Speichern")) {
                saveFilter()
            }
            Button(String(localized: "General.Cancel", defaultValue: "Abbrechen"), role: .cancel) {}
        } message: {
            Text(String(localized: "EpisodeList.Filter.SaveAlert.Message",
                        defaultValue: "Der aktuelle Filter wird als neue Liste gespeichert."))
        }
    }

    private func saveFilter() {
        let trimmed = filterName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        let filter = SavedFilter(
            name: trimmed,
            statusFilter: controls.statusFilter,
            universeName: controls.filterUniverse?.name,
            moodName: controls.filterMood?.name,
            sortOrder: controls.sortOrder
        )
        savedFilterStore.add(filter)
    }
}

extension View {
    func saveFilterAlert(
        isPresented: Binding<Bool>,
        filterName: Binding<String>,
        controls: EpisodeListControlsState
    ) -> some View {
        modifier(
            SaveFilterAlertModifier(
                isPresented: isPresented,
                filterName: filterName,
                controls: controls
            )
        )
    }
}
