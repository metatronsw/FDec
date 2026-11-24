//
//   ____  ____   ____   ___
//  (  __)(    \ (  __) / __)
//   ) _)  ) D (  ) _) ( (__   Mtrn (C)
//  (__)  (____/ (____) \___)  2023.07.30.
//
//  https://github.com/metatronsw/FDec.git

// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

import Foundation

/// A fixed decimal number format.
///
public struct FDec {

	/// The value actually shifted & stored inernaly
	private(set) var value: Int

	// MARK: Init default

	/// Default Zero init
	public init() { value = 0 }

	/// Init from Self.
	public init(_ F: FDec) { value = F.value }

	/// Init from shifted raw value.
	public init(raw: Int) { value = raw }

}

extension FDec {

	// MARK: Public Static - Project based config & helpers

	/// Project-based setting that lets you set the number of decimal places.
	/// The valid range is 0...18; anything else stops the program with a message.
	public static var decimalPlaces: Int = 4 {
		didSet {
			precondition((0 ... 18).contains(decimalPlaces), "FDec.decimalPlaces must be in 0...18, got \(decimalPlaces)")
			pow = decimalPlaces.pow10()
			zeroShift = String(repeating: "0", count: decimalPlaces)
			intMaxDecimals = 19 - decimalPlaces
		}
	}

	public static var pow = decimalPlaces.pow10()
	public static var zeroShift = String(repeating: "0", count: decimalPlaces)
	public static var intMaxDecimals = 19 - decimalPlaces

	public static let zero = FDec()
	/// Positive infinity. Negative infinity is `-FDec.infinity`.
	public static let infinity = FDec(raw: Int.max)
	/// Not a number: the result of an undefined operation, such as a division by zero.
	public static let nan = FDec(raw: Int.min)

	static let negativeInfinity = FDec(raw: -Int.max)

	private static func infinity(negative: Bool) -> FDec { negative ? negativeInfinity : infinity }

	/// Wraps a computed raw value. `Int.min` is reserved for `.nan`, so a result
	/// landing there is one step beyond negative infinity.
	private static func checked(_ raw: Int) -> FDec { raw == Int.min ? negativeInfinity : FDec(raw: raw) }

}

extension FDec {

	// MARK: Computed vars

	/// Shifted & stored internal value { get }
	public var rawValue: Int { value }

	public var isPositive: Bool { value > 0 }
	public var isNegative: Bool { value < 0 && !isNan }
	public var isZero: Bool { value == 0 }
	/// Parity of a whole number. Always `false` for a value with a fraction.
	public var isOdd: Bool { isFinite && !isDecimal && (value / Self.pow) & 1 == 1 }
	/// Parity of a whole number. Always `false` for a value with a fraction.
	public var isEven: Bool { isFinite && !isDecimal && (value / Self.pow) & 1 == 0 }
	public var isDecimal: Bool { isFinite && value % Self.pow != 0 }
	/// `true` for an ordinary number, `false` for `.nan` and both infinities.
	public var isFinite: Bool { value.magnitude < UInt(Int.max) }
	/// `true` for positive and negative infinity.
	public var isInfinity: Bool { value == Int.max || value == -Int.max }
	public var isNan: Bool { value == Int.min }

}

extension FDec: ExpressibleByIntegerLiteral {

	public typealias IntegerLiteralType = Int

	/// A literal that does not fit is a mistake in the source code,
	/// so it stops the program in every build configuration.
	public init(integerLiteral value: Int) {
		guard let raw = Self.scaledRaw(value) else {
			preconditionFailure("FDec integer literal out of range: \(value)")
		}
		self.value = raw
	}

	/// The raw value of a whole number, or `nil` when it does not fit as a finite value.
	private static func scaledRaw<T>(_ source: T) -> Int? where T: BinaryInteger {
		guard let int = Int(exactly: source) else { return nil }

		let (raw, over) = int.multipliedReportingOverflow(by: Self.pow)

		// The extreme raw values are reserved for nan and the infinities.
		guard !over, raw.magnitude < UInt(Int.max) else { return nil }

		return raw
	}

