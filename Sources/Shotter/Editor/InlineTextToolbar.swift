import AppKit

/// Small floating bar shown next to the text you are typing: font size, text
/// color and card color, applied live to the editor and to the annotation you
/// commit.
final class InlineTextToolbar: NSView {
    private static let textColors: [NSColor] = [.black, .white, .systemRed, .systemBlue, .systemGreen]
    private static let cardColors: [NSColor] = [.white, .black, .systemYellow, .systemRed, .systemBlue]
    private static let fontSizeStep: CGFloat = 4

    var onFontSize: ((CGFloat) -> Void)?
    var onColor: ((NSColor) -> Void)?
    var onBackgroundColor: ((NSColor) -> Void)?

    private let sizeLabel = NSTextField(labelWithString: "")
    private var textSwatches: [NSButton] = []
    private var cardSwatches: [NSButton] = []
    private var fontSize: CGFloat
    private var color: NSColor
    private var backgroundColor: NSColor

    init(fontSize: CGFloat, color: NSColor, backgroundColor: NSColor) {
        self.fontSize = fontSize
        self.color = color
        self.backgroundColor = backgroundColor
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.white.cgColor
        layer?.cornerRadius = 10
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.black.withAlphaComponent(0.12).cgColor
        shadow = {
            let shadow = NSShadow()
            shadow.shadowColor = NSColor.black.withAlphaComponent(0.25)
            shadow.shadowBlurRadius = 8
            shadow.shadowOffset = NSSize(width: 0, height: -2)
            return shadow
        }()

        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 6
        stack.alignment = .centerY
        stack.edgeInsets = NSEdgeInsets(top: 5, left: 8, bottom: 5, right: 8)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        stack.addArrangedSubview(textButton("A−", action: #selector(shrink), toolTip: "Smaller text"))
        sizeLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        sizeLabel.textColor = .black
        sizeLabel.alignment = .center
        sizeLabel.widthAnchor.constraint(equalToConstant: 24).isActive = true
        stack.addArrangedSubview(sizeLabel)
        stack.addArrangedSubview(textButton("A+", action: #selector(grow), toolTip: "Bigger text"))

        stack.addArrangedSubview(separator())
        textSwatches = Self.textColors.enumerated().map { index, swatchColor in
            swatchButton(color: swatchColor, tag: index, action: #selector(pickColor(_:)), toolTip: "Text color")
        }
        textSwatches.forEach(stack.addArrangedSubview)

        stack.addArrangedSubview(separator())
        cardSwatches = Self.cardColors.enumerated().map { index, swatchColor in
            swatchButton(color: swatchColor, tag: index, action: #selector(pickBackgroundColor(_:)), toolTip: "Background color")
        }
        cardSwatches.forEach(stack.addArrangedSubview)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        refresh()
    }

    private func separator() -> NSView {
        let box = NSBox()
        box.boxType = .separator
        box.heightAnchor.constraint(equalToConstant: 18).isActive = true
        return box
    }

    private func swatchButton(color swatchColor: NSColor, tag: Int, action: Selector, toolTip: String) -> NSButton {
        let button = NSButton(title: "", target: self, action: action)
        button.tag = tag
        button.isBordered = false
        // Keep the caret in the text you are typing while restyling it.
        button.refusesFirstResponder = true
        button.wantsLayer = true
        button.layer?.backgroundColor = swatchColor.cgColor
        button.layer?.cornerRadius = 9
        button.toolTip = toolTip
        button.widthAnchor.constraint(equalToConstant: 18).isActive = true
        button.heightAnchor.constraint(equalToConstant: 18).isActive = true
        return button
    }

    private func textButton(_ title: String, action: Selector, toolTip: String) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.isBordered = false
        button.refusesFirstResponder = true
        button.font = .systemFont(ofSize: 13, weight: .semibold)
        button.contentTintColor = .black
        button.toolTip = toolTip
        button.widthAnchor.constraint(equalToConstant: 26).isActive = true
        return button
    }

    @objc private func shrink() {
        setFontSize(fontSize - Self.fontSizeStep)
    }

    @objc private func grow() {
        setFontSize(fontSize + Self.fontSizeStep)
    }

    private func setFontSize(_ newValue: CGFloat) {
        fontSize = Swift.min(Swift.max(newValue, Annotation.minimumTextFontSize), Annotation.maximumTextFontSize)
        refresh()
        onFontSize?(fontSize)
    }

    @objc private func pickColor(_ sender: NSButton) {
        guard Self.textColors.indices.contains(sender.tag) else { return }
        color = Self.textColors[sender.tag]
        refresh()
        onColor?(color)
    }

    @objc private func pickBackgroundColor(_ sender: NSButton) {
        guard Self.cardColors.indices.contains(sender.tag) else { return }
        backgroundColor = Self.cardColors[sender.tag]
        refresh()
        onBackgroundColor?(backgroundColor)
    }

    private func refresh() {
        sizeLabel.stringValue = String(format: "%.0f", fontSize)
        highlight(textSwatches, colors: Self.textColors, selected: color)
        highlight(cardSwatches, colors: Self.cardColors, selected: backgroundColor)
    }

    private func highlight(_ buttons: [NSButton], colors: [NSColor], selected: NSColor) {
        for (index, button) in buttons.enumerated() {
            let isSelected = colors[index] == selected
            button.layer?.borderWidth = isSelected ? 3 : 1
            button.layer?.borderColor = (isSelected ? NSColor.systemBlue : NSColor.black.withAlphaComponent(0.2)).cgColor
        }
    }
}
