import SwiftUI

struct PlaceholderSectionView: View {
    @EnvironmentObject private var appState: AppState
    let section: AppSection

    private var destination: SectionDestination? {
        guard appState.selectedSection == section else {
            return section.contextualDestinations.first
        }
        return appState.selectedDestination
    }

    var body: some View {
        ContentUnavailableView {
            Label(
                destination?.title ?? section.title,
                systemImage: destination?.systemImage ?? section.systemImage
            )
        } description: {
            Text("Subvista de \(section.title) preparada para incorporar su contenido aprobado sin saturar la navegación principal.")
        }
        .navigationTitle(destination?.title ?? section.title)
    }
}
