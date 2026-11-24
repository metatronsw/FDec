# FDec – projektútmutató és elemzési jelentés

Fixpontos decimális számtípus Swifthez: egyetlen `Int` tárolja az értéket `10^decimalPlaces`-szel eltolva.
Két forrásfájl: a mag ([Sources/FDec/FDec.swift](Sources/FDec/FDec.swift)) és a ráépülő kiegészítések ([Sources/FDec/FDec+Extensions.swift](Sources/FDec/FDec+Extensions.swift)). Egy tesztfájl ([Tests/FDecTests/FDecTests.swift](Tests/FDecTests/FDecTests.swift)), függőség nincs.

## Parancsok

```bash
swift build
swift test
swift test --filter Test_Arithmetic/test_Mul_OtherScales
```

## Munkaszabályok ehhez a kódhoz

- **A `FDec.swift` lezárt:** a szerző külön engedélye nélkül nem módosítható. Minden új funkció a `FDec+Extensions.swift` fájlba kerül extensionként, és csak a mag nyilvános vagy internal elemeire épít (a `private` segédfüggvényei onnan nem érhetők el).
- `FDec.decimalPlaces` globális, de **egyszer állítható**: az FDec első használata (számítás, átalakítás, a beállítás kiolvasása) befagyasztja, utána eltérő értékre állítani `precondition`. Érvényes tartomány 0…18. A befagyott skálát egy `static let` tartja, amelyet zárolás nélkül csak olvasunk; ettől szálbiztos a típus.
- A tesztek a skálát az internal `FDec.setDecimalPlacesForTesting(_:)` kapun át váltják (nem szinkronizált, csak `@testable` importtal érhető el). Minden tesztosztály az `FDecTestCase` ősből származzon, amely `setUp`/`tearDown`-ban 4-re állítja vissza. Tesztben a nyilvános `FDec.decimalPlaces = n` más értékkel leállítja a futást.
- `FDec("1.5")` literállal a nem opcionális `init(stringLiteral:)`-t hívja (hibánál `fatalError`, az `_` és a szóköz kiszűrve), változóval a szigorú, opcionális `init?(_ description:)`-t. Ugyanez igaz a szám-literálokra. Tesztíráskor ez dönti el, melyik kódút fut.
- Tesztben a várt értéket `rawValue`-val vagy `.description`-nel kell rögzíteni, nem FDec-literállal (az mindkét oldalon ugyanazt a kódot futtatná).
- Egy viselkedést egy helyen tesztelünk. Új teszt előtt a tesztfájl `MARK` szakaszaiban meg kell nézni, nincs-e már lefedve.
- Aritmetikában tilos a csapdázó `Int` művelet; `…ReportingOverflow` vagy `multipliedFullWidth` / `dividingFullWidth` kell. Minden új művelet kezelje a három jelzőértéket (`isFinite` ág).
- Fenntartott nyers értékek: `Int.min` = `nan`, `Int.max` = `infinity`, `-Int.max` = negatív végtelen. Számított nyers értéket a `checked(_:)` segédfüggvényen át kell visszaadni.
- `nan` összehasonlítása a `Double` szabályait követi (`nan != nan`), ezért `XCTAssertEqual` helyett `isNan` kell, és mind a négy rendező operátor kézzel van megírva.
- A hibaüzenetek a `debugLog` függvényen mennek át, amely release buildben nem ír ki semmit. Könyvtári kódba csupasz `print` ne kerüljön.

---

# Elemzési jelentés

Első elemzés: 2026-11-24, teljes kódolvasás, `swift build` / `swift test`, és egy külön próbaprogram kb. 150 esettel (az összeomlás-gyanús hívások külön folyamatban). Ugyanaznap a hibák egyenként, a szerzővel egyeztetve javítva lettek. Környezet: Swift 5.9.2, macOS 13, x86_64.

**Jelenlegi állapot:** 105 teszt zöld egyetlen fájlban, debug és release build figyelmeztetés nélkül fordul. A korábban összeomló 30 próbaeset mind lefut.

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
| – | A globális skála nem volt szálbiztos, és futás közben átértelmezte a meglévő értékeket | Egyszer állítható, az első használat befagyasztja; `pow`, `zeroShift`, `intMaxDecimals` csak olvasható. Külön folyamatban és ThreadSanitizerrel ellenőrizve |
| – | `print` könyvtári kódban | `debugLog`, csak debug buildben |

