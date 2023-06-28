import XCTest
@testable import FDec




final class Test_FixDecimal_Valid: XCTestCase {
	
	func test_validator() throws {
		
		let numberFormatter = NumberFormatter()
		numberFormatter.numberStyle = .decimal
		numberFormatter.maximumFractionDigits = 6
		numberFormatter.decimalSeparator = "."
		numberFormatter.minimumFractionDigits = 6
		numberFormatter.roundingMode = .down
		
		for _ in 0...100 {
			
			let r1 = Int.random(in: -922_337...922_337)
			let r2 = Int.random(in: -922_337...922_337)
			
			let x1 = FDec(r1)
			let x2 = FDec(r2)
			
			let y1 = Decimal(r1)
			let y2 = Decimal(r2)
			
			XCTAssertEqual( (x1 + x2).string, (y1 + y2).description)
			XCTAssertEqual( (x1 - x2).string, (y1 - y2).description)
			XCTAssertEqual( (x1 * x2).string, (y1 * y2).description)
			XCTAssertEqual( (x1 / x2).string, String(numberFormatter.string(from: (y1 / y2) as NSNumber)!.dropLast(2) ))
		}
		
	}
	
}

final class Test_FixDecimal_Init: XCTestCase {
	
	func test_init_integer() throws {

		let int0 = 0
		XCTAssertEqual(FDec(0), 0)
		XCTAssertEqual(FDec(0), "0")
		XCTAssertEqual(FDec(int0), 0)
		XCTAssertEqual(FDec(int0), "0")
		XCTAssertEqual(FDec(integerLiteral: int0), 0)
		XCTAssertEqual(FDec(integerLiteral: int0), "0")

		let int0minus = -0
		XCTAssertEqual(FDec(-0), 0)
		XCTAssertEqual(FDec(-0), "0")
		XCTAssertEqual(FDec(int0minus), 0)
		XCTAssertEqual(FDec(int0minus), "0")
		XCTAssertEqual(FDec(integerLiteral: int0), 0)
		XCTAssertEqual(FDec(integerLiteral: int0), "0")
		
		let int123 = 12345
		XCTAssertEqual(FDec(12345),   12345 )
		XCTAssertEqual(FDec(12345),  "12345")
		XCTAssertEqual(FDec(int123),  12345 )
		XCTAssertEqual(FDec(int123), "12345")
		XCTAssertEqual(FDec(integerLiteral: int123),  12345 )
		XCTAssertEqual(FDec(integerLiteral: int123), "12345")

		let int123minus = -12345
		XCTAssertEqual(FDec(-12345), -12345  )
		XCTAssertEqual(FDec(-12345), "-12345")
		XCTAssertEqual(FDec(int123minus),  -12345 )
		XCTAssertEqual(FDec(int123minus), "-12345")
		XCTAssertEqual(FDec(integerLiteral: int123minus),  -12345 )
		XCTAssertEqual(FDec(integerLiteral: int123minus), "-12345")

		

		XCTAssertEqual(FDec(1_000), "1000")
		XCTAssertEqual(FDec(1000_000), "1000000")
		XCTAssertEqual(FDec(922_337_203_685_475), "922337203685475")

		XCTAssertEqual(FDec(1_000), 1000)
		XCTAssertEqual(FDec(1000_000), 1000000)
		XCTAssertEqual(FDec(922_337_203_685_475), 922337203685475)
		
		
		XCTAssertEqual(FDec(UInt8.max),   255  )
		XCTAssertEqual(FDec(UInt8.max),  "255" )
		XCTAssertEqual(FDec(Int8.min),   -128  )
		XCTAssertEqual(FDec(Int8.min),  "-128" )
		
		XCTAssertEqual(FDec(UInt16.max),  65535  )
		XCTAssertEqual(FDec(UInt16.max), "65535" )
		XCTAssertEqual(FDec(Int16.min),  -32768  )
		XCTAssertEqual(FDec(Int16.min), "-32768" )
		
		XCTAssertEqual(FDec(UInt32.max),  4294967295  )
		XCTAssertEqual(FDec(UInt32.max), "4294967295" )
		XCTAssertEqual(FDec(Int32.min),  -2147483648  )
		XCTAssertEqual(FDec(Int32.min), "-2147483648" )
	
		
	}
	
