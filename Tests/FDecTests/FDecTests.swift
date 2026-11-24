import XCTest
@testable import FDec

// Conventions used throughout this file:
// - Every test starts and ends at four decimal places (see `FDecTestCase`).
// - Expected values are pinned through `rawValue` or `description`, never through an
//   FDec literal, which would run the code under test on both sides of the assertion.
// - Each behaviour is checked in exactly one place; the MARK comments say where.

/// Base class: resets the global scale around every test and holds the shared helpers.
class FDecTestCase: XCTestCase {

	override func setUp() {
		super.setUp()
		FDec.decimalPlaces = 4
	}

	override func tearDown() {
		FDec.decimalPlaces = 4
		super.tearDown()
	}

	/// A value from a whole part and a fraction given in raw units of the current scale.
	func make(_ int: Int, _ frc: Int = 0) -> FDec { FDec(raw: int * FDec.pow + frc) }

	func raw(_ value: Int) -> FDec { FDec(raw: value) }

	/// Goes through a variable on purpose: a literal argument would pick `init(stringLiteral:)`.
	func parse(_ text: String) -> FDec? { FDec(text) }

	var inf: FDec { .infinity }
	var negInf: FDec { -FDec.infinity }
	var nan: FDec { .nan }

}


// MARK: - Scale

final class Test_Scale: FDecTestCase {

	func test_Scale_DerivedValues() {
		XCTAssertEqual(FDec.pow, 10000)
		XCTAssertEqual(FDec.zeroShift, "0000")

		FDec.decimalPlaces = 2
		XCTAssertEqual(FDec.pow, 100)
		XCTAssertEqual(FDec.zeroShift, "00")

		FDec.decimalPlaces = 0
		XCTAssertEqual(FDec.pow, 1)
		XCTAssertEqual(FDec.zeroShift, "")

		FDec.decimalPlaces = 18
		XCTAssertEqual(FDec.pow, 1_000_000_000_000_000_000)
	}

	/// Documents the hazard of changing the scale: the stored integer stays, its meaning changes.
	func test_Scale_ChangeReinterpretsValues() {
		FDec.decimalPlaces = 3
		let value = raw(111_001)
		XCTAssertEqual(value.description, "111.001")

		FDec.decimalPlaces = 4
		XCTAssertEqual(value.rawValue, 111_001)
		XCTAssertEqual(value.description, "11.1001")
	}

}


// MARK: - Initializers

final class Test_Init: FDecTestCase {

	func test_Init_Basics() {
		XCTAssertEqual(FDec().rawValue, 0)
		XCTAssertEqual(FDec.zero.rawValue, 0)
		XCTAssertEqual(FDec(raw: -42).rawValue, -42)
		XCTAssertEqual(FDec(raw(123)).rawValue, 123)
	}

	func test_Init_IntegerLiteral() {
		let a: FDec = 12345
		let b: FDec = -12345
		let c: FDec = 0

		XCTAssertEqual(a.rawValue, 123_450_000)
		XCTAssertEqual(b.rawValue, -123_450_000)
		XCTAssertEqual(c.rawValue, 0)
	}

	func test_Init_SmallIntegerTypes() {
		XCTAssertEqual(FDec(Int8.min).rawValue, -1_280_000)
		XCTAssertEqual(FDec(Int8.max).rawValue, 1_270_000)
		XCTAssertEqual(FDec(UInt8.max).rawValue, 2_550_000)
		XCTAssertEqual(FDec(Int16.min).rawValue, -327_680_000)
		XCTAssertEqual(FDec(UInt16.max).rawValue, 655_350_000)
		XCTAssertEqual(FDec(Int32.max).rawValue, 2_147_483_647 * 10000)
		XCTAssertEqual(FDec(Int32.min).rawValue, -2_147_483_648 * 10000)
		XCTAssertEqual(FDec(UInt32.max).rawValue, 4_294_967_295 * 10000)

		// Only at very large scales can these overflow; they saturate like arithmetic does.
		FDec.decimalPlaces = 18
		XCTAssertEqual(FDec(Int8(9)).rawValue, 9_000_000_000_000_000_000)
		XCTAssertEqual(FDec(Int8(10)).rawValue, Int.max)
		XCTAssertEqual(FDec(Int32.min).rawValue, -Int.max)
	}

	func test_Init_FailableIntegers() {
		let int = 123, int64: Int64 = -123, uint: UInt = 123, uint64: UInt64 = 123

		XCTAssertEqual(FDec(int)?.rawValue, 1_230_000)
		XCTAssertEqual(FDec(int64)?.rawValue, -1_230_000)
		XCTAssertEqual(FDec(uint)?.rawValue, 1_230_000)
		XCTAssertEqual(FDec(uint64)?.rawValue, 1_230_000)
		XCTAssertEqual(FDec(exactly: int)?.rawValue, 1_230_000)

		let edge = Int.max / 10000 // the largest whole number that fits at four decimals
		XCTAssertEqual(FDec(edge)?.rawValue, edge * 10000)
		XCTAssertEqual(FDec(-edge)?.rawValue, -edge * 10000)

		let tooBig = edge + 1
		XCTAssertNil(FDec(tooBig))
		XCTAssertNil(FDec(-tooBig))
		XCTAssertNil(FDec(Int64(tooBig)))
		XCTAssertNil(FDec(UInt(tooBig)))
		XCTAssertNil(FDec(exactly: tooBig))
		XCTAssertNil(FDec(Int.max))
		XCTAssertNil(FDec(Int.min))

		// Unsigned values beyond Int must not trap.
		XCTAssertNil(FDec(UInt.max))
		XCTAssertNil(FDec(UInt64.max))
		XCTAssertNil(FDec(exactly: UInt64.max))
		XCTAssertNil(FDec(UInt(Int.max) + 1))

		// The extreme raw values are reserved for the special values.
		FDec.decimalPlaces = 0
		XCTAssertEqual(FDec(Int.max - 1)?.rawValue, Int.max - 1)
		XCTAssertNil(FDec(Int.max))
		XCTAssertNil(FDec(-Int.max))
	}

	/// Covers the binary noise of Double for both floating point initializers:
	/// 0.07 * 10000 == 700.0000000000001 and 0.57 * 10000 == 5699.999999999999.
	func test_Init_Double_AllTwoDecimalValues() {
		for i in 0 ..< 10000 {
			let d = Double(i) / 100.0

			XCTAssertEqual(FDec(d)?.rawValue, i * 100, "\(d)")
			XCTAssertEqual(FDec(-d)?.rawValue, -i * 100, "-\(d)")
			XCTAssertEqual(FDec(truncating: d).rawValue, i * 100, "truncating \(d)")
			XCTAssertEqual(FDec(truncating: -d).rawValue, -i * 100, "truncating -\(d)")
		}
	}

	func test_Init_Double_RoundsToNearest() {
		let cases: [(Double, Int)] = [
			(0.12344, 1234), (0.12346, 1235), (-0.12346, -1235),
			(0.00004, 0), (0.00006, 1), (1_234_567_890.123, 12_345_678_901_230),
		]

		for (double, expected) in cases {
			XCTAssertEqual(FDec(double)?.rawValue, expected, "\(double)")
		}

		FDec.decimalPlaces = 2
		XCTAssertEqual(FDec(0.126 as Double)?.rawValue, 13)

		FDec.decimalPlaces = 0
		XCTAssertEqual(FDec(2.6 as Double)?.rawValue, 3)
	}

	func test_Init_Double_Rejected() {
		XCTAssertNil(FDec(Double.nan))
		XCTAssertNil(FDec(Double.infinity))
		XCTAssertNil(FDec(-Double.infinity))
		XCTAssertNil(FDec(1e300 as Double))
		XCTAssertNil(FDec(-1e300 as Double))
		XCTAssertNil(FDec(1e15 as Double)) // 1e19 raw does not fit
		XCTAssertNil(FDec(-922_337_203_685_477.5808 as Double)) // would be the raw value of .nan
		XCTAssertNotNil(FDec(9e14 as Double))
	}

	func test_Init_FloatLiteral() {
		let a: FDec = 0.12346
		let b: FDec = 19.99
		let c: FDec = -1.5

		XCTAssertEqual(a.rawValue, 1235)
		XCTAssertEqual(b.rawValue, 199_900)
		XCTAssertEqual(c.rawValue, -15000)
	}

	func test_Init_Truncating() {
		// Genuine extra digits are still cut toward zero.
		XCTAssertEqual(FDec(truncating: 0.12349).rawValue, 1234)
		XCTAssertEqual(FDec(truncating: -0.12349).rawValue, -1234)
		XCTAssertEqual(FDec(truncating: 0.99999).rawValue, 9999)
		XCTAssertEqual(FDec(truncating: 0.00009).rawValue, 0)
		XCTAssertEqual(FDec(truncating: 1.41421356).rawValue, 14142)
		XCTAssertEqual(FDec(truncating: 1_234_567_890.123).rawValue, 12_345_678_901_230)

		// It never fails: the special values of Double map to those of FDec.
		XCTAssertTrue(FDec(truncating: .nan).isNan)
		XCTAssertEqual(FDec(truncating: .infinity).rawValue, Int.max)
		XCTAssertEqual(FDec(truncating: -.infinity).rawValue, -Int.max)
		XCTAssertEqual(FDec(truncating: 1e300).rawValue, Int.max)
		XCTAssertEqual(FDec(truncating: -1e300).rawValue, -Int.max)
	}

	func test_Init_Float() {
		XCTAssertEqual(FDec(Float(0.1))?.rawValue, 1000)
		XCTAssertEqual(FDec(Float(1.5))?.rawValue, 15000)
		XCTAssertEqual(FDec(Float(19.99))?.rawValue, 199_900)
		XCTAssertEqual(FDec(Float(-0.07))?.rawValue, -700)
		XCTAssertEqual(FDec(Float(123_456))?.rawValue, 1_234_560_000)

		XCTAssertNil(FDec(Float.nan))
		XCTAssertNil(FDec(Float.infinity))
		XCTAssertNil(FDec(Float(1e30)))

		// At a large scale the widening noise of Float(0.1) == 0.100000001490116 must not appear.
		FDec.decimalPlaces = 9
		XCTAssertEqual(FDec(Float(0.1))?.rawValue, 100_000_000)
		XCTAssertEqual(FDec(Float(19.99))?.rawValue, 19_990_000_000)
	}

	func test_Init_Exactly_FloatingPoint() {
		XCTAssertEqual(FDec(exactly: 1.5 as Double)?.rawValue, 15000)
		XCTAssertEqual(FDec(exactly: 0.1 as Double)?.rawValue, 1000)
		XCTAssertEqual(FDec(exactly: -19.99 as Double)?.rawValue, -199_900)
		XCTAssertEqual(FDec(exactly: Float(0.1))?.rawValue, 1000)

		// More decimals than the scale: not lossless.
		XCTAssertNil(FDec(exactly: 0.12345 as Double))
		XCTAssertNil(FDec(exactly: 0.00001 as Double))
		XCTAssertNil(FDec(exactly: Float(0.12345)))

		XCTAssertNil(FDec(exactly: Double.nan))
		XCTAssertNil(FDec(exactly: Double.infinity))
		XCTAssertNil(FDec(exactly: 1e300 as Double))
	}

}


