import Noise
import Testing

enum `Noise Tests` {}

extension `Noise Tests` {
    @Suite
    struct `Noise contracts` {
        private let seed = Threefry.Key(2026, 11)

        @Test
        func `Known answers are bit-identical for a seed and a point`() {
            let one = Noise<1, Double>(seed: seed)
            #expect(one.value(at: Point(x: 0.3)).bitPattern == 13_821_976_719_660_518_273)
            #expect(one.value(at: Point(x: -17.625)).bitPattern == 4_606_170_043_468_742_656)
            let two = Noise<2, Double>(seed: seed)
            #expect(two.value(at: Point(x: 0.3, y: 1.7)).bitPattern == 13_822_257_357_009_253_046)
            #expect(two.value(at: Point(x: -5.5, y: 100.25)).bitPattern == 13_825_588_575_419_844_765)
            let three = Noise<3, Double>(seed: seed)
            #expect(three.value(at: Point(x: 0.3, y: 1.7, z: -2.4)).bitPattern == 13_818_595_340_247_268_023)
            #expect(three.value(at: Point(x: 9.5, y: -0.5, z: 3.5)).bitPattern == 13_795_293_142_642_094_869)
            let four = Noise<4, Double>(seed: seed)
            #expect(four.value(at: Point([0.3, 1.7, -2.4, 5.1])).bitPattern == 13_817_766_952_699_505_078)
            #expect(four.value(at: Point([0.5, 0.5, 0.5, 0.5])).bitPattern == 13_813_355_695_837_288_118)
            let single = Noise<3, Float>(seed: seed)
            #expect(single.value(at: Point(x: 0.3, y: 1.7, z: -2.4)).bitPattern == 3_190_561_278)
        }

        @Test
        func `The value depends on the seed and on nothing else`() {
            let point = Point<2, Double>(x: 3.25, y: -8.75)
            let noise = Noise<2, Double>(seed: seed)
            #expect(noise.value(at: point) == Noise<2, Double>(seed: seed).value(at: point))
            #expect(noise == Noise<2, Double>(seed: seed))
            #expect(noise.value(at: point) != Noise<2, Double>(seed: .init(2026, 12)).value(at: point))
            #expect(noise.value(at: point) != Noise<2, Double>(seed: .init(2027, 11)).value(at: point))
            #expect(noise != Noise<2, Double>(seed: .init(2027, 11)))
        }

        @Test
        func `Values stay within minus one and one and are not constant`() {
            let two = Noise<2, Double>(seed: seed)
            let three = Noise<3, Double>(seed: seed)
            let four = Noise<4, Float>(seed: seed)
            var low = 0.0
            var high = 0.0
            (0..<20_000).forEach { index in
                let t = Double(index)
                let a = two.value(at: Point(x: t * 0.0371, y: 50 - t * 0.0113))
                let b = three.value(at: Point(x: t * 0.0137, y: t * 0.0071 - 3, z: t * 0.0519))
                let c = Double(four.value(at: Point([Float(t) * 0.031, 0.5, Float(t) * 0.017, -Float(t) * 0.023])))
                for value in [a, b, c] {
                    #expect(value >= -1 && value <= 1)
                    low = min(low, value)
                    high = max(high, value)
                }
            }
            #expect(low < -0.5)
            #expect(high > 0.5)
        }

        @Test
        func `One-dimensional noise attains its bounds only as far as its gradients allow`() {
            let noise = Noise<1, Double>(seed: seed)
            (-50..<50).forEach { cell in
                let middle = noise.value(at: Point(x: Double(cell) + 0.5))
                let left = noise.gradient(at: Vector(x: UInt32(truncatingIfNeeded: cell))).x
                let right = noise.gradient(at: Vector(x: UInt32(truncatingIfNeeded: cell + 1))).x
                #expect(abs(left) == 1 && abs(right) == 1)
                #expect(middle == (left * 0.5 * 0.5 + right * -0.5 * 0.5) * 2)
            }
        }

        @Test
        func `The value is zero at every lattice point`() {
            let one = Noise<1, Double>(seed: seed)
            let three = Noise<3, Double>(seed: seed)
            let four = Noise<4, Float>(seed: seed)
            (-4...4).forEach { x in
                #expect(one.value(at: Point(x: Double(x))) == 0)
                (-2...2).forEach { y in
                    for z in [-1_000_000, 0, 7] {
                        #expect(three.value(at: Point(x: Double(x), y: Double(y), z: Double(z))) == 0)
                        #expect(four.value(at: Point([Float(x), Float(y), Float(z), 3])) == 0)
                    }
                }
            }
        }

