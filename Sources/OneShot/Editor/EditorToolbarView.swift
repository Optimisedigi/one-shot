import AppKit

/// Round color chip drawn over a hidden color well, so the well still opens
/// the system picker while the chip matches the toolbar mock.
private final class ColorSwatchView: NSView {
    let colorWell: NSColorWell

    init(colorWell: NSColorWell) {
        self.colorWell = colorWell
        super.init(frame: .zero)
        wantsLayer = true
        colorWell.isHidden = true
        addSubview(colorWell)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        let ring = bounds.insetBy(dx: 2.5, dy: 2.5)
        NSColor.black.withAlphaComponent(0.14).setStroke()
        let ringPath = NSBezierPath(ovalIn: ring)
        ringPath.lineWidth = 1
        ringPath.stroke()

        let fill = ring.insetBy(dx: 2, dy: 2)
        colorWell.color.setFill()
        NSBezierPath(ovalIn: fill).fill()
        NSColor.black.withAlphaComponent(0.12).setStroke()
        let fillPath = NSBezierPath(ovalIn: fill)
        fillPath.lineWidth = 1
        fillPath.stroke()
    }

    override func mouseDown(with event: NSEvent) {
        guard colorWell.isEnabled else { return }
        colorWell.activate(true)
    }
}

/// Borderless toolbar button that paints the mock's hover and selected pills.
/// Selection wins over hover, matching the HTML (`aria-pressed` after `:hover`).
private final class ToolbarHoverButton: NSButton {
    var showsSelectionChrome = false
    var hoverFill = NSColor.white.withAlphaComponent(0.55)
    private var hovered = false
    private var tracking: NSTrackingArea?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        focusRingType = .none
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        focusRingType = .none
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking {
            removeTrackingArea(tracking)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self
        )
        addTrackingArea(area)
        tracking = area
    }

    override func mouseEntered(with event: NSEvent) {
        hovered = true
        applyChrome()
    }

    override func mouseExited(with event: NSEvent) {
        hovered = false
        applyChrome()
    }

    override func layout() {
        super.layout()
        applyChrome()
    }

    func applyChrome() {
        guard let layer else { return }
        layer.masksToBounds = false
        if showsSelectionChrome {
            layer.backgroundColor = NSColor.white.cgColor
            layer.borderWidth = 1
            layer.borderColor = NSColor.black.withAlphaComponent(0.05).cgColor
            layer.shadowColor = NSColor.black.cgColor
            layer.shadowOpacity = 0.12
            layer.shadowRadius = 2
            layer.shadowOffset = CGSize(width: 0, height: -1)
            layer.shadowPath = CGPath(
                roundedRect: bounds,
                cornerWidth: layer.cornerRadius,
                cornerHeight: layer.cornerRadius,
                transform: nil
            )
        } else if hovered {
            layer.backgroundColor = hoverFill.cgColor
            layer.borderWidth = 0
            layer.shadowOpacity = 0
            layer.shadowPath = nil
        } else {
            layer.backgroundColor = NSColor.clear.cgColor
            layer.borderWidth = 0
            layer.shadowOpacity = 0
            layer.shadowPath = nil
        }
    }
}

/// Editor chrome matching the light segmented toolbar mock: tools in one pill,
/// fill/border swatches, a compact weight stepper, and icon actions on the right.
final class EditorToolbarView: NSView {
    private weak var canvasView: EditorCanvasView?
    private var toolButtons: [NSButton] = []
    private let colorWell = NSColorWell()
    private let borderColorWell = NSColorWell()
    private let weightLabel = NSTextField(labelWithString: "—")
    private let increaseWeightButton = ToolbarHoverButton()
    private let decreaseWeightButton = ToolbarHoverButton()
    private var weightValue: CGFloat?