// MARK: - Text input

final class Test_Parsing: FDecTestCase {

	func test_Parse_Accepted() {
		let cases: [(String, Int)] = [
			("0", 0), ("-0", 0), ("5", 50000), ("-5", -50000), ("+5", 50000),
			("0.5", 5000), (".5", 5000), ("5.", 50000), ("-.5", -5000), ("+1.5", 15000),
			("-0.0001", -1), ("12345.6789", 123_456_789), ("-12345.6789", -123_456_789),
			("007", 70000), ("0.50000", 5000),
			// Fraction digits beyond the scale are truncated, for both signs.
			("0.99999", 9999), ("-0.99999", -9999), ("0.00009", 0), ("-0.00009", 0), ("0.12345", 1234),
		]

		for (text, expected) in cases {
			XCTAssertEqual(parse(text)?.rawValue, expected, "'\(text)'")
		}
	}

	func test_Parse_Rejected() {
		let cases = [
			"", ".", "-", "+", "-.", "1.2.3", "1..2", "1,5", "1,000.5", "1,000", " 1", "1 ", "1 000",
			"1e3", "1.5x", "x", "--1", "+-1", "1-", "1.-5", "1.+5", "0x10", "١٢", "1_000", "Infinity", "nan",
			"0.1234x", "0.12345x",
		]

		for text in cases {
			XCTAssertNil(parse(text), "'\(text)'")
		}
	}

	func test_Parse_Limits() {
		XCTAssertEqual(parse("922337203685477.5806")?.rawValue, Int.max - 1)
		XCTAssertEqual(parse("-922337203685477.5806")?.rawValue, -(Int.max - 1))

		// A finite text never produces a special value, and an overflow is nil.
		XCTAssertNil(parse("922337203685477.5807"))
		XCTAssertNil(parse("-922337203685477.5807"))
		XCTAssertNil(parse("922337203685477.5808"))
		XCTAssertNil(parse("1000000000000000"))
		XCTAssertNil(parse("99999999999999999999999999"))

		FDec.decimalPlaces = 0
		XCTAssertEqual(parse("1.9")?.rawValue, 1)
		XCTAssertEqual(parse("42")?.rawValue, 42)

		FDec.decimalPlaces = 2
		XCTAssertEqual(parse("19.999")?.rawValue, 1999)
	}

	/// `description` and the parser are inverses of each other at every scale.
	func test_Parse_RoundTripsDescription() {
		for places in [0, 2, 4, 9, 18] {
			FDec.decimalPlaces = places

			for _ in 0 ..< 1000 {
				let original = raw(Int.random(in: -1_000_000_000_000 ... 1_000_000_000_000))
				XCTAssertEqual(parse(original.description)?.rawValue, original.rawValue, "\(original.rawValue) @\(places)")
			}
		}
	}

	func test_Parse_StringLiteralStripsSeparators() {
		let a: FDec = "1_000_000.5"
		let b: FDec = "1 000"
		let c: FDec = "-12.5"

		XCTAssertEqual(a.rawValue, 10_000_005_000)
		XCTAssertEqual(b.rawValue, 10_000_000)
		XCTAssertEqual(c.rawValue, -125_000)
	}

	func test_Parse_Substring() {
		let line = "price=19.99;qty=3"
		let field = line.split(separator: ";")[0].split(separator: "=")[1]

		XCTAssertEqual(FDec(field)?.rawValue, 199_900)
		XCTAssertNil(FDec(line.prefix(5)))
	}

	func test_Parse_IntFrcSign() {
		XCTAssertEqual(FDec(int: "1", frc: "12345")?.rawValue, 11234)
		XCTAssertEqual(FDec(int: "1", frc: "5")?.rawValue, 15000)
		XCTAssertEqual(FDec(int: "12345")?.rawValue, 123_450_000)
		XCTAssertEqual(FDec(int: "12345", sign: "-")?.rawValue, -123_450_000)
		XCTAssertEqual(FDec(int: "12345", frc: "678", sign: "-")?.rawValue, -123_456_780)
		XCTAssertEqual(FDec(int: "0", frc: "5", sign: "-")?.rawValue, -5000)
		XCTAssertEqual(FDec(int: "7", frc: "25", sign: "+")?.rawValue, 72500)
		XCTAssertEqual(FDec(int: "", frc: "5")?.rawValue, 5000)
		XCTAssertEqual(FDec(int: "3", frc: "")?.rawValue, 30000)

		XCTAssertNil(FDec(int: "", frc: ""))
		XCTAssertNil(FDec(int: "-1"))
		XCTAssertNil(FDec(int: "-1", sign: "-"))
		XCTAssertNil(FDec(int: "1", frc: "-5"))
		XCTAssertNil(FDec(int: "1.2", frc: "5"))
		XCTAssertNil(FDec(int: "1", frc: "5", sign: "--"))
		XCTAssertNil(FDec(int: "1", frc: "5", sign: "x"))
		XCTAssertNil(FDec(int: "a"))
		XCTAssertNil(FDec(int: "99999999999999999999"))
	}

}


// MARK: - Output and conversions

final class Test_Output: FDecTestCase {

	func test_Description() {
		let cases: [(Int, String)] = [
			(0, "0"), (10000, "1"), (-50000, "-5"), (10_000_000_000, "1000000"),
			(5000, "0.5"), (-5000, "-0.5"), (1, "0.0001"), (-1, "-0.0001"),
			(12300, "1.23"), (123_456_789, "12345.6789"), (-123_456_789, "-12345.6789"),
		]

		for (value, text) in cases {
			XCTAssertEqual(raw(value).description, text, "\(value)")
			XCTAssertEqual("\(raw(value))", text, "interpolation of \(value)")
		}
	}

	func test_Description_OtherScales() {
		FDec.decimalPlaces = 0
		XCTAssertEqual(raw(1234).description, "1234")
		XCTAssertEqual(raw(-7).description, "-7")

		FDec.decimalPlaces = 2
		XCTAssertEqual(raw(1999).description, "19.99")
		XCTAssertEqual(raw(-5).description, "-0.05")
		XCTAssertEqual(raw(100).description, "1")

		FDec.decimalPlaces = 18
		XCTAssertEqual(raw(1_000_000_000_000_000_000).description, "1")
		XCTAssertEqual(raw(1_500_000_000_000_000_000).description, "1.5")
		XCTAssertEqual(raw(1).description, "0.000000000000000001")
	}

	func test_DebugDescription() {
		XCTAssertEqual(raw(125_000).debugDescription, "12.5 ➞ 125000 * 10^4 ➞ 12 & 0.5")
	}

	func test_Formatted() {
		func fmt(_ value: FDec, _ size: Int = 3, fullSign: Bool = false) -> String {
			value.formatted(fullSign: fullSign, groupingSize: size, decimalSeparator: ".", groupingSeparator: ",")
		}

		let n = make(1_234_567, 5000)

		XCTAssertEqual(fmt(n), "1,234,567.5")
		XCTAssertEqual(fmt(n, 2), "1,23,45,67.5")
		XCTAssertEqual(fmt(n, 4), "123,4567.5")
		XCTAssertEqual(fmt(n, 1), "1,2,3,4,5,6,7.5")
		XCTAssertEqual(fmt(n, 7), "1234567.5")
		XCTAssertEqual(fmt(n, 20), "1234567.5")

		// Zero and negative sizes switch the grouping off.
		XCTAssertEqual(fmt(n, 0), "1234567.5")
		XCTAssertEqual(fmt(n, -1), "1234567.5")

		XCTAssertEqual(fmt(-n), "-1,234,567.5")
		XCTAssertEqual(fmt(n, fullSign: true), "+1,234,567.5")
		XCTAssertEqual(fmt(make(999)), "999")
		XCTAssertEqual(fmt(make(1000)), "1,000")
		XCTAssertEqual(fmt(make(123_456)), "123,456")
		XCTAssertEqual(fmt(make(1000, 1)), "1,000.0001")
		XCTAssertEqual(fmt(raw(500)), "0.05")
		XCTAssertEqual(fmt(raw(-500), fullSign: true), "-0.05")
		XCTAssertEqual(fmt(make(0)), "0")

		XCTAssertEqual(make(1234, 5000).formatted(decimalSeparator: ",", groupingSeparator: " "), "1 234,5")
	}

	/// Without explicit separators the current locale decides, so the expectation is built from it.
	func test_Formatted_DefaultsFollowLocale() {
		let decimal = Locale.current.decimalSeparator ?? "."
		let grouping = Locale.current.groupingSeparator ?? " "

		XCTAssertEqual(make(1234, 5000).formatted(), "1\(grouping)234\(decimal)5")
	}

	func test_Conversions() {
		XCTAssertEqual(raw(123_456).asInt, 12)
		XCTAssertEqual(raw(-79000).asInt, -7)
		XCTAssertEqual(raw(-1).asInt, 0)
		XCTAssertEqual(Int(raw(-79000)), -7)

		XCTAssertEqual(raw(123_456_789).asDouble, 12345.6789)
		XCTAssertEqual(raw(-10).asDouble, -0.001)
		XCTAssertEqual(Double(raw(-79000)), -7.9)

		XCTAssertEqual(raw(15000).asFloat, 1.5)
		XCTAssertEqual(Float(raw(-2500)), -0.25)

		XCTAssertEqual(raw(123_456).fraction, 0.3456)
		XCTAssertEqual(raw(-15000).fraction, -0.5)
		XCTAssertEqual(raw(70000).fraction, 0)
	}

	func test_AsUInt32() {
		XCTAssertEqual(make(0).asUInt32, 0)
		XCTAssertEqual(make(42, 9999).asUInt32, 42)
		XCTAssertEqual(make(4_294_967_295).asUInt32, UInt32.max)
		XCTAssertEqual(raw(-5000).asUInt32, 0) // -0.5 has a zero whole part

		XCTAssertNil(make(-1).asUInt32)
		XCTAssertNil(make(4_294_967_296).asUInt32)
	}

	func test_DigitCount() {
		let cases: [(Int, Int)] = [
			(0, 1), (5000, 1), (-5000, 1), (10000, 1), (99999, 1), (100_000, 2),
			(-50000, 1), (-100_000, 2), (9_990_000, 3), (10_000_000, 4), (123_450_000, 5),
			(Int.max - 1, 15), (-(Int.max - 1), 15),
		]

		for (value, digits) in cases {
			XCTAssertEqual(raw(value).digitCount, digits, "\(value)")
		}

		FDec.decimalPlaces = 0
		XCTAssertEqual(raw(1_000_000_000_000_000_000).digitCount, 19)
	}

	func test_SignAndKind() {
		XCTAssertTrue(raw(1).isPositive)
		XCTAssertFalse(raw(0).isPositive)
		XCTAssertTrue(raw(-1).isNegative)
		XCTAssertFalse(raw(0).isNegative)
		XCTAssertTrue(raw(0).isZero)
		XCTAssertFalse(raw(1).isZero)

		XCTAssertTrue(raw(15000).isDecimal)
		XCTAssertTrue(raw(-1).isDecimal)
		XCTAssertFalse(raw(10000).isDecimal)
		XCTAssertFalse(raw(0).isDecimal)

		XCTAssertEqual(raw(-1).sign, "-")
		XCTAssertEqual(raw(1).sign, "")
		XCTAssertEqual(raw(0).sign, "")
		XCTAssertEqual(raw(-1).signFull, "-")
		XCTAssertEqual(raw(1).signFull, "+")
		XCTAssertEqual(raw(0).signFull, "+")
	}

