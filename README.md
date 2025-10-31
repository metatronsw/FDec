# FDec

A fixed point decimal number format for Swift.

Extremely fast numerical structure for precise decimal fraction calculations. Sacrificing size and the dynamic capabilities of float, you get an easy-to-use fast and simple but accurate calculation. Suitable for finance and small calculations. The number of decimals is fixed in the Structure variable, so mixing the sizes is not recommended, but it can be done. This needs special attention, but in return a piece of Int value takes up space in memory.

```Swift
	FDec.decimalsNum = 3

	let a = FDec("32.001")
	let b = FDec(287.123)

	print(a+b) // 319.124
```

Unlike Decimal, FDec can be easily serialized as a single integer in JSON files, making storage and data transfer simple and efficient. It is particularly well-suited for databases like SQLite and MySQL, enabling fast storage, retrieval, and numeric searches. Ideal for financial and small-scale numeric computations where accuracy, performance, and compatibility matter.
