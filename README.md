# FDec

A fixed point decimal number format for Swift.

Extremely fast numerical structure for precise decimal fraction calculations. Sacrificing size and the dynamic capabilities of float, you get an easy-to-use fast and simple but accurate calculation. Suitable for finance and small calculations. The number of decimals is fixed in the Structure variable, so mixing the sizes is not recommended, but it can be done. This needs special attention, but in return a piece of Int value takes up space in memory.

```Swift
	FDec.decimalPlaces = 3

	let a = FDec("32.001")
	let b = FDec(287.123)

	print(a+b) // 319.124
```

## Scale

`FDec.decimalPlaces` sets the number of decimal places for the whole program. The default is 4 and the valid range is 0...18; any other value stops the program with a message. Set it once at startup: every existing value is interpreted with the current scale, so changing it later changes the meaning of the values you already hold.

With `n` decimal places the largest magnitude is about `9.22 × 10^(18 - n)`, which is roughly 922 trillion at the default scale.

## Creating values

```Swift
	let a: FDec = 12.34              // literals
	let b: FDec = "1_000_000.5"      // "_" and spaces are ignored in string literals
	let c = FDec(raw: 123400)        // the stored integer, 12.34 at four decimals

	let text = "12.34"
	let d = FDec(text)               // FDec?, strict parser
	let e = FDec(int: "12", frc: "34", sign: "-")
```

- **From text:** the parser accepts an optional sign, digits and at most one `.` (`"5"`, `"-0.5"`, `".5"`, `"5."`). Everything else gives `nil`: empty text, a comma, grouping, exponents, whitespace. Digits beyond the scale are truncated.
- **From `Double` and `Float`:** the nearest representable value is taken, so `FDec(0.07)` is exactly 0.07. NaN, infinity and out of range values give `nil`.
- **`init(truncating:)`:** never fails; it cuts the digits beyond the scale and maps NaN and out of range values to `FDec.nan` and the infinities.
- **`init(exactly:)`:** succeeds only when the conversion is lossless.
- **From integers:** the failable initializers return `nil` when the number does not fit. An integer literal that does not fit stops the program.

## Arithmetic

`+`, `-`, `*`, `/` and `%` work on `FDec` values, with `Int32` variants for the compound forms. Multiplication and division use a 128-bit intermediate, so a result is only reported as overflow when it really does not fit.

`*` and `/` truncate toward zero. When another rounding is needed, ask for it explicitly:

```Swift
	let two: FDec = 2, three: FDec = 3

	two / three                                              // 0.6666
	two.divided(by: three, rounding: .toNearestOrAwayFromZero) // 0.6667
	two.multiplied(by: three, rounding: .toNearestOrEven)

	let x: FDec = 12.3456
	x.rounded()                    // 12
	x.rounded(places: 2)           // 12.35
	x.rounded(.down, places: 2)    // 12.34
```

`%` is the remainder of the truncating division, like `Int`: `5.5 % 2` is `1.5` and the sign follows the dividend. `quotientAndRemainder(dividingBy:)` returns a whole quotient together with that remainder.

## Overflow, infinity and NaN

Arithmetic never traps. The special values behave like those of `Double`:

- An overflow gives `FDec.infinity` or `-FDec.infinity`, with the correct sign.
- A division or remainder by zero gives `FDec.nan`.
- `nan` is contagious, `infinity - infinity` and `infinity * 0` are `nan`, and a finite value divided by infinity is zero.
- `nan` is not equal to anything, itself included, and every ordered comparison with it is false. Test for it with `isNan`; use `isFinite` to tell ordinary numbers from all three special values.

## Output

```Swift
	let n: FDec = "1234567.5"

	n.description                                                // "1234567.5"
	n.formatted(decimalSeparator: ".", groupingSeparator: ",")   // "1,234,567.5"
	n.formatted(groupingSize: 0, decimalSeparator: ".")          // "1234567.5"
```

`formatted()` takes its separators from the current locale unless you pass them. The special values are written as `NaN`, `Infinity` and `-Infinity`.

## Serialization and databases

`FDec` is `Codable`. It encodes as decimal text, which does not depend on the scale, so a file written with one `decimalPlaces` setting is read correctly with another:

```Swift
	let data = try JSONEncoder().encode([FDec("12.34")])   // ["12.34"]
```

For compatibility the decoder also accepts a plain integer and reads it as the raw stored value, which is only correct while `decimalPlaces` matches the setting used when it was written.

In databases like SQLite and MySQL an `FDec` can be stored as a single integer through `rawValue` and restored with `FDec(raw:)`, enabling fast storage, retrieval, and numeric searches. Keep the scale fixed for such a column.

## Random values

```Swift
	FDec.random(in: 0 ... 100)     // any value the scale can represent
	FDec.random(1 ... 6)           // a whole number, FDec?
	FDec.random(1 ... 6, 0 ... 9999) // whole part plus a fraction given in raw units
```

## Limitations

- The scale is global and not thread-safe; set it before any other use.
- `sqrt` goes through `Double`, so it is only accurate to about 15 significant digits.