	func test_Parity() {
		for places in [0, 1, 4, 7] {
			FDec.decimalPlaces = places

			for n in -6 ... 6 {
				XCTAssertEqual(make(n).isOdd, n % 2 != 0, "\(n) @\(places)")
				XCTAssertEqual(make(n).isEven, n % 2 == 0, "\(n) @\(places)")
			}
		}

		FDec.decimalPlaces = 4

		// Parity is only defined for whole numbers.
		for value in [25000, 30001, 1, -1, -25000, 39999] {
			XCTAssertFalse(raw(value).isOdd, "\(value)")
			XCTAssertFalse(raw(value).isEven, "\(value)")
		}
	}

}


// MARK: - Arithmetic

final class Test_Arithmetic: FDecTestCase {

	func test_AddSub() {
		// (lhs, rhs, sum, difference) in raw units
		let cases: [(Int, Int, Int, Int)] = [
			(0, 0, 0, 0), (0, 10000, 10000, -10000), (10000, 10000, 20000, 0),
			(-30000, 20000, -10000, -50000), (-30000, -40000, -70000, 10000),
			(1000, 200, 1200, 800), (9900, 100, 10000, 9800), (100, 9100, 9200, -9000),
			(1, -1, 0, 2),
		]

		for (a, b, sum, difference) in cases {
			XCTAssertEqual((raw(a) + raw(b)).rawValue, sum, "\(a) + \(b)")
			XCTAssertEqual((raw(a) - raw(b)).rawValue, difference, "\(a) - \(b)")
		}
	}

	func test_NegateAndMagnitude() {
		XCTAssertEqual((-raw(15000)).rawValue, -15000)
		XCTAssertEqual((-raw(-15000)).rawValue, 15000)
		XCTAssertEqual((-raw(0)).rawValue, 0)

		var a = raw(15000)
		a.negate()
		XCTAssertEqual(a.rawValue, -15000)

		XCTAssertEqual(raw(-15000).magnitude.rawValue, 15000)
		XCTAssertEqual(raw(15000).magnitude.rawValue, 15000)
		XCTAssertEqual(abs(raw(-1)).rawValue, 1)
	}

	func test_Mul() {
		XCTAssertEqual((make(3) * make(-3)).rawValue, -90000)
		XCTAssertEqual((make(1, 5000) * make(1, 5000)).rawValue, 22500)
		XCTAssertEqual((raw(1) * make(10000)).rawValue, 10000)
		XCTAssertEqual((make(1_000_000) * make(1_000_000)).rawValue, 1_000_000_000_000 * 10000)

		// 123456789.1234 * 98765.4321 = 12193263123451.18122114
		XCTAssertEqual((raw(1_234_567_891_234) * raw(987_654_321)).rawValue, 121_932_631_234_511_812)
	}

	/// The scaling must not depend on a constant that is only right at four decimals.
	func test_Mul_OtherScales() {
		FDec.decimalPlaces = 6
		XCTAssertEqual((make(1000) * make(1000)).rawValue, 1_000_000 * 1_000_000)
		// 2000.5 * 3000.25 = 6002000.125
		XCTAssertEqual((make(2000, 500_000) * make(3000, 250_000)).rawValue, 6_002_000_125_000)

		FDec.decimalPlaces = 2
		XCTAssertEqual((make(100_000_000) * make(1_000_000)).rawValue, 100_000_000_000_000 * 100)
		// 12345678.9 * 98765.43 = 1219326285200.427
		XCTAssertEqual((make(12_345_678, 90) * make(98765, 43)).rawValue, 121_932_628_520_042)

		FDec.decimalPlaces = 0
		XCTAssertEqual((make(123_456) * make(654_321)).rawValue, 123_456 * 654_321)

		FDec.decimalPlaces = 18
		XCTAssertEqual((make(2) * make(3)).rawValue, 6 * FDec.pow)
		XCTAssertEqual((make(1) * raw(1)).rawValue, 1)
	}

	func test_Mul_TruncatesTowardZero() {
		let a = raw(19999) // 1.9999 * 1.9999 = 3.99960001
		let b = raw(-19999)

		XCTAssertEqual((a * a).rawValue, 39996)
		XCTAssertEqual((a * b).rawValue, -39996)
		XCTAssertEqual((b * a).rawValue, -39996)
		XCTAssertEqual((b * b).rawValue, 39996)

		XCTAssertEqual((raw(1) * raw(1)).rawValue, 0)
		XCTAssertEqual((raw(-1) * raw(1)).rawValue, 0)
	}

	func test_Mul_OverflowIsInfinityNotTrap() {
		let big = make(400_000_000_000_000)

		XCTAssertEqual((big * big).rawValue, Int.max)
		XCTAssertEqual((make(1_000_000_000) * make(1_000_000_000)).rawValue, Int.max)
		XCTAssertEqual((make(-1_000_000_000) * make(1_000_000_000)).rawValue, -Int.max)
		XCTAssertEqual((make(-1_000_000_000) * make(-1_000_000_000)).rawValue, Int.max)

		// The largest products that still fit must not be reported as overflow.
		XCTAssertEqual((raw(Int.max - 7) * make(1)).rawValue, Int.max - 7)
		XCTAssertEqual((make(30_000_000) * make(30_000_000)).rawValue, 900_000_000_000_000 * 10000)
	}

	func test_Div() {
		XCTAssertEqual((make(9) / make(-3)).rawValue, -30000)
		XCTAssertEqual((make(3) / make(2)).rawValue, 15000)
		XCTAssertEqual((make(10) / raw(5000)).rawValue, 200_000)
		XCTAssertEqual((make(2, 5000) / make(1, 1000)).rawValue, 22727)
		XCTAssertEqual((make(0) / make(1)).rawValue, 0)

		// Truncation toward zero, for both signs.
		XCTAssertEqual((make(2) / make(3)).rawValue, 6666)
		XCTAssertEqual((make(-2) / make(3)).rawValue, -6666)
		XCTAssertEqual((make(2) / make(-3)).rawValue, -6666)
		XCTAssertEqual((make(-2) / make(-3)).rawValue, 6666)
		XCTAssertEqual((raw(1) / make(2)).rawValue, 0)

		XCTAssertTrue((make(1) / make(0)).isNan)
		XCTAssertTrue((make(0) / make(0)).isNan)
	}

	/// A large dividend must not overflow while the quotient still fits.
	func test_Div_LargeValues() {
		XCTAssertEqual((make(100_000_000_000) / make(2)).rawValue, 50_000_000_000 * 10000)
		XCTAssertEqual((make(922_337_203_686) / make(1)).rawValue, 922_337_203_686 * 10000)
		XCTAssertEqual((make(-100_000_000_000) / make(2)).rawValue, -50_000_000_000 * 10000)
		XCTAssertEqual((raw(Int.max - 7) / make(1)).rawValue, Int.max - 7)
		XCTAssertEqual((raw(Int.max - 7) / make(-1)).rawValue, -(Int.max - 7))

		// A quotient that really does not fit is still reported, with its sign.
		XCTAssertEqual((make(900_000_000_000_000) / raw(1)).rawValue, Int.max)
		XCTAssertEqual((make(-900_000_000_000_000) / raw(1)).rawValue, -Int.max)
		XCTAssertEqual((make(900_000_000_000_000) / raw(-1)).rawValue, -Int.max)
	}

	func test_MulDiv_RandomAgainstDecimal() {
		for places in [0, 2, 4, 6, 9] {
			FDec.decimalPlaces = places
			let scale = Decimal(FDec.pow)

			for _ in 0 ..< 2000 {
				// Reference: exact result on the magnitudes, scaled and truncated; the sign is checked apart.
				var truncated = Decimal()

				let a = Int.random(in: -2_000_000_000_000 ... 2_000_000_000_000)
				let b = Int.random(in: -3_000_000 ... 3_000_000)
				var exactProduct = Decimal(a.magnitude) * Decimal(b.magnitude) / scale
				NSDecimalRound(&truncated, &exactProduct, 0, .down)

				let product = raw(a) * raw(b)
				XCTAssertEqual(String(product.rawValue.magnitude), truncated.description, "\(a) * \(b) @\(places)")
				if product.rawValue != 0 {
					XCTAssertEqual(product.rawValue < 0, (a < 0) != (b < 0), "sign \(a) * \(b) @\(places)")
				}

				let n = Int.random(in: -900_000_000_000_000 ... 900_000_000_000_000)
				var d = Int.random(in: -3_000_000_000 ... 3_000_000_000)
				if abs(d) < 1000 { d = 1000 }
				var exactQuotient = Decimal(n.magnitude) * scale / Decimal(d.magnitude)
				NSDecimalRound(&truncated, &exactQuotient, 0, .down)

				let quotient = raw(n) / raw(d)
				XCTAssertEqual(String(quotient.rawValue.magnitude), truncated.description, "\(n) / \(d) @\(places)")
				if quotient.rawValue != 0 {
					XCTAssertEqual(quotient.rawValue < 0, (n < 0) != (d < 0), "sign \(n) / \(d) @\(places)")
				}
			}
		}
	}

	func test_Remainder() {
		XCTAssertEqual((make(5, 5000) % make(2)).rawValue, 15000) // 5.5 % 2 = 1.5
		XCTAssertEqual((make(7) % make(2, 5000)).rawValue, 20000) // 7 % 2.5 = 2
		XCTAssertEqual((raw(5000) % raw(2000)).rawValue, 1000) // 0.5 % 0.2 = 0.1
		XCTAssertEqual((make(8) % make(2)).rawValue, 0)

		// The sign follows the dividend, exactly like Int.
		XCTAssertEqual((make(-7) % make(3)).rawValue, -10000)
		XCTAssertEqual((make(7) % make(-3)).rawValue, 10000)
		XCTAssertEqual((make(-7) % make(-3)).rawValue, -10000)

		// Large values must not overflow.
		XCTAssertEqual((make(100_000_000_000) % make(3)).rawValue, 10000)
		XCTAssertEqual((raw(Int.min + 2) % raw(-1)).rawValue, 0)

		XCTAssertTrue((make(1) % make(0)).isNan)
		XCTAssertTrue((make(0) % make(0)).isNan)

		// The remainder does not depend on the scale.
		for places in [0, 2, 8] {
			FDec.decimalPlaces = places

			for _ in 0 ..< 500 {
				let x = Int.random(in: -1_000_000_000_000 ... 1_000_000_000_000)
				let y = Int.random(in: 1 ... 1_000_000_000)
				XCTAssertEqual((raw(x) % raw(y)).rawValue, x % y)
			}
		}
	}

