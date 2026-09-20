import SwiftUI
import Kingfisher

struct FoodOfferingCard: View {
    let offering: FoodOffering
    var isCompact = false
    var showsClaimedStatus = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if showsClaimedStatus {
                Label("Claimed by you", systemImage: "checkmark.circle.fill")
                    .font(FullrFont.medium(13))
                    .foregroundStyle(FullrPalette.moss)
            }
            HStack(alignment: .top, spacing: 14) {
                OfferingImage(offering: offering)
                    .frame(width: isCompact ? 64 : 82, height: isCompact ? 68 : 88)
                    .clipShape(RoundedRectangle(cornerRadius: 17))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 5) {
                    Text(offering.providerName)
                        .font(FullrFont.regular(12, relativeTo: .caption))
                        .foregroundStyle(FullrPalette.moss)
                        .lineLimit(2)
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(offering.title)
                            .font(FullrFont.semibold(18))
                            .foregroundStyle(FullrPalette.pine)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                        PriceText(offering: offering)
                    }
                    Text(offering.badgeText)
                        .font(FullrFont.medium(12, relativeTo: .caption))
                        .foregroundStyle(FullrPalette.moss)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if !isCompact {
                Text(offering.description)
                    .font(FullrFont.regular(14, relativeTo: .subheadline))
                    .foregroundStyle(FullrPalette.moss)
                    .lineLimit(2)
            }

            VStack(alignment: .leading, spacing: 6) {
                Label(offering.pickupWindow, systemImage: "clock")
                if !isCompact { Label(offering.quantityDescription, systemImage: "basket") }
            }
            .font(FullrFont.regular(12, relativeTo: .caption))
            .foregroundStyle(FullrPalette.moss)
            .fixedSize(horizontal: false, vertical: true)

            if !isCompact { DietaryTagRow(tags: offering.dietaryTags) }
        }
        .padding(16)
        .background(FullrPalette.cream, in: RoundedRectangle(cornerRadius: 24))
        .overlay { RoundedRectangle(cornerRadius: 24).strokeBorder(FullrPalette.olive, lineWidth: 1) }
        .accessibilityElement(children: .combine)
    }
}

struct FeaturedOfferingCard: View {
    let offering: FoodOffering

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OfferingImage(offering: offering)
                .frame(height: 154)
                .clipped()
                .overlay(alignment: .topLeading) {
                    Label(offering.providerType.displayName, systemImage: offering.providerType.systemImageName)
                        .font(FullrFont.medium(11, relativeTo: .caption2))
                        .padding(.horizontal, 11)
                        .padding(.vertical, 7)
                        .foregroundStyle(FullrPalette.pine)
                        .background(FullrPalette.cream, in: Capsule())
                        .padding(12)
                }
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(offering.providerName)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    PriceText(offering: offering)
                }
                .font(FullrFont.regular(12, relativeTo: .caption))
                .foregroundStyle(FullrPalette.moss)

                Text(offering.title)
                    .font(FullrFont.semibold(20, relativeTo: .title3))
                    .tracking(-0.4)
                    .foregroundStyle(FullrPalette.pine)
                    .lineLimit(2, reservesSpace: true)

                Label(offering.pickupWindow, systemImage: "clock")
                    .font(FullrFont.regular(12, relativeTo: .caption))
                    .foregroundStyle(FullrPalette.moss)
                    .fixedSize(horizontal: false, vertical: true)

                Text(offering.badgeText)
                    .font(FullrFont.medium(12, relativeTo: .caption))
                    .foregroundStyle(FullrPalette.moss)
            }
            .padding(16)
        }
        .background(FullrPalette.cream)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay { RoundedRectangle(cornerRadius: 24).strokeBorder(FullrPalette.olive, lineWidth: 1) }
        .accessibilityElement(children: .combine)
    }
}

private struct PriceText: View {
    let offering: FoodOffering

    var body: some View {
        Text(offering.priceText)
            .font(FullrFont.medium(13, relativeTo: .caption))
            .foregroundStyle(FullrPalette.moss)
            .lineLimit(1)
            .fixedSize()
            .accessibilityLabel("Price \(offering.priceText)")
    }
}

extension FoodOffering {
    var badgeText: String {
        distanceInMiles > 0 ? String(format: "%.1f mi", distanceInMiles) : providerType.displayName
    }
}

struct OfferingImage: View {
    let offering: FoodOffering

    var body: some View {
        GeometryReader { geometry in
            KFImage(offering.imageURL)
                .placeholder {
                    ZStack {
                        FullrPalette.olive
                        Image(systemName: offering.providerType.systemImageName)
                            .font(FullrFont.regular(32, relativeTo: .title))
                            .foregroundStyle(FullrPalette.cream)
                    }
                }
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
        }
    }
}

struct DietaryTagRow: View {
    let tags: [DietaryTag]

    var body: some View {
        if !tags.isEmpty {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(tags) { tag in
                        Text(tag.displayName)
                            .font(FullrFont.medium(11, relativeTo: .caption2))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .foregroundStyle(FullrPalette.moss)
                            .overlay { Capsule().strokeBorder(FullrPalette.olive, lineWidth: 1) }
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }
}
