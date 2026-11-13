import Accelerate
import CoreGraphics
import Foundation

/// The disk as a strip of cells, one every 4pt, dithered against a 4×4 Bayer
/// matrix. A cell belongs to whatever sits over its centre, and when that
/// changes, because the scan found more or something got cleared, the cell runs
/// white-hot and cools back to its colour. So a bar that's growing shows its
/// seams marching as a bright front, and anything you clear lifts off as loose
/// pixels before the space goes dark.
///
/// The CPU only draws what changes per cell: the dithered cells at bar size,
/// a glow at one pixel per cell, and a thin overlay of filaments and motes.
/// The view's layers scale, blend, and stack them on the GPU.
final class StorageBarRenderer {
    struct Frame {
        /// Each kind's size on the bar right now, in GB.
        var sizes: [Double]
        /// 0...1 per kind: how much it's being looked at.
        var focus: [Double]
        /// 0...1: how far everything that isn't looked at steps back.
        var dim: Double
        /// 0...1 while scanning: the front of the bar runs hot.
        var scan: Double
        /// The kind being cleared, whose cells lift off as they go, or -1.
        var spill: Int
        var disk: Double
        var dt: Double
        var t: Double
    }

    struct Fill {
        let rect: CGRect
        let color: CGColor
    }

    struct Output {
        /// The dithered cells, at the bar's size.
        let cells: CGImage?
        /// The lit cells at one pixel each, padded by `glowPad` cells; the view scales it up.
        let glow: CGImage?
        /// Filaments, seams, and motes, over the whole canvas.
        let overlay: CGImage?
        /// Each part's faint tint under its cells, in bar coordinates.
        let fills: [Fill]
        /// Cells still cooling or motes still rising: keep drawing at full rate.
        let isWarm: Bool
    }

    static let height: CGFloat = 88
    static let radius: CGFloat = 10
    static let pitch: CGFloat = 4
    /// Room around the bar for motes to rise into and the glow to spill over.
    static let margin = (top: CGFloat(110), side: CGFloat(26), bottom: CGFloat(26))
    static let glowPad = 6

    let width: CGFloat
    let scale: CGFloat
    let canvas: CGSize

    private let cols: Int
    private let rows: Int
    private let ox: Float
    private let oy: Float
    private let count: Int

    // Per cell, worked out once: where it sits and what never changes about it.
    // Only cells inside the rounded bar, a column at a time.
    // Raw buffers, not arrays: per-access array checks cost more than the
    // dither itself in Debug builds.
    private let cellCount: Int
    private let cellIndex: UnsafeMutablePointer<Int32>
    private let cellColumn: UnsafeMutablePointer<Int32>
    private let cellRow: UnsafeMutablePointer<Int32>
    /// The Bayer level a cell has to clear.
    private let threshold: UnsafeMutablePointer<Float>
    /// Light gathered along the tube's top and bottom.
    private let edgeLight: UnsafeMutablePointer<Float>
    /// Staggers when each cell catches a glint.
    private let flickerSeed: UnsafeMutablePointer<Float>
    private let kind: UnsafeMutablePointer<Int8>
    private let heat: UnsafeMutablePointer<Float>
    private var motes: [Mote] = []
    private var edges: [Double]
    private let colors: [RGB]
    private let hot: [RGB]
    private let colorRefs: [CGColor]

    private let cellsWidth: Int
    private let cellsHeight: Int
    private let cells: UnsafeMutablePointer<UInt8>
    private let glowWidth: Int
    private let glowHeight: Int
    private let glowPixels: UnsafeMutablePointer<UInt8>
    private let glowScratch: UnsafeMutablePointer<UInt8>
    private let cellsContext: CGContext
    private let glowContext: CGContext
    private let overlayContext: CGContext