	func test_QuotientAndRemainder() {
		var qr = make(7).quotientAndRemainder(dividingBy: make(2))
		XCTAssertEqual(qr.quotient.rawValue, 30000)
		XCTAssertEqual(qr.remainder.rawValue, 10000)

		qr = make(5, 5000).quotientAndRemainder(dividingBy: make(2)) // 5.5 qr 2 = (2, 1.5)
		XCTAssertEqual(qr.quotient.rawValue, 20000)
		XCTAssertEqual(qr.remainder.rawValue, 15000)

		qr = make(-7).quotientAndRemainder(dividingBy: make(2)) // like Int: (-3, -1)
		XCTAssertEqual(qr.quotient.rawValue, -30000)
		XCTAssertEqual(qr.remainder.rawValue, -10000)

		qr = make(1).quotientAndRemainder(dividingBy: make(0))
		XCTAssertTrue(qr.quotient.isNan)
		XCTAssertTrue(qr.remainder.isNan)

		// Invariant: quotient * divisor + remainder == dividend
		for _ in 0 ..< 1000 {
			let n = raw(Int.random(in: -1_000_000_000_000 ... 1_000_000_000_000))
			let d = raw(Int.random(in: 1 ... 1_000_000_000))
			let r = n.quotientAndRemainder(dividingBy: d)

			XCTAssertFalse(r.quotient.isDecimal)
			XCTAssertEqual((r.quotient * d + r.remainder).rawValue, n.rawValue)
		}
	}

	func test_CompoundAssignment() {
		var a = make(10)

		a += make(5)
		XCTAssertEqual(a.rawValue, 150_000)
		a -= make(3)
		XCTAssertEqual(a.rawValue, 120_000)
		a *= make(2)
		XCTAssertEqual(a.rawValue, 240_000)
		a /= make(5)
		XCTAssertEqual(a.rawValue, 48000)
		a %= make(2)
		XCTAssertEqual(a.rawValue, 8000)
	}

	func test_Int32Operators() {
		let three = make(3)
		let two: Int32 = 2

		XCTAssertEqual((three + two).rawValue, 50000)
		XCTAssertEqual((two + three).rawValue, 50000)
		XCTAssertEqual((three - two).rawValue, 10000)
		XCTAssertEqual((two - three).rawValue, -10000)

		var a = make(10)
		a += two
		XCTAssertEqual(a.rawValue, 120_000)
		a -= two
		XCTAssertEqual(a.rawValue, 100_000)
		a *= two
		XCTAssertEqual(a.rawValue, 200_000)
		a /= two
		XCTAssertEqual(a.rawValue, 100_000)

		// Negating Int32.min must not trap.
		XCTAssertEqual((make(0) - Int32.min).rawValue, 2_147_483_648 * 10000)
		XCTAssertEqual((Int32.min - make(0)).rawValue, -2_147_483_648 * 10000)
		a = make(0)
		a -= Int32.min
		XCTAssertEqual(a.rawValue, 2_147_483_648 * 10000)
	}

	func test_LiteralOperands() {
		XCTAssertEqual((make(3) * 2).rawValue, 60000)
		XCTAssertEqual((make(3) + 0.5).rawValue, 35000)
		XCTAssertEqual((1 - make(3)).rawValue, -20000)
		XCTAssertEqual([raw(1000), raw(2000), raw(3000)].reduce(0, +).rawValue, 6000)
	}

	/// (-1.1) + (-2.2) - ((-4.4) * (-3.1) / (-1.1)) - 9.1 == 0
	func test_Sequence() {
		var a = raw(0)
		a += raw(-11000)
		a += raw(-22000)
		a -= raw(-44000) * raw(-31000) / raw(-11000)
		a -= raw(91000)

		XCTAssertEqual(a.rawValue, 0)
	}

	func test_Sqrt() {
		XCTAssertEqual(sqrt(make(2)).rawValue, 14142)
		XCTAssertEqual(sqrt(make(12, 2500)).rawValue, 35000)
		XCTAssertEqual(make(2).sqrt().rawValue, 14142)
		XCTAssertTrue(sqrt(make(-1)).isNan)

		for n in 0 ... 50 {
			XCTAssertEqual(sqrt(make(n * n)).rawValue, n * 10000, "sqrt(\(n * n))")
		}

		FDec.decimalPlaces = 2
		XCTAssertEqual(sqrt(make(2)).rawValue, 141)

		FDec.decimalPlaces = 8
		XCTAssertEqual(sqrt(make(2)).rawValue, 141_421_356)
	}

	func test_AlgebraicProperties() {
		for places in [0, 4, 9] {
			FDec.decimalPlaces = places
			let one = make(1)

			for _ in 0 ..< 1000 {
				let a = raw(Int.random(in: -1_000_000_000_000 ... 1_000_000_000_000))
				let b = raw(Int.random(in: -1_000_000_000 ... 1_000_000_000))

				XCTAssertEqual((a + b).rawValue, (b + a).rawValue)
				XCTAssertEqual((a * b).rawValue, (b * a).rawValue)
				XCTAssertEqual(((a + b) - b).rawValue, a.rawValue)
				XCTAssertEqual((a - a).rawValue, 0)
				XCTAssertEqual((-(-a)).rawValue, a.rawValue)
				XCTAssertEqual((a * one).rawValue, a.rawValue)
				XCTAssertEqual((a / one).rawValue, a.rawValue)
				XCTAssertEqual((a * make(0)).rawValue, 0)
				// Truncation is symmetric around zero.
				XCTAssertEqual((a * b).magnitude.rawValue, (a.magnitude * b.magnitude).rawValue)
			}
		}
	}

}


// MARK: - Rounding

final class Test_Rounding: FDecTestCase {

	func test_Divided_Rounding() {
		let two = make(2), three = make(3)

		XCTAssertEqual(two.divided(by: three, rounding: .towardZero).rawValue, 6666)
		XCTAssertEqual(two.divided(by: three, rounding: .toNearestOrAwayFromZero).rawValue, 6667)
		XCTAssertEqual(two.divided(by: three, rounding: .toNearestOrEven).rawValue, 6667)
		XCTAssertEqual(two.divided(by: three, rounding: .awayFromZero).rawValue, 6667)
		XCTAssertEqual(two.divided(by: three, rounding: .up).rawValue, 6667)
		XCTAssertEqual(two.divided(by: three, rounding: .down).rawValue, 6666)

		let minusTwo = make(-2)
		XCTAssertEqual(minusTwo.divided(by: three, rounding: .towardZero).rawValue, -6666)
		XCTAssertEqual(minusTwo.divided(by: three, rounding: .toNearestOrAwayFromZero).rawValue, -6667)
		XCTAssertEqual(minusTwo.divided(by: three, rounding: .awayFromZero).rawValue, -6667)
		XCTAssertEqual(minusTwo.divided(by: three, rounding: .up).rawValue, -6666)
		XCTAssertEqual(minusTwo.divided(by: three, rounding: .down).rawValue, -6667)

		// Exact ties: 0.0001 / 2 = 0.00005 and 0.0003 / 2 = 0.00015
		XCTAssertEqual(raw(1).divided(by: two, rounding: .toNearestOrAwayFromZero).rawValue, 1)
		XCTAssertEqual(raw(1).divided(by: two, rounding: .toNearestOrEven).rawValue, 0)
		XCTAssertEqual(raw(3).divided(by: two, rounding: .toNearestOrEven).rawValue, 2)
		XCTAssertEqual(raw(-3).divided(by: two, rounding: .toNearestOrAwayFromZero).rawValue, -2)

		// An exact quotient is never touched.
		XCTAssertEqual(make(3).divided(by: two, rounding: .awayFromZero).rawValue, 15000)

		XCTAssertTrue(two.divided(by: make(0), rounding: .up).isNan)
	}

	func test_Multiplied_Rounding() {
		let a = raw(19999) // 1.9999 * 1.9999 = 3.99960001

		XCTAssertEqual(a.multiplied(by: a, rounding: .towardZero).rawValue, 39996)
		XCTAssertEqual(a.multiplied(by: a, rounding: .toNearestOrAwayFromZero).rawValue, 39996)
		XCTAssertEqual(a.multiplied(by: a, rounding: .awayFromZero).rawValue, 39997)
		XCTAssertEqual(a.multiplied(by: a, rounding: .up).rawValue, 39997)
		XCTAssertEqual((-a).multiplied(by: a, rounding: .up).rawValue, -39996)
		XCTAssertEqual((-a).multiplied(by: a, rounding: .down).rawValue, -39997)

		// 0.0005 * 0.1 = 0.00005 and 0.0015 * 0.1 = 0.00015 are exact ties.
		let tenth = raw(1000)
		XCTAssertEqual(raw(5).multiplied(by: tenth, rounding: .toNearestOrAwayFromZero).rawValue, 1)
		XCTAssertEqual(raw(5).multiplied(by: tenth, rounding: .toNearestOrEven).rawValue, 0)
		XCTAssertEqual(raw(15).multiplied(by: tenth, rounding: .toNearestOrEven).rawValue, 2)

		XCTAssertEqual(make(1_000_000_000).multiplied(by: make(-1_000_000_000), rounding: .up).rawValue, -Int.max)
	}

	func test_Rounding_RandomAgainstDecimal() {
		let modes: [(FloatingPointRoundingRule, NSDecimalNumber.RoundingMode)] = [
			(.awayFromZero, .up), (.toNearestOrAwayFromZero, .plain), (.toNearestOrEven, .bankers),
		]

		for places in [2, 4, 6] {
			FDec.decimalPlaces = places
			let scale = Decimal(FDec.pow)

			for (rule, mode) in modes {
				for _ in 0 ..< 500 {
					// Positive operands: NSDecimalRound is only used on magnitudes.
					let a = Int.random(in: 1 ... 2_000_000_000_000)
					let b = Int.random(in: 1 ... 3_000_000)
					var expected = Decimal()

					var product = Decimal(a) * Decimal(b) / scale
					NSDecimalRound(&expected, &product, 0, mode)
					XCTAssertEqual(String(raw(a).multiplied(by: raw(b), rounding: rule).rawValue), expected.description, "\(a) * \(b) \(rule) @\(places)")

					// A divisor with few prime factors makes exact ties likely.
					let d = [2, 4, 8, 16, 20, 40, 3, 7][Int.random(in: 0 ..< 8)]
					var quotient = Decimal(a) * scale / Decimal(d)
					NSDecimalRound(&expected, &quotient, 0, mode)
					XCTAssertEqual(String(raw(a).divided(by: raw(d), rounding: rule).rawValue), expected.description, "\(a) / \(d) \(rule) @\(places)")
				}
			}
		}
	}

