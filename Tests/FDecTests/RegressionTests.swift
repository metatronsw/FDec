import XCTest
@testable import FDec

/// Regression tests for the defects listed in CLAUDE.md (H1–H18, C1–C14).
/// Expected values are pinned through `rawValue` / `description`, never through an FDec literal.
final class Test_Regression: XCTestCase {

	override func setUp() {
		super.setUp()
		FDec.decimalPlaces = 4
	}

	override func tearDown() {
		FDec.decimalPlaces = 4
		super.tearDown()
	}

	// MARK: H1 – comparison

	func test_H1_Comparison() {
		let one = FDec(raw: 10000)
		let two = FDec(raw: 20000)
		let minusOne = FDec(raw: -10000)

		XCTAssertFalse(one > one)
		XCTAssertTrue(one >= one)
		XCTAssertTrue(one <= one)
		XCTAssertFalse(one < one)

		XCTAssertTrue(two > one)
		XCTAssertFalse(one > two)
		XCTAssertTrue(one > minusOne)
		XCTAssertFalse(minusOne > one)

		XCTAssertTrue(one != two)
		XCTAssertFalse(one != one)

		XCTAssertEqual([two, minusOne, one].sorted().map(\.rawValue), [-10000, 10000, 20000])
		XCTAssertEqual(max(one, two).rawValue, 20000)
		XCTAssertEqual(min(one, minusOne).rawValue, -10000)
	}

	// MARK: H2 / C1 – multiplication

	/// Builds a value from an integer and a fraction given in raw units of the current scale.
	private func make(_ int: Int, _ frc: Int = 0) -> FDec {
		FDec(raw: int * FDec.pow + frc)
	}

	func test_H2_Mul_Scale4() {
		XCTAssertEqual((make(1_000_000) * make(1_000_000)).rawValue, 1_000_000_000_000 * 10000)
		XCTAssertEqual((make(1, 5000) * make(1, 5000)).rawValue, 22500)

		// 123456789.1234 * 98765.4321 = 12193263123451.18122114
		XCTAssertEqual((FDec(raw: 1_234_567_891_234) * FDec(raw: 987_654_321)).rawValue, 121_932_631_234_511_812)
	}

	func test_H2_Mul_OtherScales() {
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
		XCTAssertEqual((make(1) * FDec(raw: 1)).rawValue, 1)
	}

	func test_H2_Mul_SignsAndTruncation() {
		let a = FDec(raw: 19999) // 1.9999
		let b = FDec(raw: -19999)

		// 1.9999 * 1.9999 = 3.99960001, truncated toward zero
		XCTAssertEqual((a * a).rawValue, 39996)
		XCTAssertEqual((a * b).rawValue, -39996)
		XCTAssertEqual((b * a).rawValue, -39996)
		XCTAssertEqual((b * b).rawValue, 39996)

		XCTAssertEqual((FDec(raw: 1) * FDec(raw: 1)).rawValue, 0)
		XCTAssertEqual((FDec(raw: -1) * FDec(raw: 1)).rawValue, 0)
		XCTAssertEqual((a * FDec(raw: 0)).rawValue, 0)
		XCTAssertEqual((a * make(1)).rawValue, 19999)
	}

	func test_C1_Mul_OverflowDoesNotTrap() {
		let big = make(400_000_000_000_000)

		XCTAssertTrue((big * big).isInfinity)
		XCTAssertTrue((make(1_000_000_000) * make(1_000_000_000)).isInfinity)
		XCTAssertTrue((FDec(raw: Int.max) * FDec(raw: Int.max)).isInfinity)

		// The largest product that still fits must not be reported as overflow.
		XCTAssertEqual((FDec(raw: Int.max - 7) * make(1)).rawValue, Int.max - 7)
		XCTAssertEqual((make(30_000_000) * make(30_000_000)).rawValue, 900_000_000_000_000 * 10000)
	}

	// MARK: H3 / C4 – remainder

	func test_H3_Remainder() {
		XCTAssertEqual((make(5, 5000) % make(2)).rawValue, 15000) // 5.5 % 2 = 1.5
		XCTAssertEqual((make(7) % make(2, 5000)).rawValue, 20000) // 7 % 2.5 = 2
		XCTAssertEqual((FDec(raw: 5000) % FDec(raw: 2000)).rawValue, 1000) // 0.5 % 0.2 = 0.1
		XCTAssertEqual((make(4) % make(3)).rawValue, 10000)
		XCTAssertEqual((make(8) % make(2)).rawValue, 0)

		// The sign follows the dividend, exactly like Int.
		XCTAssertEqual((make(-7) % make(3)).rawValue, -10000)
		XCTAssertEqual((make(7) % make(-3)).rawValue, 10000)
		XCTAssertEqual((make(-7) % make(-3)).rawValue, -10000)

		// Large values no longer overflow into infinity.
		XCTAssertEqual((make(100_000_000_000) % make(3)).rawValue, 10000)

		var a = make(5, 5000)
		a %= make(2)
		XCTAssertEqual(a.rawValue, 15000)

		for _ in 0 ..< 1000 {
			let x = Int.random(in: -1_000_000_000_000 ... 1_000_000_000_000)
			let y = Int.random(in: 1 ... 1_000_000_000)
			XCTAssertEqual((FDec(raw: x) % FDec(raw: y)).rawValue, x % y)
		}
	}

