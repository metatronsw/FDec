//
//   ____  ____   ____   ___
//  (  __)(    \ (  __) / __)
//   ) _)  ) D (  ) _) ( (__   Mtrn (C)
//  (__)  (____/ (____) \___)  2023.06.28.


import Foundation

public struct FDec: SignedNumeric, ExpressibleByFloatLiteral, ExpressibleByStringLiteral, Hashable, CustomStringConvertible, CustomDebugStringConvertible, Comparable, Codable {
	
	public typealias IntegerLiteralType = Int
	public typealias StringLiteralType = String
	public typealias FloatLiteralType = Double
	
	
	/// Helper numbers, for quick internal operations
	///
	private static let half: Int =             1_000_000_000
	private static let high: Int =       100_000_000_000_000
	private static let full: Int = 1_000_000_000_000_000_000
										 // 9_223_372_036_854_775_807
	
	
	/// Static variable that defines the maximum decimal numbers at the Structural level.
	///
	public static var decimalsNum: Int = 3
	
	///The value actually stored.
	///
	private(set) var value: Int
	
	/// Internal value set at initialisation, helps fast operations, not saved at serialisation.
	///
	private(set) var pow: Int
	
	
	
	// MARK: Init
	
	public init() {
		self.value = 0
		self.pow = Self.decimalsNum.raise
	}
	
	
	public init?(_ F: FDec) { // TODO: megoldani hogy közös nevezőre hozza őket ...
		guard F.pow == Self.decimalsNum.raise else { return nil }
		self.value = F.value
		self.pow = F.pow
	}
	
	
	public init?(integer: String, fraction: String? = nil, dec: Int = Self.decimalsNum) {
		
		self.pow = dec.raise
		let dp = String(self.pow).count - 1
		
		if var fraction {
			while fraction.count != dp { fraction.append("0") }
			
			if let raw = Int(integer + fraction) {
				self.value = raw
				return
			}
			
		} else {
			
			if let int = Int(integer) {
				self.value = int * self.pow
				return
			}
		}
		
		return nil
	}
	
	
	
	/// Quick initialization with an integer number already prepared. Be careful, there is no limit to the value of decimals, above 15 it will be unusable...
	public init(raw: Int, decimals: Int = Self.decimalsNum) {
		self.value = raw
		self.pow = decimals.raise
	}
	
	
	public init(integerLiteral value: Int) {
		
		self.pow = Self.decimalsNum.raise
		
		let (num, over) = value.multipliedReportingOverflow(by: self.pow)
		self.value = num
		
		if over { Self.overFlow(String(num)) }
		
	}
	
	public init(_ value: Int) { self.init(integerLiteral: value) }
	public init(_ value: Int8) { self.init(integerLiteral: Int(value)) }
	public init(_ value: UInt8) { self.init(integerLiteral: Int(value)) }
	public init(_ value: Int16) { self.init(integerLiteral: Int(value)) }
	public init(_ value: UInt16) { self.init(integerLiteral: Int(value)) }
	public init(_ value: Int32) { self.init(integerLiteral: Int(value)) }
	public init(_ value: UInt32) { self.init(integerLiteral: Int(value)) }
	
	public init?<T>(exactly source: T) where T : BinaryInteger { self.init(integerLiteral: Int(source)) }
	
	
	
	public init(floatLiteral value: Double) {
		self.pow = Self.decimalsNum.raise
		if value > Double(Int.max / self.pow).magnitude { Self.overFlow(String(value)) }
		
		self.value = Int(value * Double(pow))
	}
	
	public init(_ value: Double) { self.init(floatLiteral: value) }
	
	public init(_ value: Float) { self.init(floatLiteral: Double(value)) }
	
	
	// TODO: Throw kell ide ...
	public init(stringLiteral value: String) {
		
		self.init()
		
		let parts = value.replacingOccurrences(of: "_", with: "").components(separatedBy: ".")
		let integer = parts.first!
		
		guard integer.count < 15 else { Self.overFlow(value) ; return }
		
		guard parts.count > 1 else {
			guard let int = Int(integer) else { Self.overFlow("Int cast failed from: \(value) › \(integer)") ; return }
			self.init(integerLiteral: int)
			return
		}
		
		let fraction = parts[1].prefix(Self.decimalsNum)
		
		let whole = String(integer + fraction) + String(repeating: "0", count: Self.decimalsNum - fraction.count )
		
		guard let raw = Int(whole) else { Self.overFlow("Fraction Int cast failed from: \(value) › \(whole)") ; return }
		
		self.init(raw: raw)
		
	}
	
