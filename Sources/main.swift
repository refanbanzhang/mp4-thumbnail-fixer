import AppKit

final class DropView: NSView {
    var onFiles: (([URL]) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL])
        wantsLayer = true
        layer?.cornerRadius = 12
        layer?.borderWidth = 2
        layer?.borderColor = NSColor.systemBlue.withAlphaComponent(0.45).cgColor
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        layer?.borderColor = NSColor.systemBlue.cgColor
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        layer?.borderColor = NSColor.systemBlue.withAlphaComponent(0.45).cgColor
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let urls = sender.draggingPasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [URL] ?? []
        layer?.borderColor = NSColor.systemBlue.withAlphaComponent(0.45).cgColor
        onFiles?(urls.filter { $0.isFileURL })
        return !urls.isEmpty
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let title = "拖入视频文件到这里"
        let subtitle = "支持 MP4、MPEG-TS 等常见视频容器"
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 20, weight: .medium),
            .foregroundColor: NSColor.labelColor
        ]
        let subtitleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13),
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        let titleSize = title.size(withAttributes: titleAttributes)
        let subtitleSize = subtitle.size(withAttributes: subtitleAttributes)
        title.draw(at: NSPoint(x: (bounds.width - titleSize.width) / 2, y: bounds.midY + 10),
                   withAttributes: titleAttributes)
        subtitle.draw(at: NSPoint(x: (bounds.width - subtitleSize.width) / 2, y: bounds.midY - 18),
                      withAttributes: subtitleAttributes)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow!
    private let statusLabel = NSTextField(labelWithString: "请选择视频，或将视频拖入上方区域")
    private let progress = NSProgressIndicator()
    private let convertButton = NSButton(title: "选择视频", target: nil, action: nil)
    private var running = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        let content = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        let dropView = DropView(frame: NSRect(x: 40, y: 125, width: 520, height: 190))
        dropView.onFiles = { [weak self] urls in self?.convert(urls) }

        convertButton.target = self
        convertButton.action = #selector(selectFiles)
        convertButton.bezelStyle = .rounded
        convertButton.controlSize = .large

        statusLabel.alignment = .center
        statusLabel.lineBreakMode = .byTruncatingMiddle

        progress.style = .spinning
        progress.controlSize = .small
        progress.isDisplayedWhenStopped = false

        content.addSubview(dropView)
        content.addSubview(convertButton)
        content.addSubview(statusLabel)
        content.addSubview(progress)

        dropView.translatesAutoresizingMaskIntoConstraints = false
        convertButton.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        progress.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            dropView.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 40),
            dropView.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -40),
            dropView.topAnchor.constraint(equalTo: content.topAnchor, constant: 35),
            dropView.heightAnchor.constraint(equalToConstant: 190),
            convertButton.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            convertButton.topAnchor.constraint(equalTo: dropView.bottomAnchor, constant: 18),
            statusLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 30),
            statusLabel.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -30),
            statusLabel.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -18),
            progress.trailingAnchor.constraint(equalTo: statusLabel.leadingAnchor, constant: -8),
            progress.centerYAnchor.constraint(equalTo: statusLabel.centerYAnchor)
        ])

        window = NSWindow(contentRect: content.frame,
                          styleMask: [.titled, .closable, .miniaturizable],
                          backing: .buffered,
                          defer: false)
        window.title = "MP4 缩略图修复器"
        window.contentView = content
        window.center()
        window.setContentSize(NSSize(width: 600, height: 400))
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func selectFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedFileTypes = ["mp4", "mov", "ts", "m2ts", "mts", "mkv", "avi", "webm"]
        if panel.runModal() == .OK {
            convert(panel.urls)
        }
    }

    private func convert(_ urls: [URL]) {
        guard !running, !urls.isEmpty else { return }
        running = true
        convertButton.isEnabled = false
        progress.startAnimation(nil)
        processNext(urls, index: 0)
    }

    private func processNext(_ urls: [URL], index: Int) {
        guard index < urls.count else {
            running = false
            convertButton.isEnabled = true
            progress.stopAnimation(nil)
            statusLabel.stringValue = "全部完成，原文件未修改"
            return
        }

        let input = urls[index]
        let output = uniqueOutput(for: input)
        statusLabel.stringValue = "正在处理 \(index + 1)/\(urls.count)：\(input.lastPathComponent)"

        guard let ffmpeg = Bundle.main.url(forResource: "ffmpeg", withExtension: nil) else {
            finishWithError("应用内缺少 ffmpeg")
            return
        }

        let task = Process()
        task.executableURL = ffmpeg
        task.arguments = [
            "-hide_banner", "-y", "-i", input.path,
            "-map", "0:v?", "-map", "0:a?", "-c", "copy",
            "-movflags", "+faststart", output.path
        ]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        do {
            try task.run()
            DispatchQueue.global(qos: .userInitiated).async {
                pipe.fileHandleForReading.readDataToEndOfFile()
                task.waitUntilExit()
                DispatchQueue.main.async {
                    if task.terminationStatus == 0 {
                        self.processNext(urls, index: index + 1)
                    } else {
                        self.finishWithError("处理失败：\(input.lastPathComponent)")
                    }
                }
            }
        } catch {
            finishWithError("无法启动 ffmpeg：\(error.localizedDescription)")
        }
    }

    private func uniqueOutput(for input: URL) -> URL {
        let base = input.deletingPathExtension().lastPathComponent + "-fixed"
        var output = input.deletingLastPathComponent().appendingPathComponent(base + ".mp4")
        var index = 1
        while FileManager.default.fileExists(atPath: output.path) {
            output = input.deletingLastPathComponent()
                .appendingPathComponent("\(base)-\(index).mp4")
            index += 1
        }
        return output
    }

    private func finishWithError(_ message: String) {
        running = false
        convertButton.isEnabled = true
        progress.stopAnimation(nil)
        statusLabel.stringValue = message
        NSSound.beep()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
