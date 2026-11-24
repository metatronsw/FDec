//
//   ____  ____   ____   ___
//  (  __)(    \ (  __) / __)
//   ) _)  ) D (  ) _) ( (__   Mtrn (C)
//  (__)  (____/ (____) \___)
//
//  https://github.com/metatronsw/FDec.git
//
//  Additions to FDec that build only on the API of FDec.swift:
//  Decimal bridging, fixed-digit formatting, allocation, percentages, Sendable,
//  whole-number operators, powers, an exact square root, rounding shorthands and sums.

import Foundation

// MARK: - Sendable

/// FDec is a single `Int`, so a value can cross concurrency domains freely.
/// It is spelled `@unchecked` only because the conformance lives outside the file of the type.
/// Note that this covers the values, not the global `FDec.decimalPlaces` setting.
extension FDec: @unchecked Sendable {}

// MARK: - Decimal

extension FDec {

	/// Converts a Foundation `Decimal`, rounding digits beyond the scale to the nearest value
	/// (ties away from zero, like the `Double` initializer).
	/// Returns `nil` for `Decimal.nan` and for a value that does not fit.
	public init?(_ decimal: Decimal) {
		guard !decimal.isNaN else { return nil }

		var scaled = decimal * Decimal(Self.pow)
		var whole = Decimal()
		NSDecimalRound(&whole, &scaled, 0, .plain)

		// A whole Decimal prints as plain digits, and Int rejects whatever is out of range.
		guard let raw = Int(whole.description), FDec(raw: raw).isFinite else { return nil }

		self.init(raw: raw)
	}

	/// The exact value as a Foundation `Decimal`.
	/// `Decimal` has no infinity, so nan and both infinities become `Decimal.nan`.
	public var asDecimal: Decimal {
		guard isFinite else { return .nan }
		return Decimal(rawValue) / Decimal(Self.pow)
	}

}

extension Decimal {
	public init(_ F: FDec) { self = F.asDecimal }
}

// MARK: - Fixed-digit formatting

extension FDec {

	/// Text with exactly `fractionDigits` digits after the decimal separator: 12.5 → "12.50".
	/// The value is rounded when it has more digits and padded with zeros when it has fewer.
	/// A value that rounds to zero is written without a sign ("0.00", never "-0.00").
	/// A zero or negative `groupingSize` switches the grouping off; the separators default to the current locale.
	public func formatted(fractionDigits: Int,
								 rounding rule: FloatingPointRoundingRule = .toNearestOrAwayFromZero,
								 fullSign: Bool = false,
								 groupingSize: Int = 3,
								 decimalSeparator: String? = nil,
								 groupingSeparator: String? = nil) -> String {
		let digits = max(0, fractionDigits)
		let value = digits < Self.decimalPlaces ? rounded(rule, places: digits) : self

		// nan and the infinities (also one produced by the rounding) have no digits to lay out.
		guard value.isFinite else {
			return value.formatted(fullSign: fullSign, groupingSize: groupingSize,
										  decimalSeparator: decimalSeparator, groupingSeparator: groupingSeparator)
		}

		let decimalSep = decimalSeparator ?? (Locale.current.decimalSeparator ?? ".")
		let groupingSep = groupingSeparator ?? (Locale.current.groupingSeparator ?? " ")

		let magnitude = value.rawValue.magnitude
		let scale = UInt(Self.pow)
		let whole = String(magnitude / scale)

		var string = value.isZero ? "" : (value.rawValue < 0 ? "-" : (fullSign ? "+" : ""))

		for (offset, chr) in whole.enumerated() {
			if groupingSize > 0, offset > 0, (whole.count - offset) % groupingSize == 0 {
				string.append(groupingSep)
			}
			string.append(chr)
		}

		guard digits > 0 else { return string }

		// All the stored fraction digits, with their leading zeros (none at all at scale zero).
		var fraction = ""
		if Self.decimalPlaces > 0 {
			let stored = String(magnitude % scale)
			fraction = String(repeating: "0", count: Self.decimalPlaces - stored.count) + stored
		}

		if digits <= Self.decimalPlaces {
			fraction = String(fraction.prefix(digits))
		} else {
			fraction += String(repeating: "0", count: digits - Self.decimalPlaces)
		}

		return string + decimalSep + fraction
	}

}

// MARK: - Allocation

extension FDec {

