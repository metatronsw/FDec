# FDec Agent Specification

## Purpose
This document defines the behavior and conventions for agents interacting with the FDec Swift library. The agent’s goal is to produce, modify, or use FDec types in a way that is accurate, consistent, and performant.

## Usage Guidelines

- Use `FDec` for all fixed-decimal calculations instead of `Float` or `Double` when precision matters.
- Avoid mixing FDec types with different scales unless explicitly handled.
- Always consider serialization: FDec encodes to JSON as decimal text (`"12.34"`), which is independent of the scale.
- For database operations (SQLite, MySQL), store `rawValue` as an integer and restore it with `FDec(raw:)` for fast querying and retrieval. The scale of such a column must stay fixed.

## Conventions
- The number of decimal places must be set at the project level before use. The valid range is 0...18; any other value stops the program:
  ```swift
  FDec.decimalPlaces = 3
  ```
- Can be initialized directly from a String, Float, or Double. Double and Float are rounded to the nearest representable value:
  ```swift
  let amountOfDouble = FDec(12.34)
  let amountOfString = FDec("12.34")
  ```
- A literal argument selects the non-failable literal initializer, which stops the program on invalid input. A variable argument selects the failable initializer, which returns `nil`:
  ```swift
  let fixed = FDec("12.34")        // FDec
  let text = "12.34"
  let parsed = FDec(text)          // FDec?
  ```
- The string parser is strict: an optional sign, digits and at most one `.`. Empty text, a comma, grouping, exponents and whitespace give `nil`. Digits beyond the scale are truncated.
- Can be initialized by providing the integer part, fractional part, and the sign (`""`, `"+"` or `"-"`). The parts may contain digits only.
  ```swift
  let decimalNumber = FDec(int: "12", frc: "34", sign: "-")
  ```
- Use standard arithmetic operators (+, -, *, /, %) with FDec objects.
- `*` and `/` truncate toward zero. Request any other rounding explicitly:
  ```swift
  let rate = price.divided(by: count, rounding: .toNearestOrEven)
  let total = price.multiplied(by: quantity, rounding: .toNearestOrAwayFromZero)
  let shown = total.rounded(places: 2)
  ```
- Maintain the fixed decimal scale consistently throughout calculations.

## Special values
- Arithmetic never traps. An overflow gives `FDec.infinity` or `-FDec.infinity`; a division or remainder by zero gives `FDec.nan`.
- The special values propagate with the rules of `Double`: `nan` is contagious, `infinity - infinity` and `infinity * 0` are `nan`.
- `nan` is not equal to anything, itself included, and every ordered comparison with it is false. Check with `isNan`, and use `isFinite` to accept ordinary numbers only.
- Check `isFinite` before storing or displaying the result of a calculation that may overflow.

## Components
- Initialization: Construct FDec values with fixed decimal precision.
- Arithmetic: Supports addition, subtraction, multiplication, division and remainder, with a 128-bit intermediate for multiplication and division.
- Rounding: `multiplied(by:rounding:)`, `divided(by:rounding:)`, `rounded(_:places:)`, `round(_:places:)`.
- Serialization: Codable as decimal text. The decoder also accepts a plain integer and reads it as the raw value of the earlier format.
- Database Usage: Store and query `rawValue` as an integer in SQLite or MySQL databases.
- Random: `FDec.random(in:)` for a range of FDec values, `FDec.random(_:_:)` for a whole part plus a fraction in raw units.

## Best Practices
- Use FDec for financial applications or cases where exact decimal fractions are required.
- Always be explicit about the decimal scale when mixing FDec instances with different precisions.
- Test edge cases for overflow or underflow, especially in high-value calculations.
- In tests, pin expected values through `rawValue` or `description`; comparing against an FDec literal runs the same code on both sides.
- A test that changes `FDec.decimalPlaces` must restore it in `tearDown`.

## Restrictions
- Do not use FDec for floating-point scientific calculations requiring dynamic precision.
- Mixing scales without proper handling may lead to incorrect results.
- Changing the decimal places during program execution is not recommended: existing values are reinterpreted with the new scale, and the setting is not thread-safe.
- `sqrt` goes through `Double` and is only accurate to about 15 significant digits.