    private static let barBackground = NSColor(srgbRed: 0.984, green: 0.984, blue: 0.988, alpha: 1)
    private static let segmentBackground = NSColor(srgbRed: 0.929, green: 0.929, blue: 0.941, alpha: 1)
    private static let ink = NSColor(srgbRed: 0.227, green: 0.227, blue: 0.235, alpha: 1)
    private static let muted = NSColor(srgbRed: 0.431, green: 0.431, blue: 0.451, alpha: 1)
    private static let accent = NSColor(srgbRed: 0.039, green: 0.518, blue: 1, alpha: 1)
    private static let hairline = NSColor.black.withAlphaComponent(0.1)

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
        layer?.backgroundColor = Self.barBackground.cgColor
        installBottomHairline()

        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 14
        stack.alignment = .centerY
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        stack.addArrangedSubview(toolSegment())
        stack.addArrangedSubview(hairlineDivider())
        stack.addArrangedSubview(propertiesGroup())

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        spacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        stack.addArrangedSubview(spacer)

        stack.addArrangedSubview(actionsGroup())

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        colorWell.color = NSColor(srgbRed: 1, green: 0.42, blue: 0.42, alpha: 1)
        borderColorWell.color = .white
        updateButtons()
        updateSelectionControls(color: nil, borderColor: nil, weight: nil)
    }

    private func toolSegment() -> NSView {
        let segment = NSStackView()
        segment.orientation = .horizontal
        segment.spacing = 2
        segment.alignment = .centerY
        segment.edgeInsets = NSEdgeInsets(top: 3, left: 3, bottom: 3, right: 3)
        segment.wantsLayer = true
        segment.layer?.backgroundColor = Self.segmentBackground.cgColor
        segment.layer?.cornerRadius = 10

        for tool in EditorTool.allCases {
            let button = toolButton(tool)
            segment.addArrangedSubview(button)
            toolButtons.append(button)
        }
        return segment
    }

    private func propertiesGroup() -> NSView {
        let props = NSStackView()
        props.orientation = .horizontal
        props.spacing = 14
        props.alignment = .centerY

        props.addArrangedSubview(property(title: "Fill", control: styledColorWell(colorWell, action: #selector(changeSelectedColor(_:)), toolTip: "Fill color")))
        props.addArrangedSubview(property(title: "Border", control: styledColorWell(borderColorWell, action: #selector(changeSelectedBorderColor(_:)), toolTip: "Border color")))
        props.addArrangedSubview(property(title: "Weight", control: weightStepper()))
        return props
    }

    private func actionsGroup() -> NSView {
        let actions = NSStackView()
        actions.orientation = .horizontal
        actions.spacing = 8
        actions.alignment = .centerY
        actions.addArrangedSubview(iconButton(symbolName: "doc.on.doc", toolTip: "Save to Desktop & copy file path", action: #selector(copyImage)))
        actions.addArrangedSubview(iconButton(symbolName: "square.and.arrow.down", toolTip: "Save As…", action: #selector(savePNG)))
        return actions
    }

    private func property(title: String, control: NSView) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 8
        row.alignment = .centerY
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 12, weight: .regular)
        label.textColor = Self.muted
        row.addArrangedSubview(label)
        row.addArrangedSubview(control)
        return row
    }

    private func toolButton(_ tool: EditorTool) -> ToolbarHoverButton {
        let button = ToolbarHoverButton(title: "", target: self, action: #selector(selectTool(_:)))
        button.identifier = NSUserInterfaceItemIdentifier(tool.rawValue)
        button.toolTip = tool.rawValue
        button.isBordered = false
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyDown
        button.setButtonType(.toggle)
        button.hoverFill = NSColor.white.withAlphaComponent(0.55)
        if tool == .step {
            // A filled SF Symbol becomes a solid disc once the toolbar tints
            // it, so the number vanishes. Draw the circle and the digit apart.
            button.image = stepToolImage(color: Self.ink)
        } else if let image = NSImage(systemSymbolName: tool.symbolName, accessibilityDescription: tool.rawValue) {
            button.image = image.withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 14, weight: .medium))
        } else {
            button.title = tool.iconTitle
            button.font = .systemFont(ofSize: 13, weight: .medium)
        }
        button.wantsLayer = true
        button.layer?.cornerRadius = 8
        button.contentTintColor = Self.ink
        button.widthAnchor.constraint(equalToConstant: 30).isActive = true
        button.heightAnchor.constraint(equalToConstant: 30).isActive = true
        return button
    }

    private func styledColorWell(_ well: NSColorWell, action: Selector, toolTip: String) -> NSView {
        well.colorWellStyle = .expanded
        well.isBordered = false
        well.isEnabled = false
        well.target = self
        well.action = action
        well.toolTip = toolTip

        let swatch = ColorSwatchView(colorWell: well)
        swatch.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            swatch.widthAnchor.constraint(equalToConstant: 28),
            swatch.heightAnchor.constraint(equalToConstant: 28)
        ])
        return swatch
    }

    private func weightStepper() -> NSView {
        let box = NSView()
        box.wantsLayer = true
        box.layer?.cornerRadius = 7
        box.layer?.masksToBounds = true
        box.layer?.backgroundColor = NSColor.white.cgColor
        box.layer?.borderWidth = 1
        box.layer?.borderColor = NSColor.black.withAlphaComponent(0.12).cgColor
        box.translatesAutoresizingMaskIntoConstraints = false

        weightLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
        weightLabel.textColor = NSColor(srgbRed: 0.114, green: 0.114, blue: 0.122, alpha: 1)
        weightLabel.alignment = .center
        weightLabel.translatesAutoresizingMaskIntoConstraints = false

        configureWeightArrow(increaseWeightButton, symbol: "chevron.up", action: #selector(increaseWeight), toolTip: "Increase weight")
        configureWeightArrow(decreaseWeightButton, symbol: "chevron.down", action: #selector(decreaseWeight), toolTip: "Decrease weight")
        increaseWeightButton.wantsLayer = true
        increaseWeightButton.layer?.cornerRadius = 4
        decreaseWeightButton.wantsLayer = true
        decreaseWeightButton.layer?.cornerRadius = 4

        let arrows = NSStackView(views: [increaseWeightButton, decreaseWeightButton])
        arrows.orientation = .vertical
        arrows.spacing = 0
        arrows.distribution = .fillEqually
        arrows.translatesAutoresizingMaskIntoConstraints = false

        let rule = NSView()
        rule.wantsLayer = true
        rule.layer?.backgroundColor = Self.hairline.cgColor
        rule.translatesAutoresizingMaskIntoConstraints = false

        box.addSubview(weightLabel)
        box.addSubview(rule)
        box.addSubview(arrows)
        NSLayoutConstraint.activate([
            box.heightAnchor.constraint(equalToConstant: 28),
            weightLabel.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 2),
            weightLabel.centerYAnchor.constraint(equalTo: box.centerYAnchor),
            weightLabel.widthAnchor.constraint(equalToConstant: 30),
            rule.leadingAnchor.constraint(equalTo: weightLabel.trailingAnchor, constant: 2),
            rule.topAnchor.constraint(equalTo: box.topAnchor),
            rule.bottomAnchor.constraint(equalTo: box.bottomAnchor),
            rule.widthAnchor.constraint(equalToConstant: 1),
            arrows.leadingAnchor.constraint(equalTo: rule.trailingAnchor),
            arrows.trailingAnchor.constraint(equalTo: box.trailingAnchor),
            arrows.topAnchor.constraint(equalTo: box.topAnchor),
            arrows.bottomAnchor.constraint(equalTo: box.bottomAnchor),
            arrows.widthAnchor.constraint(equalToConstant: 22)
        ])
        return box
    }

    private func configureWeightArrow(_ button: NSButton, symbol: String, action: Selector, toolTip: String) {
        let hoverButton = button as? ToolbarHoverButton
        hoverButton?.hoverFill = NSColor(srgbRed: 0.941, green: 0.941, blue: 0.949, alpha: 1)
        button.isBordered = false
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyDown
        button.target = self
        button.action = action
        button.toolTip = toolTip
        button.contentTintColor = Self.muted
        if let image = NSImage(systemSymbolName: symbol, accessibilityDescription: toolTip) {
            button.image = image.withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 8, weight: .bold))
        }
    }

    private func iconButton(symbolName: String, toolTip: String, action: Selector) -> ToolbarHoverButton {
        let button = ToolbarHoverButton(title: "", target: self, action: action)
        button.isBordered = false
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyDown
        button.toolTip = toolTip
        button.hoverFill = Self.segmentBackground
        button.contentTintColor = Self.ink
        if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: toolTip) {
            button.image = image.withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 15, weight: .medium))
        }
        button.wantsLayer = true
        button.layer?.cornerRadius = 8
        button.widthAnchor.constraint(equalToConstant: 32).isActive = true
        button.heightAnchor.constraint(equalToConstant: 30).isActive = true
        return button
    }

    private func hairlineDivider() -> NSView {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = Self.hairline.cgColor
        view.widthAnchor.constraint(equalToConstant: 1).isActive = true
        view.heightAnchor.constraint(equalToConstant: 22).isActive = true
        return view
    }

    private func installBottomHairline() {
        let line = NSView()
        line.wantsLayer = true
        line.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.08).cgColor
        line.translatesAutoresizingMaskIntoConstraints = false
        addSubview(line)
        NSLayoutConstraint.activate([
            line.leadingAnchor.constraint(equalTo: leadingAnchor),
            line.trailingAnchor.constraint(equalTo: trailingAnchor),
            line.bottomAnchor.constraint(equalTo: bottomAnchor),
            line.heightAnchor.constraint(equalToConstant: 1)
        ])
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

    @objc private func increaseWeight() {
        stepWeight(by: 1)
    }

    @objc private func decreaseWeight() {
        stepWeight(by: -1)
    }

    private func stepWeight(by delta: CGFloat) {
        guard let weightValue else { return }
        canvasView?.applyWeightToSelectedAnnotation(weightValue + delta)
    }

    @objc private func copyImage() {
        canvasView?.copyToClipboard()
    }

    @objc private func savePNG() {
        canvasView?.savePNG()
    }

    private func updateSelectionControls(color: NSColor?, borderColor: NSColor?, weight: CGFloat?) {
        colorWell.isEnabled = color != nil
        colorWell.superview?.alphaValue = color == nil ? 0.4 : 1
        if let color {
            colorWell.color = color
        }
        (colorWell.superview as? ColorSwatchView)?.needsDisplay = true
        borderColorWell.isEnabled = borderColor != nil
        borderColorWell.superview?.alphaValue = borderColor == nil ? 0.4 : 1
        if let borderColor {
            borderColorWell.color = borderColor
        }
        (borderColorWell.superview as? ColorSwatchView)?.needsDisplay = true
        weightValue = weight
        let enabled = weight != nil
        increaseWeightButton.isEnabled = enabled
        decreaseWeightButton.isEnabled = enabled
        increaseWeightButton.alphaValue = enabled ? 1 : 0.4
        decreaseWeightButton.alphaValue = enabled ? 1 : 0.4
        if let weight {
            weightLabel.stringValue = String(format: "%.0f", weight)
            weightLabel.textColor = NSColor(srgbRed: 0.114, green: 0.114, blue: 0.122, alpha: 1)
        } else {
            weightLabel.stringValue = "—"
            weightLabel.textColor = Self.muted
        }
    }

    private func stepToolImage(color: NSColor) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            let stroke = NSBezierPath(ovalIn: rect.insetBy(dx: 1, dy: 1))
            stroke.lineWidth = 1.4
            color.setStroke()
            stroke.stroke()

            let label = NSAttributedString(
                string: "1",
                attributes: [
                    .font: NSFont.systemFont(ofSize: 10, weight: .semibold),
                    .foregroundColor: color
                ]
            )
            let textSize = label.size()
            label.draw(at: NSPoint(
                x: (rect.width - textSize.width) / 2,
                y: (rect.height - textSize.height) / 2 - 0.5
            ))
            return true
        }
        image.isTemplate = false
        return image
    }

    private func updateButtons() {
        let selected = canvasView?.tool.rawValue
        for button in toolButtons {
            let isOn = button.identifier?.rawValue == selected
            button.state = isOn ? .on : .off
            (button as? ToolbarHoverButton)?.showsSelectionChrome = isOn
            button.contentTintColor = isOn ? Self.accent : Self.ink
            let color = isOn ? Self.accent : Self.ink
            if button.identifier?.rawValue == EditorTool.step.rawValue {
                button.image = stepToolImage(color: color)
            } else if let image = button.image {
                let tinted = image.copy() as? NSImage ?? image
                tinted.isTemplate = false
                tinted.lockFocus()
                (isOn ? Self.accent : Self.ink).set()
                NSRect(origin: .zero, size: tinted.size).fill(using: .sourceIn)
                tinted.unlockFocus()
                button.image = tinted
            }
            (button as? ToolbarHoverButton)?.applyChrome()
        }
    }
}
