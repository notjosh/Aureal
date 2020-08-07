import Cocoa

extension NSView {
    func pinEdges(to: NSView? = nil) {
        guard let to = to ?? superview else {
            print("Nothing to pin to, bailing.")
            return
        }

        NSLayoutConstraint.activate([
            leadingAnchor.constraint(equalTo: to.leadingAnchor),
            trailingAnchor.constraint(equalTo: to.trailingAnchor),
            topAnchor.constraint(equalTo: to.topAnchor),
            bottomAnchor.constraint(equalTo: to.bottomAnchor),
        ])
    }
}
