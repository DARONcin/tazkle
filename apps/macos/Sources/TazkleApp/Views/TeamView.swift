import SwiftUI
import TazkleDesignSystem

struct TeamView: View {
    @EnvironmentObject private var appState: AppState
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
                    contextBadgeTitle: "Sin datos conectados",
                    contextBadgeSystemImage: "externaldrive.badge.questionmark",
                    contextBadgeHelp: "El equipo aparecerá cuando Project Core entregue miembros, roles y capacidad reales."
                )

                ProjectSectionCard(
                    title: "Todavía no hay datos de equipo",
                    systemImage: "person.2.slash"
                ) {
                    Label(
                        "Tazkle no mostrará personas, roles, horas ni asignaciones de ejemplo.",
                        systemImage: "checkmark.shield"
                    )
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(TazkleColors.success)

                    Text(emptyStateDetail)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack {
                        ProjectStatusPill(
                            title: "Sin datos conectados",
                            systemImage: "person.crop.circle.badge.questionmark",
                            color: TazkleColors.relationship
                        )
                        Spacer()
                        Button("Revisar cuenta") {
                            appState.selectSection(.settings)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .frame(maxWidth: 760)
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

    private var emptyStateDetail: String {
        switch destinationID {
        case "team.coverage":
            "La cobertura aparecerá cuando la organización y sus responsabilidades se sincronicen con Project Core."
        case "team.capacity":
            "La capacidad se calculará cuando existan miembros, disponibilidad y asignaciones confirmadas."
        case "team.assignments":
            "Las asignaciones aparecerán cuando un miembro real sea responsable de un bloque o una tarea."
        case "team.pending":
            "Las brechas se detectarán a partir de los roles requeridos por el proyecto y de las personas disponibles."
        default:
            "Conecta una organización para calcular cobertura, carga y asignaciones. Mientras tanto puedes seguir trabajando en modo local."
        }
    }
}
