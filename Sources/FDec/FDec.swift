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


/// A fixed decimal number format for Swift.
///
public struct FDec {
	
	public typealias FBase = Int
	
	/// The value actually shifted & stored inernaly
	private(set) var value: FBase
	
	/// Shifted & stored internal value { get }
	public var rawValue: FBase { self.value }

	
	/// Static structure variables to shift the integer
	public static var fractNum: FBase = 4 {
		didSet {
			pow = fractNum.pow10()
			zeroShift = String(repeating: "0", count: Self.fractNum)
			intMaxDecimals = 19 - fractNum
		}
	}
	public static var pow = fractNum.pow10()
	public static var zeroShift = String(repeating: "0", count: Self.fractNum)
	public static var intMaxDecimals = 19 - fractNum
	
	
	/// Helper numbers, for quick internal operations
	private static let half: FBase =             1_000_000_000
	private static let high: FBase =       100_000_000_000_000
	private static let full: FBase = 1_000_000_000_000_000_000
	
	
	public static let zero = FDec()
	public static let infinity = FDec(raw: FBase.max)
	
	
	private mutating func overflow() {
		self.value = FBase.max
	}
	
	
	
	// MARK: Init
	
	/// Default Zero init
	public init() { self.value = 0 }
	
	/// Init from Self.
	public init(_ F: FDec) { self.value = F.value }
	
	/// Init from shifted raw value.
	public init(raw: FBase) { self.value = raw }
	
	
	
	// MARK: Questions

	public var isPositive : Bool { self.value > 0 }
	public var isNegative : Bool { self.value < 0 }
	public var isZero     : Bool { self.value == 0 }
	public var isOdd      : Bool { self.value & 1 == 1 }
	public var isEven     : Bool { self.value & 1 == 0 }
	public var isDecimal  : Bool { self.value % Self.pow != 0 }
	public var isInfinity : Bool { self.value == FBase.max }
	
}




extension FDec: ExpressibleByIntegerLiteral {
	
	public typealias IntegerLiteralType = Int32
	
	
	public init(integerLiteral value: Int32) {
		
		let raw = Int(value) * Self.pow
		self.value = raw
	}

	
	public init?<T>(exactly source: T) where T : BinaryInteger {
		
		let (raw, over) = Int(source).multipliedReportingOverflow(by: Self.pow)
		
//		if over || raw > Self.full { return nil }
		if over { return nil }
		
		self.value = raw
	}
	
	
	
	public init(_ value: Int8) { self.init(integerLiteral: Int32(value)) }
	public init(_ value: UInt8) { self.init(integerLiteral: Int32(value)) }
	
	public init(_ value: Int16) { self.init(integerLiteral: Int32(value)) }
	public init(_ value: UInt16) { self.init(integerLiteral: Int32(value)) }
	
	public init(_ value: Int32) { self.init(integerLiteral: value) }
	public init(_ value: UInt32) { self.init(integerLiteral: Int32(value)) }
	
	
	public init?(_ value: Int) { self.init(exactly: value) }
	public init?(_ value: UInt) { self.init(exactly: value) }
	
	public init?(_ value: Int64) { self.init(exactly: value) }
	public init?(_ value: UInt64) { self.init(exactly: value) }
	
	
	
	// MARK: Computed variables
	
	public var asInt: Int { value / Self.pow }
	
	public var digitCount: Int { Int(log10(Double(self.asInt))) + 1 }
	
}



extension FDec: ExpressibleByFloatLiteral {
	
	public typealias FloatLiteralType = Double
	
	
	public init?(_ value: Double) {
		
		guard value <= Double(Int.max / Self.pow).magnitude else { return nil }
		let shifted = value * Double(Self.pow)
		guard let raw = Int(exactly: shifted) else { print("Failed exactly init! \(shifted)") ; return nil }
		self.value = raw
	}
	
	
	public init(truncating value: Double) {
		
		let shifted = value * Double(Self.pow)
		let truncated = Int(shifted)
		
		self.value = truncated
	}
	
	
	public init(floatLiteral value: Double) {
		
		guard let inited = Self.init(value) else { fatalError("Failed floatLiteral init! \(value)") }
		
		self.value = inited.value
	}
	
	
	public init?(_ value: Float) { self.init( Double(value)) }
	public init?(_ value: Float80) { self.init( Double(value)) }
	
	
	
	// MARK: Output
	
	public var asDouble: Double { Double(value) / Double(Self.pow) }
	
	public var fraction: Double { Double(value % Self.pow) / Double(Self.pow) }
	
	
}



extension FDec: ExpressibleByStringLiteral, LosslessStringConvertible, CustomDebugStringConvertible {
	
	public typealias StringLiteralType = String
	
	
	public init(stringLiteral: String) {
		
		let clean = stringLiteral
			.replacingOccurrences(of: "_", with: "")
			.replacingOccurrences(of: " ", with: "")
		
		guard let inited = Self.init(clean) else { fatalError("Failed stringLiteral init! \(stringLiteral)") }
		
		self.value = inited.value
	}
		
	
	