	/// Splits the value into `parts` shares that add up to it exactly.
	/// What cannot be divided evenly is handed out one smallest unit at a time, starting with
	/// the first share: 100 into 3 at two decimals gives 33.34, 33.33, 33.33.
	/// Returns an empty array when `parts` is not positive; nan and the infinities are repeated as they are.
	public func allocated(into parts: Int) -> [FDec] {
		guard parts > 0 else { return [] }
		guard isFinite else { return Array(repeating: self, count: parts) }

		let share = rawValue / parts
		let rest = rawValue % parts // carries the sign of the value
		let step = rest < 0 ? -1 : 1

		return (0 ..< parts).map { FDec(raw: $0 < abs(rest) ? share + step : share) }
	}

	/// Splits the value in proportion to `ratios`, into shares that add up to it exactly.
	/// Each share is truncated, then the smallest units left over go, one each, to the first
	/// shares whose ratio is not zero: 0.05 by 70 : 30 at two decimals gives 0.04 and 0.01.
	/// Returns an empty array when the ratios are unusable: none given, a negative or
	/// non-finite one, or a zero total. nan and the infinities are repeated as they are.
	public func allocated(ratios: [FDec]) -> [FDec] {
		guard !ratios.isEmpty, ratios.allSatisfy({ $0.isFinite && !$0.isNegative }) else { return [] }
		guard isFinite else { return Array(repeating: self, count: ratios.count) }

		var total: UInt = 0
		for ratio in ratios {
			let sum = total.addingReportingOverflow(ratio.rawValue.magnitude)
			guard !sum.overflow else { return [] }
			total = sum.partialValue
		}
		guard total > 0 else { return [] }

		let amount = rawValue.magnitude

		// amount * ratio / total on 128 bits; the quotient never exceeds the amount.
		var shares = ratios.map { ratio -> UInt in
			total.dividingFullWidth(amount.multipliedFullWidth(by: ratio.rawValue.magnitude)).quotient
		}

		var left = amount - shares.reduce(0, +)

		for index in shares.indices where left > 0 && !ratios[index].isZero {
			shares[index] += 1
			left -= 1
		}

		let negative = rawValue < 0
		return shares.map { FDec(raw: negative ? -Int($0) : Int($0)) }
	}

}

// MARK: - Percentages

extension FDec {

	/// The given percentage of the value: `price.percent(27)` is 27% of the price.
	/// It is computed in one step, so there is a single rounding at the end.
	public func percent(_ percent: FDec, rounding rule: FloatingPointRoundingRule = .toNearestOrAwayFromZero) -> FDec {
		// nan and the infinities follow the rules of `*`.
		guard isFinite, percent.isFinite else { return self * percent }

		// value * percent / (100 * pow), all on the magnitudes of the raw values.
		let negative = (rawValue < 0) != (percent.rawValue < 0)
		let overflow = negative ? -FDec.infinity : FDec.infinity
		let product = rawValue.magnitude.multipliedFullWidth(by: percent.rawValue.magnitude)

		var quotient: UInt
		let rest: Rest

		let divisor = UInt(Self.pow).multipliedReportingOverflow(by: 100)

		if !divisor.overflow {
			guard product.high < divisor.partialValue else { return overflow }

			let division = divisor.partialValue.dividingFullWidth(product)
			let opposite = divisor.partialValue - division.remainder // avoids doubling the remainder

			quotient = division.quotient
			rest = division.remainder == 0 ? .none
				: division.remainder < opposite ? .belowHalf
				: division.remainder == opposite ? .half : .aboveHalf
		} else {
			// Eighteen decimals: 100 * pow does not fit, so divide by 10 * pow and then by 10.
			// Every value is below 9.23 at this scale, which keeps the first quotient in range.
			let first = (UInt(Self.pow) * 10).dividingFullWidth(product)
			let second = first.quotient.quotientAndRemainder(dividingBy: 10)

			quotient = second.quotient
			rest = second.remainder == 0 && first.remainder == 0 ? .none
				: second.remainder < 5 ? .belowHalf
				: second.remainder == 5 && first.remainder == 0 ? .half : .aboveHalf
		}

		let stepsAway = rest.stepsAway(rule, negative: negative, quotientIsOdd: quotient & 1 == 1)

		if stepsAway { quotient += 1 } // cannot overflow: the quotient is far below UInt.max

		guard quotient <= UInt(Int.max) else { return overflow }

		let raw = Int(quotient)
		return FDec(raw: negative ? -raw : raw)
	}

	/// The value increased by a percentage: `net.adding(percent: 27)` is the gross price.
	public func adding(percent: FDec, rounding rule: FloatingPointRoundingRule = .toNearestOrAwayFromZero) -> FDec {
		self + self.percent(percent, rounding: rule)
	}

