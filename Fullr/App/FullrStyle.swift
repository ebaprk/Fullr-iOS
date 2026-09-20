import CoreText
import SwiftUI

/// The shared palette stays within the six project colors. Cream carries most
/// surfaces, with the deeper greens reserved for type and small accents.
enum FullrPalette {
    static let cream = Color(hex: 0xFFF8D9)
    static let gold = Color(hex: 0xAD8820)
    static let olive = Color(hex: 0x90844A)
    static let moss = Color(hex: 0x444F24)
    static let ink = Color(hex: 0x212413)
    static let pine = Color(hex: 0x122311)
}

private extension Color {
    init(hex: UInt) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

enum FullrFont {
    // Register lazily so the bundled font also works in standalone previews.
    private static let register: Void = {
        let fontURL = Bundle.main.url(forResource: "Outfit", withExtension: "ttf")
            ?? Bundle.main.url(forResource: "Outfit", withExtension: "ttf", subdirectory: "Fonts")
        guard let url = fontURL else {
            assertionFailure("The bundled Outfit font is missing")
            return
        }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }()

    static func regular(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        register
        return .custom("Outfit-Regular", size: size, relativeTo: style)
    }

    static func medium(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        register
        return .custom("Outfit-Medium", size: size, relativeTo: style)
    }

    static func semibold(_ size: CGFloat, relativeTo style: Font.TextStyle = .headline) -> Font {
        register
        return .custom("Outfit-SemiBold", size: size, relativeTo: style)
    }
}

struct FullrWordmark: View {
    var size: CGFloat = 34

    var body: some View {
        HStack(alignment: .center, spacing: 6) {
            Text("fullr")
                .font(FullrFont.semibold(size, relativeTo: .largeTitle))
                .tracking(-1.8)
            Image("logo")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
        }
        .foregroundStyle(FullrPalette.pine)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Fullr")
    }
}

struct FullrPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

struct FullrPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(FullrFont.semibold(16))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .foregroundStyle(FullrPalette.cream)
            .background(isEnabled ? FullrPalette.moss : FullrPalette.olive, in: Capsule())
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
    }
}

struct FullrDistancePicker: View {
    let selectedDistance: Double
    let onSelect: (Double) -> Void

    var body: some View {
        HStack(spacing: 4) {
            ForEach(OfferingFilter.distanceOptionsInMiles, id: \.self) { distance in
                Button { onSelect(distance) } label: {
                    Text("\(Int(distance)) mi")
                        .font(FullrFont.medium(14, relativeTo: .subheadline))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundStyle(selectedDistance == distance ? FullrPalette.cream : FullrPalette.moss)
                        .background(selectedDistance == distance ? FullrPalette.moss : FullrPalette.cream, in: Capsule())
                }
                .buttonStyle(FullrPressStyle())
                .accessibilityLabel("Within \(Int(distance)) \(distance == 1 ? "mile" : "miles")")
                .accessibilityAddTraits(selectedDistance == distance ? .isSelected : [])
            }
        }
        .padding(4)
        .background(FullrPalette.cream, in: Capsule())
        .overlay { Capsule().strokeBorder(FullrPalette.olive, lineWidth: 1) }
    }
}

struct FullrEmptyState: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(FullrFont.regular(30, relativeTo: .title))
                .foregroundStyle(FullrPalette.moss)
                .padding(.bottom, 4)
            Text(title)
                .font(FullrFont.semibold(22, relativeTo: .title2))
                .foregroundStyle(FullrPalette.pine)
            Text(message)
                .font(FullrFont.regular(15, relativeTo: .subheadline))
                .foregroundStyle(FullrPalette.moss)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
    }
}

struct FullrToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button { configuration.isOn.toggle() } label: {
            HStack(spacing: 20) {
                configuration.label
                    .frame(maxWidth: .infinity, alignment: .leading)
                Capsule()
                    .fill(configuration.isOn ? FullrPalette.moss : FullrPalette.olive)
                    .frame(width: 48, height: 30)
                    .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                        Circle()
                            .fill(FullrPalette.cream)
                            .frame(width: 22, height: 22)
                            .padding(4)
                    }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(FullrPressStyle())
        .accessibilityValue(configuration.isOn ? "On" : "Off")
        .accessibilityAddTraits(.isToggle)
    }
}
