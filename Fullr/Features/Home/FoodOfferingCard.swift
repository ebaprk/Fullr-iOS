import SwiftUI

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

struct FoodOfferingCard: View {
    let offering: FoodOffering

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ProviderBadge(providerType: offering.providerType)

            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(offering.title)
                            .font(.headline)
                            .lineLimit(2)

                        Text(offering.providerName)
                            .font(.subheadline)
                            .foregroundStyle(FullrPalette.olive)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 8)

                    Text(offering.badgeText)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(FullrPalette.cream, in: Capsule())
                        .foregroundStyle(FullrPalette.pine)
                }

                Text(offering.description)
                    .font(.subheadline)
                    .foregroundStyle(FullrPalette.moss)
                    .lineLimit(2)

                HStack(spacing: 10) {
                    Label(offering.pickupWindow, systemImage: "clock")
                    Label(offering.quantityDescription, systemImage: "takeoutbag.and.cup.and.straw")
                }
                .font(.caption)
                .foregroundStyle(FullrPalette.moss)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

                DietaryTagRow(tags: offering.dietaryTags)
            }
        }
        .padding(14)
        .background(FullrPalette.cream, in: RoundedRectangle(cornerRadius: 8))
    }
}

struct FeaturedOfferingCard: View {
    let offering: FoodOffering

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(FullrPalette.gold)
                    .frame(height: 128)

                HillArtwork()

                VStack(alignment: .leading, spacing: 10) {
                    Image(systemName: offering.providerType.systemImageName)
                        .font(.title2)
                        .frame(width: 42, height: 42)
                        .background(FullrPalette.cream, in: RoundedRectangle(cornerRadius: 8))
                        .foregroundStyle(FullrPalette.pine)

                    Spacer()

                    Text(offering.providerType.displayName)
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(FullrPalette.cream, in: Capsule())
                        .foregroundStyle(FullrPalette.pine)
                }
                .padding(12)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(offering.title)
                        .font(.headline)
                        .lineLimit(2)

                    Spacer()

                    Text(offering.badgeText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(FullrPalette.gold)
                }

                Text(offering.providerName)
                    .font(.subheadline)
                    .foregroundStyle(FullrPalette.moss)
                    .lineLimit(1)

                Label(offering.pickupWindow, systemImage: "clock.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(FullrPalette.pine)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .background(FullrPalette.cream, in: RoundedRectangle(cornerRadius: 8))
    }
}

extension FoodOffering {
    var badgeText: String {
        distanceInMiles > 0 ? String(format: "%.1f mi", distanceInMiles) : providerType.displayName
    }
}

private struct ProviderBadge: View {
    let providerType: ProviderType

    var body: some View {
        Image(systemName: providerType.systemImageName)
            .font(.title3)
            .frame(width: 54, height: 54)
            .background(FullrPalette.moss, in: RoundedRectangle(cornerRadius: 8))
            .foregroundStyle(FullrPalette.cream)
    }
}

private struct DietaryTagRow: View {
    let tags: [DietaryTag]

    var body: some View {
        if !tags.isEmpty {
            ScrollView(.horizontal) {
                HStack(spacing: 6) {
                    ForEach(tags) { tag in
                        Text(tag.displayName)
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(FullrPalette.moss, in: Capsule())
                            .foregroundStyle(FullrPalette.cream)
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }
}

struct HillArtwork: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            FullrPalette.olive

            UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 8, bottomTrailingRadius: 8, topTrailingRadius: 0)
                .fill(FullrPalette.ink)
                .frame(height: 72)
                .offset(y: 32)

            UnevenRoundedRectangle(topLeadingRadius: 80, bottomLeadingRadius: 8, bottomTrailingRadius: 8, topTrailingRadius: 80)
                .fill(FullrPalette.pine)
                .frame(height: 82)
                .offset(x: 70, y: 42)

            UnevenRoundedRectangle(topLeadingRadius: 120, bottomLeadingRadius: 8, bottomTrailingRadius: 8, topTrailingRadius: 20)
                .fill(FullrPalette.moss)
                .frame(height: 62)
                .offset(x: -84, y: 46)
        }
        .clipped()
    }
}
