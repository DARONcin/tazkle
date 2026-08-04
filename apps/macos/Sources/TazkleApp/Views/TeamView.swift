import SwiftUI
import TazkleAuthentication
import TazkleDesignSystem
import TazkleDomain

struct TeamView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var authentication: AuthenticationController
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.tazkleHighContrast) private var highContrast

    private var destinationID: String {
        appState.selectedDestinationID ?? "team.general"
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: TazkleSpacing.xLarge) {
                ProjectSectionHeader(
                    title: appState.selectedDestination?.title ?? "Equipo",
                    subtitle: subtitle,
                    systemImage: "person.2",
                    accent: TazkleColors.relationship,
                    trailingTitle: canRetry ? "Actualizar" : nil,
                    trailingAction: canRetry ? { Task { await loadTeam() } } : nil,
                    contextBadgeTitle: headerBadge.title,
                    contextBadgeSystemImage: headerBadge.systemImage,
                    contextBadgeHelp: headerBadge.help
                )

                content
            }
            .padding(TazkleSpacing.xLarge)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(
            TazkleColors.canvas(
                for: colorScheme,
                highContrast: highContrast
            )
        )
        .task {
            guard appState.teamLoadState == .idle else { return }
            await loadTeam()
        }
    }

    private func loadTeam() async {
        await appState.loadTeamMembers(using: authentication)
    }

    private var canRetry: Bool {
        switch appState.teamLoadState {
        case .loaded, .offline, .error: true
        case .idle, .loading: false
        }
    }

    private var headerBadge: (title: String, systemImage: String, help: String) {
        switch appState.teamLoadState {
        case .idle, .loading:
            ("Cargando", "arrow.triangle.2.circlepath", "Consultando los miembros reales de tu organización.")
        case .offline:
            ("Sin conexión", "wifi.slash", "No se pudo contactar al servidor; el equipo se actualizará al recuperar conexión.")
        case .error:
            ("Error al cargar", "exclamationmark.triangle", "No fue posible consultar el equipo real.")
        case .loaded:
            ("Datos reales", "checkmark.shield", "Miembros y roles obtenidos de tu organización en Project Core.")
        }
    }

    @ViewBuilder
    private var content: some View {
        switch appState.teamLoadState {
        case .idle, .loading:
            statusCard(
                title: "Cargando el equipo…",
                systemImage: "arrow.triangle.2.circlepath",
                detail: "Consultando los miembros reales de tu organización.",
                isBusy: true
            )
        case .offline:
            statusCard(
                title: "Sin conexión",
                systemImage: "wifi.slash",
                detail: "No se pudo contactar al servidor. El equipo se actualizará automáticamente al recuperar conexión, o pulsa Actualizar para reintentar."
            )
        case let .error(message):
            statusCard(
                title: "No fue posible cargar el equipo",
                systemImage: "exclamationmark.triangle",
                detail: message
            )
        case .loaded:
            if appState.teamMembers.isEmpty {
                statusCard(
                    title: "Todavía no hay miembros",
                    systemImage: "person.2.slash",
                    detail: "Invita personas a tu organización desde Configuración para verlas aquí."
                )
            } else {
                membersCard
            }
        }
    }

    private func statusCard(
        title: String,
        systemImage: String,
        detail: String,
        isBusy: Bool = false
    ) -> some View {
        ProjectSectionCard(title: title, systemImage: systemImage) {
            if isBusy {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityHidden(true)
            }
            Text(detail)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: 760)
        .accessibilityElement(children: .combine)
    }

    private var membersCard: some View {
        ProjectSectionCard(title: "Miembros (\(appState.teamMembers.count))", systemImage: "person.2") {
            VStack(spacing: 0) {
                ForEach(Array(appState.teamMembers.enumerated()), id: \.element.id) { index, member in
                    if index > 0 {
                        Divider()
                    }
                    MemberRow(member: member)
                }
            }
        }
        .frame(maxWidth: 760)
    }

    private var subtitle: String {
        switch destinationID {
        case "team.coverage":
            "Responsabilidades cubiertas y brechas antes de aprobar el plan."
        case "team.capacity":
            "Carga prevista por persona sin inventar disponibilidad."
        case "team.assignments":
            "Módulos, dedicación y responsables confirmados del proyecto."
        case "team.pending":
            "Roles que necesitan cobertura o una excepción documentada."
        default:
            "Cobertura, capacidad y asignaciones basadas en datos reales."
        }
    }
}

private struct MemberRow: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.tazkleHighContrast) private var highContrast
    let member: OrganizationMember

    var body: some View {
        HStack(spacing: TazkleSpacing.medium) {
            ZStack {
                Circle()
                    .fill(TazkleColors.relationship.opacity(0.16))
                    .frame(width: 36, height: 36)
                Text(initials)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(TazkleColors.relationship)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(member.displayName ?? "Sin nombre")
                    .font(.callout.weight(.semibold))
                if member.status != .active {
                    Text(member.status.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(member.role.displayName)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, TazkleSpacing.medium)
                .padding(.vertical, TazkleSpacing.xSmall)
                .background(
                    TazkleColors.elevated(for: colorScheme, highContrast: highContrast)
                )
                .clipShape(Capsule())
        }
        .padding(.vertical, TazkleSpacing.medium)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(member.displayName ?? "Sin nombre"), \(member.role.displayName)\(member.status != .active ? ", \(member.status.displayName)" : "")")
    }

    private var initials: String {
        let name = member.displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let name, !name.isEmpty else { return "?" }
        let parts = name.split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first }
        return String(letters).uppercased()
    }
}