	/// Non-failable conversion of the small integer types: a value beyond the range
	/// (only possible at very large scales) becomes an infinity, like an arithmetic overflow.
	private init<T>(saturating source: T) where T: BinaryInteger {
		value = Self.scaledRaw(source) ?? (source < 0 ? Int.min + 1 : Int.max)
	}

	public init?<T>(_ source: T) where T: BinaryInteger {
		guard let raw = Self.scaledRaw(source) else { return nil }
		value = raw
	}

	public init?<T>(exactly source: T) where T: BinaryInteger {
		guard let raw = Self.scaledRaw(source) else { return nil }
		value = raw
	}

	public init(_ value: Int8) { self.init(saturating: value) }
	public init(_ value: UInt8) { self.init(saturating: value) }

	public init(_ value: Int16) { self.init(saturating: value) }
	public init(_ value: UInt16) { self.init(saturating: value) }

	public init(_ value: Int32) { self.init(saturating: value) }
	public init(_ value: UInt32) { self.init(saturating: value) }

	public init?(_ value: Int) { self.init(exactly: value) }
	public init?(_ value: UInt) { self.init(exactly: value) }

	public init?(_ value: Int64) { self.init(exactly: value) }
	public init?(_ value: UInt64) { self.init(exactly: value) }

	// MARK: Computed variables

	public var asInt: Int { value / Self.pow }

	/// The whole part, or `nil` when it is negative, too large, or the value is not finite.
	public var asUInt32: UInt32? {
		guard isFinite else { return nil }
		return UInt32(exactly: value / Self.pow)
	}

	/// Number of digits of the whole part: 12345 → 5, -5 → 1, 0 and 0.5 → 1.
	/// Zero for nan and the infinities.
	public var digitCount: Int {
		guard isFinite else { return 0 }

		var rest = (value / Self.pow).magnitude
		var count = 1

		while rest >= 10 {
			rest /= 10
			count += 1
		}

		return count
	}

}

extension Int {
	public init(_ F: FDec) { self = F.asInt }
}

extension FDec: ExpressibleByFloatLiteral {

	public typealias FloatLiteralType = Double

	public init?(_ value: Double) {
		
		guard value.isFinite else {
			debugLog("FDec Double init fail, not finite! \(value)")
			return nil
		}

		// Rounds to the nearest representable value, which also absorbs the binary noise
		// of Double (0.07 * 10000 == 700.0000000000001).
		let shifted = (value * Double(Self.pow)).rounded()

		// `Int.min` is excluded because it is the raw value of `.nan`.
		guard let raw = Int(exactly: shifted), raw != Int.min else {
			debugLog("FDec Double init fail, out of range! \(value)")
			return nil
		}

		self.value = raw
	}

	public init(truncating value: Double) {
		guard !value.isNaN else { self = .nan; return }

		let shifted = value * Double(Self.pow)
		let nearest = shifted.rounded()

		// A product that is whole within the precision of Double (0.57 * 10000 == 5699.999999999999)
		// is taken as that whole number; everything else is truncated toward zero.
		let snapped = abs(shifted - nearest) <= shifted.ulp * 2 ? nearest : shifted.rounded(.towardZero)

		// Infinite and out of range values end up here; `Int.min` is the raw value of `.nan`.
		guard let raw = Int(exactly: snapped), raw != Int.min else {
			self = snapped < 0 ? .negativeInfinity : .infinity
			return
		}

		self.value = raw
	}

	public init(floatLiteral value: Double) {
		guard let inited = Self(value) else { fatalError("Failed floatLiteral init! \(value)") }

		self.value = inited.value
	}

	/// Converts through the shortest decimal form of the Float (`Float(0.1)` is read as 0.1),
	/// so the binary noise of widening to Double never shows up at larger scales.
	public init?(_ value: Float) {
		guard value.isFinite, let double = Double(value.description) else { return nil }
		self.init(double)
	}

	/// Succeeds when the conversion is lossless, that is, converting the result back
	/// gives the very same floating point value.
	public init?<T>(exactly source: T) where T: BinaryFloatingPoint {
		let converted: FDec?
		if let float = source as? Float { converted = FDec(float) } else { converted = FDec(Double(source)) }

		guard let inited = converted, T(inited.asDouble) == source else { return nil }

		value = inited.value
	}
	
	// MARK: Output

