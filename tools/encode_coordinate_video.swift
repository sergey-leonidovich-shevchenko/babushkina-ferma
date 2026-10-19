// Кодирует последовательность нативных PNG без изменения размера через штатный AVFoundation macOS.
import Foundation
import AVFoundation
import CoreGraphics
import ImageIO

let args = CommandLine.arguments
guard (args.count == 4 || args.count == 5), let fps = Int32(args[3]), fps > 0 else {
    fatalError("Нужны каталог PNG, новый файл mp4, FPS и необязательный bitrate")
}
let bitrate = args.count == 5 ? (Int(args[4]) ?? 0) : 8_000_000
guard bitrate >= 100_000 && bitrate <= 32_000_000 else { fatalError("Неверный bitrate") }
let source = URL(fileURLWithPath: args[1], isDirectory: true)
let output = URL(fileURLWithPath: args[2])
guard !FileManager.default.fileExists(atPath: output.path) else { fatalError("Файл уже существует") }
let files = try FileManager.default.contentsOfDirectory(at: source, includingPropertiesForKeys: nil)
    .filter { $0.pathExtension == "png" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
guard let first = files.first,
      let firstSource = CGImageSourceCreateWithURL(first as CFURL, nil),
      let firstImage = CGImageSourceCreateImageAtIndex(firstSource, 0, nil) else { fatalError("Нет кадров") }
let width = firstImage.width, height = firstImage.height
let writer = try AVAssetWriter(outputURL: output, fileType: .mp4)
let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
    AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: width, AVVideoHeightKey: height,
    AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: bitrate, AVVideoMaxKeyFrameIntervalKey: Int(fps)]
])
input.expectsMediaDataInRealTime = false
let adapter = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
    kCVPixelBufferWidthKey as String: width, kCVPixelBufferHeightKey as String: height,
    kCVPixelBufferCGImageCompatibilityKey as String: true,
    kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
])
writer.add(input)
guard writer.startWriting() else { fatalError("Не удалось начать запись: \(String(describing: writer.error))") }
writer.startSession(atSourceTime: .zero)
for (index, file) in files.enumerated() {
    guard let imageSource = CGImageSourceCreateWithURL(file as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil),
          image.width == width, image.height == height else { fatalError("Неверный размер кадра") }
    while !input.isReadyForMoreMediaData {
        guard writer.status == .writing else { fatalError("Ошибка кодирования") }
        Thread.sleep(forTimeInterval: 0.005)
    }
    var buffer: CVPixelBuffer?
    guard CVPixelBufferPoolCreatePixelBuffer(nil, adapter.pixelBufferPool!, &buffer) == kCVReturnSuccess,
          let pixels = buffer else { fatalError("Нет буфера") }
    CVPixelBufferLockBaseAddress(pixels, [])
    let bitmap = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.noneSkipFirst.rawValue
    guard let context = CGContext(data: CVPixelBufferGetBaseAddress(pixels), width: width, height: height,
        bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixels),
        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: bitmap) else { fatalError("Нет контекста") }
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    CVPixelBufferUnlockBaseAddress(pixels, [])
    guard adapter.append(pixels, withPresentationTime: CMTime(value: Int64(index), timescale: fps)) else {
        fatalError("Не удалось записать кадр: \(String(describing: writer.error))")
    }
}
input.markAsFinished()
let done = DispatchSemaphore(value: 0)
writer.finishWriting { done.signal() }
done.wait()
guard writer.status == .completed else { fatalError("Запись не завершена") }
// Декодирует готовый ролик для независимой проверки размера и ориентации первого кадра.
let asset = AVURLAsset(url: output)
let track = asset.tracks(withMediaType: .video).first!
let generator = AVAssetImageGenerator(asset: asset)
generator.requestedTimeToleranceBefore = .zero
generator.requestedTimeToleranceAfter = .zero
let decoded = try generator.copyCGImage(at: .zero, actualTime: nil)
let check = output.deletingPathExtension().appendingPathExtension("decoded.png")
let destination = CGImageDestinationCreateWithURL(check as CFURL, "public.png" as CFString, 1, nil)!
CGImageDestinationAddImage(destination, decoded, nil)
guard CGImageDestinationFinalize(destination) else { fatalError("Ошибка декодированного PNG") }
let report: [String: Any] = ["encoder": "AVFoundation H.264", "width": Int(track.naturalSize.width),
    "height": Int(track.naturalSize.height), "frames": files.count, "fps": fps,
    "duration": CMTimeGetSeconds(asset.duration), "decoded_first_frame": check.lastPathComponent, "bitrate": bitrate]
let data = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
try data.write(to: output.deletingPathExtension().appendingPathExtension("json"))
print("VIDEO: \(files.count) frames, \(width)x\(height), \(fps) fps")
