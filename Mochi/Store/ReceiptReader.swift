import UIKit
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Reads a receipt photo on the phone: Vision finds the text (Japanese and
/// English, no network), the lines are put back in reading order, and
/// `ReceiptParser` finds the fields. Where Apple Intelligence is on, the
/// on-device model is asked for the lines and a category the rules could not
/// give. Nothing leaves the phone either way.
enum ReceiptReader {

    /// A line of the receipt and where it sits in the picture: normalised,
    /// origin top left, so the camera can outline the lines it used.
    struct Row: Equatable {
        var text: String
        var box: CGRect
        /// The line's four corners — top left, top right, bottom right,
        /// bottom left — so a tilted receipt is outlined along its own lines.
        var quad: [CGPoint] = []
    }

    /// One piece of text Vision found, before pieces are joined into lines:
    /// its corners normalised with the origin top left, in the order of `Row.quad`.
    struct Piece {
        var text: String
        var quad: [CGPoint]
    }

    /// The photo as read: its lines, and the picture they were read from —
    /// the receipt cut out and straightened when that read better.
    struct Reading {
        var lines: [String]
        var image: UIImage
    }

    /// The languages Vision reads, most likely first. Japanese, English and
    /// Vietnamese are all on; the order is the book's (`Store.receiptLanguages`),
    /// because the first one wins where a word could be either.
    static var languages = ["ja-JP", "en-US", "vi-VT"]

    /// The photo read carefully, after the shutter. The receipt is found,
    /// cut out of its background and straightened (a receipt held at an angle
    /// prints its lines at one), its contrast lifted, and read; the photo as
    /// taken is read too, and whichever reading finds more of the receipt is
    /// kept, with its picture. Each is read in the book's language order,
    /// and again the other way round when that looks like the wrong script.
    static func read(_ image: UIImage) async -> Reading {
        let first = languages
        return await withCheckedContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                var best: (reading: Reading, score: Int)?
                // The straightened one first: a tie goes to it.
                for candidate in flattened(image) + [image] {
                    let lines = readBothWays(candidate, first: first)
                    let s = score(lines)
                    if best == nil || s > best!.score { best = (Reading(lines: lines, image: candidate), s) }
                }
                cont.resume(returning: best?.reading ?? Reading(lines: [], image: image))
            }
        }
    }

    /// Text lines top to bottom, left to right within a line.
    static func lines(in image: UIImage) async -> [String] { await read(image).lines }

    private static func readBothWays(_ image: UIImage, first: [String]) -> [String] {
        guard let cg = image.cgImage else { return [] }
        let handler = VNImageRequestHandler(cgImage: cg, orientation: orientation(image))
        let aspect = uprightAspect(image)
        let a = rows(in: handler, languages: first, aspect: aspect).map(\.text)
        guard let other = otherOrder(for: a, after: first) else { return a }
        let b = rows(in: handler, languages: other, aspect: aspect).map(\.text)
        // A tie goes to the second reading: it was only made because the
        // first looked like the wrong script, and it keeps the accents.
        return score(b) >= score(a) ? b : a
    }

    /// The receipt cut out of the photo and its perspective undone, so its
    /// lines run straight across — once by each way of finding the paper
    /// that is confident of it, since either can be wrong where the other is
    /// right; empty when neither finds anything the size of a receipt.
    static func flattened(_ image: UIImage) -> [UIImage] {
        guard let cg = image.cgImage else { return [] }
        let handler = VNImageRequestHandler(cgImage: cg, orientation: orientation(image))
        // The paper by the document model first; where it is unsure, the
        // largest four-sided shape — a receipt on a desk is one.
        let segment = VNDetectDocumentSegmentationRequest()
        let shapes = VNDetectRectanglesRequest()
        shapes.minimumAspectRatio = 0.1
        shapes.maximumAspectRatio = 1
        shapes.minimumSize = 0.3
        shapes.quadratureTolerance = 30
        shapes.maximumObservations = 1
        try? handler.perform([segment, shapes])
        let found = ((segment.results ?? []) + (shapes.results ?? []))
            .filter { $0.confidence > 0.6 && $0.boundingBox.width * $0.boundingBox.height > 0.12 }
        return found.compactMap { straightened(cg, image, along: $0) }
    }

    private static func straightened(_ cg: CGImage, _ image: UIImage, along doc: VNRectangleObservation) -> UIImage? {
        var upright = CIImage(cgImage: cg).oriented(orientation(image))
        upright = upright.transformed(by: CGAffineTransform(translationX: -upright.extent.minX, y: -upright.extent.minY))
        let size = upright.extent.size
        func at(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x * size.width, y: p.y * size.height) }
        let straighten = CIFilter.perspectiveCorrection()
        straighten.inputImage = upright
        straighten.topLeft = at(doc.topLeft)
        straighten.topRight = at(doc.topRight)
        straighten.bottomLeft = at(doc.bottomLeft)
        straighten.bottomRight = at(doc.bottomRight)
        // Thermal paper fades: a little more contrast, no colour to distract.
        let clear = CIFilter.colorControls()
        clear.inputImage = straighten.outputImage
        clear.contrast = 1.15
        clear.saturation = 0
        guard let out = clear.outputImage,
              let result = CIContext().createCGImage(out, from: out.extent) else { return nil }
        return UIImage(cgImage: result)
    }

    /// Width over height of the picture the way it is seen.
    static func uprightAspect(_ image: UIImage) -> CGFloat {
        guard image.size.height > 0 else { return 1 }
        return image.size.width / image.size.height
    }

    /// Vision reads in the script of the first language it is given: with
    /// Japanese first, Vietnamese comes back without its accents
    /// ("Tạm tính" → "Tam tinn"); with Vietnamese first, Japanese comes back
    /// as dots ("·160"). The other order, when a reading looks like that.
    static func otherOrder(for lines: [String], after order: [String]) -> [String]? {
        let text = lines.joined()
        let scalars = text.unicodeScalars
        let japanese = scalars.contains { (0x3040...0x30FF).contains($0.value) || (0x4E00...0x9FFF).contains($0.value) }
        let latin = scalars.filter { CharacterSet.letters.contains($0) && $0.value < 0x0250 }.count
        if order.first == "ja-JP" {
            return !japanese && latin > 8 ? ["vi-VT", "en-US", "ja-JP"] : nil
        }
        // Mostly figures and dots, few letters: a Japanese receipt read as Latin.
        let digits = scalars.filter { CharacterSet.decimalDigits.contains($0) }.count
        return !lines.isEmpty && (latin * 2 < digits || text.contains("·")) ? ["ja-JP", "en-US", "vi-VT"] : nil
    }

    /// How much of a receipt a reading found: a total counts most, then a
    /// shop, a date and each line.
    static func score(_ lines: [String]) -> Int {
        let d = ReceiptParser.parse(lines)
        return (d.total != nil ? 4 : 0) + (d.merchant.isEmpty ? 0 : 2) + (d.date != nil ? 1 : 0)
            + (d.totalMatchesLines ? 3 : 0) + min(d.lines.count, 10)
    }

    /// One pass of recognition, run on the caller's thread. The live camera
    /// calls it on its own queue for a frame; `lines(in:)` for a photo.
    /// Language correction is off for a frame: it doubles the time, and the
    /// still photo taken at the shutter is read again with it on.
    static func rows(in handler: VNImageRequestHandler, languages: [String]? = nil, live: Bool = false, aspect: CGFloat = 1) -> [Row] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = languages ?? Self.languages
        request.usesLanguageCorrection = !live
        do { try handler.perform([request]) } catch { return [] }
        let pieces = (request.results ?? []).compactMap { o -> Piece? in
            guard let t = o.topCandidates(1).first?.string else { return nil }
            // Vision's origin is bottom left; the screen's is top left.
            func flip(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x, y: 1 - p.y) }
            return Piece(text: t, quad: [flip(o.topLeft), flip(o.topRight), flip(o.bottomRight), flip(o.bottomLeft)])
        }
        return group(pieces, aspect: aspect)
    }

    /// Pieces on the same printed line are one row: a receipt's name and
    /// price sit apart. "The same line" follows the text's own slant, not
    /// the picture's: a piece belongs with another when its centre lies
    /// within half a line of the line running through the other along their
    /// common direction. A receipt photographed at an angle has its prices
    /// higher or lower than their names by more than half a line, and
    /// comparing heights alone paired each price with the wrong name.
    /// `aspect` is the picture's width over height, so a slope is measured
    /// in the picture and not in its normalised square.
    static func group(_ pieces: [Piece], aspect: CGFloat) -> [Row] {
        guard !pieces.isEmpty else { return [] }
        struct Geo { var centre: CGPoint; var along: CGVector; var height: CGFloat }
        func px(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x * aspect, y: p.y) }
        func unit(_ v: CGVector) -> CGVector {
            let l = max(hypot(v.dx, v.dy), 1e-9); return CGVector(dx: v.dx / l, dy: v.dy / l)
        }
        let geo: [Geo] = pieces.map { piece in
            let q = piece.quad.map(px)
            guard q.count == 4 else { return Geo(centre: .zero, along: CGVector(dx: 1, dy: 0), height: 0.01) }
            let left = CGPoint(x: (q[0].x + q[3].x) / 2, y: (q[0].y + q[3].y) / 2)
            let right = CGPoint(x: (q[1].x + q[2].x) / 2, y: (q[1].y + q[2].y) / 2)
            let top = CGPoint(x: (q[0].x + q[1].x) / 2, y: (q[0].y + q[1].y) / 2)
            let bottom = CGPoint(x: (q[3].x + q[2].x) / 2, y: (q[3].y + q[2].y) / 2)
            return Geo(centre: CGPoint(x: (left.x + right.x) / 2, y: (left.y + right.y) / 2),
                       along: unit(CGVector(dx: right.x - left.x, dy: right.y - left.y)),
                       height: max(hypot(bottom.x - top.x, bottom.y - top.y), 1e-4))
        }
        // Vision slants the box of a long piece with its text but gives a
        // short one ("¥398", "合計") a square box whatever the slant. So a
        // short piece takes the direction of the nearest long one — near,
        // because a photo's perspective turns the lines a little across it.
        // A square box is told by its exactly level top: Vision's slanted
        // boxes are never exactly level. Where other pieces are slanted, a
        // square one says nothing about the slant, however long it is.
        func square(_ i: Int) -> Bool {
            let q = pieces[i].quad
            return q.count == 4 && abs(q[0].y - q[1].y) < 1e-6 && abs(q[0].x - q[3].x) < 1e-6
        }
        let slanted = geo.indices.filter { !square($0) }.count
        let long = geo.indices.filter { i in
            let q = pieces[i].quad.map(px)
            guard q.count == 4, !(square(i) && slanted >= 2) else { return false }
            return hypot(q[1].x - q[0].x, q[1].y - q[0].y) >= 2.5 * geo[i].height
        }
        let direction: [CGVector] = geo.indices.map { i in
            if long.contains(i) || long.isEmpty { return geo[i].along }
            let nearest = long.min { a, b in
                hypot(geo[a].centre.x - geo[i].centre.x, geo[a].centre.y - geo[i].centre.y)
                    < hypot(geo[b].centre.x - geo[i].centre.x, geo[b].centre.y - geo[i].centre.y)
            }!
            return geo[nearest].along
        }
        // Which pieces share a line, joined transitively.
        var parent = Array(pieces.indices)
        func root(_ i: Int) -> Int { var i = i; while parent[i] != i { parent[i] = parent[parent[i]]; i = parent[i] }; return i }
        for i in pieces.indices {
            for j in pieces.indices where j > i {
                let a = geo[i], b = geo[j]
                let dir = unit(CGVector(dx: direction[i].dx + direction[j].dx, dy: direction[i].dy + direction[j].dy))
                let d = CGVector(dx: b.centre.x - a.centre.x, dy: b.centre.y - a.centre.y)
                let off = abs(d.dx * dir.dy - d.dy * dir.dx)
                if off < 0.5 * max(a.height, b.height) { parent[root(j)] = root(i) }
            }
        }
        // The page's own direction, to put the rows in order top to bottom
        // and each row's pieces left to right.
        let angles = direction.map { atan2($0.dy, $0.dx) }.sorted()
        let angle = angles[angles.count / 2]
        let along = CGVector(dx: cos(angle), dy: sin(angle)), down = CGVector(dx: -sin(angle), dy: cos(angle))
        func project(_ p: CGPoint, _ v: CGVector) -> CGFloat { p.x * v.dx + p.y * v.dy }

        let groups = Dictionary(grouping: pieces.indices, by: root).values.map { members in
            members.sorted { project(geo[$0].centre, along) < project(geo[$1].centre, along) }
        }
        return groups
            .sorted { a, b in
                let ya = a.map { project(geo[$0].centre, down) }.reduce(0, +) / CGFloat(a.count)
                let yb = b.map { project(geo[$0].centre, down) }.reduce(0, +) / CGFloat(b.count)
                return ya < yb
            }
            .map { members in
                let first = pieces[members.first!].quad, last = pieces[members.last!].quad
                let quad = first.count == 4 && last.count == 4 ? [first[0], last[1], last[2], first[3]] : []
                let points = members.flatMap { pieces[$0].quad }
                let xs = points.map(\.x), ys = points.map(\.y)
                let box = CGRect(x: xs.min() ?? 0, y: ys.min() ?? 0,
                                 width: (xs.max() ?? 0) - (xs.min() ?? 0), height: (ys.max() ?? 0) - (ys.min() ?? 0))
                return Row(text: members.map { pieces[$0].text }.joined(separator: " "), box: box, quad: quad)
            }
    }

    /// Two photos of one long receipt as one picture, top above bottom, at
    /// the narrower one's width: the receipt photo kept with the spend is
    /// the whole paper, not half of it.
    static func stacked(_ top: UIImage, _ bottom: UIImage) -> UIImage {
        let width = min(top.size.width, bottom.size.width)
        let h1 = top.size.height * width / top.size.width
        let h2 = bottom.size.height * width / bottom.size.width
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: width, height: h1 + h2), format: format).image { _ in
            top.draw(in: CGRect(x: 0, y: 0, width: width, height: h1))
            bottom.draw(in: CGRect(x: 0, y: h1, width: width, height: h2))
        }
    }

    private static func orientation(_ image: UIImage) -> CGImagePropertyOrientation {
        switch image.imageOrientation {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }

    /// Whether this phone can run the on-device model: iOS 26 with Apple
    /// Intelligence switched on.
    static var modelAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26, *) {
            if case .available = SystemLanguageModel.default.availability { return true }
        }
        #endif
        return false
    }

    /// The on-device model's reading: the lines bought and the category they
    /// most look like, chosen from the book's own list. nil when the model is
    /// not there or cannot say.
    static func understand(_ lines: [String], categories: [String]) async -> (category: String?, items: [ReceiptDraft.Line])? {
        #if canImport(FoundationModels)
        if #available(iOS 26, *), modelAvailable {
            do {
                let session = LanguageModelSession(instructions: """
                    You read Japanese shop receipts. Answer only from the receipt text.
                    Pick the category from this list only: \(categories.joined(separator: ", ")).
                    """)
                let answer = try await session.respond(to: "Receipt:\n" + lines.joined(separator: "\n"),
                                                       generating: ReceiptReading.self)
                let r = answer.content
                let cat = categories.contains(r.category) ? r.category : nil
                return (cat, r.items.filter { $0.price != 0 }.map { .init(name: $0.name, price: $0.price) })
            } catch {
                return nil
            }
        }
        #endif
        return nil
    }
}

#if canImport(FoundationModels)
@available(iOS 26, *)
@Generable
struct ReceiptReading {
    @Guide(description: "The spending category, exactly as written in the list given")
    var category: String
    @Guide(description: "Each product line with its price in yen; discounts negative")
    var items: [ReceiptReadingLine]
}

@available(iOS 26, *)
@Generable
struct ReceiptReadingLine {
    var name: String
    var price: Int
}
#endif