	public var asDouble: Double {
		guard isFinite else { return isNan ? .nan : (value > 0 ? .infinity : -.infinity) }
		return Double(value) / Double(Self.pow)
	}

	public var asFloat: Float {
		guard isFinite else { return isNan ? .nan : (value > 0 ? .infinity : -.infinity) }
		return Float(value) / Float(Self.pow)
	}

	public var fraction: Double { Double(value % Self.pow) / Double(Self.pow) }

}

extension Double {
	public init(_ F: FDec) { self = F.asDouble }
}

extension Float {
	public init(_ F: FDec) { self = F.asFloat }
}


extension FDec: ExpressibleByStringLiteral, LosslessStringConvertible, CustomDebugStringConvertible {

	public typealias StringLiteralType = String

	public init(stringLiteral: String) {
		let clean = stringLiteral
			.replacingOccurrences(of: "_", with: "")
			.replacingOccurrences(of: " ", with: "")

		guard let inited = Self(clean) else { fatalError("Failed stringLiteral init! \(stringLiteral)") }

		value = inited.value
	}

	/// Strict decimal parser: an optional sign, ASCII digits and at most one `.` as decimal point,
	/// with at least one digit (`"5"`, `"-0.5"`, `".5"`, `"5."`, `"+1.5"`).
	/// Anything else gives `nil`: empty text, grouping, a comma, exponents, whitespace.
	/// Fraction digits beyond the scale are truncated.
	public init?(_ description: String) {
		var bytes = description.utf8[...]
		var negative = false

		if let first = bytes.first, first == UInt8(ascii: "-") || first == UInt8(ascii: "+") {
			negative = first == UInt8(ascii: "-")
			bytes = bytes.dropFirst()
		}

		var raw = 0
		var digitCount = 0
		var fractionCount = 0
		var seenPoint = false

		for byte in bytes {
			if byte == UInt8(ascii: ".") {
				guard !seenPoint else { debugLog("FDec String init fail! '\(description)'"); return nil }
				seenPoint = true
				continue
			}

			guard byte >= UInt8(ascii: "0"), byte <= UInt8(ascii: "9") else {
				debugLog("FDec String init fail! '\(description)'")
				return nil
			}

			digitCount += 1

			if seenPoint {
				// Still validated above, but digits beyond the scale are dropped.
				guard fractionCount < Self.decimalPlaces else { continue }
				fractionCount += 1
			}

			let shifted = raw.multipliedReportingOverflow(by: 10)
			let added = shifted.partialValue.addingReportingOverflow(Int(byte - UInt8(ascii: "0")))
			guard !shifted.overflow, !added.overflow else { debugLog("FDec String init overflow! '\(description)'"); return nil }
			raw = added.partialValue
		}

		guard digitCount > 0 else { debugLog("FDec String init fail! '\(description)'"); return nil }

		for _ in fractionCount ..< Self.decimalPlaces {
			let shifted = raw.multipliedReportingOverflow(by: 10)
			guard !shifted.overflow else { debugLog("FDec String init overflow! '\(description)'"); return nil }
			raw = shifted.partialValue
		}

		// `Int.max` is the raw value of `.infinity`; a finite text must not produce it.
		guard raw != Int.max else { debugLog("FDec String init overflow! '\(description)'"); return nil }

		value = negative ? -raw : raw
	}

	/// Builds the value from its parts through the strict string parser:
	/// `sign` is `""`, `"+"` or `"-"`, `int` and `frc` hold ASCII digits only,
	/// and fraction digits beyond the scale are truncated.
	public init?(int: String, frc: String = Self.zeroShift, sign: String = "") {
		guard sign.isEmpty || sign == "-" || sign == "+" else { return nil }

		let isDigit: (UInt8) -> Bool = { $0 >= UInt8(ascii: "0") && $0 <= UInt8(ascii: "9") }
		guard int.utf8.allSatisfy(isDigit), frc.utf8.allSatisfy(isDigit) else { return nil }

		self.init(sign + int + "." + frc)
	}

	public init?(_ substring: Substring) {
		self.init(String(substring))
	}


	// MARK: Output