	func test_init_exp() throws {

		XCTAssertEqual(FDec(98765, dec: 10),   98765 )
	}
	
	func test_init_string() throws {
		
		XCTAssertEqual(FDec(0),   0 )
		XCTAssertEqual(FDec(0),  "0")
		XCTAssertEqual(FDec(-0),  0 )
		XCTAssertEqual(FDec(-0), "0")


		XCTAssertEqual(FDec("1235"),    1235 )
		XCTAssertEqual(FDec("-1235"),  -1235 )
		XCTAssertEqual(FDec("1235"),   "1235")
		XCTAssertEqual(FDec("-1235"), "-1235")

		XCTAssertEqual(FDec("1_000"),  1000 )
		XCTAssertEqual(FDec("1_000"), "1000")
		XCTAssertEqual(FDec("1000_000"),  1000000 )
		XCTAssertEqual(FDec("1000_000"), "1000000")

		XCTAssertEqual(FDec("92233720368547758"), "92233720368547758")


		XCTAssertEqual(FDec("0.1"),   "0.1")
		XCTAssertEqual(FDec("-0.1"), "-0.1")
		
		XCTAssertEqual(FDec("-0.001"), "-0.001")
		XCTAssertEqual((FDec("-0.001")), -0.001 )
		
		XCTAssertEqual(FDec("-0.001"), "-0.001")
		XCTAssertEqual((FDec("-0.001").double), -0.001 )
		
		XCTAssertEqual(FDec("12345.6789"),   "12345.6789")
		XCTAssertEqual(FDec("-12345.6789"), "-12345.6789")
		XCTAssertEqual(FDec("12345.6789").double,   12345.6789)
		XCTAssertEqual(FDec("-12345.6789").double, -12345.6789)
		
		
		
		XCTAssertEqual(FDec("-0.9223372036854775808"),    "-0.9223372036854775808")
		XCTAssertEqual(FDec("-0.9223372036854775808111"), "-0.9223372036854775808") // Clamping
		
		
	}
	
	
	func test_init_double() throws {
		
		
//		_ = FDec(1)
//		_ = FDec(10)
//		_ = FDec(0.1)
//		_ = FDec(10.1)
//		_ = FDec(11.222)
//		_ = FDec(12345.33333)
//		_ = FDec(123456789012345.123456789)
//		_ = FDec(1234567890123451231233123121212313.123456789)
		
		
		XCTAssertEqual(FDec(0.1),   "0.1")
		
		XCTAssertEqual(FDec(-0.1), "-0.1")
		XCTAssertEqual(FDec(0.1),    0.1 )
		XCTAssertEqual(FDec(-0.1),  -0.1 )

		XCTAssertEqual(FDec(32.12),   "32.12")
		XCTAssertEqual(FDec(-32.12), "-32.12")
		XCTAssertEqual(FDec(32.12),    32.12 )
		XCTAssertEqual(FDec(-32.12),  -32.12 )

		XCTAssertEqual(FDec("-0.001"), "-0.001")
		XCTAssertEqual((FDec("-0.001").double), -0.001 )

		XCTAssertEqual(FDec("-0.001"), "-0.001")
		XCTAssertEqual((FDec("-0.001").double), -0.001 )

		XCTAssertEqual(FDec("12345.6789"),   "12345.6789")
		XCTAssertEqual(FDec("-12345.6789"), "-12345.6789")
		XCTAssertEqual(FDec("12345.6789").double,   12345.6789)
		XCTAssertEqual(FDec("-12345.6789").double, -12345.6789)
		
		
		
	}
	
}