	public init?(string value: String) { self.init(stringLiteral: value) }
	
	public init?(_ value: String) { self.init(stringLiteral: value) }
	
	
	
	
	
	
	// MARK: Encode-Decode
	
	/// Saving the private 'pow' variable is unnecessary, it must be added directly when decoding
	public func encode(to encoder: Encoder) throws {
		
		var container = encoder.singleValueContainer()
		try container.encode(value)
	}
	
	
	/// For correct decoding of the private pow variable, check the value of the Structure static 'decimalsNum'
	public init(from decoder: Decoder) throws {
		
		let value = try decoder.singleValueContainer()
		self.value = try value.decode(Int.self)
		self.pow = Self.decimalsNum.raise
	}
	
	
	
	
	
	// MARK: Computed values
	
	public var description: String {
		guard value != 0 else { return "0" }
		
		let dp = decimalPlaces
		guard isDecimal else { return String(String(value).dropLast(dp)) }
		
		var string: String
		var whole = String(value.magnitude)
		
		if whole.count <= dp { string = sign + "0." + String(repeating: "0", count: dp-whole.count) + whole }
		else {
			whole.insert(".", at: whole.index(whole.endIndex, offsetBy: -dp) )
			string = sign + whole
		}
		
		string.dropLastZeros()
		
		return string
	}
	
	public var debugDescription: String {
		"\(description) ➞ \(value) * 10^\(decimalPlaces) ➞ \(asInt) & \(fraction)"
	}
	
	public var sign: String { (value < 0) ? "-" : "" }
	
	public var signFull: String { (value < 0) ? "-" : "+" }
	
	public var magnitude: FDec {
		var mag = self
		mag.value = Int(self.value.magnitude)
		return mag
	}
	
	public var decimalPlaces: Int { String(self.pow).count - 1 }
	
	public var asInt: Int { value / pow }
	
	public var asDouble: Double { Double(value) / Double(pow) }
	
	public var fraction: Double { Double(value % pow) / Double(pow) }
	
	public func formatted() -> String { getFormated(showSign: false) }
	
	public var digitCount: Int { Int(log10(Double(self.asInt))) + 1 }
	
	
	
	
	// MARK: Questions
	
	public static var isSigned: Bool { true }
	
	public var isPositive : Bool { self.value > 0 }
	public var isNegative : Bool { self.value < 0 }
	public var isZero     : Bool { self.value == 0 }
	public var isOdd      : Bool { self.value & 1 == 1 }
	public var isEven     : Bool { self.value & 1 == 0 }
	public var isDecimal  : Bool { return (value % pow) != 0 }
	
	
	
	
	
	// MARK: Arithmetic
	
	public mutating func negate() { self.value *= -1 }
	
	public static func + (lhs: FDec, rhs: FDec) -> FDec {
		
		let (value, overflow) = lhs.value.addingReportingOverflow(rhs.value)
		
		if overflow { overFlow(String(value)) }
		
		return FDec(raw: value)
	}
	
	public static func + (lhs: FDec, rhs: Int) -> FDec  { lhs + FDec(rhs) }
	public static func + (lhs: Int, rhs: FDec) -> FDec  { FDec(lhs) + rhs }
	public static func += (lhs: inout FDec, rhs: FDec)  { lhs = lhs + rhs }
	public static func += (lhs: inout FDec, rhs: Int)   { lhs = lhs + FDec(rhs) }
	
	public static func - (lhs: FDec, rhs: FDec) -> FDec { lhs + (-rhs) }
	public static func - (lhs: FDec, rhs: Int) -> FDec  { lhs + FDec(-rhs) }
	public static func - (lhs: Int, rhs: FDec) -> FDec  { FDec(lhs) + (-rhs) }
	public static func -= (lhs: inout FDec, rhs: FDec)  { lhs = lhs + (-rhs) }
	public static func -= (lhs: inout FDec, rhs: Int)   { lhs = lhs + FDec(-rhs) }
	
	
	
	
	//	* Multiplication
	
	public static func * (lhs: FDec, rhs: FDec) -> FDec {
		
		let (high, low) = mulSplit(lhs.value, rhs.value)
		let (top, overflow) = high.multipliedReportingOverflow(by: Self.high)
		
		if overflow { overFlow("\(lhs.value) * \(rhs.value) › \(high)|\(low)") }
		
		return FDec(raw: top + (low / lhs.pow) )
		
	}
	
