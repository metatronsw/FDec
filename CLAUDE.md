# FDec – projektútmutató és elemzési jelentés

Fixpontos decimális számtípus Swifthez: egyetlen `Int` tárolja az értéket `10^decimalPlaces`-szel eltolva.
Egy forrásfájl ([Sources/FDec/FDec.swift](Sources/FDec/FDec.swift)), két tesztfájl ([FDecTests.swift](Tests/FDecTests/FDecTests.swift) – eredeti, [RegressionTests.swift](Tests/FDecTests/RegressionTests.swift) – a javításokhoz), függőség nincs.

## Parancsok

```bash
swift build
swift test
swift test --filter Test_Regression/test_H2_Mul_OtherScales
```

## Munkaszabályok ehhez a kódhoz

- `FDec.decimalPlaces` globális, mutálható állapot, érvényes tartománya 0…18 (azon kívül `precondition`). Teszt, amely átírja, `setUp`/`tearDown`-ban állítsa vissza 4-re, ahogy a `Test_Regression` teszi.
- `FDec("1.5")` literállal a nem opcionális `init(stringLiteral:)`-t hívja (hibánál `fatalError`, az `_` és a szóköz kiszűrve), változóval a szigorú, opcionális `init?(_ description:)`-t. Ugyanez igaz a szám-literálokra. Tesztíráskor ez dönti el, melyik kódút fut.
- Tesztben a várt értéket `rawValue`-val vagy `.description`-nel kell rögzíteni, nem FDec-literállal (az mindkét oldalon ugyanazt a kódot futtatná).
- Aritmetikában tilos a csapdázó `Int` művelet; `…ReportingOverflow` vagy `multipliedFullWidth` / `dividingFullWidth` kell. Minden új művelet kezelje a három jelzőértéket (`isFinite` ág).
- Fenntartott nyers értékek: `Int.min` = `nan`, `Int.max` = `infinity`, `-Int.max` = negatív végtelen. Számított nyers értéket a `checked(_:)` segédfüggvényen át kell visszaadni.
- `nan` összehasonlítása a `Double` szabályait követi (`nan != nan`), ezért `XCTAssertEqual` helyett `isNan` kell, és mind a négy rendező operátor kézzel van megírva.
- A hibaüzenetek a `debugLog` függvényen mennek át, amely release buildben nem ír ki semmit. Könyvtári kódba csupasz `print` ne kerüljön.

---

# Elemzési jelentés

Első elemzés: 2026-11-24, teljes kódolvasás, `swift build` / `swift test`, és egy külön próbaprogram kb. 150 esettel (az összeomlás-gyanús hívások külön folyamatban). Ugyanaznap a hibák egyenként, a szerzővel egyeztetve javítva lettek. Környezet: Swift 5.9.2, macOS 13, x86_64.

**Jelenlegi állapot:** 73 teszt zöld (19 eredeti + 54 regressziós), debug és release build figyelmeztetés nélkül fordul. A korábban összeomló 30 próbaeset mind lefut. Semmi nincs commitolva.

## 1. Javított hibák és a meghozott döntések

