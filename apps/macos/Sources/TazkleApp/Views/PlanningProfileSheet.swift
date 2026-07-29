import SwiftUI
import TazkleDesignSystem
import TazkleDomain

struct PlanningProfileSheet: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.tazkleHighContrast) private var highContrast

    @State private var draft: ProjectPlanningProfile

    init(profile: ProjectPlanningProfile) {
        _draft = State(initialValue: profile)
    }

    private var assessment: ProjectPlanningAssessment? {
        try? ProjectPlanningEngine.assess(
            graph: appState.graph,
            profile: draft
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            Form {
                Section("Definición del proyecto") {
                    narrativeField(
                        title: "Problema",
                        prompt: "¿Qué necesidad concreta debe resolver el producto?",
                        text: $draft.problemStatement
                    )
                    narrativeField(
                        title: "Objetivo",
                        prompt: "¿Qué resultado observable debe alcanzar?",
                        text: $draft.objective
                    )
                    narrativeField(
                        title: "Resultado del análisis de mercado",
                        prompt: "Resume entrevistas, competidores, demanda o evidencia disponible.",
                        text: $draft.marketEvidence
                    )
                }

                Section("Tiempo, capacidad y presupuesto") {
                    numericField(
                        title: "Duración objetivo",
                        suffix: "semanas",
                        value: $draft.targetWeeks
                    )
                    numericField(
                        title: "Capacidad disponible",
                        suffix: "h/sem",
                        value: $draft.teamWeeklyCapacityHours
                    )
                    numericField(
                        title: "Presupuesto disponible",
                        suffix: "MXN",
                        value: $draft.availableBudgetMXN
                    )
                }

                Section("Horas y tarifas internas") {
                    Text("Estas cifras alimentan el costo interno. El precio propuesto se calcula por separado.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Grid(
                        alignment: .leading,
                        horizontalSpacing: TazkleSpacing.large,
                        verticalSpacing: TazkleSpacing.small
                    ) {
                        GridRow {
                            tableHeading("Rol")
                            tableHeading("Horas")
                            tableHeading("Tarifa por hora")
                            tableHeading("Subtotal")
                        }

                        ForEach($draft.roles) { $role in
                            GridRow {
                                Text(role.role.displayName)
                                    .font(.callout)

                                TextField(
                                    "Horas de \(role.role.displayName)",
                                    value: $role.plannedHours,
                                    format: .number
                                )
                                .labelsHidden()
                                .frame(width: 100)
                                .accessibilityLabel("Horas planeadas para \(role.role.displayName)")

                                TextField(
                                    "Tarifa de \(role.role.displayName)",
                                    value: $role.hourlyRateMXN,
                                    format: .number
                                )
                                .labelsHidden()
                                .frame(width: 130)
                                .accessibilityLabel("Tarifa por hora para \(role.role.displayName)")

                                Text(role.plannedCostMXN, format: .currency(code: "MXN"))
                                    .font(.callout.monospacedDigit())
                                    .frame(minWidth: 130, alignment: .trailing)
                            }
                        }
                    }
                }

                Section("Costos adicionales y política de precio") {
                    numericField(
                        title: "Costos fijos",
                        suffix: "MXN",
                        value: $draft.fixedCostsMXN
                    )
                    numericField(
                        title: "Servicios periódicos",
                        suffix: "MXN/mes",
                        value: $draft.monthlyServicesMXN
                    )
                    numericField(
                        title: "Reserva de riesgo",
                        suffix: "%",
                        value: $draft.riskReservePercent
                    )
                    numericField(
                        title: "Margen para cliente",
                        suffix: "%",
                        value: $draft.clientMarginPercent
                    )
                }

                if let assessment {
                    Section("Vista previa calculada") {
                        LabeledContent("Horas planeadas") {
                            Text("\(assessment.totalHours) h")
                                .monospacedDigit()
                        }
                        LabeledContent("Carga semanal requerida") {
                            Text("\(assessment.weeklyHoursRequired) h/sem")
                                .monospacedDigit()
                        }
                        LabeledContent("Costo interno") {
                            Text(moneyRange(assessment.internalCost))
                                .monospacedDigit()
                        }
                        LabeledContent("Precio propuesto") {
                            Text(moneyRange(assessment.clientPrice))
                                .monospacedDigit()
                        }
                        LabeledContent("Resultado") {
                            Text(assessment.overall.displayName)
                        }
                    }
                } else {
                    Section {
                        Label(
                            "Revisa los valores: hay datos fuera de los rangos permitidos.",
                            systemImage: "exclamationmark.triangle"
                        )
                        .foregroundStyle(TazkleColors.warning)
                    }
                }
            }
            .formStyle(.grouped)

            Divider()
            footer
        }
        .frame(width: 820, height: 780)
        .background(
            TazkleColors.canvas(
                for: colorScheme,
                highContrast: highContrast
            )
        )
    }

    private var header: some View {
        HStack(spacing: TazkleSpacing.medium) {
            ZStack {
                Circle()
                    .fill(TazkleColors.relationship.opacity(0.16))
                    .frame(width: 42, height: 42)
                Image(systemName: "slider.horizontal.3")
                    .foregroundStyle(TazkleColors.relationship)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("Datos para factibilidad y cotización")
                    .font(.title3.weight(.semibold))
                Text("\(appState.graph.name) · guardado localmente")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            ProjectStatusPill(
                title: appState.saveState.title,
                systemImage: appState.saveState.systemImage,
                color: appState.saveState == .failed
                    ? TazkleColors.warning
                    : TazkleColors.success
            )
        }
        .padding(TazkleSpacing.xLarge)
    }

    private var footer: some View {
        HStack {
            Label(
                "La evaluación es determinista y no constituye una aprobación.",
                systemImage: "person.badge.shield.checkmark"
            )
            .font(.caption)
            .foregroundStyle(.secondary)

            Spacer()

            Button("Cancelar", role: .cancel) {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)

            Button("Guardar y recalcular") {
                _ = appState.updatePlanningProfile(draft)
            }
            .buttonStyle(.borderedProminent)
            .tint(TazkleColors.relationship)
            .keyboardShortcut(.defaultAction)
            .disabled(assessment == nil)
        }
        .padding(TazkleSpacing.large)
    }

    private func narrativeField(
        title: String,
        prompt: String,
        text: Binding<String>
    ) -> some View {
        VStack(alignment: .leading, spacing: TazkleSpacing.small) {
            Text(title)
                .font(.callout.weight(.semibold))
            TextEditor(text: text)
                .font(.body)
                .frame(minHeight: 68)
                .padding(TazkleSpacing.small)
                .background(
                    TazkleColors.elevated(
                        for: colorScheme,
                        highContrast: highContrast
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: TazkleRadius.control))
                .overlay(alignment: .topLeading) {
                    if text.wrappedValue.isEmpty {
                        Text(prompt)
                            .font(.body)
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, TazkleSpacing.medium)
                            .padding(.vertical, 14)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                }
                .accessibilityLabel(title)
                .accessibilityHint(prompt)
        }
    }

    private func numericField(
        title: String,
        suffix: String,
        value: Binding<Int>
    ) -> some View {
        LabeledContent(title) {
            HStack(spacing: TazkleSpacing.small) {
                TextField(title, value: value, format: .number)
                    .labelsHidden()
                    .multilineTextAlignment(.trailing)
                    .frame(width: 130)
                    .accessibilityLabel(title)
                Text(suffix)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(width: 74, alignment: .leading)
            }
        }
    }

    private func tableHeading(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
    }

    private func moneyRange(_ range: MoneyRange) -> String {
        "\(money(range.lowerBound)) – \(money(range.upperBound))"
    }

    private func money(_ value: Int) -> String {
        value.formatted(.currency(code: "MXN").precision(.fractionLength(0)))
    }
}
