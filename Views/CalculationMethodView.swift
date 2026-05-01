import SwiftUI

/// Calculation method selection screen - second step of onboarding
/// Allows user to choose Islamic prayer time calculation method and Asr juristic method
struct CalculationMethodView: View {
    @Binding var selectedMethod: CalculationMethod
    @Binding var selectedAsrMethod: AsrJuristicMethod
    
    let onComplete: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "gearshape.2.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(red: 0.95, green: 0.76, blue: 0.06),
                                Color(red: 0.85, green: 0.65, blue: 0.13)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .padding(.top, 40)
                
                Text("Calculation Method")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Choose the calculation method used by your local mosque")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(.bottom, 30)
            
            // Scrollable content
            ScrollView {
                VStack(spacing: 24) {
                    // Prayer Times Calculation Method
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Prayer Times Calculation")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        VStack(spacing: 8) {
                            ForEach(CalculationMethod.allCases) { method in
                                CalculationMethodRow(
                                    method: method,
                                    isSelected: selectedMethod == method
                                ) {
                                    selectedMethod = method
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    Divider()
                        .padding(.vertical, 8)
                    
                    // Asr Calculation Method
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Asr Time Calculation")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        Text("The Asr prayer can be calculated using two different juristic methods, which may result in slightly different times.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                        
                        VStack(spacing: 8) {
                            ForEach(AsrJuristicMethod.allCases) { asrMethod in
                                AsrMethodRow(
                                    method: asrMethod,
                                    isSelected: selectedAsrMethod == asrMethod
                                ) {
                                    selectedAsrMethod = asrMethod
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            
            // Continue Button
            Button(action: onComplete) {
                HStack {
                    Text("Complete Setup")
                        .font(.headline)
                    Image(systemName: "checkmark")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accentColor)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 30)
            .padding(.vertical, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

// MARK: - Calculation Method Row

struct CalculationMethodRow: View {
    let method: CalculationMethod
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Selection indicator
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: 2)
                        .frame(width: 24, height: 24)
                    
                    if isSelected {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 14, height: 14)
                    }
                }
                
                // Method info
                VStack(alignment: .leading, spacing: 4) {
                    Text(method.displayName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text(methodDescription(for: method))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.accentColor.opacity(0.1) : Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
    
    private func methodDescription(for method: CalculationMethod) -> String {
        switch method {
        case .muslimWorldLeague:
            return "Fajr: 18° | Isha: 17° • Widely used in Europe, Americas, parts of Asia"
        case .isna:
            return "Fajr: 15° | Isha: 15° • Used in North America"
        case .egypt:
            return "Fajr: 19.5° | Isha: 17.5° • Used in Africa, Syria, Iraq, Lebanon, Malaysia"
        case .ummAlQura:
            return "Fajr: 18.5° | Isha: 90 min after Maghrib • Used in Saudi Arabia"
        case .karachi:
            return "Fajr: 18° | Isha: 18° • Used in Pakistan, Bangladesh, India, Afghanistan"
        case .tehran:
            return "Fajr: 17.7° | Isha: 14° | Maghrib: 4.5° • Used in Iran, some Shia communities"
        }
    }
}

// MARK: - Asr Method Row

struct AsrMethodRow: View {
    let method: AsrJuristicMethod
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Selection indicator
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: 2)
                        .frame(width: 24, height: 24)
                    
                    if isSelected {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 14, height: 14)
                    }
                }
                
                // Method info
                VStack(alignment: .leading, spacing: 4) {
                    Text(method.displayName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text(asrMethodDescription(for: method))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.accentColor.opacity(0.1) : Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
    
    private func asrMethodDescription(for method: AsrJuristicMethod) -> String {
        switch method {
        case .standard:
            return "Shadow = object length • Shafi'i, Maliki, Hanbali schools"
        case .hanafi:
            return "Shadow = 2× object length • Hanafi school (later time)"
        }
    }
}

// MARK: - Preview

#Preview {
    CalculationMethodView(
        selectedMethod: .constant(.muslimWorldLeague),
        selectedAsrMethod: .constant(.standard)
    ) {
        print("Setup complete")
    }
}
