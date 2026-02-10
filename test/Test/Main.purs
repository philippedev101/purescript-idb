module Test.Main where

import Prelude

import Data.Array (length)
import Data.Maybe (Maybe(..))
import Effect (Effect)
import Effect.Aff (launchAff_)
import Effect.Class.Console (log)
import Foreign (unsafeToForeign, unsafeFromForeign)
import Web.IDB as IDB

-- | Foreign import to force loading the FFI module, which injects fake-indexeddb.
foreign import _setupDone :: Boolean

main :: Effect Unit
main = launchAff_ do
  db <- IDB.open "test-db" 1 ["items"]
  log "opened database"

  IDB.put db "items" "key1" (unsafeToForeign "hello")
  log "put value"

  result <- IDB.get db "items" "key1"
  case result of
    Just val -> do
      let str = unsafeFromForeign val :: String
      when (str /= "hello") $ log "FAIL: value mismatch"
      log "get returned correct value"
    Nothing -> log "FAIL: get returned Nothing"

  IDB.delete db "items" "key1"
  log "deleted key"

  result2 <- IDB.get db "items" "key1"
  case result2 of
    Nothing -> log "get after delete returned Nothing"
    Just _ -> log "FAIL: get after delete returned Just"

  IDB.put db "items" "a" (unsafeToForeign "1")
  IDB.put db "items" "b" (unsafeToForeign "2")
  all <- IDB.getAll db "items"
  when (length all /= 2) $ log "FAIL: getAll count wrong"
  log "getAll returned 2 items"

  IDB.clear db "items"
  all2 <- IDB.getAll db "items"
  when (length all2 /= 0) $ log "FAIL: clear didn't work"
  log "clear emptied store"

  log "All tests passed"