    private static let space = CGColorSpace(name: CGColorSpace.displayP3) ?? CGColorSpaceCreateDeviceRGB()
    private static let bayer: [Float] = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5].map { (Float($0) + 0.5) / 16 }

    /// Light or dark: what an empty cell, a hot cell, and a seam look like.
    let isDark: Bool
    private let empty: RGB
    private let emptyAlpha: Float
    private let seam: CGColor

    init?(width: CGFloat, scale: CGFloat, hues: [StorageHue], isDark: Bool) {
        self.isDark = isDark
        empty = isDark ? RGB(r: 255, g: 255, b: 255) : RGB(r: 0, g: 0, b: 0)
        emptyAlpha = isDark ? 18 : 22
        seam = isDark ? CGColor(gray: 1, alpha: 0.62) : CGColor(gray: 0, alpha: 0.22)
        let width = max(40, width.rounded(.down))
        let scale = min(2, max(1, scale))
        self.width = width
        self.scale = scale
        let h = Float(Self.height)
        let pitch = Float(Self.pitch)
        let cols = Int(Float(width) / pitch)
        let rows = Int(h / pitch)
        self.cols = cols
        self.rows = rows
        let ox = (Float(width) - Float(cols) * pitch) / 2
        let oy = (h - Float(rows) * pitch) / 2
        self.ox = ox
        self.oy = oy
        count = hues.count

        var index: [Int32] = []
        var column: [Int32] = []
        var row: [Int32] = []
        var threshold: [Float] = []
        var edgeLight: [Float] = []
        var flicker: [Float] = []
        let r = Float(Self.radius)
        for i in 0..<cols {
            for j in 0..<rows {
                let cx = ox + (Float(i) + 0.5) * pitch
                let cy = oy + (Float(j) + 0.5) * pitch
                let dx = max(r - cx, cx - (Float(width) - r), 0)
                let dy = max(r - cy, cy - (h - r), 0)
                guard dx * dx + dy * dy <= (r - 1) * (r - 1) else { continue }
                index.append(Int32(j * cols + i))
                column.append(Int32(i))
                row.append(Int32(j))
                threshold.append(Self.bayer[(j & 3) * 4 + (i & 3)])
                edgeLight.append(exp(-(min(cy, h - cy) - 2) / 5))
                flicker.append(Self.hash(Int32(i), Int32(j)) * 7)
            }
        }
        func buffer<T>(_ values: [T]) -> UnsafeMutablePointer<T> {
            let pointer = UnsafeMutablePointer<T>.allocate(capacity: max(1, values.count))
            _ = UnsafeMutableBufferPointer(start: pointer, count: values.count).initialize(from: values)
            return pointer
        }
        cellCount = index.count
        cellIndex = buffer(index)
        cellColumn = buffer(column)
        cellRow = buffer(row)
        self.threshold = buffer(threshold)
        self.edgeLight = buffer(edgeLight)
        flickerSeed = buffer(flicker)
        kind = buffer([Int8](repeating: -1, count: cols * rows))
        heat = buffer([Float](repeating: 0, count: cols * rows))
        edges = [Double](repeating: 0, count: hues.count + 1)
        colors = hues.map { RGB(r: Float($0.red * 255), g: Float($0.green * 255), b: Float($0.blue * 255)) }
        // Hot cells run white on graphite; on paper white would vanish, so they run deep instead.
        hot = colors.map { isDark ? RGB(r: 255, g: 255, b: 255) : RGB(r: $0.r * 0.45, g: $0.g * 0.45, b: $0.b * 0.45) }
        colorRefs = hues.map { CGColor(colorSpace: Self.space, components: [$0.red, $0.green, $0.blue, 1]) ?? CGColor(gray: 1, alpha: 1) }

        cellsWidth = Int((width * scale).rounded())
        cellsHeight = Int((Self.height * scale).rounded())
        cells = .allocate(capacity: cellsWidth * cellsHeight * 4)
        glowWidth = cols + Self.glowPad * 2
        glowHeight = rows + Self.glowPad * 2
        glowPixels = .allocate(capacity: glowWidth * glowHeight * 4)
        glowScratch = .allocate(capacity: glowWidth * glowHeight * 4)
        canvas = CGSize(width: width + Self.margin.side * 2, height: Self.height + Self.margin.top + Self.margin.bottom)

        let info = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let cellsContext = CGContext(data: cells, width: cellsWidth, height: cellsHeight, bitsPerComponent: 8, bytesPerRow: cellsWidth * 4, space: Self.space, bitmapInfo: info),
              let glowContext = CGContext(data: glowPixels, width: glowWidth, height: glowHeight, bitsPerComponent: 8, bytesPerRow: glowWidth * 4, space: Self.space, bitmapInfo: info),
              let overlayContext = CGContext(data: nil, width: Int((canvas.width * scale).rounded()), height: Int((canvas.height * scale).rounded()), bitsPerComponent: 8, bytesPerRow: 0, space: Self.space, bitmapInfo: info)
        else {
            for pointer in [cells, glowPixels] as [UnsafeMutablePointer<UInt8>] { pointer.deallocate() }
            glowScratch.deallocate()
            for pointer in [cellIndex, cellColumn, cellRow] { pointer.deallocate() }
            for pointer in [self.threshold, self.edgeLight, flickerSeed, heat] { pointer.deallocate() }
            kind.deallocate()
            return nil
        }
        self.cellsContext = cellsContext
        self.glowContext = glowContext
        self.overlayContext = overlayContext
        // Top-left origin, in points, like the canvas this came from.
        overlayContext.translateBy(x: 0, y: canvas.height * scale)
        overlayContext.scaleBy(x: scale, y: -scale)
    }

    deinit {
        cells.deallocate()
        glowPixels.deallocate()
        glowScratch.deallocate()
        freeTables()
    }

    private func freeTables() {
        cellIndex.deallocate()
        cellColumn.deallocate()
        cellRow.deallocate()
        threshold.deallocate()
        edgeLight.deallocate()
        flickerSeed.deallocate()
        kind.deallocate()
        heat.deallocate()
    }

    /// Where the bar sits in the canvas, for laying out the cell layers.
    var barRect: CGRect {
        CGRect(x: Self.margin.side, y: Self.margin.top, width: width, height: Self.height)
    }

    /// Where the glow image lands in the canvas once scaled up a cell per pixel.
    var glowRect: CGRect {
        let pad = CGFloat(Self.glowPad) * Self.pitch
        return CGRect(
            x: Self.margin.side + CGFloat(ox) - pad,
            y: Self.margin.top + CGFloat(oy) - pad,
            width: CGFloat(glowWidth) * Self.pitch,
            height: CGFloat(glowHeight) * Self.pitch
        )
    }

    // MARK: - Drawing

    // Forced on even in Debug builds: this runs every frame for ~3,000 cells,
    // and unoptimised Swift took several frames' budget to get through it.
    @_optimize(speed)
    func draw(_ f: Frame) -> Output {
        let w = Double(width)
        var acc = 0.0
        edges[0] = 0
        for k in 0..<count {
            acc += max(0, f.sizes[k])
            edges[k + 1] = f.disk > 0 ? min(1, acc / f.disk) * w : 0
        }
        let end = Float(edges[count])
        let cool = Float(exp(-f.dt / 0.42))
        let dt = Float(f.dt)
        let t = Float(f.t)
        let drift = t * 0.32
        let pitch = Float(Self.pitch)
        let s = Float(scale)
        let px = s * pitch
        let lit = max(2, Int((3 * s).rounded()))
        let dimS = max(1, Int((1.5 * s).rounded()))
        let litOffset = Int(((px - Float(lit)) / 2).rounded())
        let dimOffset = Int(((px - Float(dimS)) / 2).rounded())
        let barX = Float(Self.margin.side)
        let barY = Float(Self.margin.top)
        let scan = Float(f.scan)
        let dim = Float(f.dim)
        let glints = (t * 1.6).rounded(.down)

        // Per kind, per frame: how lit it is and how far it steps back.
        var focus = [Float](repeating: 0, count: count)
        var keep = [Float](repeating: 1, count: count)
        for k in 0..<count {
            focus[k] = Float(f.focus[k])
            keep[k] = 1 - 0.68 * dim * (1 - focus[k])
        }

        memset(cells, 0, cellsWidth * cellsHeight * 4)
        memset(glowPixels, 0, glowWidth * glowHeight * 4)

        var k = 0
        var lastColumn: Int32 = -1
        var want = -1
        var front: Float = 0
        let colorTable = colors
        let hotTable = hot
        for c in 0..<cellCount {
            let i = Int(cellColumn[c])
            let j = Int(cellRow[c])
            let n = Int(cellIndex[c])
            // What a column belongs to is the same all the way down it.
            if cellColumn[c] != lastColumn {
                lastColumn = cellColumn[c]
                let cx = ox + (Float(i) + 0.5) * pitch
                while k < count - 1, Double(cx) >= edges[k + 1] { k += 1 }
                want = cx < end && Double(cx) >= edges[k] && Double(cx) < edges[k + 1] ? k : -1
                front = scan > 0 && cx < end ? scan * exp(-(end - cx) / 22) : 0
            }

            let had = Int(kind[n])
            if had != want {
                if had >= 0, had == f.spill, Float.random(in: 0..<1) < 0.75 {
                    motes.append(Mote(
                        x: barX + ox + (Float(i) + 0.5) * pitch,
                        y: barY + oy + (Float(j) + 0.5) * pitch,
                        vx: (Float.random(in: 0..<1) - 0.4) * 30,
                        vy: -(24 + Float.random(in: 0..<1) * 70),
                        age: 0,
                        life: 0.7 + Float.random(in: 0..<1) * 0.9,
                        kind: had
                    ))
                }
                kind[n] = Int8(want)
                heat[n] = want >= 0 ? 1 : 0
            } else if heat[n] > 0 {
                heat[n] *= cool
                if heat[n] < 0.001 { heat[n] = 0 }
            }

            let x0 = Int(ox * s + Float(i) * px)
            let y0 = Int(oy * s + Float(j) * px)
            if want < 0 {
                put(x0 + dimOffset, y0 + dimOffset, dimS, empty.r, empty.g, empty.b, emptyAlpha)
                continue
            }
            let color = colorTable[want]
            let m = keep[want]
            let h = heat[n]
            // Light gathers along the top and bottom like it does in a tube, and
            // drifts through the middle in slow clouds, so the dither has something to describe.
            let cloud = Self.noise(Float(i) * 0.045 - drift, Float(j) * 0.11 + drift * 0.3) * 0.65
                + Self.noise(Float(i) * 0.13 + drift * 0.6, Float(j) * 0.3) * 0.35
            let level = -0.04 + 0.66 * edgeLight[c] + 0.44 * Self.smooth(Self.clamp01((cloud - 0.42) / 0.38))
                + 0.6 * h + 0.22 * focus[want] + 0.55 * front
            // A few cells catch the light for a moment, like dust in a beam.
            let glint: Float = Self.hash(Int32(n), Int32(glints + flickerSeed[c])) > 0.994 ? 1 : 0
            if level + glint > threshold[c] {
                let wt = min(1, h * 0.95 + focus[want] * 0.1 + front * 0.85 + glint * 0.6)
                let target = hotTable[want]
                let r = color.r + (target.r - color.r) * wt
                let g = color.g + (target.g - color.g) * wt
                let b = color.b + (target.b - color.b) * wt
                put(x0 + litOffset, y0 + litOffset, lit, r, g, b, 242 * m)
                // Being cleared: the whole run gives off loose pixels, not just its shrinking end.
                if want == f.spill, motes.count < 1600, Float.random(in: 0..<1) < 2.2 * dt {
                    motes.append(Mote(
                        x: barX + ox + (Float(i) + 0.5) * pitch,
                        y: barY + oy + (Float(j) + 0.5) * pitch,
                        vx: (Float.random(in: 0..<1) - 0.4) * 22,
                        vy: -(14 + Float.random(in: 0..<1) * 46),
                        age: 0,
                        life: 0.6 + Float.random(in: 0..<1) * 0.9,
                        kind: want
                    ))
                    heat[n] = max(heat[n], 0.7)
                }
                let alpha = 255 * m * (0.55 + 0.45 * wt)
                let a = alpha / 255
                let q = ((j + Self.glowPad) * glowWidth + i + Self.glowPad) * 4
                glowPixels[q] = UInt8(min(255, r * a))
                glowPixels[q + 1] = UInt8(min(255, g * a))
                glowPixels[q + 2] = UInt8(min(255, b * a))
                glowPixels[q + 3] = UInt8(min(255, alpha))
            } else {
                put(x0 + dimOffset, y0 + dimOffset, dimS, color.r, color.g, color.b, 70 * m)
            }
        }

        blurGlow()

        // The faint tint under each part: the view shows these as solid layers.
        var fills: [Fill] = []
        fills.reserveCapacity(count)
        for n in 0..<count {
            let a = edges[n]
            let b = edges[n + 1]
            guard b - a >= 0.25 else { continue }
            let alpha = CGFloat(0.12 * keep[n] + 0.06 * focus[n])
            fills.append(Fill(rect: CGRect(x: a, y: 0, width: b - a, height: Double(Self.height)), color: colorRefs[n].copy(alpha: alpha) ?? colorRefs[n]))
        }

        let overlay = drawOverlay(end: Double(end), keep: keep, focus: focus, dim: dim, dt: dt)

        var warm = !motes.isEmpty
        if !warm {
            for c in 0..<cellCount where heat[Int(cellIndex[c])] > 0.02 {
                warm = true
                break
            }
        }
        return Output(cells: cellsContext.makeImage(), glow: glowContext.makeImage(), overlay: overlay, fills: fills, isWarm: warm)
    }

    /// Filaments, seams, and motes. No shadows: a wide faint stroke under a
    /// thin bright one reads as the same glow for a fraction of the cost.
    @_optimize(speed)
    private func drawOverlay(end: Double, keep: [Float], focus: [Float], dim: Float, dt: Float) -> CGImage? {
        let ctx = overlayContext
        ctx.clear(CGRect(origin: .zero, size: canvas))
        let bar = barRect

        if end > 0.5 {
            let r = Double(Self.radius)
            let outline = Self.roundedPath(
                CGRect(x: bar.minX + 0.75, y: bar.minY + 0.75, width: max(end, r * 2) - 1.5, height: bar.height - 1.5),
                radii: (r - 0.75, 3, 3, r - 0.75)
            )
            for n in 0..<count {
                let a = edges[n]
                let b = edges[n + 1]
                guard b - a >= 0.25 else { continue }
                let m = CGFloat(keep[n])
                let color = colorRefs[n]
                ctx.saveGState()
                ctx.clip(to: CGRect(x: bar.minX + a, y: bar.minY - 4, width: b - a, height: bar.height + 8))
                for (lineWidth, alpha) in [(CGFloat(6), CGFloat(0.12)), (3.5, 0.28), (1.5, 0.95)] {
                    ctx.addPath(outline)
                    ctx.setStrokeColor(color.copy(alpha: alpha * m) ?? color)
                    ctx.setLineWidth(lineWidth)
                    ctx.strokePath()
                }
                ctx.restoreGState()
            }
            // Seams between parts, the way stages are ruled off.
            for n in 1..<count {
                let x = edges[n]
                let left = edges[n] - edges[n - 1]
                let right = edges[n + 1] - edges[n]
                guard left >= 2, right >= 2 else { continue }
                let m = 1 - 0.5 * dim * (1 - max(focus[n], focus[n - 1]))
                ctx.setFillColor(seam.copy(alpha: seam.alpha * CGFloat(m)) ?? seam)
                ctx.fill(CGRect(x: bar.minX + x.rounded() - 0.5, y: bar.minY + 1, width: 1, height: bar.height - 2))
            }
        }

        // What's been cleared rises off the bar and burns out.
        var index = 0
        while index < motes.count {
            motes[index].age += dt
            if motes[index].age >= motes[index].life {
                motes.swapAt(index, motes.count - 1)
                motes.removeLast()
                continue
            }
            var p = motes[index]
            p.vy -= 26 * dt
            p.vx *= exp(-dt * 1.5)
            p.x += p.vx * dt
            p.y += p.vy * dt
            motes[index] = p
            let u = p.age / p.life
            let wt = max(0, 1 - u * 1.8)
            let c = colors[p.kind]
            let h = hot[p.kind]
            ctx.setFillColor(
                red: CGFloat((c.r + (h.r - c.r) * wt) / 255),
                green: CGFloat((c.g + (h.g - c.g) * wt) / 255),
                blue: CGFloat((c.b + (h.b - c.b) * wt) / 255),
                alpha: CGFloat(pow(1 - u, 1.4))
            )
            let size = CGFloat(3 * (1 - u * 0.4))
            ctx.fill(CGRect(x: CGFloat((p.x * 2).rounded() / 2) - size / 2, y: CGFloat((p.y * 2).rounded() / 2) - size / 2, width: size, height: size))
            index += 1
        }

        return ctx.makeImage()
    }

    // MARK: - Helpers

    @_optimize(speed)
    @inline(__always)
    private func put(_ x0: Int, _ y0: Int, _ size: Int, _ r: Float, _ g: Float, _ b: Float, _ a: Float) {
        let alpha = max(0, min(255, a))
        let f = alpha / 255
        let pr = UInt8(min(255, r * f))
        let pg = UInt8(min(255, g * f))
        let pb = UInt8(min(255, b * f))
        let pa = UInt8(alpha)
        let yEnd = min(cellsHeight, y0 + size)
        let xEnd = min(cellsWidth, x0 + size)
        guard x0 >= 0, y0 >= 0, x0 < xEnd else { return }
        for y in y0..<yEnd {
            var o = (y * cellsWidth + x0) * 4
            for _ in x0..<xEnd {
                cells[o] = pr
                cells[o + 1] = pg
                cells[o + 2] = pb
                cells[o + 3] = pa
                o += 4
            }
        }
    }

    /// Three 5×5 box passes, about a 10pt Gaussian once the view scales it up:
    /// the sandbox's CSS blur. Accelerate does it in SIMD, in any build.
    private func blurGlow() {
        var source = vImage_Buffer(data: glowPixels, height: vImagePixelCount(glowHeight), width: vImagePixelCount(glowWidth), rowBytes: glowWidth * 4)
        var scratch = vImage_Buffer(data: glowScratch, height: vImagePixelCount(glowHeight), width: vImagePixelCount(glowWidth), rowBytes: glowWidth * 4)
        let flags = vImage_Flags(kvImageEdgeExtend)
        vImageBoxConvolve_ARGB8888(&source, &scratch, nil, 0, 0, 5, 5, nil, flags)
        vImageBoxConvolve_ARGB8888(&scratch, &source, nil, 0, 0, 5, 5, nil, flags)
        vImageBoxConvolve_ARGB8888(&source, &scratch, nil, 0, 0, 5, 5, nil, flags)
        // The context reads `glowPixels`.
        memcpy(glowPixels, glowScratch, glowWidth * glowHeight * 4)
    }

    /// A rounded rect with its own radius per corner: top-left, top-right, bottom-right, bottom-left.
    private static func roundedPath(_ rect: CGRect, radii: (Double, Double, Double, Double)) -> CGPath {
        let path = CGMutablePath()
        let (tl, tr, br, bl) = radii
        path.move(to: CGPoint(x: rect.minX + tl, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY))
        path.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.minY), tangent2End: CGPoint(x: rect.maxX, y: rect.minY + tr), radius: tr)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br))
        path.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.maxY), tangent2End: CGPoint(x: rect.maxX - br, y: rect.maxY), radius: br)
        path.addLine(to: CGPoint(x: rect.minX + bl, y: rect.maxY))
        path.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.maxY), tangent2End: CGPoint(x: rect.minX, y: rect.maxY - bl), radius: bl)
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + tl))
        path.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.minY), tangent2End: CGPoint(x: rect.minX + tl, y: rect.minY), radius: tl)
        path.closeSubpath()
        return path
    }

    @inline(__always)
    private static func clamp01(_ v: Float) -> Float { v < 0 ? 0 : v > 1 ? 1 : v }

    @inline(__always)
    private static func smooth(_ t: Float) -> Float { t * t * (3 - 2 * t) }

    /// An integer hash to 0..<1. The shader-style `sin` hash it replaces cost
    /// ten `sin` calls a cell, every frame.
    @_optimize(speed)
    @inline(__always)
    private static func hash(_ x: Int32, _ y: Int32) -> Float {
        var h = UInt32(bitPattern: x &* 374_761_393 &+ y &* 668_265_263)
        h = (h ^ (h >> 13)) &* 1_274_126_177
        h ^= h >> 16
        return Float(h & 0xFFFFFF) / 16_777_216
    }

    @_optimize(speed)
    @inline(__always)
    private static func noise(_ x: Float, _ y: Float) -> Float {
        let fx0 = x.rounded(.down)
        let fy0 = y.rounded(.down)
        let ix = Int32(fx0)
        let iy = Int32(fy0)
        let fx = smooth(x - fx0)
        let fy = smooth(y - fy0)
        let a = hash(ix, iy)
        let b = hash(ix &+ 1, iy)
        let c = hash(ix, iy &+ 1)
        let d = hash(ix &+ 1, iy &+ 1)
        return a + (b - a) * fx + (c - a) * fy + (a - b - c + d) * fx * fy
    }
}

private struct RGB {
    let r: Float
    let g: Float
    let b: Float
}

private struct Mote {
    var x: Float
    var y: Float
    var vx: Float
    var vy: Float
    var age: Float
    var life: Float
    let kind: Int
}
