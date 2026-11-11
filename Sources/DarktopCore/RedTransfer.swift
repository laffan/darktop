/// The color transform Darktop loads into every display's gamma table.
///
/// macOS gamma tables map each channel on its own, so the only way to stop a
/// display emitting green and blue light is to send those channels to zero.
/// The red channel is passed through (optionally inverted) and scaled by
/// `level`.
public struct RedTransfer: Equatable {
    /// Peak red output, clamped to 0...1.
    public let level: Float
    /// When true, black input becomes bright red and white input becomes black.
    public let inverted: Bool

    public init(level: Float, inverted: Bool) {
        self.level = min(max(level, 0), 1)
        self.inverted = inverted
    }

    /// Red channel samples for a table with `size` entries (at least 2).
    /// The green and blue tables are always all zeros.
    public func redTable(size: Int) -> [Float] {
        let count = max(size, 2)
        let last = Float(count - 1)
        return (0..<count).map { index in
            let input = Float(index) / last
            return level * (inverted ? 1 - input : input)
        }
    }

    /// Whether tables read back from a display still describe this transfer.
    ///
    /// Any green or blue output fails the check. The red table is compared
    /// against one of the same length, since a display may store a resampled
    /// copy of what was sent.
    public func isSatisfied(red: [Float], green: [Float], blue: [Float], tolerance: Float = 0.01) -> Bool {
        guard red.count >= 2, green.count == red.count, blue.count == red.count else { return false }
        let leak: Float = 0.0001
        guard green.allSatisfy({ $0 <= leak }), blue.allSatisfy({ $0 <= leak }) else { return false }
        return zip(red, redTable(size: red.count)).allSatisfy { abs($0 - $1) <= tolerance }
    }
}