	/// The value decreased by a percentage: `price.subtracting(percent: 10)` is the discounted price.
	public func subtracting(percent: FDec, rounding rule: FloatingPointRoundingRule = .toNearestOrAwayFromZero) -> FDec {
		self - self.percent(percent, rounding: rule)
	}

}

// MARK: - Shared rounding decision

/// What an exact division left behind, relative to half of the last kept unit.
private enum Rest {

	case none, belowHalf, half, aboveHalf

	init(remainder: UInt, divisor: UInt) {
		// Compared with `divisor - remainder`, since doubling the remainder could overflow.
		let opposite = divisor - remainder
		self = remainder == 0 ? .none : remainder < opposite ? .belowHalf : remainder == opposite ? .half : .aboveHalf
	}

	/// Whether the truncated magnitude has to be stepped one unit away from zero.
	func stepsAway(_ rule: FloatingPointRoundingRule, negative: Bool, quotientIsOdd: Bool) -> Bool {
		switch rule {
			case .towardZero: return false
			case .awayFromZero: return self != .none
			case .up: return self != .none && !negative
			case .down: return self != .none && negative
			case .toNearestOrAwayFromZero: return self == .half || self == .aboveHalf
			case .toNearestOrEven: return self == .aboveHalf || (self == .half && quotientIsOdd)
			@unknown default: return false
		}
	}

}

// MARK: - Whole-number operators

extension FDec {

	/// Multiplies by a plain whole number. Unlike `x * FDec(n)` this needs no scaling,
	/// so it is exact and also works for a factor too large to be an FDec itself.
	public static func * (lhs: FDec, rhs: Int) -> FDec {
		let negative = (lhs.rawValue < 0) != (rhs < 0)

		guard lhs.isFinite else {
			if lhs.isNan || rhs == 0 { return .nan }
			return negative ? -FDec.infinity : .infinity
		}

		let product = lhs.rawValue.multipliedReportingOverflow(by: rhs)
		let result = FDec(raw: product.partialValue)

		// A product landing on a reserved raw value is an overflow as well.
		guard !product.overflow, result.isFinite else { return negative ? -FDec.infinity : .infinity }

		return result
	}

	public static func * (lhs: Int, rhs: FDec) -> FDec { rhs * lhs }

	/// Divides by a plain whole number, truncating toward zero like `/`. A zero divisor gives `.nan`.
	public static func / (lhs: FDec, rhs: Int) -> FDec {
		guard !lhs.isNan, rhs != 0 else { return .nan }
		guard lhs.isFinite else { return (lhs.rawValue < 0) != (rhs < 0) ? -FDec.infinity : .infinity }

		// A finite raw value is never Int.min, so this division cannot overflow.
		return FDec(raw: lhs.rawValue / rhs)
	}

	public static func *= (lhs: inout FDec, rhs: Int) { lhs = lhs * rhs }
	public static func /= (lhs: inout FDec, rhs: Int) { lhs = lhs / rhs }

}

// MARK: - Powers and the exact square root

extension FDec {

	/// The value raised to a whole power, by repeated squaring.
	/// Every multiplication on the way is rounded by `rule`, so with fractions the last digits
	/// can differ from the exactly rounded power. A negative exponent gives the reciprocal
	/// of the positive power; zero raised to a negative power is `.nan`.
	public func raised(to exponent: Int, rounding rule: FloatingPointRoundingRule = .towardZero) -> FDec {
		guard !isNan else { return .nan }

		let one = FDec(raw: Self.pow)
		var result = one
		var base = self
		var left = exponent.magnitude

		while left > 0 {
			if left & 1 == 1 { result = result.multiplied(by: base, rounding: rule) }
			left >>= 1
			if left > 0 { base = base.multiplied(by: base, rounding: rule) }
		}

		return exponent < 0 ? one.divided(by: result, rounding: rule) : result
	}

	/// The square root computed on integers: exact to the last digit of the scale and truncated,
	/// at every scale. (`sqrt()` goes through Double and is only good for about 15 digits.)
	/// A negative value gives `.nan`.
	public func squareRoot() -> FDec {
		guard !isNan, rawValue >= 0 else { return .nan }
		guard isFinite else { return self }

		// sqrt(raw / pow) * pow == sqrt(raw * pow): the largest root whose square still fits under it.
		let target = rawValue.magnitude.multipliedFullWidth(by: UInt(Self.pow))
		var root: UInt = 0

		// The root is below 2^63, so it is built bit by bit from the top.
		for bit in (0 ..< 63).reversed() {
			let candidate = root | (1 << UInt(bit))
			let square = candidate.multipliedFullWidth(by: candidate)

			if square.high < target.high || (square.high == target.high && square.low <= target.low) {
				root = candidate
			}
		}

		return FDec(raw: Int(root))
	}

}