	func test_Rounded_Places() {
		let x = raw(123_456) // 12.3456

		XCTAssertEqual(x.rounded().rawValue, 120_000)
		XCTAssertEqual(x.rounded(places: 1).rawValue, 123_000)
		XCTAssertEqual(x.rounded(places: 2).rawValue, 123_500)
		XCTAssertEqual(x.rounded(places: 3).rawValue, 123_460)
		XCTAssertEqual(x.rounded(places: 4).rawValue, 123_456)
		XCTAssertEqual(x.rounded(places: 9).rawValue, 123_456)

		XCTAssertEqual(x.rounded(.up).rawValue, 130_000)
		XCTAssertEqual(x.rounded(.down).rawValue, 120_000)
		XCTAssertEqual(x.rounded(.towardZero, places: 2).rawValue, 123_400)
		XCTAssertEqual(x.rounded(.awayFromZero, places: 2).rawValue, 123_500)

		let minus = raw(-123_456)
		XCTAssertEqual(minus.rounded().rawValue, -120_000)
		XCTAssertEqual(minus.rounded(places: 2).rawValue, -123_500)
		XCTAssertEqual(minus.rounded(.up).rawValue, -120_000)
		XCTAssertEqual(minus.rounded(.down).rawValue, -130_000)
		XCTAssertEqual(minus.rounded(.towardZero, places: 2).rawValue, -123_400)

		// Ties: 0.5, 1.5, 2.5 and -0.5
		XCTAssertEqual(raw(5000).rounded().rawValue, 10000)
		XCTAssertEqual(raw(-5000).rounded().rawValue, -10000)
		XCTAssertEqual(raw(5000).rounded(.toNearestOrEven).rawValue, 0)
		XCTAssertEqual(raw(15000).rounded(.toNearestOrEven).rawValue, 20000)
		XCTAssertEqual(raw(25000).rounded(.toNearestOrEven).rawValue, 20000)
		XCTAssertEqual(raw(125).rounded(.toNearestOrEven, places: 3).rawValue, 120)
		XCTAssertEqual(raw(4999).rounded().rawValue, 0)

		var y = x
		y.round(places: 2)
		XCTAssertEqual(y.rawValue, 123_500)
		y.round()
		XCTAssertEqual(y.rawValue, 120_000)

		// Rounding past the range becomes an infinity.
		XCTAssertEqual(raw(Int.max - 1).rounded(.up).rawValue, Int.max)
		XCTAssertEqual(raw(-(Int.max - 1)).rounded(.down).rawValue, -Int.max)
		XCTAssertEqual(raw(Int.max - 1).rounded(.down).rawValue, 922_337_203_685_477 * 10000)
	}

}


// MARK: - nan and the infinities

final class Test_SpecialValues: FDecTestCase {

	func test_Special_Identity() {
		XCTAssertEqual(inf.rawValue, Int.max)
		XCTAssertEqual(negInf.rawValue, -Int.max)
		XCTAssertEqual(nan.rawValue, Int.min)

		XCTAssertTrue(inf.isInfinity)
		XCTAssertTrue(negInf.isInfinity)
		XCTAssertFalse(nan.isInfinity)
		XCTAssertFalse(make(5).isInfinity)
		XCTAssertTrue(nan.isNan)
		XCTAssertFalse(inf.isNan)

		XCTAssertTrue(inf.isPositive)
		XCTAssertTrue(negInf.isNegative)
		XCTAssertFalse(nan.isNegative)
		XCTAssertFalse(nan.isPositive)

		for special in [inf, negInf, nan] {
			XCTAssertFalse(special.isFinite)
			XCTAssertFalse(special.isDecimal)
			XCTAssertFalse(special.isOdd)
			XCTAssertFalse(special.isEven)
			XCTAssertFalse(special.isZero)
			XCTAssertEqual(special.digitCount, 0)
			XCTAssertNil(special.asUInt32)
		}

		XCTAssertTrue(make(5).isFinite)
		XCTAssertTrue(raw(Int.max - 1).isFinite)
		XCTAssertTrue(raw(-(Int.max - 1)).isFinite)
	}

	func test_Special_AdditionOverflowKeepsSign() {
		let big = raw(Int.max - 5)
		let negBig = raw(-(Int.max - 5))

		XCTAssertEqual((big + raw(10)).rawValue, Int.max)
		XCTAssertEqual((negBig + raw(-10)).rawValue, -Int.max)
		XCTAssertEqual((negBig - raw(10)).rawValue, -Int.max)

		// Landing exactly on the raw value of nan must become negative infinity.
		XCTAssertEqual((negBig + raw(-6)).rawValue, -Int.max)
		XCTAssertEqual((negBig + raw(-4)).rawValue, -(Int.max - 1))
	}

	func test_Special_NanPropagates() {
		let five = make(5)

		for result in [nan + five, five + nan, nan - five, five - nan, nan * five, five * nan,
		               nan / five, five / nan, nan % five, five % nan, -nan, nan.magnitude,
		               nan + inf, nan * make(0), sqrt(nan), nan.rounded(),
		               nan.multiplied(by: five, rounding: .up), five.divided(by: nan, rounding: .up)] {
			XCTAssertTrue(result.isNan)
		}

		let qr = nan.quotientAndRemainder(dividingBy: five)
		XCTAssertTrue(qr.quotient.isNan)
		XCTAssertTrue(qr.remainder.isNan)
	}

	func test_Special_InfinityArithmetic() {
		let five = make(5)
		let zero = make(0)

		// Addition and subtraction
		XCTAssertEqual((inf + five).rawValue, Int.max)
		XCTAssertEqual((inf - five).rawValue, Int.max)
		XCTAssertEqual((five - inf).rawValue, -Int.max)
		XCTAssertEqual((negInf + five).rawValue, -Int.max)
		XCTAssertEqual((inf + inf).rawValue, Int.max)
		XCTAssertEqual((negInf + negInf).rawValue, -Int.max)
		XCTAssertTrue((inf - inf).isNan)
		XCTAssertTrue((inf + negInf).isNan)

		// Multiplication
		XCTAssertEqual((inf * five).rawValue, Int.max)
		XCTAssertEqual((inf * make(-5)).rawValue, -Int.max)
		XCTAssertEqual((negInf * make(-5)).rawValue, Int.max)
		XCTAssertEqual((negInf * inf).rawValue, -Int.max)
		XCTAssertEqual((inf * inf).rawValue, Int.max)
		XCTAssertEqual((inf * raw(1)).rawValue, Int.max)
		XCTAssertTrue((inf * zero).isNan)
		XCTAssertTrue((zero * negInf).isNan)

		// Division
		XCTAssertEqual((inf / five).rawValue, Int.max)
		XCTAssertEqual((inf / make(-5)).rawValue, -Int.max)
		XCTAssertEqual((five / inf).rawValue, 0)
		XCTAssertEqual((five / negInf).rawValue, 0)
		XCTAssertTrue((inf / inf).isNan)
		XCTAssertTrue((inf / zero).isNan)

		// Remainder
		XCTAssertTrue((inf % five).isNan)
		XCTAssertEqual((five % inf).rawValue, 50000)
		XCTAssertEqual((make(-5) % negInf).rawValue, -50000)

		let qr = five.quotientAndRemainder(dividingBy: inf)
		XCTAssertEqual(qr.quotient.rawValue, 0)
		XCTAssertEqual(qr.remainder.rawValue, 50000)

		// Negation, magnitude, rounding and sqrt
		XCTAssertEqual((-negInf).rawValue, Int.max)
		XCTAssertEqual(negInf.magnitude.rawValue, Int.max)
		XCTAssertEqual(inf.rounded().rawValue, Int.max)
		XCTAssertEqual(negInf.rounded(places: 2).rawValue, -Int.max)
		XCTAssertEqual(sqrt(inf).rawValue, Int.max)
		XCTAssertTrue(sqrt(negInf).isNan)
	}

	func test_Special_Output() {
		XCTAssertEqual(nan.description, "NaN")
		XCTAssertEqual(inf.description, "Infinity")
		XCTAssertEqual(negInf.description, "-Infinity")

		XCTAssertEqual(nan.formatted(decimalSeparator: ".", groupingSeparator: ","), "NaN")
		XCTAssertEqual(inf.formatted(decimalSeparator: ".", groupingSeparator: ","), "Infinity")
		XCTAssertEqual(inf.formatted(fullSign: true, decimalSeparator: ".", groupingSeparator: ","), "+Infinity")
		XCTAssertEqual(negInf.formatted(decimalSeparator: ".", groupingSeparator: ","), "-Infinity")

		XCTAssertTrue(nan.asDouble.isNaN)
		XCTAssertEqual(inf.asDouble, .infinity)
		XCTAssertEqual(negInf.asDouble, -.infinity)
		XCTAssertTrue(nan.asFloat.isNaN)
		XCTAssertEqual(negInf.asFloat, -.infinity)
	}

	/// Like Double: nan is unordered and not even equal to itself.
	func test_Special_Comparison() {
		let five = make(5)

		XCTAssertFalse(nan == nan)
		XCTAssertTrue(nan != nan)
		XCTAssertFalse(nan == five)

		for other in [five, inf, negInf, nan] {
			XCTAssertFalse(nan < other)
			XCTAssertFalse(nan > other)
			XCTAssertFalse(nan <= other)
			XCTAssertFalse(nan >= other)
			XCTAssertFalse(other < nan)
			XCTAssertFalse(other > nan)
			XCTAssertFalse(other <= nan)
			XCTAssertFalse(other >= nan)
		}

		XCTAssertTrue(negInf < five)
		XCTAssertTrue(five < inf)
		XCTAssertTrue(negInf < inf)
		XCTAssertTrue(inf > raw(Int.max - 1))
		XCTAssertTrue(negInf < raw(-(Int.max - 1)))
		XCTAssertTrue(inf == inf)
		XCTAssertTrue(inf >= inf)
		XCTAssertTrue(negInf <= negInf)
		XCTAssertFalse(inf == negInf)
	}

}


// MARK: - Comparable, Hashable, Strideable, Codable

final class Test_Protocols: FDecTestCase {

	func test_Comparable() {
		let one = raw(10000)
		let two = raw(20000)
		let minusOne = raw(-10000)

		XCTAssertFalse(one > one)
		XCTAssertFalse(one < one)
		XCTAssertTrue(one >= one)
		XCTAssertTrue(one <= one)
		XCTAssertTrue(one == raw(10000))

		XCTAssertTrue(two > one)
		XCTAssertFalse(one > two)
		XCTAssertTrue(one < two)
		XCTAssertTrue(one > minusOne)
		XCTAssertFalse(minusOne > one)
		XCTAssertTrue(one != two)
		XCTAssertFalse(one != one)

		XCTAssertEqual([two, minusOne, one].sorted().map(\.rawValue), [-10000, 10000, 20000])
		XCTAssertEqual(max(one, two).rawValue, 20000)
		XCTAssertEqual(min(one, minusOne).rawValue, -10000)
	}

	func test_Hashable() {
		XCTAssertEqual(raw(10000).hashValue, make(1).hashValue)
		XCTAssertEqual(Set([raw(10000), make(1), parse("1.0000")!, raw(10001)]).count, 2)

		var prices: [FDec: String] = [:]
		prices[make(1, 5000)] = "a"
		prices[raw(15000)] = "b"

		XCTAssertEqual(prices.count, 1)
		XCTAssertEqual(prices[make(1, 5000)], "b")
	}

	func test_Strideable() {
		let quarter = raw(2500)

		XCTAssertEqual(stride(from: make(0), to: make(1), by: quarter).map(\.rawValue), [0, 2500, 5000, 7500])
		XCTAssertEqual(stride(from: make(0), through: make(1), by: quarter).map(\.rawValue), [0, 2500, 5000, 7500, 10000])
		XCTAssertEqual(stride(from: make(1), to: make(0), by: -quarter).map(\.rawValue), [10000, 7500, 5000, 2500])

		XCTAssertEqual(make(1).distance(to: make(3)).rawValue, 20000)
		XCTAssertEqual(make(3).distance(to: make(1)).rawValue, -20000)
		XCTAssertEqual(make(1).advanced(by: quarter).rawValue, 12500)
	}

	private struct Invoice: Codable, Equatable {
		var id: Int
		var total: FDec
		var discount: FDec?
	}

