import XCTest
@testable import FDec

typealias T = FDec


final class Test_Common: XCTestCase {
	
	func test_Init_Int() throws {
		
		
		XCTAssertEqual( T(integerLiteral: 0), 0)
		XCTAssertEqual( T(integerLiteral: 12345), 12345)
		XCTAssertEqual( T(integerLiteral: -12345), -12345)
		
		
		XCTAssertEqual( T(UInt8.max),   255 )
		XCTAssertEqual( T(UInt8.min),     0 )
		XCTAssertEqual( T(Int8.max),    127 )
		XCTAssertEqual( T(Int8.min),   -128 )
		
		XCTAssertEqual( T(UInt16.max),  65535 )
		XCTAssertEqual( T(UInt16.min),      0 )
		XCTAssertEqual( T(Int16.max),   32767 )
		XCTAssertEqual( T(Int16.min),  -32768 )
		
		XCTAssertEqual( T(Int32.max),   2147483647 )
		XCTAssertEqual( T(Int32.min),  -2147483648 )
		
		let intMin = UInt.min
		XCTAssertEqual( T(intMin),  0 )
		
		print(Int.max)
		print(Int.min)
		print(UInt.min)
		print(UInt.min)
		
		let int = 100_000_000_000_000
		XCTAssertEqual( T(int)!.asInt,  int )
		
		let intBig = 900_000_000_000_000_000
		XCTAssertNil( T(intBig) )
		
		
	}
	
	
	func test_Init_Double() throws {

		XCTAssertEqual( T(0), 0.0)
		XCTAssertEqual( T(1), 1.0)
		XCTAssertEqual( T(10), 10.0)
		
		XCTAssertEqual( T(1.0), 1.0)
		XCTAssertEqual( T(0.1), 0.1)
		XCTAssertEqual( T(10.1), 10.1)
		XCTAssertEqual( T(11.222), 11.222)
		XCTAssertEqual( T(12345.3333), 12345.3333)
		
		XCTAssertEqual( T(12345.3333).asDouble, 12345.3333)
		
		let double = 1234567890.1234
		XCTAssertEqual( T(double)!.asDouble, 1234567890.1234)
		
		let long = 1234567890.1234567
		XCTAssertNil( T(long) )
		
		XCTAssertEqual( T(truncating: long), 1234567890.1234)
		
	}
	
	
	func test_Init_String() throws {
		
		XCTAssertEqual( T("0"),  "0")
		XCTAssertEqual( T("-0"), "0")
		
		XCTAssertFalse( T("0").isNegative)
		XCTAssertFalse( T("-0").isNegative)
		XCTAssertTrue(  T("-1").isNegative)
		
		XCTAssertEqual( T("1235"),   "1235")
		XCTAssertEqual( T("-1235"), "-1235")
		
		XCTAssertEqual( T("1_000"), "1000")
		XCTAssertEqual( T("1000_000"), "1000000")
		XCTAssertEqual( T("1_000_000"), "1000000")
		
		XCTAssertEqual( T("0.1"), "0.1")
		XCTAssertEqual( T("-0.1"), "-0.1")
		XCTAssertEqual( T("-0.001"), "-0.001")
		XCTAssertEqual( T("12345.6789"),   "12345.6789")
		XCTAssertEqual( T("-12345.6789"), "-12345.6789")
		
		let strFail = "habakuk"
		XCTAssertNil( T(strFail) )
		
		let short = "123456789.0123"
		XCTAssertEqual( T(short)!.description, short )
		
		let long = "1234567890123456789.01234"
		XCTAssertNil( T(long) )
		
		let strUnderscore = "123_456_789"
		XCTAssertNil( T(strUnderscore)?.description, "123456789")
		XCTAssertEqual( T(stringLiteral: strUnderscore).description, "123456789")
		XCTAssertEqual( T("123456789").asInt, 123456789)
		
		let strUnderscoreAndFrc = "123_456_789.123"
		XCTAssertEqual( T(stringLiteral: strUnderscoreAndFrc).description, "123456789.123")
		
		XCTAssertEqual( T(int: "12345", sign: "-"), -12345 )
		XCTAssertEqual( T(int: "12345", frc: "678", sign: "-"), "-12345.678" )
		
	}
	
	
	func test_Init_Self()  throws {

		FDec.fractNum = 3
		let a = T("111.001")

		FDec.fractNum = 4
		let b = T("222.1234")
		
		let c = T("111.001")

		XCTAssertNotEqual( a, b )
		XCTAssertNotEqual( a, c )
		
	}
	
	
	func test_Output_String() throws {
		
		XCTAssertEqual( T(0), "0")
		XCTAssertEqual( T(0).description, "0")
		
		XCTAssertEqual( T(1), "1")
		XCTAssertEqual( T(1).description, "1")
		
		XCTAssertEqual( T(1_000), "1000")
		XCTAssertEqual( T(1_000).description, "1000")
		
		XCTAssertEqual( T(1_000_000), "1000000")
		
	}
	
	
	func test_Output_Formatted() throws {
		
		XCTAssertEqual( T(0).formatted(), "0")
		XCTAssertEqual( T(1_000).formatted(), "1 000")
		XCTAssertEqual( T(1_000_000).formatted(), "1 000 000")
		
		XCTAssertEqual( T("1_000.1").formatted(),   "1 000.1")
		XCTAssertEqual( T("1_000.001").formatted(), "1 000.001")
		XCTAssertEqual( T("1_000.0001").formatted(), "1 000.0001")
		
	}
	
	
	func test_Casting_Int() throws {
		
		XCTAssertEqual( T("0").asInt,   0 )
		XCTAssertEqual( T("1").asInt,   1 )
		XCTAssertEqual( T("1111").asInt,   1111 )
		XCTAssertEqual( T("-0.001").asInt, 0 )
		XCTAssertEqual( T("12345.6789").asInt,   12345)
		XCTAssertEqual( T("-12345.6789").asInt, -12345)
		
		
	}
	
	
	func test_Casting_Double() throws {
		
		XCTAssertEqual( T("0").asDouble,   0.0 )
		XCTAssertEqual( T("1").asDouble,   1.0 )
		XCTAssertEqual( T("0.001").asDouble,   0.001 )
		XCTAssertEqual( T("-0.001").asDouble, -0.001 )
		XCTAssertEqual( T("12345.6789").asDouble,   12345.6789)
		XCTAssertEqual( T("-12345.6789").asDouble, -12345.6789)
		
	}
	
}


