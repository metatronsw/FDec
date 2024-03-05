//
//   ____  ____   ____   ___
//  (  __)(    \ (  __) / __)
//   ) _)  ) D (  ) _) ( (__   Mtrn (C)
//  (__)  (____/ (____) \___)  2023.06.28.


import Foundation

public struct FDec: SignedNumeric, ExpressibleByFloatLiteral, ExpressibleByStringLiteral, Hashable, CustomStringConvertible, CustomDebugStringConvertible, Comparable, Codable {


	public typealias Base = Int

	public typealias StringLiteralType = String
	public typealias FloatLiteralType = Double
	
	static let half: Base =             1_000_000_000
	static let high: Base =       100_000_000_000_000
	static let full: Base = 1_000_000_000_000_000_000
	static let max:  Base =       922_337_203_685_475
	static let min:  Base =      -922_337_203_685_475

	public static let decimalPlaces: Base = 4  // Fontos ! ! ! Fölötte levágja
	public static let decimalMultipler: Base = 10_000
	

	public var value: Base
	public var over: String? = nil
	
	public var exp: Base = Self.decimalPlaces { didSet { self.pow = Self.raise(exp) } }
	
	private var pow: Base = Self.decimalMultipler
	
	
	public func encode(to encoder: Encoder) throws {

		var container = encoder.singleValueContainer()
		try container.encode(value)
	}


