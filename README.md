# purescript-idb

PureScript FFI bindings for the [idb](https://github.com/nicolo-ribaudo/idb) library, providing a simple `Aff`-based API for IndexedDB.

## API

```purescript
open    :: String -> Int -> Array String -> Aff IDBDatabase
get     :: IDBDatabase -> String -> String -> Aff (Maybe Foreign)
getAll  :: IDBDatabase -> String -> Aff (Array Foreign)
put     :: IDBDatabase -> String -> String -> Foreign -> Aff Unit
delete  :: IDBDatabase -> String -> String -> Aff Unit
clear   :: IDBDatabase -> String -> Aff Unit
```

## Usage

```purescript
import Web.IDB as IDB
import Foreign (unsafeToForeign, unsafeFromForeign)

main :: Effect Unit
main = launchAff_ do
  db <- IDB.open "my-db" 1 ["items"]
  IDB.put db "items" "key1" (unsafeToForeign "hello")
  result <- IDB.get db "items" "key1"
  -- result :: Maybe Foreign
```

## Setup

Requires PureScript (`purs`) on PATH.

```bash
bun install
bunx spago build
bunx spago test
```

## Testing

Tests use [fake-indexeddb](https://github.com/nicolo-ribaudo/idb) to provide an in-memory IndexedDB implementation in Node.js.

```bash
bunx spago test
```