/// `pow(x, n)` for a whole exponent, truncating at every step. See `FDec.raised(to:rounding:)`.
public func pow(_ base: FDec, _ exponent: Int) -> FDec { base.raised(to: exponent) }

// MARK: - Rounding shorthands and small helpers

extension FDec {

	/// Rounds toward negative infinity: 1.5 → 1, -1.5 → -2.
	public func floor(places: Int = 0) -> FDec { rounded(.down, places: places) }

	/// Rounds toward positive infinity: 1.5 → 2, -1.5 → -1.
	public func ceil(places: Int = 0) -> FDec { rounded(.up, places: places) }

	/// Drops the digits beyond `places`: 1.5 → 1, -1.5 → -1.
	public func truncated(places: Int = 0) -> FDec { rounded(.towardZero, places: places) }

	/// `true` for a finite value without a fraction.
	public var isWhole: Bool { isFinite && !isDecimal }

	/// -1, 0 or 1 by the sign of the value; 0 for nan.
	public func signum() -> Int { isNan ? 0 : rawValue.signum() }

	/// The value limited to the range. nan stays nan.
	public func clamped(to range: ClosedRange<FDec>) -> FDec {
		guard !isNan else { return self }
		return self < range.lowerBound ? range.lowerBound : (self > range.upperBound ? range.upperBound : self)
	}

}

// MARK: - Sums and averages

extension Sequence where Element == FDec {

	/// The sum of the elements, zero for an empty sequence. It is accumulated on 128 bits,
	/// so a running total that leaves the range and comes back still gives the right result;
	/// only a final sum that does not fit becomes an infinity.
	public func sum() -> FDec {
		var total = WideSum()
		for element in self { total.add(element) }
		return total.special ?? total.quotient(dividedBy: 1, rounding: .towardZero)
	}

	/// The arithmetic mean, or `nil` for an empty sequence. Truncates toward zero unless another rule is given.
	public func average(rounding rule: FloatingPointRoundingRule = .towardZero) -> FDec? {
		var total = WideSum()
		for element in self { total.add(element) }

		guard total.count > 0 else { return nil }

		return total.special ?? total.quotient(dividedBy: total.count, rounding: rule)
	}

}

/// A signed 128-bit running total of raw values, with the special values tracked apart.
private struct WideSum {

	private var high = 0
	private var low: UInt = 0
	private var sawNan = false
	private var sawPositiveInfinity = false
	private var sawNegativeInfinity = false

	private(set) var count: UInt = 0

	mutating func add(_ element: FDec) {
		count += 1

		guard element.isFinite else {
			if element.isNan { sawNan = true }
			else if element.rawValue > 0 { sawPositiveInfinity = true }
			else { sawNegativeInfinity = true }
			return
		}

		// Two's complement addition of the sign-extended raw value.
		let sum = low.addingReportingOverflow(UInt(bitPattern: element.rawValue))
		low = sum.partialValue
		high += (element.rawValue < 0 ? -1 : 0) + (sum.overflow ? 1 : 0)
	}

	/// The result forced by nan or the infinities, if any was added.
	var special: FDec? {
		if sawNan || (sawPositiveInfinity && sawNegativeInfinity) { return .nan }
		if sawPositiveInfinity { return .infinity }
		if sawNegativeInfinity { return -FDec.infinity }
		return nil
	}

	func quotient(dividedBy divisor: UInt, rounding rule: FloatingPointRoundingRule) -> FDec {
		let negative = high < 0
		let overflow = negative ? -FDec.infinity : FDec.infinity

		// Magnitude of the two's complement total.
		var magnitude = (high: UInt(bitPattern: high), low: low)
		if negative {
			magnitude.low = ~low &+ 1
			magnitude.high = ~UInt(bitPattern: high) &+ (magnitude.low == 0 ? 1 : 0)
		}

		guard magnitude.high < divisor else { return overflow }

		var (quotient, remainder) = divisor.dividingFullWidth(magnitude)

		if Rest(remainder: remainder, divisor: divisor).stepsAway(rule, negative: negative, quotientIsOdd: quotient & 1 == 1) {
			quotient += 1 // cannot overflow: the quotient of a division by one or more of a guarded total
		}

		guard quotient < UInt(Int.max) else { return overflow }

		let raw = Int(quotient)
		return FDec(raw: negative ? -raw : raw)
	}

}
