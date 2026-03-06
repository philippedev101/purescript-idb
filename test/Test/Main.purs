module Test.Main where

import Prelude

import Data.Array (length)
import Data.Maybe (Maybe(..), isNothing)
import Effect (Effect)
import Effect.Aff (launchAff_)
import Effect.Class (liftEffect)
import Effect.Class.Console (log)
import Foreign (unsafeToForeign, unsafeFromForeign)
import Test.Assert (assert', assertEqual)
import Web.IDB as IDB

-- | Foreign import to force loading the FFI module, which injects fake-indexeddb.
foreign import _setupDone :: Boolean

main :: Effect Unit
main = launchAff_ do
  log "--- open ---"
  db <- IDB.open "test-db" 1 ["store1", "store2"]
  log "opened database with two stores"

  log "--- put / get ---"
  IDB.put db "store1" "k1" (unsafeToForeign "hello")
  result <- IDB.get db "store1" "k1"
  liftEffect $ assert' "put then get returns the value" case result of
    Just val -> (unsafeFromForeign val :: String) == "hello"
    Nothing  -> false

  log "--- get missing key returns Nothing ---"
  missing <- IDB.get db "store1" "nonexistent"
  liftEffect $ assert' "missing key returns Nothing" (isNothing missing)

  log "--- put overwrites existing key ---"
  IDB.put db "store1" "k1" (unsafeToForeign "updated")
  result2 <- IDB.get db "store1" "k1"
  liftEffect $ assert' "overwritten value is correct" case result2 of
    Just val -> (unsafeFromForeign val :: String) == "updated"
    Nothing  -> false

  log "--- delete ---"
  IDB.delete db "store1" "k1"
  afterDelete <- IDB.get db "store1" "k1"
  liftEffect $ assert' "get after delete returns Nothing" (isNothing afterDelete)

  log "--- delete non-existent key is no-op ---"
  IDB.delete db "store1" "does-not-exist"
  log "delete non-existent key did not throw"

  log "--- getAll ---"
  IDB.put db "store1" "a" (unsafeToForeign "1")
  IDB.put db "store1" "b" (unsafeToForeign "2")
  IDB.put db "store1" "c" (unsafeToForeign "3")
  all <- IDB.getAll db "store1"
  liftEffect $ assertEqual { expected: 3, actual: length all }

  log "--- getAll on empty store ---"
  empty <- IDB.getAll db "store2"
  liftEffect $ assertEqual { expected: 0, actual: length empty }

  log "--- clear ---"
  IDB.clear db "store1"
  afterClear <- IDB.getAll db "store1"
  liftEffect $ assertEqual { expected: 0, actual: length afterClear }

  log "--- clear already empty store ---"
  IDB.clear db "store2"
  log "clear on empty store did not throw"

  log "--- stores are isolated ---"
  IDB.put db "store1" "x" (unsafeToForeign "in-store1")
  IDB.put db "store2" "x" (unsafeToForeign "in-store2")
  r1 <- IDB.get db "store1" "x"
  r2 <- IDB.get db "store2" "x"
  liftEffect $ assert' "store1 has its own value" case r1 of
    Just val -> (unsafeFromForeign val :: String) == "in-store1"
    Nothing  -> false
  liftEffect $ assert' "store2 has its own value" case r2 of
    Just val -> (unsafeFromForeign val :: String) == "in-store2"
    Nothing  -> false

  log "--- non-string values ---"
  let obj = unsafeToForeign { name: "test", count: 42 }
  IDB.put db "store1" "obj" obj
  objResult <- IDB.get db "store1" "obj"
  liftEffect $ assert' "object round-trips" case objResult of
    Just val ->
      let r = unsafeFromForeign val :: { name :: String, count :: Int }
      in  r.name == "test" && r.count == 42
    Nothing -> false

  log "--- open existing database (re-open) ---"
  db2 <- IDB.open "test-db" 1 ["store1", "store2"]
  r3 <- IDB.get db2 "store1" "obj"
  liftEffect $ assert' "re-opened db sees previous data" case r3 of
    Just _  -> true
    Nothing -> false

  log "All tests passed"