	private func json<V: Encodable>(_ value: V) throws -> String {
		let encoder = JSONEncoder()
		encoder.outputFormatting = .sortedKeys
		return String(decoding: try encoder.encode(value), as: UTF8.self)
	}

	private func decode<V: Decodable>(_ type: V.Type, _ text: String) throws -> V {
		try JSONDecoder().decode(type, from: Data(text.utf8))
	}

	func test_Codable_EncodesText() throws {
		XCTAssertEqual(try json([raw(123_400)]), "[\"12.34\"]")
		XCTAssertEqual(try json([raw(-5), raw(0), make(7)]), "[\"-0.0005\",\"0\",\"7\"]")
		XCTAssertEqual(try json(Invoice(id: 1, total: raw(199_900), discount: nil)), "{\"id\":1,\"total\":\"19.99\"}")
		XCTAssertEqual(try json([nan, inf, negInf]), "[\"NaN\",\"Infinity\",\"-Infinity\"]")
	}

	func test_Codable_RoundTrip() throws {
		let invoice = Invoice(id: 7, total: raw(-123_456_789), discount: raw(1))
		XCTAssertEqual(try decode(Invoice.self, try json(invoice)), invoice)

		for _ in 0 ..< 500 {
			let original = raw(Int.random(in: -1_000_000_000_000 ... 1_000_000_000_000))
			XCTAssertEqual(try decode([FDec].self, try json([original])).first?.rawValue, original.rawValue)
		}

		let specials = try decode([FDec].self, try json([nan, inf, negInf]))
		XCTAssertTrue(specials[0].isNan)
		XCTAssertEqual(specials[1].rawValue, Int.max)
		XCTAssertEqual(specials[2].rawValue, -Int.max)
	}

	func test_Codable_IndependentOfScale() throws {
		let text = try json([raw(123_400)]) // 12.34 written at four decimals

		FDec.decimalPlaces = 2
		XCTAssertEqual(try decode([FDec].self, text).first?.rawValue, 1234)

		FDec.decimalPlaces = 6
		XCTAssertEqual(try decode([FDec].self, text).first?.rawValue, 12_340_000)
	}

	func test_Codable_LegacyAndInvalid() throws {
		// The earlier format, a raw integer, is still readable.
		XCTAssertEqual(try decode([FDec].self, "[123400]").first?.rawValue, 123_400)

		XCTAssertThrowsError(try decode([FDec].self, "[\"abc\"]"))
		XCTAssertThrowsError(try decode([FDec].self, "[\"1,5\"]"))
		XCTAssertThrowsError(try decode([FDec].self, "[\"\"]"))
		XCTAssertThrowsError(try decode([FDec].self, "[12.34]"))
		XCTAssertThrowsError(try decode([FDec].self, "[true]"))
		XCTAssertThrowsError(try decode([FDec].self, "[null]"))
	}

}


// MARK: - Random

final class Test_Random: FDecTestCase {

	func test_Random_InRange() {
		let low = raw(-15000)
		let high = raw(25000)
		var seen = Set<Int>()

		for _ in 0 ..< 2000 {
			let closed = FDec.random(in: low ... high)
			XCTAssertTrue(closed >= low && closed <= high)
			seen.insert(closed.rawValue)

			let open = FDec.random(in: low ..< high)
			XCTAssertTrue(open >= low && open < high)
		}

		// The smallest step of the scale is used, not only whole numbers.
		XCTAssertTrue(seen.contains { $0 % 10000 != 0 })
		XCTAssertGreaterThan(seen.count, 500)

		XCTAssertEqual(FDec.random(in: high ... high).rawValue, 25000)
		XCTAssertEqual(FDec.random(in: raw(7) ..< raw(8)).rawValue, 7)
	}

	func test_Random_WholeAndFraction() {
		XCTAssertEqual(FDec.random(5 ... 5)?.rawValue, 50000)
		XCTAssertEqual(FDec.random(5 ... 5, 3000 ... 3000)?.rawValue, 53000)
		// The fraction follows the sign of the whole part.
		XCTAssertEqual(FDec.random(-5 ... -5, 3000 ... 3000)?.rawValue, -53000)
		XCTAssertEqual(FDec.random(0 ... 0, 1 ... 1)?.rawValue, 1)

		for _ in 0 ..< 1000 {
			let value = FDec.random(-3 ... 3, 0 ... 9999)
			XCTAssertNotNil(value)
			XCTAssertLessThan(abs(value?.rawValue ?? Int.max), 40000)
		}

		// The scale of the type is always used.
		FDec.decimalPlaces = 2
		XCTAssertEqual(FDec.random(5 ... 5)?.rawValue, 500)
		XCTAssertEqual(FDec.random(5 ... 5, 30 ... 30)?.rawValue, 530)
		XCTAssertNil(FDec.random(5 ... 5, 0 ... 100))
	}

	func test_Random_InvalidInputIsNil() {
		let edge = Int.max / 10000

		XCTAssertNil(FDec.random(edge ... edge, 9999 ... 9999))
		XCTAssertNil(FDec.random(Int.max ... Int.max))
		XCTAssertNil(FDec.random(Int.min ... Int.min))
		XCTAssertNil(FDec.random(1 ... 1, -5 ... 5))
		XCTAssertNil(FDec.random(1 ... 1, 0 ... 10000))
		XCTAssertNotNil(FDec.random(edge ... edge, 0 ... 5000))
	}

}


// MARK: - Extensions (FDec+Extensions.swift)

final class Test_Decimal: FDecTestCase {

	private func decimal(_ text: String) -> Decimal { Decimal(string: text)! }

	func test_Decimal_Init() {
		let cases: [(String, Int)] = [
			("0", 0), ("12.34", 123_400), ("-12.34", -123_400), ("0.0001", 1), ("1000000", 10_000_000_000),
			// Digits beyond the scale round to nearest, ties away from zero.
			("0.12344", 1234), ("0.12345", 1235), ("-0.12345", -1235), ("0.00004", 0), ("0.99995", 10000),
		]

		for (text, expected) in cases {
			XCTAssertEqual(FDec(decimal(text))?.rawValue, expected, text)
		}

		XCTAssertNil(FDec(Decimal.nan))
		XCTAssertNil(FDec(decimal("1e20")))
		XCTAssertNil(FDec(decimal("-1e20")))
		XCTAssertNil(FDec(decimal("922337203685477.5807"))) // the raw value of infinity
		XCTAssertEqual(FDec(decimal("922337203685477.5806"))?.rawValue, Int.max - 1)
	}

	func test_Decimal_Output() {
		XCTAssertEqual(raw(123_400).asDecimal, decimal("12.34"))
		XCTAssertEqual(raw(-1).asDecimal, decimal("-0.0001"))
		XCTAssertEqual(raw(0).asDecimal, 0)
		XCTAssertEqual(Decimal(raw(15000)), decimal("1.5"))

		XCTAssertTrue(nan.asDecimal.isNaN)
		XCTAssertTrue(inf.asDecimal.isNaN)
		XCTAssertTrue(negInf.asDecimal.isNaN)
	}

	func test_Decimal_RoundTrip() {
		for places in [0, 2, 4, 9, 18] {
			FDec.decimalPlaces = places

			for _ in 0 ..< 500 {
				let original = raw(Int.random(in: -1_000_000_000_000_000 ... 1_000_000_000_000_000))
				XCTAssertEqual(FDec(original.asDecimal)?.rawValue, original.rawValue, "\(original.rawValue) @\(places)")
				XCTAssertEqual(original.asDecimal.description, original.description, "\(original.rawValue) @\(places)")
			}
		}
	}

}

final class Test_FixedFormat: FDecTestCase {

	private func fmt(_ value: FDec, _ digits: Int, _ rule: FloatingPointRoundingRule = .toNearestOrAwayFromZero,
						  fullSign: Bool = false, size: Int = 3) -> String {
		value.formatted(fractionDigits: digits, rounding: rule, fullSign: fullSign, groupingSize: size,
							 decimalSeparator: ".", groupingSeparator: ",")
	}

	func test_FixedFormat_PadsAndRounds() {
		let x = raw(125_000) // 12.5

		XCTAssertEqual(fmt(x, 2), "12.50")
		XCTAssertEqual(fmt(x, 1), "12.5")
		XCTAssertEqual(fmt(x, 4), "12.5000")
		XCTAssertEqual(fmt(x, 6), "12.500000")
		XCTAssertEqual(fmt(x, 0), "13")
		XCTAssertEqual(fmt(x, -3), "13")
		XCTAssertEqual(fmt(x, 0, .toNearestOrEven), "12")
		XCTAssertEqual(fmt(x, 0, .down), "12")

		XCTAssertEqual(fmt(raw(123_456), 2), "12.35")
		XCTAssertEqual(fmt(raw(123_456), 2, .towardZero), "12.34")
		XCTAssertEqual(fmt(raw(123_456), 6), "12.345600")
		XCTAssertEqual(fmt(raw(9999), 2), "1.00") // 0.9999 carries into the whole part
		XCTAssertEqual(fmt(raw(5), 2), "0.00")
		XCTAssertEqual(fmt(raw(5), 3), "0.001")
		XCTAssertEqual(fmt(raw(5), 4), "0.0005")
		XCTAssertEqual(fmt(make(7), 2), "7.00")
		XCTAssertEqual(fmt(make(0), 2), "0.00")
	}

	func test_FixedFormat_SignAndGrouping() {
		XCTAssertEqual(fmt(raw(-125_000), 2), "-12.50")
		XCTAssertEqual(fmt(raw(125_000), 2, fullSign: true), "+12.50")
		XCTAssertEqual(fmt(raw(-50), 2), "-0.01")

		// A value that rounds to zero carries no sign.
		XCTAssertEqual(fmt(raw(-10), 2), "0.00")
		XCTAssertEqual(fmt(raw(10), 2, fullSign: true), "0.00")

		let n = make(1_234_567, 5000)
		XCTAssertEqual(fmt(n, 2), "1,234,567.50")
		XCTAssertEqual(fmt(-n, 2), "-1,234,567.50")
		XCTAssertEqual(fmt(n, 2, size: 0), "1234567.50")
		XCTAssertEqual(fmt(n, 0), "1,234,568")
		XCTAssertEqual(fmt(make(999, 9999), 2), "1,000.00")
		XCTAssertEqual(n.formatted(fractionDigits: 2, decimalSeparator: ",", groupingSeparator: " "), "1 234 567,50")
	}

	func test_FixedFormat_SpecialValuesAndScales() {
		XCTAssertEqual(fmt(nan, 2), "NaN")
		XCTAssertEqual(fmt(inf, 2), "Infinity")
		XCTAssertEqual(fmt(negInf, 2), "-Infinity")
		XCTAssertEqual(fmt(raw(Int.max - 1), 0), "Infinity") // the rounding itself overflows

		FDec.decimalPlaces = 0
		XCTAssertEqual(fmt(raw(42), 2), "42.00")
		XCTAssertEqual(fmt(raw(42), 0), "42")

		FDec.decimalPlaces = 2
		XCTAssertEqual(fmt(raw(1999), 2), "19.99")
		XCTAssertEqual(fmt(raw(1999), 1), "20.0")
		XCTAssertEqual(fmt(raw(5), 3), "0.050")
	}

}

final class Test_Allocation: FDecTestCase {