| # | Hiba | Döntés / javítás |
|---|------|------------------|
| H1 | `>` valójában `>=` volt | Saját `>` és `!=` törölve, később a NaN miatt mind a négy rendezés kézzel megírva |
| H2, C1 | Szorzás csak 4 tizedesnél volt helyes, nagy számnál összeomlott | 128 bites köztes szorzat; `mulSplit` és a `half`/`high`/`full` konstansok törölve |
| H3, C4 | `%` hibás képlet, nullánál összeomlás | Osztási maradék, mint az `Int`-nél (előjel az osztandóé); nullánál `nan`; új `%=` |
| H4 | Osztás ~92 milliárd fölött `Infinity` | 128 bites köztes osztandó |
| H5 | `quotientAndRemainder` skálázatlan hányados | Egész hányados + maradék (`7 qr 2 = (3, 1)`); nullánál `(nan, nan)` |
| H6, C12 | `init?(Double)` a kéttizedes értékek 12%-ára `nil` | Mindig a legközelebbi értékre kerekít; `nil` csak nem véges vagy tartományon kívüli értékre. A float literál így szintén kerekít |
| H7, C9, C10 | `init(truncating:)` a bináris zajjal együtt vágott, határesetben összeomlott | Zajtűrő vágás (2 ulp-on belül egésznek veszi); NaN → `nan`, túl nagy → előjeles végtelen. `sqrt(-1)` → `nan` |
| H8 | `init?(Float)` szinte mindig `nil` | A Float legrövidebb decimális alakjából indul, így nagy skálán sincs bővítési zaj |
| H9 | `init?(exactly:)` csak egészt fogadott el | Akkor sikerül, ha az átalakítás oda-vissza veszteségmentes |
| H10 | Engedékeny szövegértelmező | Szigorú: előjel, ASCII számjegyek, legfeljebb egy `.`; a vessző hiba; fölös tizedesek **vágva**; `Int.max` nyers értéket adó szöveg `nil` |
| H11 | `init(int:frc:sign:)` a törtrész végét vette | A szigorú értelmezőre épül; `sign` csak `""`, `"+"`, `"-"` |
| H12 | `isOdd` / `isEven` a nyers bitet nézte | Az egész érték párossága; törtnél mindkettő hamis |
| H13, H14, C2, C3 | Végtelen és NaN nem terjedt, nem volt negatív végtelen | Terjedő, előjeles modell a `Double` szabályaival; új `isFinite`; `isInfinity` mindkét előjelre igaz; kiírás `"NaN"`, `"Infinity"`, `"-Infinity"`; összehasonlítás `Double` szerint |
| H15, C13 | `random` hibás skála és előjel, összeomlás | Új `random(in:)` zárt és félig nyitott tartományra; a régi javítva, a `decimals` paraméter megszűnt |
| H16 | Nem volt választható kerekítés | A `*` és `/` továbbra is vág; új `multiplied(by:rounding:)`, `divided(by:rounding:)`, `rounded(_:places:)`, `round(_:places:)` `FloatingPointRoundingRule`-lal |
| H17 | Codable skála nélküli egészt írt | Mostantól decimális **szöveg** (`"12.34"`), skálafüggetlen; a régi egész formátum még beolvasható nyers értékként |
| H18 | 18 tizedesnél minden `Infinity` | A 128 bites műveletekkel megoldódott |
| C5 | `digitCount` összeomlott | Az egészrész számjegyei logaritmus nélkül (0 és 0.5 → 1); jelzőértékre 0 |
| C6 | `asUInt32` összeomlott | `nil`, ha nem fér el vagy nem véges |
| C7, C8 | Egész initek összeomlottak | Az opcionálisak `nil`-t adnak; túl nagy **literál** `precondition`; a kis egész típusok (Int8…UInt32) nem opcionális initje telítődik végtelenre |
| C11 | `formatted(groupingSize: 0)` összeomlott | Nulla vagy negatív csoportméret: nincs tagolás |
| C14 | Érvénytelen `decimalPlaces` üzenet nélkül állt le | `precondition` érthető üzenettel |
| – | `print` könyvtári kódban | `debugLog`, csak debug buildben |

### Viselkedésváltozások, amelyek meglévő hívót érinthetnek

- **Codable kimenet:** egész helyett szöveg. A README és az AGENT.md már ezt írja le.
- **Szövegértelmező:** `"1,5"`, `""`, `"."`, `"1.2.3"` mostantól `nil`.
- **`nan == nan` hamis:** NaN-t tartalmazó tömb rendezése és `Set`-be tétele ugyanúgy megbízhatatlan, mint `Double`-nél.
- **`random(_:_:decimals:)`:** a `decimals` paraméter megszűnt.
- **`isInfinity`:** negatív végtelenre is igaz.
- **Törölt belső elemek:** `mulSplit`, `overflow()`.

## 2. Ami még hátravan

### Ismert, még nem javított problémák
- `Darwin.sqrt` – Linuxon nem fordul (nem ellenőrzött). Az `sqrt` Double-ön át számol, ~15 értékes jegy fölött pontatlan.
- `pow`, `zeroShift`, `intMaxDecimals` nyilvános és írható, így kívülről inkonzisztenssé tehető; `intMaxDecimals` sehol sincs használva.
- A statikus változók nem szálbiztosak; Swift 6 nyelvi módban fordítási hiba lesz belőlük (nem ellenőrzött).
- `asInt` és `fraction` a jelzőértékekre értelmetlen számot ad; a `debugDescription` ezeket ki is írja.
- `LosslessStringConvertible` nem teljes: a `"NaN"` / `"Infinity"` kimenetet a szövegértelmező nem olvassa vissza (a Codable dekóder igen).
- `x / 0` minden esetben `nan` (a `Double` itt előjeles végtelent adna) – ez tudatos döntés maradt.
- `.gitignore`: a `.icns` minta nem illeszkedik semmire (`*.icns` kellene), a `fdec.icns` (480 KB) követett fájl. Nincs `LICENSE` fájl.

