// Reads consecutive frames from the completed MP4s; never reconstructs game images.
import Foundation
import AVFoundation
import ImageIO

let args = CommandLine.arguments
guard args.count == 4 else { fatalError("Need A.mp4 B.mp4 new-output-directory") }
let folder = URL(fileURLWithPath: args[3], isDirectory: true)
guard !FileManager.default.fileExists(atPath: folder.path) else { fatalError("Fresh output required") }
try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
var rows: [[String: Any]] = []
for (mode, path) in zip(["physical", "shared"], [args[1], args[2]]) {
    let asset = AVURLAsset(url: URL(fileURLWithPath: path))
    let generator = AVAssetImageGenerator(asset: asset)
    generator.requestedTimeToleranceBefore = .zero
    generator.requestedTimeToleranceAfter = .zero
    for frame in 90...97 {
        var actual = CMTime.zero
        let image = try generator.copyCGImage(at: CMTime(value: Int64(frame), timescale: 60), actualTime: &actual)
        guard abs(CMTimeGetSeconds(actual) - Double(frame)/60.0) < 0.00001 else { fatalError("Wrong decoded timestamp") }
        let name = String(format: "%@-%04d.png", mode, frame)
        let output = folder.appendingPathComponent(name)
        let destination = CGImageDestinationCreateWithURL(output as CFURL, "public.png" as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { fatalError("PNG write failed") }
        rows.append(["mode": mode, "frame": frame, "seconds": CMTimeGetSeconds(actual),
                     "width": image.width, "height": image.height, "file": name])
    }
}
try JSONSerialization.data(withJSONObject: rows, options: [.prettyPrinted, .sortedKeys])
    .write(to: folder.appendingPathComponent("frames.json"))
print("DECODED: 16 consecutive frames from the two native MP4s")
