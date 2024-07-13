import XCTest
@testable import FDec

typealias T = FDec


final class Test_Init: XCTestCase {
	
	func test_Init_Literal_Int() throws {
		
		XCTAssertEqual( T(0), 0)
		XCTAssertEqual( T(integerLiteral: 0), 0)
		
		XCTAssertEqual( T(12345),   12345 )
		XCTAssertEqual( T(integerLiteral: 12345), 12345)
		
		XCTAssertEqual( T(-12345),   -12345 )
		XCTAssertEqual( T(integerLiteral: -12345), -12345)

		XCTAssertEqual( T(1_000), 1000)
		XCTAssertEqual( T(integerLiteral: 1_000), 1000)

	}
	
	func test_Init_Literal_Float() throws {
		
		XCTAssertEqual( T(0.1),    0.1 )
		XCTAssertEqual( T(-0.1),  -0.1 )
		XCTAssertEqual( T(0.001),   0.001)
		XCTAssertEqual( T(-0.001), -0.001)
		
		XCTAssertEqual( T(32.12),    32.12 )
		XCTAssertEqual( T(-32.12),  -32.12 )
		
		XCTAssertEqual( T(12345.6789),   12345.6789 )
		XCTAssertEqual( T(-12345.6789), -12345.6789 )
		
	}
	
	func test_Init_Integer() throws {
		
		var int: Int
		
		int = 0
		XCTAssertEqual( T(int), 0)
		
		int = -0
		XCTAssertEqual( T(int), 0)
		
		int = 12345
		XCTAssertEqual( T(int),  12345 )
		
		int = -12345
		XCTAssertEqual( T(int), -12345 )
		
		XCTAssertEqual( T(UInt8.max),   255 )
		XCTAssertEqual( T(Int8.min),   -128 )
		
		XCTAssertEqual( T(UInt16.max),  65535 )
		XCTAssertEqual( T(Int16.min),  -32768 )
		
		XCTAssertEqual( T(UInt32.max),  4294967295 )
		XCTAssertEqual( T(Int32.min),  -2147483648 )
		
	}
	
	func test_Init_String() throws {
		
		XCTAssertEqual( T("0"),  "0")
		XCTAssertEqual( T("-0"), "0")
		XCTAssertEqual( T("-0").isNegative, false)
		XCTAssertEqual( T("-1").isNegative, true)
		
		XCTAssertEqual( T("1235"),   "1235")
		XCTAssertEqual( T("-1235"), "-1235")
		
		XCTAssertEqual( T("1_000"), "1000")
		XCTAssertEqual( T("1000_000"), "1000000")
		XCTAssertEqual( T("1_000_000"), "1000000")
		
		XCTAssertEqual( T("0.1"),   "0.1")
		XCTAssertEqual( T("-0.1"), "-0.1")
		XCTAssertEqual( T("-0.001"), "-0.001")
		XCTAssertEqual( T("12345.6789"),   "12345.6789")
		XCTAssertEqual( T("-12345.6789"), "-12345.6789")
		
	}
	
	func test_Init_Double() throws {
		
		XCTAssertEqual( T(Double(1)), 1.0)
		XCTAssertEqual( T(Double(1)), 1.0)
		XCTAssertEqual( T(Double(10)), 10.0)
		XCTAssertEqual( T(Double(0.1)), 0.1)
		XCTAssertEqual( T(Double(10.1)), 10.1)
		XCTAssertEqual( T(Double(11.222)), 11.222)
		XCTAssertEqual( T(Double(12345.33333)), 12345.33333)
	}
	
//	func test_Init_Self()  throws {
//
//		FDec.decimalsNum = 3
//
//		let a = T("111.001")
//
//		FDec.decimalsNum = 2
//
//		let c = T("222.01")
//
//		XCTAssertNotEqual( c, a ) // Not !
//	}
	
}



final class TestOutput: XCTestCase {
	
	func testOutput_String() throws {
		
		XCTAssertEqual( T(0), "0")
		XCTAssertEqual( T(0).description, "0")
		
		XCTAssertEqual( T(1), "1")
		XCTAssertEqual( T(1).description, "1")
		
		XCTAssertEqual( T(1_000), "1000")
		XCTAssertEqual( T(1_000).description, "1000")
		
		XCTAssertEqual( T(1_000_000), "1000000")
		
	}
	
	func testOutput_Formatted() throws {
		
		XCTAssertEqual( T(0).formatted(), "0")
		XCTAssertEqual( T(1_000).formatted(), "1 000")
		XCTAssertEqual( T(1_000_000).formatted(), "1 000 000")
		XCTAssertEqual( T(922_337_203_685_475).formatted(), "922 337 203 685 475")
		
		XCTAssertEqual( T("1_000.1").formatted(),   "1 000.1")
		XCTAssertEqual( T("1_000.001").formatted(), "1 000.001")
		XCTAssertEqual( T("1_000.0001").formatted(), "1 000.0001")
		
	}
	
	func testCasting_Double() throws {
		
		XCTAssertEqual( (T("0").asDouble),   0.0 )
		XCTAssertEqual( (T("1").asDouble),   1.0 )
		XCTAssertEqual( (T("0.001").asDouble),   0.001 )
		XCTAssertEqual( (T("-0.001").asDouble), -0.001 )
		XCTAssertEqual( T("12345.6789").asDouble,   12345.6789)
		XCTAssertEqual( T("-12345.6789").asDouble, -12345.6789)
	}
}