### Viselkedésváltozások, amelyek meglévő hívót érinthetnek

- **Codable kimenet:** egész helyett szöveg. A README és az AGENT.md már ezt írja le.
- **Szövegértelmező:** `"1,5"`, `""`, `"."`, `"1.2.3"` mostantól `nil`.
- **`nan == nan` hamis:** NaN-t tartalmazó tömb rendezése és `Set`-be tétele ugyanúgy megbízhatatlan, mint `Double`-nél.
- **`random(_:_:decimals:)`:** a `decimals` paraméter megszűnt.
- **`isInfinity`:** negatív végtelenre is igaz.
- **Törölt belső elemek:** `mulSplit`, `overflow()`.
- **Skála:** az első használat után `FDec.decimalPlaces` eltérő értékre állítása leállítja a programot; `FDec.pow`, `zeroShift` és `intMaxDecimals` már nem írható.

## 2. Ami még hátravan

### Ismert, még nem javított problémák
- `intMaxDecimals` sehol sincs használva.
- Swift 6 nyelvi módban a fordítás nem ellenőrzött (a skála már `static let` mögött van, `@unchecked Sendable` tárolóval).
- `asInt` és `fraction` a jelzőértékekre értelmetlen számot ad; a `debugDescription` ezeket ki is írja.
- `LosslessStringConvertible` nem teljes: a `"NaN"` / `"Infinity"` kimenetet a szövegértelmező nem olvassa vissza (a Codable dekóder igen).
- `x / 0` minden esetben `nan` (a `Double` itt előjeles végtelent adna) – ez tudatos döntés maradt.
- `.gitignore`: a `.icns` minta nem illeszkedik semmire (`*.icns` kellene), a `fdec.icns` (480 KB) követett fájl. Nincs `LICENSE` fájl.

### Elkészült kiegészítések (`FDec+Extensions.swift`)
- `init?(_: Decimal)`, `asDecimal`, `Decimal(FDec)` – a `Decimal`-nak nincs végtelenje, ezért a jelzőértékek `Decimal.nan`-ra képződnek.
- `formatted(fractionDigits:rounding:…)` – rögzített tizedesszám (`12.5` → `"12.50"`); nullára kerekedő érték előjel nélkül jelenik meg.
- `allocated(into:)`, `allocated(ratios:)` – maradék nélküli szétosztás; a fennmaradó egységek az első (nem nulla arányú) részekhez kerülnek. Érvénytelen bemenetre üres tömb.
- `percent(_:rounding:)`, `adding(percent:)`, `subtracting(percent:)` – egy lépésben, egyetlen kerekítéssel; alapértelmezés a féltől felfelé kerekítés.
- `Sendable` megfelelés (`@unchecked`, mert a típus fájlján kívül van deklarálva). Az értékekre vonatkozik, a globális `decimalPlaces` továbbra sem szálbiztos.
- `FDec * Int`, `Int * FDec`, `FDec / Int`, `*=`, `/=` – a szorzó nincs skálázva, ezért pontos, és olyan nagy egésszel is működik, amely FDec-ként nem férne el. Egész literálnál (`x * 2`) a fordító mostantól ezt a változatot választja; az eredmény ugyanaz.
- `raised(to:rounding:)` és a szabad `pow(_:_:)` – ismételt négyzetre emelés; minden lépés kerekít, ezért törtnél az utolsó jegyek eltérhetnek a pontosan kerekített hatványtól. Negatív kitevő a reciprokot adja.
- `squareRoot()` – egész alapú, minden skálán az utolsó jegyig pontos, vágott gyök. A `FDec.swift`-beli `sqrt()` és a szabad `sqrt(_:)` a szerző külön engedélyével erre hív tovább, így a `Darwin.sqrt` függőség megszűnt.
- `floor(places:)`, `ceil(places:)`, `truncated(places:)`, `isWhole`, `signum()`, `clamped(to:)`.
- `Sequence<FDec>.sum()` és `average(rounding:)` – 128 bites összegzés, így a közben túlcsorduló, de végül elférő összeg is helyes.
- `addingReportingOverflow` / `subtracting…` / `multiplied…(by:)` / `divided…(by:)` – a szokásos eredmény és egy jelző; a jelző minden nem véges eredményre igaz (NaN-ra és eleve nem véges operandusra is).
- `FDec.greatestFiniteMagnitude`, `FDec.leastNonzeroMagnitude`. Szándékosan nem `max` / `min` a nevük: egy `FDec.max` statikus tag a típuson belül eltakarná a `max(a, b)` függvényt.
- `init?(raw:scale:rounding:)` és `rawValue(scale:rounding:)` – más skálán tárolt nyers érték beolvasása és kiírása (adatbázis-oszlophoz).
- `init?(_:locale:)` és `formatted(locale:fractionDigits:…)` – a locale elválasztóival. A beolvasás a tagoló jeleket bárhol eldobja (nem ellenőrzi, hogy hármasával állnak-e), ezért `en_US` alatt az `"1,5"` tizenöt.
- `FDec.Style` (`Foundation.FormatStyle`, macOS 12 / iOS 15-től) és `value.formatted(.fdec.precision(2))`; SwiftUI-ban `Text(value, format: .fdec)`. A kerekítés itt mindig féltől felfelé történik. Linuxon nem ellenőrzött.

