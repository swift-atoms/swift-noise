public struct Noise<let N: Int, Scalar: BinaryFloatingPoint> {
    public let seed: Threefry.Key

    @usableFromInline
    internal init(dimensioned seed: Threefry.Key) { self.seed = seed }
}

extension Noise: Equatable {}
extension Noise: Hashable {}
extension Noise: Sendable {}

extension Noise where N == 1 {
    @inlinable
    public init(seed: Threefry.Key) { self.init(dimensioned: seed) }
}

extension Noise where N == 2 {
    @inlinable
    public init(seed: Threefry.Key) { self.init(dimensioned: seed) }
}

extension Noise where N == 3 {
    @inlinable
    public init(seed: Threefry.Key) { self.init(dimensioned: seed) }
}

extension Noise where N == 4 {
    @inlinable
    public init(seed: Threefry.Key) { self.init(dimensioned: seed) }
}

extension Noise {

    @inlinable
    public func value(at point: Point<N, Scalar>) -> Scalar {
        let coordinates = point.coordinates
        let floors = coordinates.map { $0.rounded(.down) }
        let fraction = coordinates - floors
        let cell = floors.map(Self.wrapped)
        let fade = fraction.map { $0 * $0 * $0 * ($0 * ($0 * 6 - 15) + 10) }
        var total: Scalar = 0
        (0..<(1 << N)).forEach { corner in
            var lattice = cell
            var offset = fraction
            var weight: Scalar = 1
            (0..<N).forEach { axis in
                if (corner >> axis) & 1 == 1 {
                    lattice[axis] = cell[axis] &+ 1
                    offset[axis] = fraction[axis] - 1
                    weight *= fade[axis]
                } else {
                    weight *= 1 - fade[axis]
                }
            }
            total += weight * gradient(at: lattice).dot(offset)
        }
        let scaled = total * 2 / Scalar(N).squareRoot()
        return scaled.isNaN ? .nan : Swift.min(Swift.max(scaled, -1), 1)
    }

    @inlinable
    public func gradient(at lattice: Vector<N, UInt32>) -> Vector<N, Scalar> {
        var counter: InlineArray<2, UInt64> = [0, 0]
        (0..<N).forEach { axis in
            counter[axis / 2] |= UInt64(lattice[axis]) << UInt64(axis % 2 * 32)
        }
        let own = Threefry.block(key: seed, counter: Threefry.Block(counter[0], counter[1]))
        let key = Threefry.Key(own.first, own.second)
        var attempt: UInt64 = 0
        while true {
            let block = Threefry.block(key: key, counter: Threefry.Block(attempt, 0))
            let words: InlineArray<2, UInt64> = [block.first, block.second]
            let candidate = Vector<N, Scalar>(
                InlineArray { axis in
                    let bits = UInt32(truncatingIfNeeded: words[axis / 2] >> UInt64(axis % 2 * 32))
                    return Scalar(Int32(bitPattern: bits)) / 2_147_483_648
                }
            )
            let lengthSquared = candidate.dot(candidate)
            if lengthSquared > 0, lengthSquared <= 1 {
                let length = lengthSquared.squareRoot()
                return candidate.map { $0 / length }
            }
            attempt &+= 1
        }
    }

    /// A whole-valued coordinate modulo 2^32. A non-finite one maps to zero; its fraction is NaN.
    @usableFromInline
    static func wrapped(_ floor: Scalar) -> UInt32 {
        guard floor.isFinite else { return 0 }
        let period = Scalar(4_294_967_296 as UInt64)
        return UInt32(truncatingIfNeeded: Int64(floor.truncatingRemainder(dividingBy: period)))
    }
}
