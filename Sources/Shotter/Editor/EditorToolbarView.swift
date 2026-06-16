import AppKit

final class EditorToolbarView: NSView {
    private weak var canvasView: EditorCanvasView?
    private var buttons: [NSButton] = []
    private let colorWell = NSColorWell()

    init(canvasView: EditorCanvasView) {
        self.canvasView = canvasView
        super.init(frame: .zero)
        canvasView.onSelectionChange = { [weak self] color in
            self?.updateColorWell(with: color)
        }
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 8
        stack.alignment = .centerY
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        for tool in EditorTool.allCases {
            let button = NSButton(title: tool.iconTitle, target: self, action: #selector(selectTool(_:)))
            button.toolTip = tool.rawValue
            button.font = .systemFont(ofSize: 22, weight: .semibold)
            button.bezelStyle = .rounded
            button.identifier = NSUserInterfaceItemIdentifier(tool.rawValue)
            button.widthAnchor.constraint(equalToConstant: 48).isActive = true
            stack.addArrangedSubview(button)
            buttons.append(button)
        }

        stack.addArrangedSubview(separator())

        let colorLabel = NSTextField(labelWithString: "Color")
        colorLabel.textColor = .secondaryLabelColor
        stack.addArrangedSubview(colorLabel)
        colorWell.color = .systemRed
        colorWell.isEnabled = false
        colorWell.target = self
        colorWell.action = #selector(changeSelectedColor(_:))
        colorWell.widthAnchor.constraint(equalToConstant: 44).isActive = true
        stack.addArrangedSubview(colorWell)

        stack.addArrangedSubview(separator())
        let saveButton = NSButton(title: "💾", target: self, action: #selector(savePNG))
        saveButton.toolTip = "Save As…"
        saveButton.font = .systemFont(ofSize: 22, weight: .semibold)
        saveButton.bezelStyle = .rounded
        saveButton.widthAnchor.constraint(equalToConstant: 48).isActive = true
        stack.addArrangedSubview(saveButton)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -12),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        updateButtons()
    }

    @objc private func selectTool(_ sender: NSButton) {
        guard let raw = sender.identifier?.rawValue, let tool = EditorTool(rawValue: raw) else { return }
        canvasView?.tool = tool
        updateButtons()
    }

    @objc private func changeSelectedColor(_ sender: NSColorWell) {
        canvasView?.applyColorToSelectedAnnotation(sender.color)
    }

    @objc private func savePNG() {
        canvasView?.savePNG()
    }

    private func updateColorWell(with color: NSColor?) {
        colorWell.isEnabled = color != nil
        if let color {
            colorWell.color = color
        }
    }

    private func updateButtons() {
        for button in buttons {
            button.state = button.identifier?.rawValue == canvasView?.tool.rawValue ? .on : .off
        }
    }

    private func separator() -> NSView {
        let view = NSBox()
        view.boxType = .separator
        return view
    }
}