### Hiányzó funkciók
- `Int`-es `+` és `-` operátor (ma csak `Int32`-re van).
- Pénznem szerinti formázás (`.currency(code:)`), `ParseableFormatStyle`.
- A skála típusba emelése (`FDec<Scale>`), hogy egy programban több skála is élhessen – a szerző ezt külön forkban tervezi.

### Csomagolás
- `LICENSE`, `platforms` a `Package.swift`-ben, Linux-támogatás, CI (macOS + Linux).
- A README és az AGENT.md frissítve (a README példái lefordítva és lefuttatva ellenőrizve).

## 3. A tesztfájl felépítése

Az eredeti tesztfájl és a javításokhoz írt regressziós fájl egyetlen fájlba lett összevonva; az átfedő esetek (alapműveletek kis számokon, szöveges init, formázás) egyszer szerepelnek, az eredeti fájl hibás tesztjei (állapotszivárgás, locale-függés, tautologikus állítások, prefix-összehasonlítás) megszűntek.

| Osztály | Mit fed le |
|---------|------------|
| `Test_Scale` | `pow` / `zeroShift` követi a skálát; skálaváltás újraértelmezi a tárolt értéket |
| `Test_Init` | literálok, egész típusok, `Double` / `Float` / `truncating` / `exactly` |
| `Test_Parsing` | szigorú értelmező (elfogadott, elutasított, határok), `description` oda-vissza, `Substring`, `int:frc:sign:` |
| `Test_Output` | `description` több skálán, `formatted`, átalakítások, `asUInt32`, `digitCount`, előjel, párosság |
| `Test_Arithmetic` | `+ - * / %`, több skála, túlcsordulás, `quotientAndRemainder`, összetett és `Int32`-es operátorok, `sqrt`, algebrai tulajdonságok, `Decimal`-lal összevetett véletlen esetek |
| `Test_Rounding` | `multiplied` / `divided` kerekítési módokkal, `rounded(places:)`, `Decimal`-lal összevetve |
| `Test_SpecialValues` | `nan` és a végtelenek azonosítása, terjedése, kiírása, összehasonlítása |
| `Test_Protocols` | `Comparable`, `Hashable`, `Strideable`, `Codable` |
| `Test_Random` | `random(in:)` és `random(_:_:)` |
| `Test_Decimal`, `Test_FixedFormat`, `Test_Allocation`, `Test_Percent`, `Test_Sendable`, `Test_WholeNumberOperators`, `Test_PowerAndRoot`, `Test_Helpers`, `Test_Sums`, `Test_Limits`, `Test_ScaleConversion`, `Test_LocaleText` | a `FDec+Extensions.swift` függvényei |

## 4. Ami tesztből még hiányzik

- Teljesítmény: `measure {}` a négy alapműveletre `Decimal`-lal összevetve – a README „extremely fast” állítását ma semmi nem támasztja alá, és a jelzőértékek ellenőrzése plusz elágazásokat hozott.
- A szándékos leállások (`decimalPlaces` tartomány, túl nagy literál, `rounded(places:)` negatív értékkel, `random(in:)` nem véges határral) XCTesttel nem tesztelhetők; ezeket külön folyamatban kell ellenőrizni.
- `formatted()` alapértelmezett elválasztói csak a futtató gép locale-jával vannak ellenőrizve.
