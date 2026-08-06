import AppKit

final class EditorToolbarView: NSView {
    private weak var canvasView: EditorCanvasView?
    private var buttons: [NSButton] = []
    private let colorWell = NSColorWell()
    private let borderColorWell = NSColorWell()
    private let weightStepper = NSStepper()
    private let weightLabel = NSTextField(labelWithString: "—")

    init(canvasView: EditorCanvasView) {
        self.canvasView = canvasView
        super.init(frame: .zero)
        canvasView.onSelectionChange = { [weak self] color, borderColor, weight in
            self?.updateSelectionControls(color: color, borderColor: borderColor, weight: weight)
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
            let button = iconButton(symbolName: tool.symbolName, fallbackTitle: tool.iconTitle, target: self, action: #selector(selectTool(_:)))
            button.toolTip = tool.rawValue
            button.identifier = NSUserInterfaceItemIdentifier(tool.rawValue)
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

        let borderColorLabel = NSTextField(labelWithString: "Border")
        borderColorLabel.textColor = .secondaryLabelColor
        stack.addArrangedSubview(borderColorLabel)
        borderColorWell.color = .white
        borderColorWell.isEnabled = false
        borderColorWell.toolTip = "Border color (Step badges)"
        borderColorWell.target = self
        borderColorWell.action = #selector(changeSelectedBorderColor(_:))
        borderColorWell.widthAnchor.constraint(equalToConstant: 44).isActive = true
        stack.addArrangedSubview(borderColorWell)

        let weightTitle = NSTextField(labelWithString: "Weight")
        weightTitle.textColor = .secondaryLabelColor
        stack.addArrangedSubview(weightTitle)
        weightStepper.minValue = Double(min(Annotation.minimumLineWidth, Annotation.minimumTextFontSize))
        weightStepper.maxValue = Double(max(Annotation.maximumLineWidth, Annotation.maximumTextFontSize))
        weightStepper.increment = 1
        weightStepper.isEnabled = false
        weightStepper.target = self
        weightStepper.action = #selector(changeSelectedWeight(_:))
        stack.addArrangedSubview(weightStepper)
        weightLabel.alignment = .right
        weightLabel.widthAnchor.constraint(equalToConstant: 28).isActive = true
        stack.addArrangedSubview(weightLabel)

        stack.addArrangedSubview(separator())
        let copyButton = iconButton(symbolName: "doc.on.doc", fallbackTitle: "📋", target: self, action: #selector(copyImage))
        copyButton.toolTip = "Copy"
        stack.addArrangedSubview(copyButton)
        let saveButton = iconButton(symbolName: "square.and.arrow.down", fallbackTitle: "💾", target: self, action: #selector(savePNG))
        saveButton.toolTip = "Save As…"
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

    @objc private func changeSelectedBorderColor(_ sender: NSColorWell) {
        canvasView?.applyBorderColorToSelectedAnnotation(sender.color)
    }

    @objc private func changeSelectedWeight(_ sender: NSStepper) {
        canvasView?.applyWeightToSelectedAnnotation(CGFloat(sender.doubleValue))
    }

    @objc private func copyImage() {
        canvasView?.copyToClipboard()
    }

    @objc private func savePNG() {
        canvasView?.savePNG()
    }

    private func updateSelectionControls(color: NSColor?, borderColor: NSColor?, weight: CGFloat?) {
        colorWell.isEnabled = color != nil
        if let color {
            colorWell.color = color
        }
        borderColorWell.isEnabled = borderColor != nil
        if let borderColor {
            borderColorWell.color = borderColor
        }
        weightStepper.isEnabled = weight != nil
        if let weight {
            weightStepper.doubleValue = Double(weight)
            weightLabel.stringValue = String(format: "%.0f", weight)
        } else {
            weightLabel.stringValue = "—"
        }
    }

    private func iconButton(symbolName: String, fallbackTitle: String, target: AnyObject?, action: Selector) -> NSButton {
        let button = NSButton(title: fallbackTitle, target: target, action: action)
        if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: fallbackTitle) {
            let config = NSImage.SymbolConfiguration(pointSize: 17, weight: .semibold)
            button.image = image.withSymbolConfiguration(config)
            button.imagePosition = .imageOnly
            button.title = ""
        } else {
            button.font = .systemFont(ofSize: 22, weight: .semibold)
            button.imagePosition = .noImage
        }
        button.bezelStyle = .rounded
        button.alignment = .center
        button.widthAnchor.constraint(equalToConstant: 48).isActive = true
        button.heightAnchor.constraint(equalToConstant: 44).isActive = true
        return button
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
