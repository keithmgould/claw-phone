import SwiftUI

struct MessageBubbleView: View {
    let role: String
    let content: String
    var isPartial: Bool = false

    private var isUser: Bool { role == "user" }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: UIScreen.main.bounds.width * 0.25) }

            Text(content)
                .font(.body)
                .italic(isPartial)
                .foregroundColor(isPartial ? .secondary : .primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    isUser
                        ? Color.purple.opacity(isPartial ? 0.3 : 0.6)
                        : Color(.systemGray4).opacity(isPartial ? 0.5 : 1.0)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))

            if !isUser { Spacer(minLength: UIScreen.main.bounds.width * 0.25) }
        }
    }
}