final class Test_Aritmetic: XCTestCase {

	func test_Negate() throws {

		let a = T(1)
		let b = T(2)

		XCTAssertEqual( a + b,  3)
		XCTAssertEqual( a + (-b),  -1)
	}
	
	
	func test_Integer_Add_Sub() throws {
		
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

	
	func test_Integer_Mul_Div() throws {
		
		XCTAssertEqual( T(0) * T(1), 0)
		XCTAssertEqual( T(3) * T(1), 3)
		
		XCTAssertEqual( T(3) * T(3), 9)
		XCTAssertEqual( T(3) * T(-3), -9)
		
		XCTAssertEqual( T(0) / T(1), 0)
		
		XCTAssertEqual( T(9) / T(3), 3)
		XCTAssertEqual( T(9) / T(-3), -3)
		
	}
	
	
	func test_Fraction_Add() throws {

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

	
	func test_Fraction_Sub() throws {

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


	func test_Fraction_Mul() throws {
		
		XCTAssertEqual( T(1.5) * T(2), 3)
		XCTAssertEqual( T(1.5) * T(1.5), 2.25)
		XCTAssertEqual( T(10) * T(0.5), 5)
		XCTAssertEqual( T(0.1) * T(10), 1)
		XCTAssertEqual( T(0.0001) * T(10000), 1)
		
	}
	
	
	func test_Fraction_Div() throws {
		
		XCTAssertEqual( T(3) / T(2), 1.5)
		XCTAssertEqual( T(4) / T(3), 1.3333)
		
		XCTAssertEqual( T(3) / T(1.5), 2)
		XCTAssertEqual( T(2.5) / T(1.5), 1.6666)
		
		XCTAssertEqual( T(2.5) / T(1.1), 2.2727)
		XCTAssertEqual( T(10) / T(0.5), 20)
		
	}
	
	
	func test_Fraction_Mod() throws {
		
		XCTAssertEqual( T(4) % T(3), 1)
		XCTAssertEqual( T(8) % T(2), 0)
		
	}
	
	
	func test_Sequence() throws {

		// (-1.1) + (-2.2) - (-4.4) * (-3.1) / (-1.1) - (9.1)

		var a: T
		
		a = T(0)
		a += T(-1.1)
		a += T(-2.2)
		a -= T(-4.4) * T(-3.1) / T(-1.1)
		a -= T(9.1)
		XCTAssertEqual( a, 0)
		
	}
	
	
	func test_Random() throws {
	
		for _ in 0...1000 {
			
		let rA = Int16.random(in: 0...Int16.max)
		let rB = Int16.random(in: 0...Int16.max)
		let rX = Int16.random(in: 0...9999)
		let rY = Int16.random(in: 0...9999)
		
		let floatA = String(rA) + "." + String(rX)
		let floatB = String(rB) + "." + String(rY)
		
		let sdecA = Decimal(string: floatA)!
		let sdecB = Decimal(string: floatB)!
		
		let fdecA = FDec(stringLiteral: floatA)
		let fdecB = FDec(stringLiteral: floatB)
		
		XCTAssertEqual( (fdecA + fdecB).description, (sdecA + sdecB).description )
		XCTAssertEqual( (fdecA - fdecB).description, (sdecA - sdecB).description )
		
		let mul = (fdecA * fdecB).description
		XCTAssertEqual( mul, String((sdecA * sdecB).description.prefix(mul.count) ))

		let div = (fdecA / fdecB).description
		XCTAssertEqual( div, String((sdecA / sdecB).description.prefix(div.count) ))
		
		}
	}

	
	func test_Sqrt() throws {
	
		let base = [9.0, 13.0, 21.0, 44.0, 123.0, 255.0, 12.25]
		
		for i in 1..<base.count {
			
			T.fractNum = i
			
			let f = T(base[i])!
			let d = Double(base[i])
			
			let sqrtf = sqrt(f).description
			let sqrtd = sqrt(d).description
			
			print(i, base[i], ":", f, d, sqrtf, sqrtd)
			
			XCTAssertEqual( sqrtf, String(sqrtd.prefix(sqrtf.count)) )
		}
	}
	
}




