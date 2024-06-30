# FDec

A fixed decimal number format for Swift.

Extremely fast numerical structure for precise decimal fraction calculations. Sacrificing size and the dynamic capabilities of float, you get an easy-to-use fast and simple but accurate calculation. Suitable for finance and small calculations. The number of decimals is fixed in the Structure variable, so mixing the sizes is not recommended, but it can be done. This needs special attention, but in return a piece of Int value takes up space in memory.

```Swift 
	FDec.decimalsNum = 3

	let a = FDec("32.001")
	let b = FDec(287.123)

	print(a+b) // 319.124
```

The biggest advantage is that you can save a decimal fractional value as Int type. Numbers are not distorted during serialization, and in most cases it takes up less space than a string.