	func test_H3_Remainder_OtherScales() {
		FDec.decimalPlaces = 2
		XCTAssertEqual((make(5, 50) % make(2)).rawValue, 150)

		FDec.decimalPlaces = 8
		XCTAssertEqual((make(5, 50_000_000) % make(2)).rawValue, 150_000_000)
	}

	func test_C4_Remainder_ByZero() {
		XCTAssertTrue((make(1) % make(0)).isNan)
		XCTAssertTrue((make(0) % make(0)).isNan)
		XCTAssertEqual((FDec(raw: Int.min + 2) % FDec(raw: -1)).rawValue, 0)
	}

	// MARK: H4 – division

	func test_H4_Div_LargeDividend() {
		XCTAssertEqual((make(100_000_000_000) / make(2)).rawValue, 50_000_000_000 * 10000)
		XCTAssertEqual((make(922_337_203_686) / make(1)).rawValue, 922_337_203_686 * 10000)
		XCTAssertEqual((make(-100_000_000_000) / make(2)).rawValue, -50_000_000_000 * 10000)
		XCTAssertEqual((FDec(raw: Int.max - 7) / make(1)).rawValue, Int.max - 7)
		XCTAssertEqual((FDec(raw: Int.max - 7) / make(-1)).rawValue, -(Int.max - 7))
	}

	func test_H4_Div_Basics() {
		XCTAssertEqual((make(3) / make(2)).rawValue, 15000)
		XCTAssertEqual((make(10) / FDec(raw: 5000)).rawValue, 200_000)

		// Truncation toward zero, for both signs.
		XCTAssertEqual((make(2) / make(3)).rawValue, 6666)
		XCTAssertEqual((make(-2) / make(3)).rawValue, -6666)
		XCTAssertEqual((make(2) / make(-3)).rawValue, -6666)
		XCTAssertEqual((make(-2) / make(-3)).rawValue, 6666)
		XCTAssertEqual((FDec(raw: 1) / make(2)).rawValue, 0)

		XCTAssertTrue((make(1) / make(0)).isNan)
		XCTAssertTrue((make(0) / make(0)).isNan)

		// A quotient that really does not fit is still reported.
		XCTAssertTrue((make(900_000_000_000_000) / FDec(raw: 1)).isInfinity)
	}

	func test_H4_Div_RandomAgainstDecimal() {
		for places in [0, 2, 4, 6, 9] {
			FDec.decimalPlaces = places
			let scale = Decimal(FDec.pow)

			for _ in 0 ..< 2000 {
				let a = Int.random(in: -900_000_000_000_000 ... 900_000_000_000_000)
				var b = Int.random(in: -3_000_000_000 ... 3_000_000_000)
				if abs(b) < 1000 { b = 1000 }

				var exact = Decimal(a.magnitude) * scale / Decimal(b.magnitude)
				var truncated = Decimal()
				NSDecimalRound(&truncated, &exact, 0, .down)

				let result = FDec(raw: a) / FDec(raw: b)

				XCTAssertEqual(String(result.rawValue.magnitude), truncated.description, "\(a) / \(b) @\(places)")
				if result.rawValue != 0 {
					XCTAssertEqual(result.rawValue < 0, (a < 0) != (b < 0), "sign \(a) / \(b) @\(places)")
				}
			}
		}
	}

	// MARK: H5 – quotientAndRemainder

