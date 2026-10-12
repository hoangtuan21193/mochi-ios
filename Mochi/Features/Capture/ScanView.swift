import SwiftUI
import PhotosUI
import AVFoundation
import Vision

/// The receipt camera. It reads while the receipt is held up — a frame a
/// few times a second, on the phone — so the tray fills with what it has
/// found and the lines it used are outlined on the paper before the shutter
/// is pressed. What the tray shows when the shutter is pressed is the
/// reading; the photo is kept as the receipt and not read again.
///
/// VisionKit's document camera was used first. It finds the paper and
/// straightens it, but shows nothing of what it read until it is closed, and
/// "what did it read" is the whole question at a till.
struct ScanView: View {
    @Environment(Store.self) private var store
    @Environment(\.openURL) private var openURL
    let camera: ScanCamera
    /// Scanning the rest of a receipt already partly read.
    var continuing = false
    @State private var photo: PhotosPickerItem?
    /// The shutter was pressed: the screen goes now, the photo follows.
    let shutter: () -> Void
    /// A receipt picked from Photos.
    let picked: (UIImage) -> Void
    let typeInstead: () -> Void
    /// Close: out of capture, or back to the part already read.
    let close: () -> Void

    var body: some View {
        ZStack {
            Organic.Camera.bg.ignoresSafeArea()
            if camera.state == .running {
                CameraPreview(session: camera.session).ignoresSafeArea()
                outlines.ignoresSafeArea()
            }
            VStack(spacing: 0) {
                topBar
                ViewfinderCorners()
                    .stroke(Organic.Camera.frame, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .overlay { unavailable }
                    // About a receipt's shape at arm's length, never wider than the screen allows.
                    .frame(maxWidth: 300, maxHeight: 470)
                    .padding(.horizontal, 44).padding(.vertical, Organic.Space.l)
                    .frame(maxHeight: .infinity)
                tray
            }
        }
        .foregroundStyle(Organic.Camera.ink)
        .onAppear { camera.start() }
        .onDisappear { camera.pause() }
        .onChange(of: photo) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                    picked(image)
                }
                photo = nil
            }
        }
    }

    private var topBar: some View {
        HStack {
            CameraRoundButton(symbol: continuing ? "chevron.left" : "xmark", label: continuing ? "Back" : "Close", action: close)
            Spacer(minLength: Organic.Space.m)
            CameraPill(text: "Read on this iPhone", symbol: "lock")
            Spacer(minLength: Organic.Space.m)
            if camera.hasTorch {
                CameraRoundButton(symbol: camera.torchOn ? "bolt.fill" : "bolt", label: "Flash", on: camera.torchOn) { camera.toggleTorch() }
            } else {
                // No torch, no button; the pill stays centred.
                Color.clear.frame(width: Organic.Camera.controlSize, height: Organic.Camera.controlSize)
            }
        }
        .padding(.horizontal, Organic.Space.gutter).padding(.top, Organic.Space.m)
    }

    /// Where there is no picture: why, and what still works.
    @ViewBuilder private var unavailable: some View {
        switch camera.state {
        case .noCamera, .denied:
            VStack(spacing: Organic.Space.m) {
                Image(systemName: "camera").font(Organic.display(28)).foregroundStyle(Organic.Camera.quiet)
                Text(camera.state == .denied ? "Mochi is not allowed to use the camera" : "No camera on this device")
                    .font(Organic.title).multilineTextAlignment(.center)
                Text("Pick the receipt from Photos, or type it.")
                    .font(Organic.caption).foregroundStyle(Organic.Camera.quiet).multilineTextAlignment(.center)
                if camera.state == .denied, let url = URL(string: UIApplication.openSettingsURLString) {
                    Button { openURL(url) } label: { CameraTrayLabel(title: "Settings") }.buttonStyle(.plain)
                }
            }
            .padding(Organic.Space.card)
        default:
            EmptyView()
        }
    }

    /// Each line that gave a field, outlined where it sits on the paper. The
    /// picture is drawn to fill the screen, so the frame is scaled the same way.
    private var outlines: some View {
        GeometryReader { geo in
            let size = geo.size
            let aspect = camera.frameAspect
            let shown = size.width / size.height > aspect
                ? CGSize(width: size.width, height: size.width / aspect)
                : CGSize(width: size.height * aspect, height: size.height)
            let dx = (size.width - shown.width) / 2, dy = (size.height - shown.height) / 2
            ForEach(Array(camera.used).sorted(), id: \.self) { i in
                if i < camera.rows.count, camera.rows[i].quad.count == 4 {
                    // Along the line's own four corners, so a tilted receipt
                    // is outlined on its slant.
                    LineOutline(corners: camera.rows[i].quad.map { CGPoint(x: dx + $0.x * shown.width, y: dy + $0.y * shown.height) })
                        .stroke(Organic.Camera.frame, style: StrokeStyle(lineWidth: 2, lineJoin: .round))
                }
            }
        }
        .allowsHitTesting(false)
        .animation(.easeOut(duration: 0.15), value: camera.used)
    }

    private var tray: some View {
        let found = store.foundFields(camera.draft)
        return VStack(alignment: .leading, spacing: Organic.Space.l) {
            HStack(alignment: .firstTextBaseline) {
                Text("Found on this receipt").font(Organic.title)
                Spacer()
                Text(verbatim: status(found.isEmpty)).font(Organic.caption).foregroundStyle(Organic.Camera.quiet)
            }
            if continuing {
                Text("Now the rest of the receipt. It is joined to the part already read.")
                    .font(Organic.caption).foregroundStyle(Organic.Camera.quiet)
            }
            if found.isEmpty {
                Text(camera.state == .running ? "Hold the receipt inside the corners" : "Nothing read yet")
                    .font(Organic.value).foregroundStyle(Organic.Camera.quiet)
                    .frame(minHeight: 34, alignment: .leading)
            } else {
                FlowRow(spacing: Organic.Space.m) {
                    ForEach(found) { f in FoundChip(label: label(f.kind), value: f.value) }
                }
                // The shutter keeps this reading as it stands (decision #34).
                Text("Press when it is right: this is what gets saved. The photo is kept as the receipt and not read again.")
                    .font(Organic.caption).foregroundStyle(Organic.Camera.quiet)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                PhotosPicker(selection: $photo, matching: .images) { CameraTrayLabel(title: "Photos", symbol: "photo") }
                    .buttonStyle(.plain)
                Spacer()
                ShutterButton(enabled: camera.state == .running, action: shutter)
                Spacer()
                Button(action: typeInstead) { CameraTrayLabel(title: "Type instead") }.buttonStyle(.plain)
            }
            .padding(.top, Organic.Space.xs)
        }
        .padding(Organic.Space.gutter)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: Organic.Camera.trayRadius, topTrailingRadius: Organic.Camera.trayRadius, style: .continuous)
                .fill(Organic.Camera.tray)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func status(_ nothing: Bool) -> String {
        guard let s = camera.readSeconds, !nothing else { return "" }
        return String(localized: "\(s.formatted(.number.precision(.fractionLength(1)))) s · hold still")
    }

    private func label(_ kind: Store.FoundField.Kind) -> LocalizedStringKey {
        switch kind {
        case .total: return "Total"
        case .when: return "When"
        case .shop: return "Shop"
        case .card: return "Card"
        }
    }
}