	public var description: String {
		guard !isZero else { return "0" }

		guard isFinite else { return isNan ? "NaN" : (value > 0 ? "Infinity" : "-Infinity") }

		guard isDecimal else { return String(String(value).dropLast(Self.decimalPlaces)) }

		var string: String
		var whole = String(value.magnitude)

		if whole.count <= Self.decimalPlaces {
			string = sign + "0." + String(repeating: "0", count: Self.decimalPlaces - whole.count) + whole
		} else {
			whole.insert(".", at: whole.index(whole.endIndex, offsetBy: -Self.decimalPlaces))
			string = sign + whole
		}

		string.dropLastZeros()

		return string
	}

	public var debugDescription: String {
		"\(description) ➞ \(value) * 10^\(Self.decimalPlaces) ➞ \(asInt) & \(fraction)"
	}

	public func formatted(fullSign: Bool = false,
								 groupingSize: Int = 3,
								 decimalSeparator: String? = nil,
								 groupingSeparator: String? = nil) -> String {
		guard !isZero else { return "0" }

		guard isFinite else {
			if isNan { return "NaN" }
			return value > 0 ? (fullSign ? "+Infinity" : "Infinity") : "-Infinity"
		}

		let decimalSep = decimalSeparator ?? (Locale.current.decimalSeparator ?? ".")
		let groupingSep = groupingSeparator ?? (Locale.current.groupingSeparator ?? " ")

		let whole = String(value.magnitude)
		let signstr = fullSign ? signFull : sign

		guard whole.count > Self.decimalPlaces else {
			var frc = signstr + "0" + decimalSep + String(repeating: "0", count: Self.decimalPlaces - whole.count) + whole
			while frc.hasSuffix("0") {
				frc.removeLast()
			}
			return frc
		}

		let int = String(whole.dropLast(Self.decimalPlaces))
		var frc = String(whole.suffix(Self.decimalPlaces))

		// A zero or negative grouping size switches the grouping off.
		var string = signstr

		for (offset, chr) in int.enumerated() {
			if groupingSize > 0, offset > 0, (int.count - offset) % groupingSize == 0 {
				string.append(groupingSep)
			}
			string.append(chr)
		}

		frc.dropLastZeros()

		if frc.isEmpty { return string }
		return string + decimalSep + frc
	}

}

extension FDec: SignedNumeric {

	// MARK: Questions

	public var magnitude: FDec {
		guard !isNan else { return .nan }
		return FDec(raw: abs(value))
	}

	public mutating func negate() {
		guard !isNan else { return }
		value = -value
	}

	public static var isSigned: Bool { true }

	public var sign: String { (value < 0) ? "-" : "" }

	public var signFull: String { (value < 0) ? "-" : "+" }

	// MARK: (+) Addition

	public static func + (lhs: FDec, rhs: FDec) -> FDec {
		guard lhs.isFinite, rhs.isFinite else {
			if lhs.isNan || rhs.isNan { return .nan }
			// Opposite infinities cancel into nan, everything else keeps the infinity.
			if lhs.isInfinity, rhs.isInfinity { return lhs.value == rhs.value ? lhs : .nan }
			return lhs.isInfinity ? lhs : rhs
		}

		let (value, over) = lhs.value.addingReportingOverflow(rhs.value)

		// An overflow needs operands of the same sign, so the sign of either one decides.
		guard !over else { return infinity(negative: lhs.value < 0) }

		return checked(value)
	}

	public static func + (lhs: FDec, rhs: Int32) -> FDec { lhs + FDec(rhs) }
	public static func + (lhs: Int32, rhs: FDec) -> FDec { FDec(lhs) + rhs }
	public static func += (lhs: inout FDec, rhs: FDec) { lhs = lhs + rhs }
	public static func += (lhs: inout FDec, rhs: Int32) { lhs = lhs + FDec(rhs) }

	// MARK: (-) Subtraction

	public static func - (lhs: FDec, rhs: FDec) -> FDec { lhs + -rhs }

	public static func - (lhs: FDec, rhs: Int32) -> FDec { lhs - FDec(rhs) }
	public static func - (lhs: Int32, rhs: FDec) -> FDec { FDec(lhs) + -rhs }
	public static func -= (lhs: inout FDec, rhs: FDec) { lhs = lhs + -rhs }
	public static func -= (lhs: inout FDec, rhs: Int32) { lhs = lhs - FDec(rhs) }