        @Test
        func `Lattice gradients are unit vectors fixed by seed and lattice point`() {
            let three = Noise<3, Double>(seed: seed)
            let four = Noise<4, Double>(seed: seed)
            var directions = Set<Vector<3, Double>>()
            (0..<200 as Range<UInt32>).forEach { index in
                let lattice = Vector<3, UInt32>(x: index, y: index &* 31, z: 7 &- index)
                let gradient = three.gradient(at: lattice)
                #expect(abs(gradient.dot(gradient) - 1) < 1e-15)
                #expect(gradient == three.gradient(at: lattice))
                directions.insert(gradient)
                let wide = four.gradient(at: Vector([index, 1, 2, 3]))
                #expect(abs(wide.dot(wide) - 1) < 1e-15)
            }
            #expect(directions.count == 200)
            #expect(
                three.gradient(at: Vector(x: 1, y: 2, z: 3))
                    != Noise<3, Double>(seed: .init(0, 0)).gradient(at: Vector(x: 1, y: 2, z: 3))
            )
        }

        @Test
        func `Inside a cell the value blends the corner ramps with the quintic fade`() {
            let noise = Noise<2, Double>(seed: seed)
            func fade(_ t: Double) -> Double { t * t * t * (t * (t * 6 - 15) + 10) }
            func mix(_ a: Double, _ b: Double, _ t: Double) -> Double { a + (b - a) * t }
            for (x, y) in [(0.25, 0.75), (3.5, -2.125), (-0.875, 10.0625)] {
                let cellX = x.rounded(.down)
                let cellY = y.rounded(.down)
                let u = x - cellX
                let v = y - cellY
                func ramp(_ dx: Int, _ dy: Int) -> Double {
                    let lattice = Vector<2, UInt32>(
                        x: UInt32(truncatingIfNeeded: Int(cellX) + dx),
                        y: UInt32(truncatingIfNeeded: Int(cellY) + dy)
                    )
                    let gradient = noise.gradient(at: lattice)
                    return gradient.x * (u - Double(dx)) + gradient.y * (v - Double(dy))
                }
                let expected =
                    mix(mix(ramp(0, 0), ramp(1, 0), fade(u)), mix(ramp(0, 1), ramp(1, 1), fade(u)), fade(v))
                    * 2 / 2.0.squareRoot()
                #expect(abs(noise.value(at: Point(x: x, y: y)) - expected) < 1e-14)
            }
        }

        @Test
        func `The value and its first two derivatives are continuous across lattice planes`() {
            let noise = Noise<3, Double>(seed: seed)
            let h = 1.0 / 1024
            for plane in [-3.0, 0, 1, 12] {
                for (y, z) in [(0.3, 0.6), (4.75, -2.5), (-9.125, 0.875)] {
                    func value(_ steps: Double) -> Double {
                        noise.value(at: Point(x: plane + steps * h, y: y, z: z))
                    }
                    #expect(abs(value(-1) - value(1)) < 4 * h)
                    let slopeBefore = (value(0) - value(-1)) / h
                    let slopeAfter = (value(1) - value(0)) / h
                    #expect(abs(slopeBefore - slopeAfter) < 16 * h)
                    let curveBefore = (value(0) - 2 * value(-1) + value(-2)) / (h * h)
                    let curveAfter = (value(2) - 2 * value(1) + value(0)) / (h * h)
                    #expect(abs(curveBefore - curveAfter) < 256 * h)
                }
            }
        }

        @Test
        func `The field repeats every two to the thirty-second along each axis`() {
            let noise = Noise<2, Double>(seed: seed)
            let period = 4_294_967_296.0
            for (x, y) in [(0.5, 0.25), (-3.75, 8.125), (1000.0625, -0.5)] {
                let value = noise.value(at: Point(x: x, y: y))
                #expect(value != 0)
                #expect(noise.value(at: Point(x: x + period, y: y)) == value)
                #expect(noise.value(at: Point(x: x, y: y - period)) == value)
                #expect(noise.value(at: Point(x: x - 3 * period, y: y + 2 * period)) == value)
            }
        }

        @Test
        func `Coordinates of any magnitude are accepted and non-finite ones give NaN`() {
            let noise = Noise<2, Double>(seed: seed)
            #expect(noise.value(at: Point(x: 1e300, y: -1e300)) == 0)
            #expect(noise.value(at: Point(x: .greatestFiniteMagnitude, y: 0.5)).isFinite)
            #expect(noise.value(at: Point(x: .nan, y: 0)).isNaN)
            #expect(noise.value(at: Point(x: 0, y: .infinity)).isNaN)
            #expect(noise.value(at: Point(x: -.infinity, y: .nan)).isNaN)
        }

        @Test
        func `Noise values are hashable and sendable`() {
            func requireSendable<T: Sendable>(_ value: T) {}
            let noise = Noise<4, Float>(seed: seed)
            requireSendable(noise)
            #expect(Set([noise, noise, Noise<4, Float>(seed: .init(1, 2))]).count == 2)
        }
    }
}
