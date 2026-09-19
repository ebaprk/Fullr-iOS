import Foundation

struct AppUser: Identifiable, Equatable {
    let id: UUID
    let name: String
    let email: String
    let schoolName: String?

    static let preview = AppUser(id: UUID(), name: "Abe Park", email: "abe@example.edu", schoolName: "Fullr University")
}
