# FUTURE – a skála a típusban

Ötlet és kivitelezési terv egy jövőbeli, nem kompatibilis főverzióhoz. Semmi nincs belőle megírva.

## A probléma, amit megold

Ma a skála (`FDec.decimalPlaces`) a program egészére szóló beállítás, amelyet az első használat befagyaszt. Ez szálbiztos, de három korlátja megmarad:

- Egy programban egyetlen skála élhet. Nem lehet egyszerre 2 tizedes pénzösszeg és 6 tizedes árfolyam.
- A skála nem látszik a kódban. Egy `FDec` értékről csak a futó program tudja, hány tizedest jelent.
- A beállítás helyessége futásidőben derül ki (késői átállításnál a program leáll), nem fordításkor.

## Az ötlet

A skála a típus része legyen. Minden skálához külön típus tartozik, a tizedesjegyek száma fordítási idejű állandó.

```swift
public protocol FixedScale {
	static var places: Int { get }   // 0...18
	static var pow: Int { get }      // 10^places
}

public enum Places2: FixedScale { public static let places = 2; public static let pow = 100 }
public enum Places4: FixedScale { public static let places = 4; public static let pow = 10_000 }
public enum Places6: FixedScale { public static let places = 6; public static let pow = 1_000_000 }
// ... Places0-tól Places18-ig

@frozen public struct Fixed<S: FixedScale> {
	public private(set) var rawValue: Int
}

public typealias FDec = Fixed<Places4>     // a mai alapértelmezés neve megmarad
```

Használat:

```swift
typealias Money = Fixed<Places2>
typealias Rate  = Fixed<Places6>

let price: Money = 19.99
let rate: Rate = 1.083452

let wrong = price * rate                       // fordítási hiba: két különböző típus
let converted = price.multiplied(by: rate)     // Money, a kerekítés a hívásnál látszik
let precise = Rate(price)                      // explicit, veszteségmentes bővítés
let rounded = Money(rate, rounding: .toNearestOrEven)   // explicit, kerekítő szűkítés
```

## Mit nyerünk és mit veszítünk

| | Ma (globális, befagyó skála) | Típusba emelt skála |
|---|---|---|
| Több skála egy programban | nem | igen |
| Skálák keverése | futásidőben hibás eredmény | fordítási hiba |
| Szálbiztonság | az első használat után | mindig, nincs megosztott állapot |
| A `pow` elérése | statikus `let` + osztálymező olvasása | fordítási idejű állandó |
| Tesztek több skálán | belső tesztkapuval | egyszerűen több típussal |
| Skála futásidőben választva (pl. konfigurációból) | igen | csak előre felsorolt típusok közül |
| Meglévő hívó kód | – | törik: `FDec.decimalPlaces = n` megszűnik |

A futásidőben választott skála elvesztése a fő ár. Akinek ez kell, annak marad a mostani ág, vagy egy külön, skálát értékenként tároló típus (lásd a nyitott kérdéseket).

## Tervezési döntések

- **A skálatípusok üres `enum`-ok**, példányuk nincs. A `pow` bennük `static let`, mert generikus típusban tárolt statikus tulajdonság nem lehet, konkrét típusban igen.
- **A `pow` kézzel beírt állandó, nem számított érték**, és egy teszt ellenőrzi mind a 19 típusra, hogy `pow == 10^places`. Így nem kell futásidejű hatványozás.
- **`@frozen` és `@inlinable` a forró útvonalakon** (aritmetika, összehasonlítás). Enélkül a modulhatáron át a generikus kód nem specializálódik, és lassabb lesz a mostaninál.
- **A jelzőértékek változatlanok:** `Int.min` = nan, `Int.max` = végtelen, `-Int.max` = negatív végtelen, a `Double` szabályaival. Ezek nem függnek a skálától.
- **Vegyes skálájú operátor nincs.** A `Fixed<A> * Fixed<B>` szándékosan nem fordul; helyette explicit átalakítás vagy névvel ellátott függvény kell, amelynél az eredmény típusa és a kerekítés látszik.
- **A Codable formátum nem változik:** már ma is decimális szöveg (`"12.34"`), amely nem függ a skálától. A régi nyers egész formátum dekódolását ebben a verzióban érdemes megszüntetni, mert típusonként mást jelentene.
- **A `Sendable` megfelelés feltétel nélküli** lesz, `@unchecked` nélkül, mert a típus fájljában deklarálható.

## Kivitelezési terv

### 1. Váz és a skálatípusok
- `FixedScale` protokoll, `Places0` … `Places18`, `Fixed<S>` a tárolt `rawValue`-val és az `init(raw:)`-val.
- Teszt: mind a 19 skálatípus `places` és `pow` értéke összhangban van.
- Kész, ha: a csomag fordul, és `MemoryLayout<Fixed<Places4>>.size == 8`.