final class TestAritmetic: XCTestCase {
	
	func testBasic_INT_Add_Sub() throws{
		
		XCTAssertEqual( T(0) + T(0),  0)
		XCTAssertEqual( T(0) + T(1),  1)
		XCTAssertEqual( T(0) - T(0),  0)
		XCTAssertEqual( T(0) - T(1), -1)
		
		XCTAssertEqual( T(1) + T(1),  2)
		XCTAssertEqual( T(1) - T(1),  0)
		
		XCTAssertEqual( T(2) - T(1),  1)
		XCTAssertEqual( T(2) - T(3), -1)
		
		XCTAssertEqual( T(-3) + T(2), -1)
		XCTAssertEqual( T(-3) + T(3),  0)
		XCTAssertEqual( T(-3) + T(4),  1)
		
		XCTAssertEqual( T(-3) + T(-2), -5)
		XCTAssertEqual( T(-3) + T(-3), -6)
		XCTAssertEqual( T(-3) + T(-4), -7)
		
		XCTAssertEqual( T(-3) - T(2),  -5)
		XCTAssertEqual( T(-3) - T(3),  -6)
		XCTAssertEqual( T(-3) - T(4),  -7)
		
		XCTAssertEqual( T(-3) - T(-2), -1)
		XCTAssertEqual( T(-3) - T(-3),  0)
		XCTAssertEqual( T(-3) - T(-4),  1)
		
	}
	
	func testBasic_Negate() throws {
		
		let a = T(1)
		let b = T(2)
		
		XCTAssertEqual( a + b,  3)
		XCTAssertEqual( a + (-b),  -1)		
	}
	
	func testBasic_FRC_Add() throws {
		
		XCTAssertEqual( T(0) + T(0.0), "0")
		XCTAssertEqual( T(0) + T(0.1), "0.1")
		
		XCTAssertEqual( T(0.1) + T(0.1),  "0.2")
		XCTAssertEqual( T(0.1) + T(0.02), "0.12")
		XCTAssertEqual( T(0.1) + T(0.9),  "1")
		XCTAssertEqual( T(0.1) + T(0.91), "1.01")
		
		
		XCTAssertEqual( T(0.0001) + T(0.1), "0.1001")
		
		XCTAssertEqual( T(0.99) + T(0.01),  "1")
		XCTAssertEqual( T(0.99) + T(0.02),  "1.01")
	}
	
	func testBasic_FRC_Sub() throws {
		
		XCTAssertEqual( T(0) - T(0.0), "0")
		XCTAssertEqual( T(0) - T(0.1), "-0.1")
		
		XCTAssertEqual( T(0.1) + T(0.1),  "0.2")
		XCTAssertEqual( T(0.1) + T(0.02), "0.12")
		XCTAssertEqual( T(0.1) + T(0.9),  "1")
		XCTAssertEqual( T(0.1) + T(0.91), "1.01")
		
		
		XCTAssertEqual( T(0.01) - T(0.002),  "0.008")
		XCTAssertEqual( T(0.01) - T(0.002),  "0.008")
		XCTAssertEqual( T(0.1) - T(0.91),  "-0.81")
		XCTAssertEqual( T(0.01) - T(0.91),  "-0.9")
		
	}
	
	func testBasic_Rhs_INT() throws {
		
		var a = T(1)
		XCTAssertEqual( (a + 1), 2)
		XCTAssertEqual( (a + 99), 100)
		XCTAssertEqual( (a - 1), 0)
		XCTAssertEqual( (a - 2), -1)
		XCTAssertEqual( (a - 100), -99)
		
		a += 1
		XCTAssertEqual( a.description, "2")
		
		a -= 3
		XCTAssertEqual( a.description, "-1")
		
		a += 5
		XCTAssertEqual( a.description, "4")
		
		a += (-1)
		XCTAssertEqual( a.description, "3")
		
		
		
		let b = T(-1)
		XCTAssertEqual( (b + 1), 0)
		XCTAssertEqual( (b + 2), 1)
		XCTAssertEqual( (b - 1), -2)
		XCTAssertEqual( (b - (-2) ), 1)
		
	}
	
	func testBasic_Seq() throws {
		
		// (-1.1) + (-2.2) - (-4.4) * (-3.1) / (-1.1) - (9.1)

		var a = T(0)
		a += T(-1.1)
		a += T(-2.2)
		a -= T(-4.4) * T(-3.1) / T(-1.1)
		a -= T(9.1)
		
		XCTAssertEqual( a, 0)
		
	}
	
}



final class Test_Random: XCTestCase {
	
	func test_RandomNumGen() throws {
		for _ in 0...100 {
			let r = T.random(0...100000, 1000...9000)
			print( r, r?.digitCount )
		}
	}
	
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
			
			let x1 = T(r1)
			let x2 = T(r2)
			
			let y1 = Decimal(r1)
			let y2 = Decimal(r2)
			
			XCTAssertEqual( (x1 + x2).description, (y1 + y2).description)
			XCTAssertEqual( (x1 - x2).description, (y1 - y2).description)
			XCTAssertEqual( (x1 * x2).description, (y1 * y2).description)
			// XCTAssertEqual( (x1 / x2).asDouble.round().description , String(numberFormatter.string(from: (y1 / y2) as NSNumber)!.dropLast(2) ))
		}
		
	}
	
}


