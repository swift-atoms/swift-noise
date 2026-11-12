extension Noise {
    /// The gradients at the corners of the last cell a field was read in, so that reading many points of one
    /// cell draws its 2^N gradients once. A value read through a cache is the value read without one, bit for bit.
    public struct Cache {
        @usableFromInline
        internal var seed: Threefry.Key?
        @usableFromInline
        internal var cell: Vector<N, UInt32>?
        @usableFromInline
        internal var gradients: [Vector<N, Scalar>]

        @inlinable
        public init() {
            seed = nil
            cell = nil
            gradients = []
        }
    }
}

extension Noise.Cache: Sendable where Scalar: Sendable {}

extension Noise.Cache {
    /// Whether the cache holds the gradients of a cell of the field of a seed.
    @inlinable
    internal func holds(_ cell: Vector<N, UInt32>, of seed: Threefry.Key) -> Bool {
        guard self.seed == seed, let held = self.cell else { return false }
        var axis = 0
        while axis < N {
            guard held[axis] == cell[axis] else { return false }
            axis += 1
        }
        return true
    }

    /// The cache holding a cell's gradients, in the order of its corners.
    @inlinable
    internal mutating func fill(_ cell: Vector<N, UInt32>, of seed: Threefry.Key, _ gradients: [Vector<N, Scalar>]) {
        self.seed = seed
        self.cell = cell
        self.gradients = gradients
    }
}
