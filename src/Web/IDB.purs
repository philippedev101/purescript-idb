module Web.IDB
  ( IDBDatabase
  , open
  , get
  , getAll
  , put
  , delete
  , clear
  ) where

import Prelude

import Data.Maybe (Maybe)
import Data.Nullable (Nullable, toMaybe)
import Effect (Effect)
import Effect.Aff (Aff)
import Foreign (Foreign)
import Promise (Promise)
import Promise.Aff (toAffE)

foreign import data IDBDatabase :: Type

foreign import _open :: String -> Int -> Array String -> Effect (Promise IDBDatabase)
foreign import _get :: IDBDatabase -> String -> String -> Effect (Promise (Nullable Foreign))
foreign import _getAll :: IDBDatabase -> String -> Effect (Promise (Array Foreign))
foreign import _put :: IDBDatabase -> String -> String -> Foreign -> Effect (Promise Unit)
foreign import _delete :: IDBDatabase -> String -> String -> Effect (Promise Unit)
foreign import _clear :: IDBDatabase -> String -> Effect (Promise Unit)

-- | Open (or create) a database. Creates any missing object stores.
open :: String -> Int -> Array String -> Aff IDBDatabase
open name version stores = toAffE (_open name version stores)

-- | Get a value by key from a store. Returns Nothing if not found.
get :: IDBDatabase -> String -> String -> Aff (Maybe Foreign)
get db store key = map toMaybe (toAffE (_get db store key))

-- | Get all values from a store.
getAll :: IDBDatabase -> String -> Aff (Array Foreign)
getAll db store = toAffE (_getAll db store)

-- | Put a value at a key in a store (upsert).
put :: IDBDatabase -> String -> String -> Foreign -> Aff Unit
put db store key value = toAffE (_put db store key value)

-- | Delete a key from a store.
delete :: IDBDatabase -> String -> String -> Aff Unit
delete db store key = toAffE (_delete db store key)

-- | Clear all entries in a store.
clear :: IDBDatabase -> String -> Aff Unit
clear db store = toAffE (_clear db store)
