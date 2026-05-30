import Foundation

@MainActor
final class WhisperTranscriber {
    private let binaryName = "whisper-cli"
    private let modelName = "ggml-small.bin"

    var resourceDirectory: URL? {
        if let url = Bundle.main.resourceURL {
            return url
        }
        return Bundle.module.resourceURL
    }

    var binaryURL: URL? {
        locateResource(named: binaryName, subdirectory: "bin")
    }

    var modelURL: URL? {
        locateResource(named: modelName, subdirectory: "Models")
    }

    func transcribe(audioURL: URL, language: String) async throws -> String {
        guard let binaryURL else {
            throw WhisperError.missingBinary(expectedName: binaryName)
        }
        guard let modelURL else {
            throw WhisperError.missingModel(expectedName: modelName)
        }

        do {
            return try await runWhisper(binaryURL: binaryURL, modelURL: modelURL, audioURL: audioURL, language: language, noGPU: false)
        } catch {
            return try await runWhisper(binaryURL: binaryURL, modelURL: modelURL, audioURL: audioURL, language: language, noGPU: true)
        }
    }

    private func locateResource(named name: String, subdirectory: String) -> URL? {
        let candidates = [
            Bundle.main.url(forResource: name, withExtension: nil, subdirectory: subdirectory),
            Bundle.main.url(forResource: name, withExtension: nil, subdirectory: "Resources/\(subdirectory)"),
            Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Resources/\(subdirectory)")
        ]
        return candidates.compactMap { $0 }.first { FileManager.default.fileExists(atPath: $0.path) }
    }

    private func runWhisper(
        binaryURL: URL,
        modelURL: URL,
        audioURL: URL,
        language: String,
        noGPU: Bool
    ) async throws -> String {
        let outputBase = FileManager.default.temporaryDirectory
            .appendingPathComponent("voicetyper-\(UUID().uuidString)")

        return try await Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = binaryURL

            var arguments = [
                "-m", modelURL.path,
                "-f", audioURL.path,
                "-l", language,
                "-otxt",
                "-of", outputBase.path,
                "-nt"
            ]
            if noGPU {
                arguments.append("-ng")
            }
            process.arguments = arguments

            let errorPipe = Pipe()
            process.standardError = errorPipe
            try process.run()
            process.waitUntilExit()

            let outputURL = outputBase.appendingPathExtension("txt")
            defer { try? FileManager.default.removeItem(at: outputURL) }

            guard process.terminationStatus == 0 else {
                let data = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let message = String(data: data, encoding: .utf8) ?? "whisper-cli 运行失败"
                throw WhisperError.processFailed(message)
            }

            guard FileManager.default.fileExists(atPath: outputURL.path) else {
                throw WhisperError.missingOutput
            }

            return try String(contentsOf: outputURL, encoding: .utf8)
        }.value
    }
}

enum WhisperError: LocalizedError {
    case missingBinary(expectedName: String)
    case missingModel(expectedName: String)
    case missingOutput
    case processFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingBinary(let expectedName):
            "缺少 \(expectedName)，请先运行 Scripts/bootstrap_whisper.sh"
        case .missingModel(let expectedName):
            "缺少 \(expectedName)，请先运行 Scripts/bootstrap_whisper.sh"
        case .missingOutput:
            "Whisper 没有生成转写结果"
        case .processFailed(let message):
            "Whisper 转写失败：\(message)"
        }
    }
}