	// MARK: (*) Multiplication

	/// Truncates toward zero. Use `multiplied(by:rounding:)` to pick another rounding rule.
	public static func * (lhs: FDec, rhs: FDec) -> FDec { lhs.multiplied(by: rhs, rounding: .towardZero) }

	/// The product, with the digits beyond the scale rounded by the given rule.
	public func multiplied(by rhs: FDec, rounding rule: FloatingPointRoundingRule) -> FDec {
		let negative = (value < 0) != (rhs.value < 0)

		guard isFinite, rhs.isFinite else {
			// nan is contagious, and infinity times zero is undefined.
			if isNan || rhs.isNan || isZero || rhs.isZero { return .nan }
			return Self.infinity(negative: negative)
		}

		// Exact 128-bit product of the magnitudes, then scaled back by `pow`.
		let product = value.magnitude.multipliedFullWidth(by: rhs.value.magnitude)

		return Self.quotient(of: product, dividedBy: UInt(Self.pow), negative: negative, rounding: rule)
	}

	public static func *= (lhs: inout FDec, rhs: FDec) { lhs = lhs * rhs }
	public static func *= (lhs: inout FDec, rhs: Int32) { lhs = lhs * FDec(rhs) }

	// MARK: (/) Divison

	/// Truncates toward zero. Use `divided(by:rounding:)` to pick another rounding rule.
	public static func / (lhs: FDec, rhs: FDec) -> FDec { lhs.divided(by: rhs, rounding: .towardZero) }

	/// The quotient, with the digits beyond the scale rounded by the given rule.
	public func divided(by rhs: FDec, rounding rule: FloatingPointRoundingRule) -> FDec {
		guard !isNan, !rhs.isNan, !rhs.isZero else { return .nan }

		let negative = (value < 0) != (rhs.value < 0)

		// infinity / infinity is undefined, infinity / finite stays infinite, finite / infinity is zero.
		guard isFinite else { return rhs.isFinite ? Self.infinity(negative: negative) : .nan }
		guard rhs.isFinite else { return .zero }

		// The dividend is scaled up by `pow` on 128 bits, so only a quotient
		// that really does not fit is reported as overflow.
		let dividend = value.magnitude.multipliedFullWidth(by: UInt(Self.pow))

		return Self.quotient(of: dividend, dividedBy: rhs.value.magnitude, negative: negative, rounding: rule)
	}

	public static func /= (lhs: inout FDec, rhs: FDec) { lhs = lhs / rhs }
	public static func /= (lhs: inout FDec, rhs: Int32) { lhs = lhs / FDec(rhs) }

	// MARK: (%) Modulus

	/// Remainder of the truncating division, like `Int`: the sign follows the dividend.
	/// A zero divisor gives `.nan`, consistent with `/`.
	public static func % (lhs: FDec, rhs: FDec) -> FDec {
		// Undefined for nan, for a zero divisor and for an infinite dividend.
		guard !lhs.isNan, !rhs.isNan, !rhs.isZero, lhs.isFinite else { return .nan }

		// A finite value fits into infinity zero times, so it is its own remainder.
		guard rhs.isFinite else { return lhs }

		// Both operands share the scale, so the raw remainder is already correctly scaled.
		return FDec(raw: lhs.value % rhs.value)
	}

	public static func %= (lhs: inout FDec, rhs: FDec) { lhs = lhs % rhs }

	// MARK: Rounding

	/// The value rounded to the given number of decimal places (0 rounds to a whole number).
	/// `places` must not be negative; a value at or above the scale leaves the number unchanged.
	public func rounded(_ rule: FloatingPointRoundingRule = .toNearestOrAwayFromZero, places: Int = 0) -> FDec {
		precondition(places >= 0, "FDec.rounded(places:) needs a non-negative number of places")

		guard isFinite, places < Self.decimalPlaces else { return self }

		let unit = UInt((Self.decimalPlaces - places).pow10())
		let negative = value < 0
		let (whole, remainder) = value.magnitude.quotientAndRemainder(dividingBy: unit)
		let steps = Self.roundsAway(rule, negative: negative, remainder: remainder, divisor: unit, quotientIsOdd: whole & 1 == 1) ? whole + 1 : whole
		let scaled = steps.multipliedReportingOverflow(by: unit)

		guard !scaled.overflow, scaled.partialValue <= UInt(Int.max) else { return Self.infinity(negative: negative) }

		let raw = Int(scaled.partialValue)
		return FDec(raw: negative ? -raw : raw)
	}

