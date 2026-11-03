import Foundation

struct LocalBackupSnapshot: Codable, Identifiable, Equatable {
    let id: UUID
    let name: String
    let createdAt: Date
    let profileID: UUID
    let profileName: String
    let byteCount: Int
}

enum LocalBackupError: LocalizedError {
    case invalidName
    case missingBackup
    case invalidBackup

    var errorDescription: String? {
        switch self {
        case .invalidName: "Use a name of 1 to 80 characters."
        case .missingBackup: "That local backup is no longer available."
        case .invalidBackup: "This local backup could not be opened."
        }
    }
}

struct LocalBackupLibrary {
    let baseURL: URL
    private let files = FileManager.default

    private func profileDirectory(_ profileID: UUID) -> URL {
        baseURL.appendingPathComponent("local-backups", isDirectory: true)
            .appendingPathComponent(profileID.uuidString, isDirectory: true)
    }

    private func snapshotDirectory(_ id: UUID, profileID: UUID) -> URL {
        profileDirectory(profileID).appendingPathComponent(id.uuidString, isDirectory: true)
    }

    func list(profileID: UUID) throws -> [LocalBackupSnapshot] {
        let directory = profileDirectory(profileID)
        guard files.fileExists(atPath: directory.path) else { return [] }
        let folders = try files.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isDirectoryKey])
        return folders.compactMap { folder in
            guard let id = UUID(uuidString: folder.lastPathComponent),
                  let data = try? Data(contentsOf: folder.appendingPathComponent("info.json")),
                  let snapshot = try? JSONDecoder().decode(LocalBackupSnapshot.self, from: data),
                  snapshot.id == id, snapshot.profileID == profileID,
                  files.fileExists(atPath: folder.appendingPathComponent("backup.json").path)
            else { return nil }
            return snapshot
        }.sorted { $0.createdAt > $1.createdAt }
    }

    func create(name: String, profileID: UUID, profileName: String, data: Data) throws -> LocalBackupSnapshot {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (1...80).contains(cleanName.count) else { throw LocalBackupError.invalidName }
        guard (try? JSONDecoder().decode(StoredData.self, from: data)) != nil else {
            throw LocalBackupError.invalidBackup
        }
        let snapshot = LocalBackupSnapshot(id: UUID(), name: cleanName, createdAt: Date(),
                                           profileID: profileID, profileName: profileName,
                                           byteCount: data.count)
        let folder = snapshotDirectory(snapshot.id, profileID: profileID)
        try files.createDirectory(at: folder, withIntermediateDirectories: true)
        do {
            try data.write(to: folder.appendingPathComponent("backup.json"), options: .atomic)
            try JSONEncoder().encode(snapshot).write(to: folder.appendingPathComponent("info.json"), options: .atomic)
        } catch {
            try? files.removeItem(at: folder)
            throw error
        }
        return snapshot
    }

    func load(id: UUID, profileID: UUID) throws -> Data {
        let data = try loadRaw(id: id, profileID: profileID)
        guard (try? JSONDecoder().decode(StoredData.self, from: data)) != nil else {
            throw LocalBackupError.invalidBackup
        }
        return data
    }

    func loadRaw(id: UUID, profileID: UUID) throws -> Data {
        let folder = snapshotDirectory(id, profileID: profileID)
        guard let metadata = try? Data(contentsOf: folder.appendingPathComponent("info.json")),
              let snapshot = try? JSONDecoder().decode(LocalBackupSnapshot.self, from: metadata),
              snapshot.id == id, snapshot.profileID == profileID,
              let data = try? Data(contentsOf: folder.appendingPathComponent("backup.json"),
                                   options: .mappedIfSafe)
        else { throw LocalBackupError.missingBackup }
        return data
    }

    func delete(id: UUID, profileID: UUID) throws {
        let folder = snapshotDirectory(id, profileID: profileID)
        guard files.fileExists(atPath: folder.path) else { throw LocalBackupError.missingBackup }
        try files.removeItem(at: folder)
    }
}