	public static func *= (lhs: inout FDec, rhs: FDec) { lhs = lhs * rhs }
	public static func *= (lhs: inout FDec, rhs: Int)  { lhs = lhs * FDec(rhs) }
	
	
	//  / Divison
	
	public static func / (lhs: FDec, rhs: FDec) -> FDec {
		
		return FDec(raw: (lhs.value * lhs.pow) / (rhs.value) )
	}
	
	public static func /= (lhs: inout FDec, rhs: FDec) { lhs = lhs / rhs }
	public static func /= (lhs: inout FDec, rhs: Int)  { lhs = lhs / FDec(rhs) }
	
	
	
	
	public static func % (lhs: FDec, rhs: FDec) -> FDec {
		
		return FDec(raw: (lhs.value * lhs.pow) % (rhs.value) )
	}
	
	public func quotientAndRemainder(dividingBy rhs: FDec) -> (quotient: FDec, remainder: FDec) {
		
		let (quotient, remainder) = self.value.quotientAndRemainder(dividingBy: rhs.value)
		
		return ( FDec(raw: quotient), FDec(raw: remainder) )
	}
	
	
	
	
	// MARK: Compare
	
	public static func < (lhs: FDec, rhs: FDec) -> Bool {
		
		guard lhs.pow == rhs.pow  else { return false }
		return lhs.value < rhs.value
	}
	
	public static func == (lhs: FDec, rhs: FDec) -> Bool {
		
		guard lhs.pow == rhs.pow  else { return false }
		return lhs.value == rhs.value
	}
	
	public static func > (lhs: FDec, rhs: FDec) -> Bool { !(lhs < rhs) }
	
	public static func != (lhs: FDec, rhs: FDec) -> Bool { !(lhs == rhs) }
	
	
	
	
	
	// MARK: Internal Functions
	
	
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
	
	
	private static func overFlow(_ str: String? = nil, sender: String = #function ) {
		fatalError("Overflow: \(str ?? "") #\(str?.count ?? 0)  from \(sender)")
	}
	
	
	
	
	// MARK: Public Functions
	
	public static func random(_ rangeInt: ClosedRange<Int>, _ rangeFraction: ClosedRange<Int>? = nil, decimals: Int = Self.decimalsNum) -> FDec? {
		
		let rnd = Int.random(in: rangeInt)
		let (int, overInt) = rnd.multipliedReportingOverflow(by: decimals.raise)
		if overInt { return nil }

		let dec = rangeFraction == nil ? 0 : Int.random(in: rangeFraction!)
		let raw = int + dec
		
		return FDec(raw: raw)
	}
	
	
	public func abs(_ x: FDec) -> FDec { FDec(raw: Int(x.value.magnitude) ) }
	
	
	public func hash(into hasher: inout Hasher) { hasher.combine("\(self.value)\(self.pow)") }
	

	public func min(_ x: FDec, _ y: FDec ) -> FDec { (x < y) ? x: y }


	public func max(_ x: FDec, _ y: FDec ) -> FDec { (x > y) ? x: y }

	
	
	public func getFormated(showSign: Bool = true, groupingSize: Int = 3, decimalSeparator: String? = nil, groupingSeparator: String? = nil) -> String {
		
		guard value != 0 else { return "0" }
		
		let decimalSep = decimalSeparator ?? (Locale.current.decimalSeparator ?? ".")
		let groupingSep = groupingSeparator ?? (Locale.current.groupingSeparator ?? " ")
		
		let whole = String(value.magnitude)
		let signstr = showSign ? signFull : sign
		
		let dp = decimalPlaces
		
		guard whole.count > dp else {
			var frc = signstr + "0" + decimalSep + String(repeating: "0", count: dp-whole.count) + whole
			while frc.hasSuffix("0") { frc.removeLast() }
			return frc
		}
		
		
		let int = String(whole.dropLast(dp))
		var frc = String(whole.suffix(dp))
		
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
		
		if frc == "0000" { return string }
		frc.dropLastZeros()
		
		return string + decimalSep + frc
		
		
	}
	
	
}


extension String {
	
	internal mutating func dropLastZeros()  {
		while self.hasSuffix("0") { self.removeLast() }
	}
}


extension Int {
	
	internal var raise: Int {
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
			case 18: return 100000000000000000
			case 19: return 1000000000000000000
			default: return 1
		}
	}
	
}