	public mutating func round(_ rule: FloatingPointRoundingRule = .toNearestOrAwayFromZero, places: Int = 0) {
		self = rounded(rule, places: places)
	}

	/// Divides a 128-bit magnitude and applies the sign and the rounding rule.
	private static func quotient(of wide: (high: UInt, low: UInt), dividedBy divisor: UInt, negative: Bool, rounding rule: FloatingPointRoundingRule) -> FDec {
		// The quotient only fits into 64 bits when the high word is smaller than the divisor.
		guard wide.high < divisor else { return infinity(negative: negative) }

		var (quotient, remainder) = divisor.dividingFullWidth(wide)

		if roundsAway(rule, negative: negative, remainder: remainder, divisor: divisor, quotientIsOdd: quotient & 1 == 1) {
			let bumped = quotient.addingReportingOverflow(1)
			guard !bumped.overflow else { return infinity(negative: negative) }
			quotient = bumped.partialValue
		}

		guard quotient <= UInt(Int.max) else { return infinity(negative: negative) }

		let raw = Int(quotient)
		return FDec(raw: negative ? -raw : raw)
	}

	/// Whether a truncated magnitude has to be stepped one unit away from zero.
	private static func roundsAway(_ rule: FloatingPointRoundingRule, negative: Bool, remainder: UInt, divisor: UInt, quotientIsOdd: Bool) -> Bool {
		guard remainder != 0 else { return false }

		// `remainder` is compared with `divisor - remainder`, since doubling it could overflow.
		let rest = divisor - remainder

		switch rule {
			case .towardZero: return false
			case .awayFromZero: return true
			case .up: return !negative
			case .down: return negative
			case .toNearestOrAwayFromZero: return remainder >= rest
			case .toNearestOrEven: return remainder > rest || (remainder == rest && quotientIsOdd)
			@unknown default: return false
		}
	}

	// MARK: Internal functions

	public func quotientAndRemainder(dividingBy rhs: FDec) -> (quotient: FDec, remainder: FDec) {
		// Zero divisor, nan and the infinities follow the rules of `/` and `%`.
		guard isFinite, rhs.isFinite, !rhs.isZero else { return (self / rhs, self % rhs) }

		// The raw quotient is a plain whole number, so it has to be scaled back up.
		let scaled = (value / rhs.value).multipliedReportingOverflow(by: Self.pow)
		let quotient = scaled.overflow
			? FDec.infinity(negative: (value < 0) != (rhs.value < 0))
			: FDec.checked(scaled.partialValue)

		return (quotient, self % rhs)
	}

	// MARK: Static functions

	/// A random value between the two bounds, chosen uniformly from every value
	/// the current scale can represent. The bounds have to be finite.
	public static func random(in range: ClosedRange<FDec>) -> FDec {
		precondition(range.lowerBound.isFinite && range.upperBound.isFinite, "FDec.random(in:) needs finite bounds")
		return FDec(raw: Int.random(in: range.lowerBound.value ... range.upperBound.value))
	}

	/// A random value from the half-open range, the upper bound excluded.
	public static func random(in range: Range<FDec>) -> FDec {
		precondition(range.lowerBound.isFinite && range.upperBound.isFinite, "FDec.random(in:) needs finite bounds")
		return FDec(raw: Int.random(in: range.lowerBound.value ..< range.upperBound.value))
	}

	/// A random whole part from `rangeInt` plus an optional random fraction.
	/// `rangeFraction` is given in the smallest units of the scale (`0...9999` at four decimals)
	/// and follows the sign of the whole part: -5 with 3000 is -5.3.
	/// Returns `nil` when the fraction range is invalid or the value does not fit.
	public static func random(_ rangeInt: ClosedRange<Int>, _ rangeFraction: ClosedRange<Int>? = nil) -> FDec? {
		let int = Int.random(in: rangeInt)
		let scaled = int.multipliedReportingOverflow(by: Self.pow)
		guard !scaled.overflow else { return nil }

		var fraction = 0
		if let rangeFraction {
			guard rangeFraction.lowerBound >= 0, rangeFraction.upperBound < Self.pow else { return nil }
			fraction = Int.random(in: rangeFraction)
		}

		let combined = scaled.partialValue.addingReportingOverflow(int < 0 ? -fraction : fraction)
		guard !combined.overflow else { return nil }

		let result = FDec(raw: combined.partialValue)
		return result.isFinite ? result : nil
	}

}

