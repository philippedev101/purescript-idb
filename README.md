# purescript-idb

PureScript FFI bindings for the [idb](https://github.com/nicolo-ribaudo/idb) library, providing a simple `Aff`-based API for IndexedDB.

## API

### Single-key operations

```purescript
open    :: String -> Int -> Array String -> Aff IDBDatabase
get     :: IDBDatabase -> String -> String -> Aff (Maybe Foreign)
put     :: IDBDatabase -> String -> String -> Foreign -> Aff Unit
delete  :: IDBDatabase -> String -> String -> Aff Unit
clear   :: IDBDatabase -> String -> Aff Unit
```

### Bulk reads

```purescript
getAll      :: IDBDatabase -> String -> Aff (Array Foreign)
getAllKeys   :: IDBDatabase -> String -> Aff (Array String)
getAllEntries :: IDBDatabase -> String -> Aff (Array (Tuple String Foreign))
```

`getAllEntries` reads keys and values in a single readonly transaction, guaranteeing consistency.

### Transaction API

```purescript
withWriteTransaction :: IDBDatabase -> String -> (TxStore -> Effect Unit) -> Aff Unit
txPut    :: TxStore -> String -> Foreign -> Effect Unit
txDelete :: TxStore -> String -> Effect Unit
txClear  :: TxStore -> Effect Unit
```

The callback is `Effect` (not `Aff`) to prevent the transaction from auto-committing between async operations.

### Convenience batch operations

Built on `withWriteTransaction`:

```purescript
putBatch        :: IDBDatabase -> String -> Array (Tuple String Foreign) -> Aff Unit
clearAndPutBatch :: IDBDatabase -> String -> Array (Tuple String Foreign) -> Aff Unit
deleteBatch     :: IDBDatabase -> String -> Array String -> Aff Unit
```

## Usage

```purescript
import Web.IDB as IDB
import Data.Tuple (Tuple(..))
import Foreign (unsafeToForeign, unsafeFromForeign)

main :: Effect Unit
main = launchAff_ do
  db <- IDB.open "my-db" 1 ["items"]

  -- Single key
  IDB.put db "items" "key1" (unsafeToForeign "hello")
  result <- IDB.get db "items" "key1"
  -- result :: Maybe Foreign

  -- Batch write (single transaction)
  IDB.putBatch db "items"
    [ Tuple "a" (unsafeToForeign "val-a")
    , Tuple "b" (unsafeToForeign "val-b")
    ]

  -- Mixed put + delete in one atomic transaction
  IDB.withWriteTransaction db "items" \tx -> do
    IDB.txPut tx "new-key" (unsafeToForeign "value")
    IDB.txDelete tx "old-key"
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
