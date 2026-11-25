extension Noise {
    /// Grain: space is cut into unit cells, and each has a share of its own, which the seed alone decides.
    public struct Grain {
        public let seed: Threefry.Key

        @usableFromInline
        internal init(dimensioned seed: Threefry.Key) { self.seed = seed }
    }
}

extension Noise.Grain: Equatable {}
extension Noise.Grain: Hashable {}
extension Noise.Grain: Sendable {}

extension Noise.Grain where N == 1 {
    @inlinable
    public init(seed: Threefry.Key) { self.init(dimensioned: seed) }
}

extension Noise.Grain where N == 2 {
    @inlinable
    public init(seed: Threefry.Key) { self.init(dimensioned: seed) }
}

extension Noise.Grain where N == 3 {
    @inlinable
    public init(seed: Threefry.Key) { self.init(dimensioned: seed) }
}

extension Noise.Grain where N == 4 {
    @inlinable
    public init(seed: Threefry.Key) { self.init(dimensioned: seed) }
}

extension Noise.Grain {
    /// The cell that holds a point, by its corner nearest −∞: whole numbers. It is nil for a point with a coordinate
    /// that is not finite or lies 2⁶² or more from the origin.
    @inlinable
    public func cell(at point: Point<N, Scalar>) -> Point<N, Scalar>? {
        let corner: Vector<N, Scalar> = point.coordinates.map { $0.rounded(.down) }
        let far = Scalar(4_611_686_018_427_387_904 as UInt64)
        var axis = 0
        while axis < N {
            guard corner[axis] > -far, corner[axis] < far else { return nil }
            axis += 1
        }
        return Point(coordinates: corner)
    }

    /// The share of a cell, from −1 to 1: the mean of two even draws from −1 to 1, so shares near 0 are the most common.
    @inlinable
    public func share(of cell: Point<N, Scalar>) -> Scalar {
        let corner = cell.coordinates
        var key = seed
        var block = Threefry.Block(0, 0)
        var axis = 0
        while axis < N {
            let first = UInt64(bitPattern: Int64(corner[axis]))
            let second = axis + 1 < N ? UInt64(bitPattern: Int64(corner[axis + 1])) : 0
            block = Threefry.block(key: key, counter: Threefry.Block(first, second))
            key = Threefry.Key(block.first, block.second)
            axis += 2
        }
        let units = block.units(as: Scalar.self)
        return units.first + units.second - 1
    }

    /// The share of the cell that holds a point, and 0 where no cell does.
    @inlinable
    public func share(at point: Point<N, Scalar>) -> Scalar {
        guard let cell = cell(at: point) else { return 0 }
        return share(of: cell)
    }
}
