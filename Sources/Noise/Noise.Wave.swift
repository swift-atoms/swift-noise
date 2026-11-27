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
