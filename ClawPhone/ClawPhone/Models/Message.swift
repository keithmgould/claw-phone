import Foundation

struct Message: Identifiable {
    let id = UUID()
    let role: String
    let content: String
    let timestamp = Date()

    func toDict() -> [String: String] {
        ["role": role, "content": content]
    }
}