### 2. A mag átültetése
- A [Sources/FDec/FDec.swift](Sources/FDec/FDec.swift) minden `Self.pow` és `Self.decimalPlaces` hivatkozása `S.pow` és `S.places` lesz.
- Megszűnik: `decimalPlaces` beállító, `ScaleConfiguration`, a befagyott `Scale` tároló, `setDecimalPlacesForTesting`, `zeroShift`, `intMaxDecimals`.
- Sorrend: init-ek és szövegértelmező → kiírás → aritmetika → kerekítés → protokollmegfelelések.
- Kész, ha: a mai `Test_Init`, `Test_Parsing`, `Test_Output`, `Test_Arithmetic`, `Test_Rounding`, `Test_SpecialValues`, `Test_Protocols` megfelelői zöldek.

### 3. A kiegészítések átültetése
- A [Sources/FDec/FDec+Extensions.swift](Sources/FDec/FDec+Extensions.swift) függvényei `extension Fixed` alá kerülnek. A kerekítési döntés (`Rest`) ekkor egyetlen helyre vonható össze, mert a két fájl közti `private` korlát megszűnik.
- A `Sequence where Element == FDec` kiterjesztés generikussá válik: `extension Sequence { func sum<S>() -> Fixed<S> where Element == Fixed<S> }`.
- Az `init(raw:scale:)` és a `rawValue(scale:)` megmarad adatbázis-oszlopokhoz, a futásidejű skálát paraméterként kapva.

### 4. Átalakítás skálák között (új funkció)
- `init<T>(_ other: Fixed<T>)` – csak akkor érhető el veszteség nélkül, ha a cél finomabb; durvább célnál a `rounding:` paraméter kötelező.
- `init?<T>(exactly other: Fixed<T>)` – `nil`, ha tizedes veszne el vagy az érték nem fér el.
- `multiplied<T>(by: Fixed<T>, rounding:)` és `divided<T>(by:rounding:)` – vegyes skálájú művelet, az eredmény a bal oldal típusa. A 128 bites köztes szorzatot a jobb oldal `pow`-jával kell visszaosztani.
- Kész, ha: véletlen értékeken a finomabb skálára és vissza vezető út veszteségmentes, a szűkítés pedig a `Decimal`-lal összevetve minden kerekítési módban egyezik.

### 5. Tesztek
- A mai [Tests/FDecTests/FDecTests.swift](Tests/FDecTests/FDecTests.swift) a kiindulás. A `setDecimalPlacesForTesting(n)` hívások helyére generikus segédfüggvények lépnek, amelyeket a teszt több típussal hív meg:
  ```swift
  func checkMultiplication<S: FixedScale>(_: S.Type) { ... }
  func test_Mul() { checkMultiplication(Places0.self); checkMultiplication(Places4.self); checkMultiplication(Places18.self) }
  ```
- A külön folyamatban futtatott befagyási próbák megszűnnek, mert nincs mit befagyasztani.
- Új: fordítási hibát váró esetek (vegyes skálájú operátor) dokumentált példaként, mert XCTesttel nem ellenőrizhetők.
- A hibabeültetéses ellenőrzést (szándékos hibák egyenként) az átültetés végén meg kell ismételni.

### 6. Teljesítménymérés
- `measure {}` a négy alapműveletre a mostani `main` ággal és a `Decimal`-lal összevetve.
- Elfogadási feltétel: a típusos változat nem lassabb a mostaninál. Ha az, az `@inlinable` jelölések hiányoznak valahol.

### 7. Dokumentáció és kiadás
- README és AGENT.md átírása, költöztetési útmutató a `FDec.decimalPlaces = n` → `typealias` váltáshoz.
- Új főverzió (2.0), mert a nyilvános API törik.

## Költöztetés a hívó oldalán

| Ma | Utána |
|---|---|
| `FDec.decimalPlaces = 2` induláskor | `typealias Money = Fixed<Places2>` |
| `FDec.decimalPlaces = 4` vagy semmi | semmi teendő, az `FDec` név `Fixed<Places4>` |
| `FDec.pow` | `Places4.pow` vagy `Money.scale.pow` |
| `FDec(raw: n)` adatbázisból | változatlan, de a skálát a típus rögzíti |
| JSON szövegként | változatlan |
| JSON nyers egészként (régi formátum) | egyszeri átalakítás kell |

## Nyitott kérdések

- **Elnevezés:** `Fixed<Places4>`, `FDec<Places4>` vagy `FDec4`-szerű kész nevek? Az utóbbi rövidebb, de 19 típusnév.
- **Maradjon-e az `FDec` név** a 4 tizedes aliasaként? Kényelmes a költöztetéshez, de elfedi, hogy a skála már nem állítható.
- **Kell-e futásidejű skála is?** Ha igen, az külön típus (`DynamicFixed`, amely az értékkel együtt tárolja a skálát, 16 bájton), nem ennek a tervnek a része.
- **Vegyes skálájú `+` és `-`:** legyen-e olyan változat, amely automatikusan a finomabb típust adja vissza? Kényelmes, de Swiftben a „két típus közül a finomabb" kifejezéséhez típusonkénti túlterhelés vagy makró kell.
- **Swift-verzió:** a terv Swift 5.7-tel megvalósítható. Egész értékű generikus paraméterrel (`Fixed<4>`, Swift 6.2-től) a 19 skálatípus fölöslegessé válna; megéri-e emiatt emelni a minimumot?
- **Egy csomag vagy kettő?** Külön ágon és főverzióként ugyanebben a repóban, vagy önálló csomagként más néven.
