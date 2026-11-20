// Writes face boxes (left top width height, in pixels, top-left origin) for
// the README redaction demo, using Apple's on-device Vision framework.
//
//   swift tool/readme_assets/detect_faces.swift example/assets/people_sample.jpg \
//     > tool/readme_assets/people_faces.txt
import AppKit
import Vision

let path = CommandLine.arguments[1]
guard let image = NSImage(contentsOfFile: path),
      let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
  FileHandle.standardError.write("cannot read \(path)\n".data(using: .utf8)!)
  exit(1)
}
let request = VNDetectFaceRectanglesRequest()
try VNImageRequestHandler(cgImage: cg, options: [:]).perform([request])
let w = Double(cg.width), h = Double(cg.height)
print("# left top width height (px) for \(path) \(cg.width)x\(cg.height)")
for face in request.results ?? [] {
  let b = face.boundingBox
  print(String(format: "%.0f %.0f %.0f %.0f", b.minX * w, (1 - b.maxY) * h, b.width * w, b.height * h))
}