/// The back camera, a frame read a few times a second, and the shutter.
/// Frames are read on the camera's own queue, one at a time; a frame that
/// arrives while one is being read is dropped, so reading never falls behind
/// the picture.
@Observable
final class ScanCamera: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, AVCapturePhotoCaptureDelegate {
    enum State { case starting, running, noCamera, denied }
    private(set) var state: State = .starting
    private(set) var rows: [ReceiptReader.Row] = []
    /// Everything read so far. A field once read stays while the hand wobbles:
    /// a frame that misses the total does not take it back.
    private(set) var draft = ReceiptDraft()
    /// The rows of the latest frame that gave a field.
    private(set) var used: Set<Int> = []
    /// Width over height of the frames, portrait.
    private(set) var frameAspect: CGFloat = 3.0 / 4.0
    private(set) var readSeconds: Double?
    private(set) var torchOn = false
    private(set) var hasTorch = false

    @ObservationIgnored let session = AVCaptureSession()
    @ObservationIgnored private let photoOutput = AVCapturePhotoOutput()
    @ObservationIgnored private let videoOutput = AVCaptureVideoDataOutput()
    @ObservationIgnored private let queue = DispatchQueue(label: "mochi.scan.frames", qos: .userInitiated)
    @ObservationIgnored private var device: AVCaptureDevice?
    @ObservationIgnored private var lastRead = Date.distantPast
    @ObservationIgnored private var taken: ((UIImage?) -> Void)?
    @ObservationIgnored private var configured = false
    /// The language order the frames are read in, once one frame showed the
    /// receipt is in the other script. Touched on the frame queue only.
    @ObservationIgnored private var liveOrder: [String]?
    /// Asked to stop while a photo was on its way: stop once it lands.
    @ObservationIgnored private var stopWhenTaken = false