extension FDec: Strideable {

	public typealias Stride = FDec

	public func distance(to other: FDec) -> FDec {
		other - self
	}

	public func advanced(by n: FDec) -> FDec {
		self + n
	}

}

extension FDec: Hashable, Comparable {

	// MARK: Compare

	// Like Double: nan is not equal to anything, itself included, and every ordered
	// comparison involving nan is false. All four orderings are spelled out because
	// the defaults derived from `<` would turn `nan <= x` into true.

	public static func == (lhs: FDec, rhs: FDec) -> Bool { !lhs.isNan && lhs.value == rhs.value }

	public static func < (lhs: FDec, rhs: FDec) -> Bool { !lhs.isNan && lhs.value < rhs.value }

	public static func > (lhs: FDec, rhs: FDec) -> Bool { !rhs.isNan && lhs.value > rhs.value }

	public static func <= (lhs: FDec, rhs: FDec) -> Bool { !lhs.isNan && !rhs.isNan && lhs.value <= rhs.value }

	public static func >= (lhs: FDec, rhs: FDec) -> Bool { !lhs.isNan && !rhs.isNan && lhs.value >= rhs.value }

	// MARK: Hashable

	public func hash(into hasher: inout Hasher) {
		hasher.combine(value)
	}

}

extension FDec: Codable {

	/// Encodes the decimal text (`"12.34"`), which does not depend on `decimalPlaces`.
	/// The special values are written as `"NaN"`, `"Infinity"` and `"-Infinity"`.
	public func encode(to encoder: Encoder) throws {
		var container = encoder.singleValueContainer()
		try container.encode(description)
	}

	/// Decodes the decimal text written by `encode(to:)`. A plain integer is still accepted
	/// and read as the raw value of the earlier format, which is only correct
	/// while `decimalPlaces` matches the value used when it was written.
	public init(from decoder: Decoder) throws {
		let container = try decoder.singleValueContainer()

		guard let text = try? container.decode(String.self) else {
			value = try container.decode(Int.self)
			return
		}

		switch text {
			case "NaN": self = .nan
			case "Infinity": self = .infinity
			case "-Infinity": self = .negativeInfinity
			default:
				guard let parsed = FDec(text) else {
					throw DecodingError.dataCorruptedError(in: container, debugDescription: "Not a valid FDec decimal text: '\(text)'")
				}
				self = parsed
		}
	}

}

public extension FDec {
	/// The exact, truncated square root. See `squareRoot()` in FDec+Extensions.swift.
	func sqrt() -> FDec { squareRoot() }
}

public func sqrt(_ value: FDec) -> FDec { value.sqrt() }

private extension Int {
	func pow10() -> Int {
		switch self {
			case 0: return 1
			case 1: return 10
			case 2: return 100
			case 3: return 1000
			case 4: return 10000
			case 5: return 100_000
			case 6: return 1_000_000
			case 7: return 10_000_000
			case 8: return 100_000_000
			case 9: return 1_000_000_000
			case 10: return 10_000_000_000
			case 11: return 100_000_000_000
			case 12: return 1_000_000_000_000
			case 13: return 10_000_000_000_000
			case 14: return 100_000_000_000_000
			case 15: return 1_000_000_000_000_000
			case 16: return 10_000_000_000_000_000
			case 17: return 100_000_000_000_000_000
			case 18: return 1_000_000_000_000_000_000
			default: fatalError()
		}
	}
}

/// Diagnostic output for failed initializers. Compiled out of release builds.
private func debugLog(_ message: @autoclosure () -> String) {
	#if DEBUG
	print(message())
	#endif
}

private extension String {
	mutating func dropLastZeros() {
		while hasSuffix("0") {
			removeLast()
		}
	}
}
