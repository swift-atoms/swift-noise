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

    /// Evaluates 1D gradient noise at `coordinate`.
    @inlinable
    public func value(at coordinate: Scalar) -> Scalar {
        value(at: Point<1, Scalar>([coordinate]))
    }

    /// Evaluates 1D gradient noise at `coordinate`, through `cache`.
    @inlinable
    public func value(at coordinate: Scalar, cache: inout Cache) -> Scalar {
        value(at: Point<1, Scalar>([coordinate]), cache: &cache)
    }

    /// A weighted three-octave sum (fractional Brownian motion) at `coordinate`.
    @inlinable
    public func wave(at coordinate: Scalar) -> Scalar {
        var wave = Wave(self)
        return wave.value(at: coordinate)
    }
}

extension Noise {
    /// The three octaves of a 1D field's wave, each with the cache of the cell it was last read in, so that reading
    /// the wave at many nearby coordinates draws each cell's gradients once. A wave read through it is the wave read
    /// without it, bit for bit.
    public struct Wave {
        @usableFromInline
        internal let octaves: (Noise, Noise, Noise)
        @usableFromInline
        internal var caches: (Cache, Cache, Cache)
    }
}

extension Noise.Wave: Sendable where Scalar: Sendable {}

extension Noise.Wave where N == 1 {
    /// The wave of `noise`.
    @inlinable
    public init(_ noise: Noise<1, Scalar>) {
        octaves = (
            noise,
            Noise<1, Scalar>(seed: Threefry.Key(noise.seed.first &+ 7, noise.seed.second)),
            Noise<1, Scalar>(seed: Threefry.Key(noise.seed.first &+ 13, noise.seed.second))
        )
        caches = (.init(), .init(), .init())
    }

    /// The weighted three-octave sum at `coordinate`.
    @inlinable
    public mutating func value(at coordinate: Scalar) -> Scalar {
        0.62 * octaves.0.value(at: Point<1, Scalar>([coordinate]), cache: &caches.0)
            + 0.28 * octaves.1.value(at: Point<1, Scalar>([coordinate * 2.3 + 11.1]), cache: &caches.1)
            + 0.10 * octaves.2.value(at: Point<1, Scalar>([coordinate * 5.1 + 3.3]), cache: &caches.2)
    }
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
        var cache = Cache()
        return value(at: point, cache: &cache)
    }

    @inlinable
    public func value(at point: Point<N, Scalar>, cache: inout Cache) -> Scalar {
        value(at: point) { cell, corner in
            if corner == 0, !cache.holds(cell, of: seed) {
                cache.fill(cell, of: seed) { corner in gradient(at: Self.corner(corner, of: cell)) }
            }
            return cache.gradients[corner]
        }
    }

    /// The field's value at a point, from the gradients `gradient` gives for a cell's corners, which are asked for in
    /// order, the first one first.
    @inlinable
    @inline(__always)
    public func value(
        at point: Point<N, Scalar>,
        gradient: (_ cell: Vector<N, UInt32>, _ corner: Int) -> Vector<N, Scalar>
    ) -> Scalar {
        let coordinates = point.coordinates
        let floors: Vector<N, Scalar> = coordinates.map { $0.rounded(.down) }
        let fraction: Vector<N, Scalar> = coordinates - floors
        let cell: Vector<N, UInt32> = floors.map(Self.wrapped)
        let fade: Vector<N, Scalar> = fraction.map { $0 * $0 * $0 * ($0 * ($0 * 6 - 15) + 10) }
        var total: Scalar = 0
        var corner = 0
        while corner < 1 << N {
            let gradient = gradient(cell, corner)
            // The gradient's dot product with the offset from the corner, summed in the order of the axes.
            var product: Scalar = 0
            var weight: Scalar = 1
            var axis = 0
            while axis < N {
                if (corner >> axis) & 1 == 1 {
                    product += gradient[axis] * (fraction[axis] - 1)
                    weight *= fade[axis]
                } else {
                    product += gradient[axis] * fraction[axis]
                    weight *= 1 - fade[axis]
                }
                axis += 1
            }
            total += weight * product
            corner += 1
        }
        let scaled = total * 2 / Scalar(N).squareRoot()
        return scaled.isNaN ? .nan : Swift.min(Swift.max(scaled, -1), 1)
    }

    /// The lattice point of a cell's corner: one higher along each axis whose bit is set in `corner`.
    @inlinable
    public static func corner(_ corner: Int, of cell: Vector<N, UInt32>) -> Vector<N, UInt32> {
        var lattice = cell
        (0..<N).forEach { axis in
            if (corner >> axis) & 1 == 1 { lattice[axis] = cell[axis] &+ 1 }
        }
        return lattice
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
    @inlinable
    static func wrapped(_ floor: Scalar) -> UInt32 {
        guard floor.isFinite else { return 0 }
        let near = Scalar(4_611_686_018_427_387_904 as UInt64)
        if floor > -near, floor < near { return UInt32(truncatingIfNeeded: whole(floor)) }
        let period = Scalar(4_294_967_296 as UInt64)
        return UInt32(truncatingIfNeeded: whole(floor.truncatingRemainder(dividingBy: period)))
    }

    /// A whole value below 2^63 in magnitude as an integer. The standard library converts a `Float` or a `Double` in
    /// one instruction where the type is written, and bit by bit where it is a type parameter.
    @inlinable
    static func whole(_ value: Scalar) -> Int64 {
        if Scalar.self == Float.self { return Int64(unsafe unsafeBitCast(value, to: Float.self)) }
        if Scalar.self == Double.self { return Int64(unsafe unsafeBitCast(value, to: Double.self)) }
        return Int64(value)
    }
}
