import SwiftUI

struct CalculationMethodView: View {
    @Binding var selectedMethod: CalculationMethod
    @Binding var selectedAsrMethod: AsrJuristicMethod

    let onConfirm: () -> Void
    let onBack: () -> Void             // US-0027

    var body: some View {
        VStack(spacing: 0) {

            // ── Step indicator (US-0027) ────────────────────────────
            StepIndicator(current: 2, total: 2)
                .padding(.top, 28)
                .padding(.bottom, 4)

            VStack(spacing: 20) {
                Text("Calculation Settings")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Select the calculation method used in your region.")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .font(.subheadline)

                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Calculation Method")
                            .font(.headline)
                        Text("Different organisations use different angles for Fajr and Isha.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Picker("Calculation Method", selection: $selectedMethod) {
                            ForEach(CalculationMethod.allCases) { method in
                                Text(method.displayName).tag(method)
                            }
                        }
                        .labelsHidden()
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Asr Calculation")
                            .font(.headline)
                        Text("The Hanafi school uses a different shadow length calculation.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Picker("Asr Method", selection: $selectedAsrMethod) {
                            ForEach(AsrJuristicMethod.allCases) { method in
                                Text(method.displayName).tag(method)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.radioGroup)
                    }
                }
                .frame(maxWidth: 400)
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .padding(.horizontal, 32)
            .padding(.top, 16)

            Spacer()

            // ── Navigation buttons ──────────────────────────────────
            HStack {
                Button(action: onBack) {
                    Label("Back", systemImage: "chevron.left")
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Spacer()

                Button(action: onConfirm) {
                    Text("Continue")
                        .frame(minWidth: 100)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 28)
        }
        .frame(minWidth: 450, minHeight: 420)
    }
}