	public init?(_ description: String) {
		 
		let parts = description.components(separatedBy: ".")
		
		guard let int = parts.first else { print("Wrong description! \(description)") ; return nil }

		var frc: String
		
		if parts.count > 1 {
			frc = String(parts[1].prefix(Self.fractNum))
			if frc.count < Self.fractNum {
				frc = frc + String(repeating: "0", count: Self.fractNum - frc.count)
			}
		}
		else {
			frc = Self.zeroShift
		}
		
//		print(":", int,frc)
		guard let raw = Int(int + frc) else { print("Overflow! \(int).\(frc)") ; return nil }
		
		self.value = raw
	}
	
	
	
	public init?(int: String, frc: String = Self.zeroShift, sign: String = "") {
		
		var frc = frc
		
		if frc.count > Self.fractNum { frc = String(frc.suffix(Self.fractNum)) }
		while frc.count < Self.fractNum { frc.append("0") }
		
		guard let raw = Int(sign + int + frc) else { print("Overflow! \(int).\(frc)") ; return nil }
		self.value = raw
	}
	
	
	
	// MARK: Output
	
	public var description: String {
		
		guard !isZero else { return "0" }
		guard !isInfinity else { return "Infinity" }
		
		guard isDecimal else { return String(String(value).dropLast(Self.fractNum)) }
		
		var string: String
		var whole = String(value.magnitude)
		
		if whole.count <= Self.fractNum {
			string = self.sign + "0." + String(repeating: "0", count: Self.fractNum - whole.count) + whole
		}
		else {
			whole.insert(".", at: whole.index(whole.endIndex, offsetBy: -Self.fractNum ) )
			string = self.sign + whole
		}
		
		string.dropLastZeros()
		
		return string
	}
	
	
	public var debugDescription: String {
		"\(description) ➞ \(value) * 10^\(Self.fractNum) ➞ \(asInt) & \(fraction)"
	}

	
	public func formatted(fullSign: Bool = false, groupingSize: Int = 3, decimalSeparator: String? = nil, groupingSeparator: String? = nil) -> String {
		
		guard !self.isZero else { return "0" }
		
		let decimalSep = decimalSeparator ?? (Locale.current.decimalSeparator ?? ".")
		let groupingSep = groupingSeparator ?? (Locale.current.groupingSeparator ?? " ")
		
		let whole = String(value.magnitude)
		let signstr = fullSign ? signFull : sign
		
		
		guard whole.count > Self.fractNum else {
			var frc = signstr + "0" + decimalSep + String(repeating: "0", count: Self.fractNum - whole.count) + whole
			while frc.hasSuffix("0") { frc.removeLast() }
			return frc
		}
		
		
		let int = String(whole.dropLast(Self.fractNum))
		var frc = String(whole.suffix(Self.fractNum))
		
		var gapPoint = int.count % groupingSize
		if groupingSize >= int.count { gapPoint = int.count + 2 }
		else if gapPoint == 0 { gapPoint = groupingSize }
		
		var index = 1
		var string = signstr
		
		for chr in int {
			if index > gapPoint {
				string.append("\(groupingSep)\(chr)")
				gapPoint += groupingSize - 1
				continue
			}
			
			string.append(chr)
			index += 1
		}
		
		frc.dropLastZeros()
		
		if frc.isEmpty { return string }
		return string + decimalSep + frc
	}
	
}




extension FDec: SignedNumeric {
	
	
	// MARK: Questions
	
	public var magnitude: FDec {
		var mag = self
		mag.value = Int(self.value.magnitude)
		return mag
	}
	
	public mutating func negate() { self.value *= -1 }
	
	public static var isSigned: Bool { true }
	
	public var sign: String { (value < 0) ? "-" : "" }
	
	public var signFull: String { (value < 0) ? "-" : "+" }
	
	
	
	// MARK: (+) Addition
	
	public static func + (lhs: FDec, rhs: FDec) -> FDec {
		
		let (value, over) = lhs.value.addingReportingOverflow(rhs.value)
		
		guard !over else { return .infinity }
		
		return FDec(raw: value)
	}
	
	public static func + (lhs: FDec, rhs: Int32) -> FDec { lhs + FDec(rhs) }
	public static func + (lhs: Int32, rhs: FDec) -> FDec { FDec(lhs) + rhs }
	public static func += (lhs: inout FDec, rhs: FDec) { lhs = lhs + rhs }
	public static func += (lhs: inout FDec, rhs: Int32) { lhs = lhs + FDec(rhs) }
	
	
	// MARK: (-) Subtraction
	
	public static func - (lhs: FDec, rhs: FDec) -> FDec { lhs + (-rhs) }
	
	public static func - (lhs: FDec, rhs: Int32) -> FDec { lhs + FDec(-rhs) }
	public static func - (lhs: Int32, rhs: FDec) -> FDec { FDec(lhs) + (-rhs) }
	public static func -= (lhs: inout FDec, rhs: FDec) { lhs = lhs + (-rhs) }
	public static func -= (lhs: inout FDec, rhs: Int32) { lhs = lhs + FDec(-rhs) }
	
	
	// MARK: (*) Multiplication
	
