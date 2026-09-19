import SwiftUI

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
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 8)

                    Text(String(format: "%.1f mi", offering.distanceInMiles))
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color(.secondarySystemGroupedBackground), in: Capsule())
                        .foregroundStyle(.secondary)
                }

                Text(offering.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                HStack(spacing: 10) {
                    Label(offering.pickupWindow, systemImage: "clock")
                    Label(offering.quantityDescription, systemImage: "takeoutbag.and.cup.and.straw")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

                DietaryTagRow(tags: offering.dietaryTags)
            }
        }
        .padding(14)
        .background(.white, in: RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
    }
}

struct FeaturedOfferingCard: View {
    let offering: FoodOffering

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(featureGradient)
                    .frame(height: 128)

                VStack(alignment: .leading, spacing: 10) {
                    Image(systemName: offering.providerType.systemImageName)
                        .font(.title2)
                        .frame(width: 42, height: 42)
                        .background(.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 8))

                    Spacer()

                    Text(offering.providerType.displayName)
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(.white.opacity(0.92), in: Capsule())
                }
                .padding(12)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(offering.title)
                        .font(.headline)
                        .lineLimit(2)

                    Spacer()

                    Text(String(format: "%.1f mi", offering.distanceInMiles))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Text(offering.providerName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Label(offering.pickupWindow, systemImage: "clock.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .background(.white, in: RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.07), radius: 12, y: 5)
    }

    private var featureGradient: LinearGradient {
        LinearGradient(
            colors: [Color.green.opacity(0.78), Color.teal.opacity(0.72)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct ProviderBadge: View {
    let providerType: ProviderType

    var body: some View {
        Image(systemName: providerType.systemImageName)
            .font(.title3)
            .frame(width: 54, height: 54)
            .background(Color.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
            .foregroundStyle(.green)
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
                            .background(.green.opacity(0.12), in: Capsule())
                            .foregroundStyle(.green)
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }
}