	public init(from decoder: Decoder) throws {

		let value = try decoder.singleValueContainer()

		self.init()
		self.value = try value.decode(Base.self)
	}
	
	
	
	
	static func raise(_ num: Base) -> Base {
		switch num {
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
	
	
	
	
	// MARK: Init
	
	public init() {
		self.value = 0
	}


	public init(raw: Base, dec: Int? = nil, over: String? = nil) {
		
		if let dec {
			self.exp = Base(dec)
			self.pow = Self.raise(exp)
		}
		
		self.value = raw
		self.over = over
	}
	

	public init<T>(_ source: T, dec: Int? = nil) where T : BinaryInteger {
		
		if let dec {
			self.exp = Base(dec)
			self.pow = Self.raise(exp)
		}
		
		let value = Base(source)
		let (num, overflow) = value.multipliedReportingOverflow(by: pow)
		
		guard !overflow else { fatalError("Overflow: \(source) !") }
		
		self.value = num
	}

	
	public init?<T>(exactly source: T) where T : BinaryInteger {
		
		self.init(integerLiteral: Base(source) )
	}
	
	
	public init(integerLiteral value: Int) {
		
		let (num, overflow) = value.multipliedReportingOverflow(by: pow)
		guard !overflow else { fatalError("Overflow: \(value) !") }
		
		self.value = num
		
	}
	
	
	public init(floatLiteral value: Double) {
		
		let num = value * Double(pow)
		guard num < Double(Base.max), value > Double(Base.min) else { fatalError("Overflow !") }
		
		self.value = Base(num)
		
	}
	
	public init(_ value: Double) {
		self.init(floatLiteral: value)
	}
	
	/// int hosszúságát dinamikusra venni !
	public init(stringLiteral value: String) {
		
		let parts = value.replacingOccurrences(of: "_", with: "").components(separatedBy: ".")
		let integer = parts.first!.prefix(15)
		
		guard parts.count > 1 else {
			self.value = (Int(integer) ?? 0) * pow
			return
		}
		
		
		
		let fraction = parts[1].prefix(exp)
		
		let whole = String(integer + fraction) + String(repeating: "0", count: (exp-fraction.count) )
		
		self.value = Int(whole) ?? 0
		
//		print(description)
		
	}
	
	
	public init?(string value: String) {
		
		let string = value.trimmingCharacters(in: .whitespaces)
		let parts = string.replacingOccurrences(of: "_", with: "").components(separatedBy: ".")
		let integer = parts.first!.prefix(15)
		
		print(parts)
		
		guard parts.count > 1 else {
			guard let int = Int(integer) else {
				return nil
			}
			self.value = int * pow
			return
		}
		
		
		let fraction = parts[1].prefix(exp)
		
		let whole = String(integer + fraction) + String(repeating: "0", count: (exp-fraction.count) )
		
		guard let int = Int(whole) else { return nil }
		self.value = int
		return
		
//		print(description)
		
	}
	
	
	public init?(integer: String, fraction: String? = nil, dec: Int? = nil) {
		
		self.exp = Base(dec ?? Self.decimalPlaces)
		
		
		if var frc = fraction {
			while frc.count != self.exp { frc.append("0") }
			
			if let val = Base(integer + frc) {
				self.value = val
				return
			}
			
		} else {
			
			if let val = Base(integer) {
				self.value = val * pow
				return
			}
		}
		
		return nil
	}
	
	
	
	
		// MARK:
	
	public var description: String {
//		guard over == nil else { return over! }
//		return "\(value / pow).\((value % pow).magnitude)"
		return string
	}
	
	
	public var debugDescription: String {
		return string
//		guard over == nil else { return "«\(over!)»  ^ \(exp)"}
//		return "[\(value)]^(\(exp)) ➞ {\(integer)|\(fraction)} (\(isFraction ? "fract" : "int"))"
	}
	
	
	public var string: String {
		
		guard value != 0 else { return "0" }
		guard over == nil else { return over! }
		guard isFraction else { return String(String(value).dropLast(exp)) }
		
		var string: String
		var whole = String(value.magnitude)
		
		if whole.count <= exp { string = sign + "0." + String(repeating: "0", count: exp-whole.count) + whole }
		else {
			whole.insert(".", at: whole.index(whole.endIndex, offsetBy: -exp) )
			
			if let over {
				string = sign + String(over) + "|" + whole
			} else {
			string = sign + whole
		}
		}

//		while string.hasSuffix("0") { string.removeLast() }
		
		return string
	}
	
	
	public var integer: Int {
		return value / pow
	}
	
	
	public var fraction: Double {
		return Double(value % pow) / Double(pow)
	}
	
	
	public var sign: String {
		return (value < 0) ? "-" : ""
	}

	
	public var fullsign: String {
		return (value < 0) ? "-" : "+"
	}
	
	
	public var magnitude: FDec {
		var mag = self
		mag.value = Base(self.value.magnitude)
		return mag
	}
	
	
	public var int64: Int64 {
		Int64(self.value)
	}
	
	
	public var double: Double {
		return Double(value) / Double(pow)
	}
	
	
	public var cgFloat: CGFloat {
		return CGFloat(value) / CGFloat(pow)
	}

	
	
	
		// MARK: Questions
	
	public var isPositive : Bool { self.value > 0 }
	public var isNegative : Bool { self.value < 0 }
	
	public var isZero     : Bool { self.value == 0 }
	public var isNotZero  : Bool { self.value != 0  }
	
	public var isOdd      : Bool { self.value & 1 == 1 }
	public var isEven     : Bool { self.value & 1 == 0 }
	
	public var isFraction : Bool { return (value % pow) != 0 }
	public var isDecimal  : Bool { return (value % pow) == 0 }
	
	public static var isSigned: Bool { true }
	
	
	
	
	
		// MARK: Arithmetic
	
	public mutating func negate() { self.value *= -1 }
	
		// + Addicion
	public prefix static func + (x: FDec) -> FDec { x }
	
	public static func + (lhs: FDec, rhs: FDec) -> FDec {
		
		let (value, overflow) = lhs.value.addingReportingOverflow(rhs.value)

		if overflow { print("Error >> Overflow!") }

		return FDec(raw: value)
		
//		var sum = lhs.value + rhs.value
//
//		return FDec(raw: sum)
		
	}
	
	public static func + (lhs: FDec, rhs: Int) -> FDec  { lhs + FDec(rhs) }
	public static func + (lhs: Int, rhs: FDec) -> FDec  { FDec(lhs) + rhs }
	public static func += (lhs: inout FDec, rhs: FDec)  { lhs = lhs + rhs }
	public static func += (lhs: inout FDec, rhs: Int)   { lhs = lhs + FDec(rhs) }
	


	
	
	
		// - Subtraction
	public prefix static func - (x: FDec) -> FDec { var y = x ; y.value *= -1 ; return y }
	
	public static func - (lhs: FDec, rhs: FDec) -> FDec {
		
		let (value, overflow) = lhs.value.subtractingReportingOverflow(rhs.value)
		
		if overflow { print("Error >> Overflow!") }
		
		return FDec(raw:  value)
		
	}
	
	public static func - (lhs: FDec, rhs: Int) -> FDec  { lhs - FDec(rhs) }
	public static func - (lhs: Int, rhs: FDec) -> FDec  { FDec(lhs) - rhs }
	public static func -= (lhs: inout FDec, rhs: FDec)  { lhs = lhs - rhs }
	public static func -= (lhs: inout FDec, rhs: Int)   { lhs = lhs - FDec(rhs) }
	


	
		//	* Multiplication
	
	public static func * (lhs: FDec, rhs: FDec) -> FDec {
		
		let (value, overflow) = lhs.value.multipliedReportingOverflow(by: rhs.value)
		
		guard overflow else { return FDec(raw: value / lhs.pow ) }
		
		
		let (high, low) = mulSplit(lhs.value, rhs.value)
		let (top, overflow2) = high.multipliedReportingOverflow(by: Self.high)
		
	
		if overflow2 { print("\(high)|\(low) >> Overflow!")
			return FDec(raw:  0, over: "\(high)\(low / lhs.pow / lhs.pow)")
		}
	
		return FDec(raw:  top + (low / lhs.pow) )
		
	}
	
	public static func *= (lhs: inout FDec, rhs: FDec) { lhs = lhs * rhs }
	public static func *= (lhs: inout FDec, rhs: Int)  { lhs = lhs * FDec(rhs) }

	
	 //  / Divison
	
	public static func / (lhs: FDec, rhs: FDec) -> FDec {
		
		return FDec(raw:  (lhs.value * lhs.pow) / (rhs.value) )
		
	}
	
	public static func /= (lhs: inout FDec, rhs: FDec) { lhs = lhs / rhs }
	public static func /= (lhs: inout FDec, rhs: Int)  { lhs = lhs / FDec(rhs) }
	
	
		/// MEGIRNI RENDESEN
	public static func % (lhs: FDec, rhs: FDec) -> FDec {
		
		return FDec(raw: (lhs.value * lhs.pow) % (rhs.value) )
		
	}
	
	public func quotientAndRemainder(dividingBy rhs: FDec) -> (quotient: FDec, remainder: FDec) {
		
		let (quotient, remainder) =	self.value.quotientAndRemainder(dividingBy: rhs.value)
		
		return ( FDec(raw: quotient), FDec(raw: remainder) )
	}
	
	
	
	
		// MARK: Compare
	
	public static func < (lhs: FDec, rhs: FDec) -> Bool {

		if lhs.value < rhs.value { return true }
			//		if lhs.exp != rhs.exp  { return false }
		
		return false
	}
	
	public static func == (lhs: FDec, rhs: FDec) -> Bool {
		
		if lhs.value != rhs.value  { return false }
			//		if lhs.exp != rhs.exp  { return false }
		
		return true
	}
	
	public static func > (lhs: FDec, rhs: FDec) -> Bool { !(lhs < rhs) }
	
	public static func != (lhs: FDec, rhs: FDec) -> Bool { !(lhs == rhs) }
	
	
	
	
	
		// MARK: Misc Functions
	
	internal static func mulSplit(_ lhs: Base, _ rhs: Base) -> (high: Base, low: Base) {

		
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
	
	
	public func abs(_ x: FDec) -> FDec {
		return FDec(raw: Base(x.value.magnitude) )
	}
	
	
	public static func random(_ rangeInt: ClosedRange<Int>, rangeFraction: ClosedRange<Int>? = nil) -> FDec {
		return FDec(raw: Int.random(in: rangeInt))
	}
	
	
	public func hash(into hasher: inout Hasher) {
		hasher.combine("\(self.value)\(self.exp)")
	}
	
	
	public func getFormated(showSign: Bool = true, groupingSize: Int = 3, decimalSeparator: String? = nil, groupingSeparator: String? = nil) -> String {
		
		guard value != 0 else { return "0" }

		let decimalSep = decimalSeparator ?? (Locale.current.decimalSeparator ?? ".")
		let groupingSep = groupingSeparator ?? (Locale.current.groupingSeparator ?? " ")
		
		let whole = String(value.magnitude)
		let signstr = showSign ? fullsign : sign
		
		
		guard whole.count > exp else {
			var frc = signstr + "0" + decimalSep + String(repeating: "0", count: exp-whole.count) + whole
			while frc.hasSuffix("0") { frc.removeLast() }
			return frc
		}
		
		
		let int = whole.dropLast(exp)
		var frc = whole.suffix(exp)

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
		
		while frc.hasSuffix("0") { frc.removeLast() }
		return string + decimalSep + frc
		

	}

	public func formatted() -> String {
		getFormated(showSign: false)
	}
	
	/// Retun kisebb
	public func min(_ x: FDec, _ y: FDec ) -> FDec {
		return (x < y) ? x: y
	}
	/// Retun nagyobb
	public func max(_ x: FDec, _ y: FDec ) -> FDec {
		return (x > y) ? x: y
	}
	
}



