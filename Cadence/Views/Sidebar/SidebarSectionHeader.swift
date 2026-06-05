import SwiftUI

struct SidebarSectionHeader: View {
    @Environment(\.colorScheme) private var colorScheme

    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .bold))
            .tracking(0.02 * 11)
            .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.4) : Color.black.opacity(0.4))
            .padding(.top, 16)
            .padding(.bottom, 4)
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