    /// Starts the picture, or starts it again after a retake with nothing
    /// carried over from the last receipt.
    func start() {
        rows = []; used = []; draft = ReceiptDraft(); readSeconds = nil
        queue.async { self.liveOrder = nil }
        stopWhenTaken = false
        if configured {
            queue.async { if !self.session.isRunning { self.session.startRunning() } }
            return
        }
        // No camera at all (the simulator) is not the same as a refusal, and
        // sending the user to Settings for it would be a dead end.
        guard AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) != nil else { state = .noCamera; return }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: configure()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { ok in
                DispatchQueue.main.async { if ok { self.configure() } else { self.state = .denied } }
            }
        default: state = .denied
        }
    }

    /// The camera screen went: the picture stops, unless a photo is still
    /// on its way — then it stops when that lands.
    func pause() {
        setTorch(false)
        if taken != nil { stopWhenTaken = true; return }
        queue.async { self.session.stopRunning() }
    }

    func stop() { pause() }

    func toggleTorch() { setTorch(!torchOn) }

    func takePhoto(_ done: @escaping (UIImage?) -> Void) {
        guard state == .running, taken == nil else { return }
        taken = done
        photoOutput.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
    }

    /// The back camera as the system's multi-lens device where there is one.
    /// Only a virtual device switches lenses by itself, so only it goes to
    /// the ultra wide (macro) when a receipt comes close, as the Camera app
    /// does. The wide lens alone cannot focus nearer than about 20 cm on a
    /// Pro, and a receipt is held nearer than that.
    private static func backCamera() -> AVCaptureDevice? {
        AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInTripleCamera, .builtInDualWideCamera, .builtInWideAngleCamera],
                                         mediaType: .video, position: .back).devices.first
    }

    private func configure() {
        guard let cam = Self.backCamera(),
              let input = try? AVCaptureDeviceInput(device: cam) else { state = .noCamera; return }
        device = cam
        hasTorch = cam.hasTorch
        configured = true
        session.beginConfiguration()
        session.sessionPreset = .photo
        if session.canAddInput(input) { session.addInput(input) }
        if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: queue)
        if session.canAddOutput(videoOutput) { session.addOutput(videoOutput) }
        // Portrait frames, so a line's box is where it looks on screen.
        for c in [videoOutput.connection(with: .video), photoOutput.connection(with: .video)] {
            if let c, c.isVideoRotationAngleSupported(90) { c.videoRotationAngle = 90 }
        }
        session.commitConfiguration()
        if (try? cam.lockForConfiguration()) != nil {
            // A receipt is held a hand's length away.
            if cam.isFocusModeSupported(.continuousAutoFocus) { cam.focusMode = .continuousAutoFocus }
            if cam.isAutoFocusRangeRestrictionSupported { cam.autoFocusRangeRestriction = .near }
            cam.videoZoomFactor = Self.startingZoom(for: cam)
            if cam.isVirtualDevice {
                cam.setPrimaryConstituentDeviceSwitchingBehavior(.auto, restrictedSwitchingBehaviorConditions: [])
            }
            cam.unlockForConfiguration()
        }
        queue.async {
            self.session.startRunning()
            DispatchQueue.main.async { self.state = .running }
        }
    }

    /// Where the zoom starts. On a virtual device 1× is the ultra wide, so the
    /// start is the wide lens (the Camera app's "1×"). Where the ultra wide
    /// can focus close, that is all: the device goes to macro by itself.
    /// Where it cannot (a phone without macro), the picture is zoomed in so
    /// that a receipt filling the frame is held at the wide lens's closest
    /// focus, not nearer — Apple's advice for scanning.
    private static func startingZoom(for cam: AVCaptureDevice) -> CGFloat {
        let wideAt = cam.virtualDeviceSwitchOverVideoZoomFactors.first.map { CGFloat(truncating: $0) } ?? 1
        let ultra = cam.constituentDevices.first { $0.deviceType == .builtInUltraWideCamera }
        if let ultra, ultra.minimumFocusDistance > 0, ultra.minimumFocusDistance < 100 { return wideAt }
        let wide = cam.constituentDevices.first { $0.deviceType == .builtInWideAngleCamera } ?? cam
        let dims = CMVideoFormatDescriptionGetDimensions(cam.activeFormat.formatDescription)
        let extra = zoomToFill(fieldOfView: Double(cam.activeFormat.videoFieldOfView), zoom: Double(wideAt),
                               shortOverLong: Double(min(dims.width, dims.height)) / Double(max(1, max(dims.width, dims.height))),
                               minimumFocus: Double(wide.minimumFocusDistance))
        return min(wideAt * CGFloat(extra), cam.maxAvailableVideoZoomFactor, wideAt * 3)
    }

    /// How much more to zoom so a receipt fills `fill` of the screen's width
    /// at the lens's closest focus. `fieldOfView` is the format's long side in
    /// degrees at 1×; in portrait the screen's width is the frame's short
    /// side. 1 when the receipt already fills it from far enough away.
    static func zoomToFill(fieldOfView: Double, zoom: Double, shortOverLong: Double, minimumFocus: Double,
                           receiptWidth: Double = 80, fill: Double = 0.75) -> Double {
        guard minimumFocus > 0, fieldOfView > 0, zoom > 0 else { return 1 }
        let halfShort = tan(fieldOfView / 2 * .pi / 180) / zoom * shortOverLong
        let distance = (receiptWidth / fill / 2) / halfShort
        return max(1, minimumFocus / distance)
    }

    private func setTorch(_ on: Bool) {
        guard let d = device, d.hasTorch, (try? d.lockForConfiguration()) != nil else { return }
        d.torchMode = on ? .on : .off
        d.unlockForConfiguration()
        torchOn = on
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard Date.now.timeIntervalSince(lastRead) > 0.25, let pixels = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let began = Date.now
        let order = liveOrder ?? ReceiptReader.languages
        let aspect = CGFloat(CVPixelBufferGetWidth(pixels)) / CGFloat(max(1, CVPixelBufferGetHeight(pixels)))
        let rows = ReceiptReader.rows(in: VNImageRequestHandler(cvPixelBuffer: pixels, orientation: .up), languages: order, live: true, aspect: aspect)
        let texts = rows.map(\.text)
        // A receipt in the other script: read the next frames the other way round.
        if let other = ReceiptReader.otherOrder(for: texts, after: order) { liveOrder = other }
        let read = ReceiptParser.parse(texts)
        let used = ReceiptParser.linesUsed(texts, for: read)
        let seconds = Date.now.timeIntervalSince(began)
        lastRead = .now
        DispatchQueue.main.async {
            self.rows = rows
            self.used = used
            self.frameAspect = aspect
            self.readSeconds = seconds
            self.draft = self.draft.filled(from: read, preferringOther: true)
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let image = photo.fileDataRepresentation().flatMap(UIImage.init(data:))
        DispatchQueue.main.async {
            let done = self.taken
            self.taken = nil
            done?(image)
            if self.stopWhenTaken {
                self.stopWhenTaken = false
                self.queue.async { self.session.stopRunning() }
            }
        }
    }
}

/// The live picture, filling its frame.
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var preview: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }

    func makeUIView(context: Context) -> PreviewView {
        let v = PreviewView()
        v.preview.session = session
        v.preview.videoGravity = .resizeAspectFill
        return v
    }
    func updateUIView(_ v: PreviewView, context: Context) {}
}
