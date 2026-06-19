import SwiftUI

struct EpisodeEditSectionOrderView: View {
    @AppStorage(EpisodeEditSectionOrder.storageKey) private var sectionOrderRaw = ""

    private var sections: [EpisodeEditSection] {
        EpisodeEditSectionOrder.sections(from: sectionOrderRaw)
    }

    var body: some View {
        List {
            Section {
                ForEach(sections) { section in
                    HStack {
                        Image(systemName: "line.3.horizontal")
                            .foregroundStyle(.secondary)
                        Text(section.displayName)
                    }
                }
                .onMove { from, to in
                    var ordered = sections
                    ordered.move(fromOffsets: from, toOffset: to)
                    sectionOrderRaw = EpisodeEditSectionOrder.encode(ordered)
                }
            } header: {
                Text(String(localized: "EpisodeEditSectionOrder.Header",
                            defaultValue: "Felder in der Folgenbearbeitung"))
            } footer: {
                Text(String(localized: "EpisodeEditSectionOrder.Footer",
                            defaultValue: "Zieht die Felder in die gewünschte Reihenfolge."))
            }
        }
        .navigationTitle(
            String(localized: "EpisodeEditSectionOrder.Title",
                   defaultValue: "Felder-Reihenfolge")
        )
        .environment(\.editMode, .constant(.active))
    }
}