	public static func * (lhs: FDec, rhs: FDec) -> FDec {
		
		let (high, low) = mulSplit(lhs.value, rhs.value)
		let (top, over) = high.multipliedReportingOverflow(by: Self.high)
		
		guard !over else { return .infinity }
		
		return FDec(raw: top + (low / Self.pow) )
		
	}
	
	public static func *= (lhs: inout FDec, rhs: FDec) { lhs = lhs * rhs }
	public static func *= (lhs: inout FDec, rhs: Int32) { lhs = lhs * FDec(rhs) }
	
	
	// MARK: (/) Divison
	
	public static func / (lhs: FDec, rhs: FDec) -> FDec {
		
		let (raw, over) = lhs.value.multipliedReportingOverflow(by: Self.pow)
		
		guard !over else { return .infinity }
		
		return FDec(raw: raw / (rhs.value) )
	}
	
	public static func /= (lhs: inout FDec, rhs: FDec) { lhs = lhs / rhs }
	public static func /= (lhs: inout FDec, rhs: Int32) { lhs = lhs / FDec(rhs) }
	
	
	
	// MARK: (%) Modulus
	
	public static func % (lhs: FDec, rhs: FDec) -> FDec {
		
		let (raw, over) = lhs.value.multipliedReportingOverflow(by: Self.pow)
		
		guard !over else { return .infinity }
		
		return FDec(raw: raw % (rhs.value) )
	}
	
	
	
	
	// MARK: Internal functions
	
	public func quotientAndRemainder(dividingBy rhs: FDec) -> (quotient: FDec, remainder: FDec) {
		
		let (quotient, remainder) = self.value.quotientAndRemainder(dividingBy: rhs.value)
		
		return ( FDec(raw: quotient), FDec(raw: remainder) )
	}
	

	
	
	// MARK: Static functions
	
	internal static func mulSplit(_ lhs: Int, _ rhs: Int) -> (high: Int, low: Int) {
		
		
		let (lLo, lHi) = (lhs % Self.half, lhs / Self.half)
		let (rLo, rHi) = (rhs % Self.half, rhs / Self.half)
		
		let K = (lHi * rLo) + (rHi * lLo)
		
		var resHi = (lHi * rHi) + (K / Self.half)
		var resLo = (lLo * rLo) + ((K % Self.half) * Self.half)
		
		if resLo >= Self.full {
			resLo -= Self.full
			resHi += 1
		}
		
		return (resHi, resLo)
	}
	
	
	public static func random(_ rangeInt: ClosedRange<Int>, _ rangeFraction: ClosedRange<Int>? = nil, decimals: Int = Self.fractNum) -> FDec? {
		
		let rnd = Int.random(in: rangeInt)
		let (int, overInt) = rnd.multipliedReportingOverflow(by: decimals.pow10() )
		if overInt { return nil }
		
		let dec = rangeFraction == nil ? 0 : Int.random(in: rangeFraction!)
		let raw = int + dec
		
		return FDec(raw: raw)
	}
}



extension FDec: Hashable, Comparable {
	
	// MARK: Compare

	public static func == (lhs: FDec, rhs: FDec) -> Bool { lhs.value == rhs.value }
	
	public static func < (lhs: FDec, rhs: FDec) -> Bool { lhs.value < rhs.value }
	
	public static func > (lhs: FDec, rhs: FDec) -> Bool { !(lhs < rhs) }
	
	public static func != (lhs: FDec, rhs: FDec) -> Bool { !(lhs == rhs) }
	
	
	
	// MARK: Hashable
	
	public func hash(into hasher: inout Hasher) {
		hasher.combine(self.value)
	}
	
}



extension FDec: Codable {
	
	public func encode(to encoder: Encoder) throws {
		
		var container = encoder.singleValueContainer()
		try container.encode(value)
	}
	
	
	/// For correct decoding of the private pow variable, check the static value of the FDec structure: 'decimalsNum'
	public init(from decoder: Decoder) throws {
		
		let value = try decoder.singleValueContainer()
		self.value = try value.decode(Int.self)
	}
}




fileprivate extension Int {
	
	func pow10() -> Int {
	switch self {
		case 0:  return 1
		case 1:  return 10
		case 2:  return 100
		case 3:  return 1000
		case 4:  return 10000
		case 5:  return 100000
		case 6:  return 1000000
		case 7:  return 10000000
		case 8:  return 100000000
		case 9:  return 1000000000
		case 10: return 10000000000
		case 11: return 100000000000
		case 12: return 1000000000000
		case 13: return 10000000000000
		case 14: return 100000000000000
		case 15: return 1000000000000000
		case 16: return 10000000000000000
		case 17: return 100000000000000000
		case 18: return 1000000000000000000
		default: fatalError()
	}
}
	
}


fileprivate extension String {
	
	 mutating func dropLastZeros() {
		while self.hasSuffix("0") { self.removeLast() }
	}
	
}