	func test_H5_QuotientAndRemainder() {
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
			let n = FDec(raw: Int.random(in: -1_000_000_000_000 ... 1_000_000_000_000))
			let d = FDec(raw: Int.random(in: 1 ... 1_000_000_000))
			let r = n.quotientAndRemainder(dividingBy: d)

			XCTAssertFalse(r.quotient.isDecimal)
			XCTAssertEqual((r.quotient * d + r.remainder).rawValue, n.rawValue)
		}
	}

	// MARK: H6 – Double init

	func test_H6_Double_AllTwoDecimalValues() {
		for i in 0 ..< 10000 {
			let d = Double(i) / 100.0
			XCTAssertEqual(FDec(d)?.rawValue, i * 100, "\(d)")
			XCTAssertEqual(FDec(-d)?.rawValue, -i * 100, "-\(d)")
		}
	}

	func test_H6_Double_Rounding() {
		let cases: [(Double, Int)] = [
			(0.07, 700), (0.57, 5700), (19.99, 199_900), (4.35, 43500),
			(0.12344, 1234), (0.12346, 1235), (-0.12346, -1235),
			(0.00004, 0), (0.00006, 1), (1_234_567_890.123, 12_345_678_901_230),
		]

		for (double, raw) in cases {
			XCTAssertEqual(FDec(double)?.rawValue, raw, "\(double)")
		}

		FDec.decimalPlaces = 2
		XCTAssertEqual(FDec(19.99 as Double)?.rawValue, 1999)
		XCTAssertEqual(FDec(0.126 as Double)?.rawValue, 13)

		FDec.decimalPlaces = 0
		XCTAssertEqual(FDec(2.6 as Double)?.rawValue, 3)
	}

	func test_H6_Double_Rejected() {
		XCTAssertNil(FDec(Double.nan))
		XCTAssertNil(FDec(Double.infinity))
		XCTAssertNil(FDec(-Double.infinity))
		XCTAssertNil(FDec(1e300 as Double))
		XCTAssertNil(FDec(-1e300 as Double))
		XCTAssertNil(FDec(1e15 as Double)) // 1e19 raw does not fit
		XCTAssertNil(FDec(-922_337_203_685_477.5808 as Double)) // would be the raw value of .nan
		XCTAssertNotNil(FDec(9e14 as Double))
	}

	func test_H6_FloatLiteral_Rounds() {
		let a: FDec = 0.12346
		XCTAssertEqual(a.rawValue, 1235)

		let b: FDec = 19.99
		XCTAssertEqual(b.rawValue, 199_900)
	}

	// MARK: H7 / C9 / C10 – init(truncating:)

	func test_H7_Truncating_AllTwoDecimalValues() {
		for i in 0 ..< 10000 {
			let d = Double(i) / 100.0
			XCTAssertEqual(FDec(truncating: d).rawValue, i * 100, "\(d)")
			XCTAssertEqual(FDec(truncating: -d).rawValue, -i * 100, "-\(d)")
		}
	}

	func test_H7_Truncating_StillTruncates() {
		XCTAssertEqual(FDec(truncating: 0.12349).rawValue, 1234)
		XCTAssertEqual(FDec(truncating: -0.12349).rawValue, -1234)
		XCTAssertEqual(FDec(truncating: 0.99999).rawValue, 9999)
		XCTAssertEqual(FDec(truncating: 0.00009).rawValue, 0)
		XCTAssertEqual(FDec(truncating: 1.41421356).rawValue, 14142)
		XCTAssertEqual(FDec(truncating: 0.57).rawValue, 5700)
		XCTAssertEqual(FDec(truncating: 1_234_567_890.123).rawValue, 12_345_678_901_230)
	}

	func test_C9_Truncating_SpecialValues() {
		XCTAssertTrue(FDec(truncating: .nan).isNan)
		XCTAssertTrue(FDec(truncating: .infinity).isInfinity)
		XCTAssertTrue(FDec(truncating: -.infinity).isInfinity)
		XCTAssertTrue(FDec(truncating: 1e300).isInfinity)
		XCTAssertTrue(FDec(truncating: -1e300).isInfinity)
	}

	func test_C10_Sqrt_Negative() {
		XCTAssertTrue(sqrt(make(-1)).isNan)
		XCTAssertEqual(sqrt(make(0)).rawValue, 0)
		XCTAssertEqual(sqrt(make(4)).rawValue, 20000)
		XCTAssertEqual(sqrt(make(2)).rawValue, 14142)
		XCTAssertEqual(sqrt(make(12, 2500)).rawValue, 35000)
	}

	// MARK: H8 – Float init

	func test_H8_Float() {
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

	// MARK: H9 – init(exactly:) from floating point

	func test_H9_Exactly_FloatingPoint() {
		XCTAssertEqual(FDec(exactly: 1.5 as Double)?.rawValue, 15000)
		XCTAssertEqual(FDec(exactly: 0.1 as Double)?.rawValue, 1000)
		XCTAssertEqual(FDec(exactly: 2.0 as Double)?.rawValue, 20000)
		XCTAssertEqual(FDec(exactly: -19.99 as Double)?.rawValue, -199_900)
		XCTAssertEqual(FDec(exactly: Float(0.1))?.rawValue, 1000)

		// More decimals than the scale: not lossless.
		XCTAssertNil(FDec(exactly: 0.12345 as Double))
		XCTAssertNil(FDec(exactly: 0.00001 as Double))
		XCTAssertNil(FDec(exactly: Float(0.12345)))

		XCTAssertNil(FDec(exactly: Double.nan))
		XCTAssertNil(FDec(exactly: Double.infinity))
		XCTAssertNil(FDec(exactly: 1e300 as Double))

		// The integer overload is untouched.
		XCTAssertEqual(FDec(exactly: 7 as Int)?.rawValue, 70000)
	}

	// MARK: H10 – string parser

	/// Goes through a variable on purpose: a literal argument would pick `init(stringLiteral:)`.
	private func parse(_ text: String) -> FDec? { FDec(text) }

	func test_H10_String_Accepted() {
		let cases: [(String, Int)] = [
			("0", 0), ("-0", 0), ("5", 50000), ("-5", -50000), ("+5", 50000),
			("0.5", 5000), (".5", 5000), ("5.", 50000), ("-.5", -5000), ("+1.5", 15000),
			("-0.0001", -1), ("12345.6789", 123_456_789), ("-12345.6789", -123_456_789),
			("007", 70000), ("0.50000", 5000),
			// Fraction digits beyond the scale are truncated, for both signs.
			("0.99999", 9999), ("-0.99999", -9999), ("0.00009", 0), ("-0.00009", 0), ("0.12345", 1234),
		]

		for (text, raw) in cases {
			XCTAssertEqual(parse(text)?.rawValue, raw, "'\(text)'")
		}
	}

	func test_H10_String_Rejected() {
		let cases = [
			"", ".", "-", "+", "-.", "1.2.3", "1..2", "1,5", "1,000.5", "1,000", " 1", "1 ", "1 000",
			"1e3", "1.5x", "x", "--1", "+-1", "1-", "1.-5", "1.+5", "0x10", "١٢", "1_000", "Infinity", "nan",
			"0.1234x", "0.12345x",
		]

		for text in cases {
			XCTAssertNil(parse(text), "'\(text)'")
		}
	}

	func test_H10_String_Limits() {
		XCTAssertEqual(parse("922337203685477.5806")?.rawValue, Int.max - 1)
		XCTAssertEqual(parse("-922337203685477.5806")?.rawValue, -(Int.max - 1))
		XCTAssertNil(parse("922337203685477.5808"))
		XCTAssertNil(parse("1000000000000000"))
		XCTAssertNil(parse("99999999999999999999999999"))

		FDec.decimalPlaces = 0
		XCTAssertEqual(parse("1.9")?.rawValue, 1)
		XCTAssertEqual(parse("42")?.rawValue, 42)

		FDec.decimalPlaces = 2
		XCTAssertEqual(parse("19.999")?.rawValue, 1999)
	}

	func test_H10_String_RoundTrip() {
		for places in [0, 2, 4, 9] {
			FDec.decimalPlaces = places

			for _ in 0 ..< 1000 {
				let original = FDec(raw: Int.random(in: -1_000_000_000_000 ... 1_000_000_000_000))
				XCTAssertEqual(parse(original.description)?.rawValue, original.rawValue, "\(original.rawValue) @\(places)")
			}
		}
	}

	func test_H10_StringLiteral_StillStripsSeparators() {
		let a: FDec = "1_000_000.5"
		XCTAssertEqual(a.rawValue, 10_000_005_000)

		let b: FDec = "1 000"
		XCTAssertEqual(b.rawValue, 10_000_000)
	}

	// MARK: H11 – init(int:frc:sign:)

	func test_H11_IntFrcSign() {
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

	// MARK: H12 – parity

	func test_H12_Parity() {
		for places in [0, 1, 4, 7] {
			FDec.decimalPlaces = places

			for n in -6 ... 6 {
				XCTAssertEqual(make(n).isOdd, n % 2 != 0, "\(n) @\(places)")
				XCTAssertEqual(make(n).isEven, n % 2 == 0, "\(n) @\(places)")
			}
		}

		FDec.decimalPlaces = 4

		// Parity is only defined for whole numbers.
		for raw in [25000, 30001, 1, -1, -25000, 39999] {
			XCTAssertFalse(FDec(raw: raw).isOdd, "\(raw)")
			XCTAssertFalse(FDec(raw: raw).isEven, "\(raw)")
		}
	}

	// MARK: H13 / H14 / C2 / C3 – infinity and nan

	private var inf: FDec { .infinity }
	private var negInf: FDec { -FDec.infinity }
	private var nan: FDec { .nan }

	func test_H13_SpecialValues_Identity() {
		XCTAssertTrue(inf.isInfinity)
		XCTAssertTrue(negInf.isInfinity)
		XCTAssertEqual(negInf.rawValue, -Int.max)
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
		}

		XCTAssertTrue(make(5).isFinite)
		XCTAssertTrue(FDec(raw: Int.max - 1).isFinite)
		XCTAssertTrue(FDec(raw: -(Int.max - 1)).isFinite)
		XCTAssertFalse(make(5).isInfinity)
	}

	func test_H13_SignedOverflow() {
		let big = FDec(raw: Int.max - 5)
		let negBig = FDec(raw: -(Int.max - 5))

		XCTAssertEqual((big + FDec(raw: 10)).rawValue, Int.max)
		XCTAssertEqual((negBig + FDec(raw: -10)).rawValue, -Int.max)
		XCTAssertEqual((negBig - FDec(raw: 10)).rawValue, -Int.max)
		// Landing exactly on the raw value of nan must become negative infinity.
		XCTAssertEqual((negBig + FDec(raw: -6)).rawValue, -Int.max)
		XCTAssertEqual((negBig + FDec(raw: -4)).rawValue, -(Int.max - 1))

		XCTAssertEqual((make(-1_000_000_000) * make(1_000_000_000)).rawValue, -Int.max)
		XCTAssertEqual((make(-1_000_000_000) * make(-1_000_000_000)).rawValue, Int.max)
		XCTAssertEqual((make(-900_000_000_000_000) / FDec(raw: 1)).rawValue, -Int.max)
		XCTAssertEqual((make(900_000_000_000_000) / FDec(raw: -1)).rawValue, -Int.max)

		XCTAssertEqual(FDec(truncating: -1e300).rawValue, -Int.max)
		XCTAssertEqual(FDec(truncating: -.infinity).rawValue, -Int.max)
		XCTAssertEqual(FDec(truncating: .infinity).rawValue, Int.max)
	}

	func test_H14_NanPropagates() {
		let five = make(5)

		for result in [nan + five, five + nan, nan - five, five - nan, nan * five, five * nan,
		               nan / five, five / nan, nan % five, five % nan, -nan, nan.magnitude,
		               nan + inf, nan * make(0), sqrt(nan)] {
			XCTAssertTrue(result.isNan)
		}

		let qr = nan.quotientAndRemainder(dividingBy: five)
		XCTAssertTrue(qr.quotient.isNan)
		XCTAssertTrue(qr.remainder.isNan)
	}

	func test_H14_InfinityArithmetic() {
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
		XCTAssertEqual((inf * FDec(raw: 1)).rawValue, Int.max)
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

		// Negation and magnitude
		XCTAssertEqual((-negInf).rawValue, Int.max)
		XCTAssertEqual(negInf.magnitude.rawValue, Int.max)
		XCTAssertEqual(abs(negInf).rawValue, Int.max)

		// sqrt
		XCTAssertEqual(sqrt(inf).rawValue, Int.max)
		XCTAssertTrue(sqrt(negInf).isNan)
	}

	func test_C3_Int32Min() {
		XCTAssertEqual((make(0) - Int32.min).rawValue, 2_147_483_648 * 10000)

		var a = make(0)
		a -= Int32.min
		XCTAssertEqual(a.rawValue, 2_147_483_648 * 10000)
		XCTAssertEqual((Int32.min - make(0)).rawValue, -2_147_483_648 * 10000)
	}

	func test_H14_Comparison_LikeDouble() {
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
		XCTAssertTrue(inf > FDec(raw: Int.max - 1))
		XCTAssertTrue(negInf < FDec(raw: -(Int.max - 1)))
		XCTAssertTrue(inf == inf)
		XCTAssertTrue(inf >= inf)
		XCTAssertTrue(negInf <= negInf)
		XCTAssertFalse(inf == negInf)
	}

	func test_H14_SpecialValues_Output() {
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

		// A finite text never produces a special value.
		XCTAssertNil(parse("922337203685477.5807"))
		XCTAssertNil(parse("-922337203685477.5807"))
		XCTAssertNil(parse("-922337203685477.5808"))
	}

	// MARK: H15 / C13 – random

	func test_H15_RandomIn() {
		let low = FDec(raw: -15000)
		let high = FDec(raw: 25000)
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
		XCTAssertEqual(FDec.random(in: FDec(raw: 7) ..< FDec(raw: 8)).rawValue, 7)
	}

	func test_H15_RandomParts() {
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

	func test_C13_RandomParts_Invalid() {
		let edge = Int.max / 10000

		XCTAssertNil(FDec.random(edge ... edge, 9999 ... 9999))
		XCTAssertNil(FDec.random(Int.max ... Int.max))
		XCTAssertNil(FDec.random(Int.min ... Int.min))
		XCTAssertNil(FDec.random(1 ... 1, -5 ... 5))
		XCTAssertNil(FDec.random(1 ... 1, 0 ... 10000))
		XCTAssertNotNil(FDec.random(edge ... edge, 0 ... 5000))
	}

	// MARK: H16 – rounding

	func test_H16_Divided_Rounding() {
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
		XCTAssertEqual(FDec(raw: 1).divided(by: two, rounding: .towardZero).rawValue, 0)
		XCTAssertEqual(FDec(raw: 1).divided(by: two, rounding: .toNearestOrAwayFromZero).rawValue, 1)
		XCTAssertEqual(FDec(raw: 1).divided(by: two, rounding: .toNearestOrEven).rawValue, 0)
		XCTAssertEqual(FDec(raw: 3).divided(by: two, rounding: .toNearestOrEven).rawValue, 2)
		XCTAssertEqual(FDec(raw: -3).divided(by: two, rounding: .toNearestOrAwayFromZero).rawValue, -2)

		// An exact quotient is never touched.
		XCTAssertEqual(make(3).divided(by: two, rounding: .awayFromZero).rawValue, 15000)

		// The operator keeps truncating.
		XCTAssertEqual((two / three).rawValue, 6666)

		XCTAssertTrue(two.divided(by: make(0), rounding: .up).isNan)
	}

	func test_H16_Multiplied_Rounding() {
		let a = FDec(raw: 19999) // 1.9999 * 1.9999 = 3.99960001

		XCTAssertEqual(a.multiplied(by: a, rounding: .towardZero).rawValue, 39996)
		XCTAssertEqual(a.multiplied(by: a, rounding: .toNearestOrAwayFromZero).rawValue, 39996)
		XCTAssertEqual(a.multiplied(by: a, rounding: .awayFromZero).rawValue, 39997)
		XCTAssertEqual(a.multiplied(by: a, rounding: .up).rawValue, 39997)
		XCTAssertEqual((-a).multiplied(by: a, rounding: .up).rawValue, -39996)
		XCTAssertEqual((-a).multiplied(by: a, rounding: .down).rawValue, -39997)

		// 0.0005 * 0.1 = 0.00005 and 0.0015 * 0.1 = 0.00015 are exact ties.
		let tenth = FDec(raw: 1000)
		XCTAssertEqual(FDec(raw: 5).multiplied(by: tenth, rounding: .toNearestOrAwayFromZero).rawValue, 1)
		XCTAssertEqual(FDec(raw: 5).multiplied(by: tenth, rounding: .toNearestOrEven).rawValue, 0)
		XCTAssertEqual(FDec(raw: 15).multiplied(by: tenth, rounding: .toNearestOrEven).rawValue, 2)
		XCTAssertEqual(FDec(raw: 5).multiplied(by: tenth, rounding: .towardZero).rawValue, 0)

		XCTAssertEqual((a * a).rawValue, 39996)
		XCTAssertTrue(make(1_000_000_000).multiplied(by: make(-1_000_000_000), rounding: .up).isInfinity)
	}

	func test_H16_Rounding_RandomAgainstDecimal() {
		let modes: [(FloatingPointRoundingRule, NSDecimalNumber.RoundingMode)] = [
			(.towardZero, .down), (.awayFromZero, .up), (.toNearestOrAwayFromZero, .plain), (.toNearestOrEven, .bankers),
		]

		for places in [2, 4, 6] {
			FDec.decimalPlaces = places
			let scale = Decimal(FDec.pow)

			for (rule, mode) in modes {
				for _ in 0 ..< 500 {
					// Positive operands: NSDecimalRound is only used on magnitudes.
					let a = Int.random(in: 1 ... 2_000_000_000_000)
					let b = Int.random(in: 1 ... 3_000_000)

					var product = Decimal(a) * Decimal(b) / scale
					var expected = Decimal()
					NSDecimalRound(&expected, &product, 0, mode)
					XCTAssertEqual(String(FDec(raw: a).multiplied(by: FDec(raw: b), rounding: rule).rawValue), expected.description, "\(a) * \(b) \(rule) @\(places)")

					// A divisor with few prime factors makes exact ties likely.
					let d = [2, 4, 8, 16, 20, 40, 3, 7][Int.random(in: 0 ..< 8)]
					var quotient = Decimal(a) * scale / Decimal(d)
					NSDecimalRound(&expected, &quotient, 0, mode)
					XCTAssertEqual(String(FDec(raw: a).divided(by: FDec(raw: d), rounding: rule).rawValue), expected.description, "\(a) / \(d) \(rule) @\(places)")
				}
			}
		}
	}

	func test_H16_Rounded_Places() {
		let x = FDec(raw: 123_456) // 12.3456

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

		let minus = FDec(raw: -123_456)
		XCTAssertEqual(minus.rounded().rawValue, -120_000)
		XCTAssertEqual(minus.rounded(places: 2).rawValue, -123_500)
		XCTAssertEqual(minus.rounded(.up).rawValue, -120_000)
		XCTAssertEqual(minus.rounded(.down).rawValue, -130_000)
		XCTAssertEqual(minus.rounded(.towardZero, places: 2).rawValue, -123_400)

		// Ties: 0.5, 1.5, 2.5 and -0.5
		XCTAssertEqual(FDec(raw: 5000).rounded().rawValue, 10000)
		XCTAssertEqual(FDec(raw: -5000).rounded().rawValue, -10000)
		XCTAssertEqual(FDec(raw: 5000).rounded(.toNearestOrEven).rawValue, 0)
		XCTAssertEqual(FDec(raw: 15000).rounded(.toNearestOrEven).rawValue, 20000)
		XCTAssertEqual(FDec(raw: 25000).rounded(.toNearestOrEven).rawValue, 20000)
		XCTAssertEqual(FDec(raw: 125).rounded(.toNearestOrEven, places: 3).rawValue, 120)
		XCTAssertEqual(FDec(raw: 4999).rounded().rawValue, 0)

		var y = x
		y.round(places: 2)
		XCTAssertEqual(y.rawValue, 123_500)
		y.round()
		XCTAssertEqual(y.rawValue, 120_000)

		// Special values pass through, and rounding past the range becomes infinity.
		XCTAssertTrue(FDec.nan.rounded().isNan)
		XCTAssertEqual(FDec.infinity.rounded().rawValue, Int.max)
		XCTAssertEqual((-FDec.infinity).rounded(places: 2).rawValue, -Int.max)
		XCTAssertEqual(FDec(raw: Int.max - 1).rounded(.up).rawValue, Int.max)
		XCTAssertEqual(FDec(raw: -(Int.max - 1)).rounded(.down).rawValue, -Int.max)
		XCTAssertEqual(FDec(raw: Int.max - 1).rounded(.down).rawValue, 922_337_203_685_477 * 10000)
	}

	// MARK: H17 – Codable

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

	func test_H17_Codable_EncodesText() throws {
		XCTAssertEqual(try json([FDec(raw: 123_400)]), "[\"12.34\"]")
		XCTAssertEqual(try json([FDec(raw: -5), FDec(raw: 0), make(7)]), "[\"-0.0005\",\"0\",\"7\"]")
		XCTAssertEqual(try json(Invoice(id: 1, total: FDec(raw: 199_900), discount: nil)), "{\"id\":1,\"total\":\"19.99\"}")
		XCTAssertEqual(try json([FDec.nan, FDec.infinity, -FDec.infinity]), "[\"NaN\",\"Infinity\",\"-Infinity\"]")
	}

	func test_H17_Codable_RoundTrip() throws {
		let invoice = Invoice(id: 7, total: FDec(raw: -123_456_789), discount: FDec(raw: 1))
		XCTAssertEqual(try decode(Invoice.self, try json(invoice)), invoice)

		for _ in 0 ..< 500 {
			let original = FDec(raw: Int.random(in: -1_000_000_000_000 ... 1_000_000_000_000))
			XCTAssertEqual(try decode([FDec].self, try json([original])).first?.rawValue, original.rawValue)
		}

		let specials = try decode([FDec].self, try json([FDec.nan, FDec.infinity, -FDec.infinity]))
		XCTAssertTrue(specials[0].isNan)
		XCTAssertEqual(specials[1].rawValue, Int.max)
		XCTAssertEqual(specials[2].rawValue, -Int.max)
	}

	func test_H17_Codable_IndependentOfScale() throws {
		let text = try json([FDec(raw: 123_400)]) // 12.34 written at four decimals

		FDec.decimalPlaces = 2
		XCTAssertEqual(try decode([FDec].self, text).first?.rawValue, 1234)

		FDec.decimalPlaces = 6
		XCTAssertEqual(try decode([FDec].self, text).first?.rawValue, 12_340_000)
	}

	func test_H17_Codable_LegacyAndInvalid() throws {
		// The earlier format, a raw integer, is still readable.
		XCTAssertEqual(try decode([FDec].self, "[123400]").first?.rawValue, 123_400)

		XCTAssertThrowsError(try decode([FDec].self, "[\"abc\"]"))
		XCTAssertThrowsError(try decode([FDec].self, "[\"1,5\"]"))
		XCTAssertThrowsError(try decode([FDec].self, "[\"\"]"))
		XCTAssertThrowsError(try decode([FDec].self, "[12.34]"))
		XCTAssertThrowsError(try decode([FDec].self, "[true]"))
		XCTAssertThrowsError(try decode([FDec].self, "[null]"))
	}

	// MARK: C5 – digitCount

	func test_C5_DigitCount() {
		let cases: [(Int, Int)] = [
			(0, 1), (5000, 1), (-5000, 1), (10000, 1), (90000, 1), (99999, 1), (100_000, 2),
			(-50000, 1), (-100_000, 2), (9_990_000, 3), (10_000_000, 4), (123_450_000, 5),
			(Int.max - 1, 15), (-(Int.max - 1), 15),
		]

		for (raw, digits) in cases {
			XCTAssertEqual(FDec(raw: raw).digitCount, digits, "\(raw)")
		}

		XCTAssertEqual(FDec.nan.digitCount, 0)
		XCTAssertEqual(FDec.infinity.digitCount, 0)
		XCTAssertEqual((-FDec.infinity).digitCount, 0)

		FDec.decimalPlaces = 0
		XCTAssertEqual(FDec(raw: 1_000_000_000_000_000_000).digitCount, 19)
	}

	// MARK: C6 – asUInt32

	func test_C6_AsUInt32() {
		XCTAssertEqual(make(0).asUInt32, 0)
		XCTAssertEqual(make(42, 9999).asUInt32, 42)
		XCTAssertEqual(make(4_294_967_295).asUInt32, UInt32.max)
		XCTAssertEqual(FDec(raw: -5000).asUInt32, 0) // -0.5 has a zero whole part

		XCTAssertNil(make(-1).asUInt32)
		XCTAssertNil(make(4_294_967_296).asUInt32)
		XCTAssertNil(FDec.nan.asUInt32)
		XCTAssertNil(FDec.infinity.asUInt32)
		XCTAssertNil((-FDec.infinity).asUInt32)
	}

	// MARK: C7 / C8 – integer initializers

	func test_C7_IntegerInit() {
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
	}

	func test_C8_UnsignedBeyondInt() {
		XCTAssertNil(FDec(UInt.max))
		XCTAssertNil(FDec(UInt64.max))
		XCTAssertNil(FDec(exactly: UInt64.max))
		XCTAssertNil(FDec(UInt(Int.max) + 1))
	}

	func test_C7_SmallIntegerTypes() {
		XCTAssertEqual(FDec(Int8.min).rawValue, -1_280_000)
		XCTAssertEqual(FDec(UInt16.max).rawValue, 655_350_000)
		XCTAssertEqual(FDec(Int32.min).rawValue, -2_147_483_648 * 10000)
		XCTAssertEqual(FDec(UInt32.max).rawValue, 4_294_967_295 * 10000)

		// Only at very large scales can these overflow; they saturate like arithmetic does.
		FDec.decimalPlaces = 18
		XCTAssertEqual(FDec(Int8(9)).rawValue, 9_000_000_000_000_000_000)
		XCTAssertEqual(FDec(Int8(10)).rawValue, Int.max)
		XCTAssertEqual(FDec(Int32.min).rawValue, -Int.max)

		FDec.decimalPlaces = 0
		let max = Int.max - 1
		XCTAssertEqual(FDec(max)?.rawValue, max)
		XCTAssertNil(FDec(Int.max))
		XCTAssertNil(FDec(-Int.max))
	}

	// MARK: C11 – formatted

	func test_C11_Formatted_Grouping() {
		func fmt(_ value: FDec, _ size: Int, fullSign: Bool = false) -> String {
			value.formatted(fullSign: fullSign, groupingSize: size, decimalSeparator: ".", groupingSeparator: ",")
		}

		let n = make(1_234_567, 5000)

		XCTAssertEqual(fmt(n, 3), "1,234,567.5")
		XCTAssertEqual(fmt(n, 2), "1,23,45,67.5")
		XCTAssertEqual(fmt(n, 4), "123,4567.5")
		XCTAssertEqual(fmt(n, 1), "1,2,3,4,5,6,7.5")
		XCTAssertEqual(fmt(n, 7), "1234567.5")
		XCTAssertEqual(fmt(n, 20), "1234567.5")

		// Zero and negative sizes switch the grouping off.
		XCTAssertEqual(fmt(n, 0), "1234567.5")
		XCTAssertEqual(fmt(n, -1), "1234567.5")

		XCTAssertEqual(fmt(-n, 3), "-1,234,567.5")
		XCTAssertEqual(fmt(n, 3, fullSign: true), "+1,234,567.5")
		XCTAssertEqual(fmt(make(999), 3), "999")
		XCTAssertEqual(fmt(make(1000), 3), "1,000")
		XCTAssertEqual(fmt(make(100_000), 3), "100,000")
		XCTAssertEqual(fmt(make(123_456), 3), "123,456")
		XCTAssertEqual(fmt(FDec(raw: 500), 3), "0.05")
		XCTAssertEqual(fmt(FDec(raw: -500), 3, fullSign: true), "-0.05")
		XCTAssertEqual(fmt(make(0), 3), "0")

		XCTAssertEqual(make(1234, 5000).formatted(decimalSeparator: ",", groupingSeparator: " "), "1 234,5")
	}

	func test_H2_Mul_RandomAgainstDecimal() {
		for places in [0, 2, 4, 6, 9] {
			FDec.decimalPlaces = places
			let scale = Decimal(FDec.pow)

			for _ in 0 ..< 2000 {
				let a = Int.random(in: -2_000_000_000_000 ... 2_000_000_000_000)
				let b = Int.random(in: -3_000_000 ... 3_000_000)

				// Reference: exact product of the magnitudes, scaled back and truncated.
				var exact = Decimal(a.magnitude) * Decimal(b.magnitude) / scale
				var truncated = Decimal()
				NSDecimalRound(&truncated, &exact, 0, .down)

				let result = FDec(raw: a) * FDec(raw: b)

				XCTAssertEqual(String(result.rawValue.magnitude), truncated.description, "\(a) * \(b) @\(places)")
				if result.rawValue != 0 {
					XCTAssertEqual(result.rawValue < 0, (a < 0) != (b < 0), "sign \(a) * \(b) @\(places)")
				}
			}
		}
	}

}
