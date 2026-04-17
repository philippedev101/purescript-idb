-- | PureScript FFI bindings for IndexedDB via the
-- | [idb](https://www.npmjs.com/package/idb) library.
-- |
-- | All operations run in `Aff` and work with any IndexedDB-compatible
-- | environment (browsers, or Node.js with `fake-indexeddb`).
-- |
-- | ## Transaction safety
-- |
-- | IndexedDB transactions auto-commit when there are no pending requests
-- | on the event loop. `withWriteTransaction` enforces this by accepting
-- | an `Effect` callback (synchronous), preventing accidental `await`s
-- | that would close the transaction prematurely.
module Web.IDB
  ( IDBDatabase
  , TxStore
  -- Opening
  , open
  -- Single-key reads
  , get
  -- Bulk reads
  , getAll
  , getAllKeys
  , getAllEntries
  -- Single-key writes (auto-transaction)
  , put
  , delete
  , clear
  -- Transaction API
  , withWriteTransaction
  , txPut
  , txDelete
  , txClear
  -- Convenience batch operations
  , putBatch
  , clearAndPutBatch
  , deleteBatch
  ) where

import Prelude

import Data.Array (zipWith)
import Data.Foldable (for_)
import Data.Maybe (Maybe)
import Data.Nullable (Nullable, toMaybe)
import Data.Tuple (Tuple(..))
import Effect (Effect)
import Effect.Aff (Aff)
import Foreign (Foreign)
import Promise (Promise)
import Promise.Aff (toAffE)

-- | An opaque handle to an open IndexedDB database.
foreign import data IDBDatabase :: Type

-- | An opaque handle to an object store within a write transaction.
-- | Operations on TxStore are synchronous (Effect) to prevent the
-- | transaction from auto-committing between async operations.
foreign import data TxStore :: Type

foreign import _open :: String -> Int -> Array String -> Effect (Promise IDBDatabase)
foreign import _get :: IDBDatabase -> String -> String -> Effect (Promise (Nullable Foreign))
foreign import _getAll :: IDBDatabase -> String -> Effect (Promise (Array Foreign))
foreign import _getAllKeys :: IDBDatabase -> String -> Effect (Promise (Array String))
foreign import _getAllEntries :: IDBDatabase -> String -> Effect (Promise { keys :: Array String, values :: Array Foreign })
foreign import _put :: IDBDatabase -> String -> String -> Foreign -> Effect (Promise Unit)
foreign import _delete :: IDBDatabase -> String -> String -> Effect (Promise Unit)
foreign import _clear :: IDBDatabase -> String -> Effect (Promise Unit)
foreign import _withWriteTransaction :: IDBDatabase -> String -> (TxStore -> Effect Unit) -> Effect (Promise Unit)
foreign import _txPut :: TxStore -> String -> Foreign -> Effect Unit
foreign import _txDelete :: TxStore -> String -> Effect Unit
foreign import _txClear :: TxStore -> Effect Unit


------------------------------------------------------------------------
-- Opening
------------------------------------------------------------------------

-- | Open (or create) a database. Creates any missing object stores.
open :: String -> Int -> Array String -> Aff IDBDatabase
open name version stores = toAffE (_open name version stores)


------------------------------------------------------------------------
-- Single-key reads
------------------------------------------------------------------------

-- | Get a value by key from a store. Returns Nothing if not found.
get :: IDBDatabase -> String -> String -> Aff (Maybe Foreign)
get db store key = map toMaybe (toAffE (_get db store key))


------------------------------------------------------------------------
-- Bulk reads
------------------------------------------------------------------------

-- | Get all values from a store.
getAll :: IDBDatabase -> String -> Aff (Array Foreign)
getAll db store = toAffE (_getAll db store)

-- | Get all keys from a store (as strings).
getAllKeys :: IDBDatabase -> String -> Aff (Array String)
getAllKeys db store = toAffE (_getAllKeys db store)

-- | Get all key-value pairs from a store in a single readonly transaction.
-- | This is atomic: keys and values are guaranteed to be consistent.
getAllEntries :: IDBDatabase -> String -> Aff (Array (Tuple String Foreign))
getAllEntries db store = do
  { keys, values } <- toAffE (_getAllEntries db store)
  pure $ zipWith Tuple keys values


------------------------------------------------------------------------
-- Single-key writes (each creates its own auto-committed transaction)
------------------------------------------------------------------------

-- | Put a value at a key in a store (upsert).
put :: IDBDatabase -> String -> String -> Foreign -> Aff Unit
put db store key value = toAffE (_put db store key value)

-- | Delete a key from a store.
delete :: IDBDatabase -> String -> String -> Aff Unit
delete db store key = toAffE (_delete db store key)

-- | Clear all entries in a store.
clear :: IDBDatabase -> String -> Aff Unit
clear db store = toAffE (_clear db store)


------------------------------------------------------------------------
-- Transaction API
------------------------------------------------------------------------

-- | Execute a batch of write operations in a single atomic transaction.
-- |
-- | The callback receives a `TxStore` handle and must queue all operations
-- | synchronously using `txPut`, `txDelete`, and `txClear`. The transaction
-- | commits automatically when all queued operations complete.
-- |
-- | The callback is `Effect` (not `Aff`) to prevent awaiting between
-- | operations, which would cause the transaction to auto-commit.
withWriteTransaction :: IDBDatabase -> String -> (TxStore -> Effect Unit) -> Aff Unit
withWriteTransaction db store callback = toAffE (_withWriteTransaction db store callback)

-- | Queue a put (upsert) operation within a write transaction.
txPut :: TxStore -> String -> Foreign -> Effect Unit
txPut = _txPut

-- | Queue a delete operation within a write transaction.
txDelete :: TxStore -> String -> Effect Unit
txDelete = _txDelete

-- | Queue a clear operation within a write transaction.
txClear :: TxStore -> Effect Unit
txClear = _txClear


------------------------------------------------------------------------
-- Convenience batch operations (built on withWriteTransaction)
------------------------------------------------------------------------

-- | Put multiple key-value pairs in a single atomic transaction.
putBatch :: IDBDatabase -> String -> Array (Tuple String Foreign) -> Aff Unit
putBatch db store entries = withWriteTransaction db store \tx ->
  for_ entries \(Tuple key value) -> txPut tx key value

-- | Clear a store then put multiple key-value pairs, all in one atomic transaction.
clearAndPutBatch :: IDBDatabase -> String -> Array (Tuple String Foreign) -> Aff Unit
clearAndPutBatch db store entries = withWriteTransaction db store \tx -> do
  txClear tx
  for_ entries \(Tuple key value) -> txPut tx key value

-- | Delete multiple keys in a single atomic transaction.
deleteBatch :: IDBDatabase -> String -> Array String -> Aff Unit
deleteBatch db store keys = withWriteTransaction db store \tx ->
  for_ keys \key -> txDelete tx key
