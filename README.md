# swift-noise

Use this package when you need a smooth pseudo-random field: a value at every point of a line, plane, space or four-dimensional space that varies continuously, looks random, and is the same for the same seed on every machine. Start from `Noise<N, Scalar>` with `N` from 1 to 4 and read it with `value(at:)` on a `Point<N, Scalar>` from swift-point. It is Perlin's gradient noise with the quintic fade, and its lattice gradients come from swift-threefry, so a value needs no table and no earlier value. It gives one octave at unit lattice spacing: scale the point for another frequency, and sum scaled copies yourself for fractal noise. For independent random numbers with no spatial coherence, use `Threefry` directly.

## Laws

- A `Noise<N, Scalar>` can be created only for `N` of 1, 2, 3 or 4, and is determined by its seed: equal seeds give equal fields, and equality and hashing compare the seed.
- `value(at:)` uses only addition, subtraction, multiplication, division, rounding down and square root, each exactly specified by IEEE 754. The result is therefore bit-identical on every platform for the same seed, point and `Scalar`. The tests pin known answers.
- Every value lies in `-1...1`. Lattice gradients are unit vectors, which bounds the blend by √N / 2 in magnitude; the result is that blend times 2 / √N, clamped so that rounding cannot leave the range.
- The value is zero at every point whose coordinates are all whole numbers.
- The field is C² continuous: the value and its first and second derivatives are continuous everywhere, including across cell boundaries.
- Lattice coordinates are taken modulo 2^32, so along each axis the field repeats with period 2^32. A finite coordinate of any magnitude is accepted; one too large to have a fractional part sits on the lattice and gives zero.
- A point with a NaN or infinite coordinate gives NaN.
- `gradient(at:)` is the unit vector at a lattice point, fixed by the seed and that point. It is drawn by rejection from the unit ball, so directions are uniform on the sphere; in one dimension it is exactly `1` or `-1`. The draw repeats until a candidate falls inside the ball, which takes fewer than four attempts on average in four dimensions and fewer below.
- Inside a cell the value is the multilinear blend of the corner ramps `gradient · (point − corner)`, weighted along each axis by `6t⁵ − 15t⁴ + 10t³` of the fractional coordinate `t`.
- `value(at:)` and `gradient(at:)` are `@inlinable`, so a client specialises them for its own dimension and scalar. A value costs one Threefry block for each of the 2^N corners' gradients and more for each rejected draw; measured through swift-picture's displacement effect, which reads two three-dimensional fields at every pixel, a full-HD frame in a release build on one core of an Intel Xeon at 2.1 GHz under Linux went from 163 s with the generic code called unspecialised to 23 s inlined.