	func test_Allocate_IntoParts() {
		XCTAssertEqual(make(100).allocated(into: 3).map(\.rawValue), [333_334, 333_333, 333_333])
		XCTAssertEqual(make(100).allocated(into: 4).map(\.rawValue), [250_000, 250_000, 250_000, 250_000])
		XCTAssertEqual(raw(2).allocated(into: 3).map(\.rawValue), [1, 1, 0])
		XCTAssertEqual(raw(-10).allocated(into: 3).map(\.rawValue), [-4, -3, -3])
		XCTAssertEqual(raw(0).allocated(into: 2).map(\.rawValue), [0, 0])
		XCTAssertEqual(raw(12345).allocated(into: 1).map(\.rawValue), [12345])

		XCTAssertEqual(make(1).allocated(into: 0).count, 0)
		XCTAssertEqual(make(1).allocated(into: -2).count, 0)
		XCTAssertEqual(inf.allocated(into: 2).map(\.rawValue), [Int.max, Int.max])
		XCTAssertTrue(nan.allocated(into: 2).allSatisfy(\.isNan))

		FDec.decimalPlaces = 2
		XCTAssertEqual(make(100).allocated(into: 3).map(\.description), ["33.34", "33.33", "33.33"])
	}

	func test_Allocate_ByRatios() {
		XCTAssertEqual(make(100).allocated(ratios: [make(1), make(1), make(1)]).map(\.rawValue), [333_334, 333_333, 333_333])
		XCTAssertEqual(make(100).allocated(ratios: [make(70), make(30)]).map(\.rawValue), [700_000, 300_000])
		XCTAssertEqual(make(100).allocated(ratios: [raw(1), raw(3)]).map(\.rawValue), [250_000, 750_000])

		// 0.0005 by 70 : 30 is 0.00035 and 0.00015; the unit left over goes to the first share.
		XCTAssertEqual(raw(5).allocated(ratios: [make(70), make(30)]).map(\.rawValue), [4, 1])
		XCTAssertEqual(raw(-5).allocated(ratios: [make(70), make(30)]).map(\.rawValue), [-4, -1])

		// A zero ratio never receives a leftover unit.
		XCTAssertEqual(raw(5).allocated(ratios: [make(0), make(1)]).map(\.rawValue), [0, 5])
		XCTAssertEqual(raw(5).allocated(ratios: [make(1), make(0), make(1)]).map(\.rawValue), [3, 0, 2])
		XCTAssertEqual(raw(5).allocated(ratios: [make(0), make(1), make(1)]).map(\.rawValue), [0, 3, 2])

		// Large amounts and ratios must not overflow on the way.
		XCTAssertEqual(raw(Int.max - 1).allocated(ratios: [raw(Int.max - 1)]).map(\.rawValue), [Int.max - 1])

		XCTAssertEqual(make(1).allocated(ratios: []).count, 0)
		XCTAssertEqual(make(1).allocated(ratios: [make(1), make(-1)]).count, 0)
		XCTAssertEqual(make(1).allocated(ratios: [make(0), make(0)]).count, 0)
		XCTAssertEqual(make(1).allocated(ratios: [make(1), nan]).count, 0)
		XCTAssertEqual(make(1).allocated(ratios: [make(1), inf]).count, 0)
		XCTAssertTrue(nan.allocated(ratios: [make(1), make(2)]).allSatisfy(\.isNan))
	}

	/// The shares always add up to the amount, and no share strays more than one unit from its exact value.
	func test_Allocate_AlwaysAddsUp() {
		for _ in 0 ..< 1000 {
			let amount = raw(Int.random(in: -1_000_000_000_000 ... 1_000_000_000_000))

			let parts = Int.random(in: 1 ... 12)
			let even = amount.allocated(into: parts)
			XCTAssertEqual(even.count, parts)
			XCTAssertEqual(even.reduce(0) { $0 + $1.rawValue }, amount.rawValue)
			XCTAssertLessThanOrEqual(even.map(\.rawValue).max()! - even.map(\.rawValue).min()!, 1)

			let ratios = (0 ..< Int.random(in: 1 ... 6)).map { _ in raw(Int.random(in: 0 ... 1_000_000)) }
			let total = ratios.reduce(0) { $0 + $1.rawValue }
			guard total > 0 else { continue }

			let shares = amount.allocated(ratios: ratios)
			XCTAssertEqual(shares.count, ratios.count)
			XCTAssertEqual(shares.reduce(0) { $0 + $1.rawValue }, amount.rawValue)

			for (share, ratio) in zip(shares, ratios) {
				let exact = Double(amount.rawValue) * Double(ratio.rawValue) / Double(total)
				XCTAssertLessThan(abs(Double(share.rawValue) - exact), 1.001, "\(amount.rawValue) by \(ratios.map(\.rawValue))")
			}
		}
	}

}

final class Test_Percent: FDecTestCase {

	func test_Percent() {
		XCTAssertEqual(make(200).percent(make(27)).rawValue, 540_000)
		XCTAssertEqual(make(-200).percent(make(27)).rawValue, -540_000)
		XCTAssertEqual(make(200).percent(make(-27)).rawValue, -540_000)
		XCTAssertEqual(make(200).percent(make(0)).rawValue, 0)
		XCTAssertEqual(make(200).percent(make(100)).rawValue, 2_000_000)
		XCTAssertEqual(make(80).percent(make(12, 5000)).rawValue, 100_000) // 12.5% of 80
		XCTAssertEqual(make(19, 9900).percent(27).rawValue, 53973) // 19.99 * 27% = 5.3973

		XCTAssertEqual(make(100).adding(percent: make(27)).rawValue, 1_270_000)
		XCTAssertEqual(make(100).subtracting(percent: make(10)).rawValue, 900_000)
	}

	func test_Percent_Rounding() {
		// 50% of 0.0001 is 0.00005, an exact tie; 50% of 0.0003 is 0.00015.
		XCTAssertEqual(raw(1).percent(make(50)).rawValue, 1)
		XCTAssertEqual(raw(1).percent(make(50), rounding: .towardZero).rawValue, 0)
		XCTAssertEqual(raw(1).percent(make(50), rounding: .toNearestOrEven).rawValue, 0)
		XCTAssertEqual(raw(3).percent(make(50), rounding: .toNearestOrEven).rawValue, 2)
		XCTAssertEqual(raw(-1).percent(make(50)).rawValue, -1)
		XCTAssertEqual(raw(-1).percent(make(50), rounding: .up).rawValue, 0)
		XCTAssertEqual(raw(-1).percent(make(50), rounding: .down).rawValue, -1)

		// 33% of 0.0001 is 0.000033: below half.
		XCTAssertEqual(raw(1).percent(make(33)).rawValue, 0)
		XCTAssertEqual(raw(1).percent(make(33), rounding: .awayFromZero).rawValue, 1)
		XCTAssertEqual(raw(1).percent(make(33), rounding: .up).rawValue, 1)

		// 10% of 9.9999 is 0.99999: one rounding only, no double rounding.
		XCTAssertEqual(raw(99999).percent(make(10)).rawValue, 10000)
	}

	func test_Percent_SpecialValuesAndOverflow() {
		XCTAssertTrue(nan.percent(make(10)).isNan)
		XCTAssertTrue(make(10).percent(nan).isNan)
		XCTAssertEqual(inf.percent(make(10)).rawValue, Int.max)
		XCTAssertEqual(inf.percent(make(-10)).rawValue, -Int.max)
		XCTAssertTrue(inf.percent(make(0)).isNan)

		let big = raw(Int.max - 1)
		XCTAssertEqual(big.percent(make(50)).rawValue, (Int.max - 1) / 2)
		XCTAssertEqual(big.percent(make(1000)).rawValue, Int.max)
		XCTAssertEqual((-big).percent(make(1000)).rawValue, -Int.max)
		XCTAssertEqual(big.adding(percent: make(50)).rawValue, Int.max)
	}

	func test_Percent_RandomAgainstDecimal() {
		let modes: [(FloatingPointRoundingRule, NSDecimalNumber.RoundingMode)] = [
			(.towardZero, .down), (.awayFromZero, .up), (.toNearestOrAwayFromZero, .plain), (.toNearestOrEven, .bankers),
		]

		for places in [0, 2, 4, 9, 18] {
			FDec.decimalPlaces = places
			let divisor = Decimal(FDec.pow) * 100

			for (rule, mode) in modes {
				for _ in 0 ..< 300 {
					// Positive operands: NSDecimalRound is only used on magnitudes.
					let a = Int.random(in: 1 ... 2_000_000_000_000)
					// Percentages on a grid of quarters make exact ties likely; capped so that
					// the raw percentage still fits at eighteen decimals.
					let quarter = max(1, FDec.pow / 4)
					let p = Int.random(in: 1 ... min(400, (Int.max - 1) / quarter)) * quarter

					var exact = Decimal(a) * Decimal(p) / divisor
					var expected = Decimal()
					NSDecimalRound(&expected, &exact, 0, mode)

					XCTAssertEqual(String(raw(a).percent(raw(p), rounding: rule).rawValue), expected.description, "\(a) % \(p) \(rule) @\(places)")
				}
			}
		}
	}

}

final class Test_Sendable: FDecTestCase {

	func test_Sendable_CrossesConcurrencyDomains() {
		func requireSendable<T: Sendable>(_: T.Type) {}
		requireSendable(FDec.self)

		let value = raw(123_400)
		let done = expectation(description: "background")
		var seen = 0

		DispatchQueue.global().async {
			seen = value.rawValue
			done.fulfill()
		}

		wait(for: [done], timeout: 2)
		XCTAssertEqual(seen, 123_400)
	}

}

final class Test_WholeNumberOperators: FDecTestCase {

	func test_IntOperators() {
		let seven = 7, minusThree = -3
		let x = raw(15000) // 1.5

		XCTAssertEqual((x * seven).rawValue, 105_000)
		XCTAssertEqual((seven * x).rawValue, 105_000)
		XCTAssertEqual((x * minusThree).rawValue, -45000)
		XCTAssertEqual((x * (0 as Int)).rawValue, 0)

		// Division truncates toward zero, like `/`.
		XCTAssertEqual((raw(10) / (3 as Int)).rawValue, 3)
		XCTAssertEqual((raw(-10) / (3 as Int)).rawValue, -3)
		XCTAssertEqual((raw(10) / minusThree).rawValue, -3)
		XCTAssertEqual((x / seven).rawValue, 2142)
		XCTAssertTrue((x / (0 as Int)).isNan)

		var a = x
		a *= seven
		XCTAssertEqual(a.rawValue, 105_000)
		a /= seven
		XCTAssertEqual(a.rawValue, 15000)
	}

	/// The factor is not scaled, so it may be far larger than any FDec.
	func test_IntOperators_LargeFactorAndOverflow() {
		let huge = 900_000_000_000_000_000

		XCTAssertEqual((raw(1) * huge).rawValue, huge)
		XCTAssertEqual((raw(-10) * huge / huge).rawValue, -10)

		XCTAssertEqual((make(1) * huge).rawValue, Int.max)
		XCTAssertEqual((make(-1) * huge).rawValue, -Int.max)
		XCTAssertEqual((raw(2) * Int.max).rawValue, Int.max)
		XCTAssertEqual((raw(-2) * Int.max).rawValue, -Int.max)

		// Products landing on the reserved raw values are overflows too.
		XCTAssertEqual((raw(1) * Int.max).rawValue, Int.max)
		XCTAssertEqual((raw(1) * Int.min).rawValue, -Int.max)
		XCTAssertEqual((raw(-1) * Int.max).rawValue, -Int.max)
	}

