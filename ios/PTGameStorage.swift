
import Foundation

enum PTGameStorage {

    static let requiredFiles = [
        "chunk1.psarc",
        "texture.qar",
        "pathid_list_ps4.bin"
    ]

    static var documentsURL: URL {
        FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0]
    }

    static var gameURL: URL {
        documentsURL.appendingPathComponent(
            "Game",
            isDirectory: true
        )
    }

    // Create the visible game folder and its README marker.
    static func prepareFolders() throws {
        let fm = FileManager.default

        try fm.createDirectory(
            at: gameURL,
            withIntermediateDirectories: true
        )

        let readmeURL = gameURL.appendingPathComponent("README.txt")

        if !fm.fileExists(atPath: readmeURL.path) {
            let instructions = """
            P.T. GAME DATA

            Copy these three files directly into this folder:

            chunk1.psarc
            texture.qar
            pathid_list_ps4.bin

            Restart P.T. after copying the files.
            """

            try instructions.write(
                to: readmeURL,
                atomically: true,
                encoding: .utf8
            )
        }
    }

    // Check that all three files exist and are non-empty.
    static func containsGameData(at folder: URL) -> Bool {
        requiredFiles.allSatisfy { name in
            let file = folder.appendingPathComponent(name)
            var isDirectory: ObjCBool = false

            guard
                FileManager.default.fileExists(
                    atPath: file.path,
                    isDirectory: &isDirectory
                ),
                !isDirectory.boolValue,
                let values = try? file.resourceValues(
                    forKeys: [.fileSizeKey]
                ),
                let size = values.fileSize,
                size > 0
            else {
                return false
            }

            return true
        }
    }

    // Find the installed game data automatically.
    static func detectGameFolder() -> URL? {
        if containsGameData(at: gameURL) {
            return gameURL
        }

        if let bundledGame = Bundle.main.resourceURL?
            .appendingPathComponent("Game", isDirectory: true),
           containsGameData(at: bundledGame) {
            return bundledGame
        }

        return nil
    }
}
