# FDec

A fixed decimal number format.

Extremely fast numerical structure for precise decimal fraction calculations. Sacrificing size and the dynamic capabilities of float, you get an easy-to-use fast and simple but accurate calculation. Suitable for finance and small calculations, it is highly serializable because it saves only one value. The number of decimals is fixed in the Structure variable, so mixing the sizes is not recommended, but it can be done. 

```
	FDec.decimalsNum = 3

	let a = FDec("32.001")
	let b = FDec(287.123)

	print(a+b) // 319.124
```
