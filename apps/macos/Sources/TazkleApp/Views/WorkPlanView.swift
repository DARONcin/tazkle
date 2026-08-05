import SwiftUI
import TazkleDesignSystem

struct WorkPlanView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.tazkleHighContrast) private var highContrast

    private var destinationID: String {
        appState.selectedDestinationID ?? "work.summary"
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: TazkleSpacing.xLarge) {
                ProjectSectionHeader(
                    title: appState.selectedDestination?.title ?? "Plan de trabajo",
                    subtitle: subtitle,
                    systemImage: "calendar",
                    accent: TazkleColors.actionPrimary,
                    trailingTitle: destinationID == "work.summary" ? "Abrir tablero" : nil,
                    trailingAction: destinationID == "work.summary" ? {
                        appState.selectDestination(WorkPrototype.destination("work.board"))
                    } : nil
                )

                switch destinationID {
                case "work.calendar":
                    WorkCalendarView()
                case "work.board":
                    WorkBoardView()
                case "work.backlog":
                    WorkBacklogView()
                case "work.deliverables":
                    WorkDeliverablesView()
                case "work.approvals":
                    WorkApprovalsView()
                default:
                    WorkPlanDashboardView()
                }
            }
            .padding(TazkleSpacing.xLarge)
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
        case "work.calendar": "Dependencias y duración por semana, sin mezclar el tablero."
        case "work.board": "Trabajo por estado con movimiento accesible entre columnas."
        case "work.backlog": "Elementos priorizados que todavía no pertenecen a un sprint."
        case "work.deliverables": "Resultado esperado, compromiso y evidencia de aceptación."
        case "work.approvals": "Revisiones pendientes y responsables de cada entrega."
        default: "Objetivo, capacidad y siguiente trabajo del sprint actual."
        }
    }
}

private struct WorkPlanDashboardView: View {
    var body: some View {
        SectionUnavailableView(
            title: "Plan de trabajo pendiente",
            detail: "El objetivo, la capacidad y el trabajo activo del sprint todavía no existen como dominio real en Project Core."
        )
    }
}

private struct WorkCalendarView: View {
    var body: some View {
        SectionUnavailableView(
            title: "Calendario pendiente",
            detail: "Las dependencias y la duración por semana todavía no existen como dominio real en Project Core."
        )
    }
}

private struct WorkBoardView: View {
    var body: some View {
        SectionUnavailableView(
            title: "Tablero pendiente",
            detail: "El trabajo por estado con movimiento entre columnas todavía no existe como dominio real en Project Core."
        )
    }
}

private struct WorkBacklogView: View {
    var body: some View {
        SectionUnavailableView(
            title: "Backlog pendiente",
            detail: "Los elementos priorizados que todavía no pertenecen a un sprint no existen como dominio real en Project Core."
        )
    }
}

private struct WorkDeliverablesView: View {
    var body: some View {
        SectionUnavailableView(
            title: "Entregables pendientes",
            detail: "El resultado esperado, compromiso y evidencia de aceptación todavía no existen como dominio real en Project Core."
        )
    }
}

private struct WorkApprovalsView: View {
    var body: some View {
        SectionUnavailableView(
            title: "Aprobaciones pendientes",
            detail: "Las revisiones pendientes y responsables de cada entrega todavía no existen como dominio real en Project Core."
        )
    }
}

private enum WorkPrototype {
    static func destination(_ id: String) -> SectionDestination {
        AppSection.workPlan.contextualDestinations.first { $0.id == id }
            ?? AppSection.workPlan.contextualDestinations[0]
    }
}