	func test_IntOperators_SpecialValues() {
		XCTAssertTrue((nan * (2 as Int)).isNan)
		XCTAssertTrue((nan / (2 as Int)).isNan)
		XCTAssertTrue((inf * (0 as Int)).isNan)
		XCTAssertEqual((inf * (2 as Int)).rawValue, Int.max)
		XCTAssertEqual((inf * (-2 as Int)).rawValue, -Int.max)
		XCTAssertEqual((negInf * (-2 as Int)).rawValue, Int.max)
		XCTAssertEqual((inf / (-2 as Int)).rawValue, -Int.max)
		XCTAssertEqual((negInf / (2 as Int)).rawValue, -Int.max)
		XCTAssertTrue((inf / (0 as Int)).isNan)
	}

}

final class Test_PowerAndRoot: FDecTestCase {

	func test_Raised() {
		XCTAssertEqual(make(2).raised(to: 10).rawValue, 10_240_000)
		XCTAssertEqual(make(-2).raised(to: 3).rawValue, -80000)
		XCTAssertEqual(make(-2).raised(to: 4).rawValue, 160_000)
		XCTAssertEqual(make(1, 5000).raised(to: 2).rawValue, 22500)
		XCTAssertEqual(make(7, 1234).raised(to: 1).rawValue, 71234)
		XCTAssertEqual(make(7, 1234).raised(to: 0).rawValue, 10000)
		XCTAssertEqual(make(0).raised(to: 0).rawValue, 10000)
		XCTAssertEqual(make(0).raised(to: 5).rawValue, 0)
		XCTAssertEqual(pow(make(2), 3).rawValue, 80000)

		// Negative exponents give the reciprocal.
		XCTAssertEqual(make(2).raised(to: -2).rawValue, 2500)
		XCTAssertEqual(make(10).raised(to: -4).rawValue, 1)
		XCTAssertEqual(make(10).raised(to: -5).rawValue, 0)
		XCTAssertTrue(make(0).raised(to: -1).isNan)

		// 1.0001^2 = 1.00020001
		XCTAssertEqual(raw(10001).raised(to: 2).rawValue, 10002)
		XCTAssertEqual(raw(10001).raised(to: 2, rounding: .awayFromZero).rawValue, 10003)

		XCTAssertEqual(make(10).raised(to: 14).rawValue, 100_000_000_000_000 * 10000)
		XCTAssertEqual(make(10).raised(to: 15).rawValue, Int.max)
		XCTAssertEqual(make(-10).raised(to: 15).rawValue, -Int.max)
		XCTAssertTrue(nan.raised(to: 2).isNan)
		XCTAssertTrue(nan.raised(to: 0).isNan)
		XCTAssertEqual(negInf.raised(to: 2).rawValue, Int.max)
		XCTAssertEqual(negInf.raised(to: 3).rawValue, -Int.max)
		XCTAssertEqual(inf.raised(to: -1).rawValue, 0)

		FDec.decimalPlaces = 18
		XCTAssertEqual(make(2).raised(to: 3).rawValue, 8 * FDec.pow)
	}

	func test_SquareRoot() {
		XCTAssertEqual(make(2).squareRoot().rawValue, 14142)
		XCTAssertEqual(raw(1).squareRoot().rawValue, 100) // sqrt(0.0001) = 0.01
		XCTAssertEqual(raw(2).squareRoot().rawValue, 141) // sqrt(0.0002) = 0.01414...
		XCTAssertEqual(make(12, 2500).squareRoot().rawValue, 35000)

		for n in 0 ... 200 {
			XCTAssertEqual(make(n * n).squareRoot().rawValue, n * 10000, "sqrt(\(n * n))")
		}

		XCTAssertTrue(make(-1).squareRoot().isNan)
		XCTAssertTrue(raw(-1).squareRoot().isNan)
		XCTAssertTrue(nan.squareRoot().isNan)
		XCTAssertTrue(negInf.squareRoot().isNan)
		XCTAssertEqual(inf.squareRoot().rawValue, Int.max)

		// sqrt(2) = 1.41421356237309504880..., beyond the precision of Double.
		FDec.decimalPlaces = 18
		XCTAssertEqual(make(2).squareRoot().rawValue, 1_414_213_562_373_095_048)

		FDec.decimalPlaces = 0
		XCTAssertEqual(raw(99).squareRoot().rawValue, 9)
		XCTAssertEqual(raw(100).squareRoot().rawValue, 10)
	}

	/// The defining property: root² <= value < (root + one unit)², checked on 128 bits.
	func test_SquareRoot_IsTheExactTruncatedRoot() {
		func notAbove(_ a: (high: UInt, low: UInt), _ b: (high: UInt, low: UInt)) -> Bool {
			a.high < b.high || (a.high == b.high && a.low <= b.low)
		}

		for places in [0, 4, 9, 18] {
			FDec.decimalPlaces = places

			var samples = (0 ..< 500).map { _ in Int.random(in: 0 ... Int.max - 1) }
			samples += (0 ..< 500).map { _ in Int.random(in: 0 ... 1_000_000) }
			samples += [0, 1, 2, 3, Int.max - 1]

			for sample in samples {
				let root = raw(sample).squareRoot().rawValue.magnitude
				let target = sample.magnitude.multipliedFullWidth(by: UInt(FDec.pow))

				XCTAssertTrue(notAbove(root.multipliedFullWidth(by: root), target), "\(sample) @\(places)")
				XCTAssertFalse(notAbove((root + 1).multipliedFullWidth(by: root + 1), target), "\(sample) @\(places)")
			}
		}
	}

}

final class Test_Helpers: FDecTestCase {

	func test_FloorCeilTruncated() {
		let x = raw(15000), y = raw(-15000)

		XCTAssertEqual(x.floor().rawValue, 10000)
		XCTAssertEqual(x.ceil().rawValue, 20000)
		XCTAssertEqual(x.truncated().rawValue, 10000)

		XCTAssertEqual(y.floor().rawValue, -20000)
		XCTAssertEqual(y.ceil().rawValue, -10000)
		XCTAssertEqual(y.truncated().rawValue, -10000)

		XCTAssertEqual(raw(12345).floor(places: 2).rawValue, 12300)
		XCTAssertEqual(raw(12345).ceil(places: 2).rawValue, 12400)
		XCTAssertEqual(raw(-12345).truncated(places: 2).rawValue, -12300)
		XCTAssertEqual(make(3).ceil().rawValue, 30000)
	}

	func test_IsWholeAndSignum() {
		XCTAssertTrue(make(3).isWhole)
		XCTAssertTrue(make(0).isWhole)
		XCTAssertTrue(make(-3).isWhole)
		XCTAssertFalse(raw(15000).isWhole)
		XCTAssertFalse(inf.isWhole)
		XCTAssertFalse(nan.isWhole)

		XCTAssertEqual(raw(5).signum(), 1)
		XCTAssertEqual(raw(-5).signum(), -1)
		XCTAssertEqual(raw(0).signum(), 0)
		XCTAssertEqual(inf.signum(), 1)
		XCTAssertEqual(negInf.signum(), -1)
		XCTAssertEqual(nan.signum(), 0)
	}

	func test_Clamped() {
		let range = raw(10) ... raw(20)

		XCTAssertEqual(raw(5).clamped(to: range).rawValue, 10)
		XCTAssertEqual(raw(25).clamped(to: range).rawValue, 20)
		XCTAssertEqual(raw(15).clamped(to: range).rawValue, 15)
		XCTAssertEqual(raw(10).clamped(to: range).rawValue, 10)
		XCTAssertEqual(inf.clamped(to: range).rawValue, 20)
		XCTAssertEqual(negInf.clamped(to: range).rawValue, 10)
		XCTAssertTrue(nan.clamped(to: range).isNan)
	}

}

final class Test_Sums: FDecTestCase {

	func test_Sum() {
		XCTAssertEqual([raw(1), raw(2), raw(-10)].sum().rawValue, -7)
		XCTAssertEqual([FDec]().sum().rawValue, 0)
		XCTAssertEqual(Set([raw(1), raw(2)]).sum().rawValue, 3)
		XCTAssertEqual([raw(5)].sum().rawValue, 5)

		// A running total that leaves the range and comes back is still right.
		let big = raw(Int.max - 1)
		XCTAssertEqual([big, raw(10), raw(-20)].sum().rawValue, Int.max - 11)
		XCTAssertEqual([-big, raw(-10), raw(20)].sum().rawValue, -(Int.max - 11))
		XCTAssertEqual([big, big, big, -big, -big].sum().rawValue, Int.max - 1)

		// Only a final sum that does not fit is an infinity.
		XCTAssertEqual([big, big].sum().rawValue, Int.max)
		XCTAssertEqual([-big, -big].sum().rawValue, -Int.max)
		XCTAssertEqual([big, raw(1)].sum().rawValue, Int.max)
		XCTAssertEqual([-big, raw(-1)].sum().rawValue, -Int.max)

		XCTAssertTrue([raw(1), nan, inf].sum().isNan)
		XCTAssertTrue([inf, negInf].sum().isNan)
		XCTAssertEqual([inf, raw(1), big].sum().rawValue, Int.max)
		XCTAssertEqual([negInf, raw(1)].sum().rawValue, -Int.max)
	}

	func test_Average() {
		XCTAssertNil([FDec]().average())
		XCTAssertEqual([raw(10), raw(20), raw(30)].average()?.rawValue, 20)

		// 1.5 and -1.5 raw units
		XCTAssertEqual([raw(1), raw(2)].average()?.rawValue, 1)
		XCTAssertEqual([raw(1), raw(2)].average(rounding: .toNearestOrAwayFromZero)?.rawValue, 2)
		XCTAssertEqual([raw(1), raw(2)].average(rounding: .toNearestOrEven)?.rawValue, 2)
		XCTAssertEqual([raw(-1), raw(-2)].average()?.rawValue, -1)
		XCTAssertEqual([raw(-1), raw(-2)].average(rounding: .down)?.rawValue, -2)
		XCTAssertEqual([raw(-1), raw(-2)].average(rounding: .up)?.rawValue, -1)

		// The sum overflows, the average does not.
		let big = raw(Int.max - 1)
		XCTAssertEqual([big, big, big].average()?.rawValue, Int.max - 1)
		XCTAssertEqual([-big, -big].average()?.rawValue, -(Int.max - 1))

		XCTAssertEqual([nan, raw(1)].average()?.isNan, true)
		XCTAssertEqual([inf, raw(1)].average()?.rawValue, Int.max)
	}

	func test_SumAndAverage_RandomAgainstInt() {
		for _ in 0 ..< 500 {
			let values = (0 ..< Int.random(in: 1 ... 20)).map { _ in Int.random(in: -1_000_000_000_000 ... 1_000_000_000_000) }
			let total = values.reduce(0, +)
			let elements = values.map { raw($0) }

			XCTAssertEqual(elements.sum().rawValue, total)
			XCTAssertEqual(elements.average()?.rawValue, total / values.count)
		}
	}

}