### Hiányzó funkciók
- `Decimal` / `NSDecimalNumber` átjárás, `Sendable` megfelelés.
- `signum`, `pow(_: Int)`, `Int`-es operátorváltozatok (ma csak `Int32` van, és a `*`, `/` nem értékadó `Int32`-es alakja hiányzik).
- Egészaritmetikás `sqrt`.
- `formatted` `Locale` paraméterrel és rögzített tizedesszámmal (`12.50`), `FormatStyle` megfelelés.
- Skálaváltás (`rescaled(to:)`).
- Tartós megoldás a globális skálára: a skála típusba emelése (`FDec<Scale>`) vagy a beállítás egyszer írhatóvá tétele.

### Csomagolás
- `LICENSE`, `platforms` a `Package.swift`-ben, Linux-támogatás, CI (macOS + Linux).
- A README és az AGENT.md frissítve (a README példái lefordítva és lefuttatva ellenőrizve).

## 3. Az eredeti tesztfájl értékelése

A [FDecTests.swift](Tests/FDecTests/FDecTests.swift) érintetlen maradt; a hibáit a regressziós fájl kerüli meg, de nem javítja.

- **Állapotszivárgás:** `test_Sqrt` 1…6-ra állítja a `decimalPlaces`-t és nem állítja vissza. Az XCTest ábécérendje miatt a `Test_Common` első négy tesztje 6 tizedessel fut, amíg `test_Init_Self` vissza nem állítja 4-re.
- **`test_Sqrt`** `1..<base.count` miatt a `9.0` alapot kihagyja.
- **Locale-függés:** `test_Output_Formatted` az alapértelmezett locale-lal `"1 000"`-et vár. Ez `en_HU` alatt átmegy, `en_US` vagy `hu_HU` alatt elbukna.
- **Tautológia:** `XCTAssertEqual(T("1_000"), "1000")` mindkét oldalon ugyanazt az értelmezőt futtatja.
- **Rossz paraméter:** `XCTAssertNil(T(strUnderscore)?.description, "123456789")` – a második argumentum hibaüzenet, nem várt érték.
- **Gyenge prefix-összehasonlítás:** `test_Random` a `Decimal` eredményt az FDec kimenet hosszára vágja, tehát egy túl rövid hibás eredmény is átmegy.
- **`test_Fraction_Mod`** csak `4 % 3` és `8 % 2`; **`test_Fraction_Sub`** első négy állítása összeadás.
- **`test_Init_Self`** neve félrevezető: azt rögzíti, hogy skálaváltás után ugyanaz a literál nem egyenlő önmagával.
- `test_Negate` nem hívja a `negate()`-et; kikommentelt állítások és `print` sorok maradtak; az osztálynév elírt (`Test_Aritmetic`).

## 4. Még megírandó tesztek

A regressziós fájl lefedi az 1. fejezet minden sorát, több helyen `Decimal`-lal összevetett véletlen esetekkel és több skálán. Ami még nincs lefedve:

- `Hashable`: `Set([a, b]).count`, szótárkulcsként használat.
- `Strideable`: `stride(from:to:by:)` és `through:` elemszáma, `distance(to:)`, `advanced(by:)`.
- `description` a 4-től eltérő skálákon (0 és 18 is), `debugDescription`.
- `fraction`, `asFloat`, `asInt` negatív és nagy értékre; `Int(FDec)`, `Double(FDec)`, `Float(FDec)`.
- `init(_: Substring)`, `init(_: FDec)`, `magnitude` és `negate()` véges értékre, `sign` / `signFull`.
- Tulajdonságalapú tesztek: kommutativitás, `(a + b) - b == a`, `a * 1 == a`, `a / 1 == a`.
- `Int32`-es operátorok mindkét oldalon, `reduce(0, +)`.
- Teljesítmény: `measure {}` a négy alapműveletre `Decimal`-lal összevetve – a README „extremely fast” állítását ma semmi nem támasztja alá, és a jelzőértékek ellenőrzése plusz elágazásokat hozott.
- Az összeomlással járó szándékos leállások (`decimalPlaces` tartomány, túl nagy literál, `rounded(places:)` negatív értékkel) XCTesttel nem tesztelhetők; ezeket külön folyamatban kell ellenőrizni.
