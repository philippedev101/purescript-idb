module Test.Main where

import Prelude

import Data.Array (length, sort)
import Data.Maybe (Maybe(..), isNothing)
import Data.Tuple (Tuple(..), fst)
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

  -- Clean up for new tests
  IDB.clear db "store1"
  IDB.clear db "store2"

  -----------------------------------------------------------------------
  -- getAllKeys
  -----------------------------------------------------------------------

  log "--- getAllKeys ---"
  IDB.put db "store1" "zz" (unsafeToForeign "v1")
  IDB.put db "store1" "aa" (unsafeToForeign "v2")
  IDB.put db "store1" "mm" (unsafeToForeign "v3")
  keys <- IDB.getAllKeys db "store1"
  liftEffect $ assertEqual { expected: 3, actual: length keys }
  liftEffect $ assertEqual { expected: ["aa", "mm", "zz"], actual: sort keys }

  log "--- getAllKeys on empty store ---"
  emptyKeys <- IDB.getAllKeys db "store2"
  liftEffect $ assertEqual { expected: 0, actual: length emptyKeys }

  -----------------------------------------------------------------------
  -- getAllEntries
  -----------------------------------------------------------------------

  log "--- getAllEntries ---"
  entries <- IDB.getAllEntries db "store1"
  liftEffect $ assertEqual { expected: 3, actual: length entries }
  -- IDB returns entries sorted by key: aa, mm, zz
  liftEffect $ assertEqual { expected: ["aa", "mm", "zz"], actual: map fst entries }
  liftEffect $ assertEqual { expected: ["v2", "v3", "v1"], actual: map (\(Tuple _ v) -> unsafeFromForeign v :: String) entries }

  log "--- getAllEntries on empty store ---"
  emptyEntries <- IDB.getAllEntries db "store2"
  liftEffect $ assertEqual { expected: 0, actual: length emptyEntries }

  -----------------------------------------------------------------------
  -- withWriteTransaction + txPut
  -----------------------------------------------------------------------

  log "--- withWriteTransaction + txPut ---"
  IDB.clear db "store1"
  IDB.withWriteTransaction db "store1" \tx -> do
    IDB.txPut tx "t1" (unsafeToForeign "val1")
    IDB.txPut tx "t2" (unsafeToForeign "val2")
    IDB.txPut tx "t3" (unsafeToForeign "val3")
  txAll <- IDB.getAll db "store1"
  liftEffect $ assertEqual { expected: 3, actual: length txAll }
  t1 <- IDB.get db "store1" "t1"
  liftEffect $ assert' "txPut wrote correct value" case t1 of
    Just val -> (unsafeFromForeign val :: String) == "val1"
    Nothing  -> false

  -----------------------------------------------------------------------
  -- withWriteTransaction + txClear + txPut
  -----------------------------------------------------------------------

  log "--- withWriteTransaction + txClear + txPut ---"
  IDB.withWriteTransaction db "store1" \tx -> do
    IDB.txClear tx
    IDB.txPut tx "new1" (unsafeToForeign "fresh")
  afterReplace <- IDB.getAll db "store1"
  liftEffect $ assertEqual { expected: 1, actual: length afterReplace }
  n1 <- IDB.get db "store1" "new1"
  liftEffect $ assert' "txClear + txPut replaced contents" case n1 of
    Just val -> (unsafeFromForeign val :: String) == "fresh"
    Nothing  -> false
  -- Old keys should be gone
  gone <- IDB.get db "store1" "t1"
  liftEffect $ assert' "old key removed after txClear" (isNothing gone)

  -----------------------------------------------------------------------
  -- withWriteTransaction + txDelete
  -----------------------------------------------------------------------

  log "--- withWriteTransaction + txDelete ---"
  IDB.clear db "store1"
  IDB.put db "store1" "d1" (unsafeToForeign "keep")
  IDB.put db "store1" "d2" (unsafeToForeign "remove")
  IDB.put db "store1" "d3" (unsafeToForeign "remove")
  IDB.withWriteTransaction db "store1" \tx -> do
    IDB.txDelete tx "d2"
    IDB.txDelete tx "d3"
  afterTxDelete <- IDB.getAll db "store1"
  liftEffect $ assertEqual { expected: 1, actual: length afterTxDelete }
  kept <- IDB.get db "store1" "d1"
  liftEffect $ assert' "txDelete kept undeleted key" case kept of
    Just val -> (unsafeFromForeign val :: String) == "keep"
    Nothing  -> false

  -----------------------------------------------------------------------
  -- withWriteTransaction: mixed put + delete (Phase 2 use case)
  -----------------------------------------------------------------------

  log "--- withWriteTransaction: mixed put + delete ---"
  IDB.clear db "store1"
  IDB.put db "store1" "old" (unsafeToForeign "to-remove")
  IDB.withWriteTransaction db "store1" \tx -> do
    IDB.txDelete tx "old"
    IDB.txPut tx "new" (unsafeToForeign "added")
  mixedAll <- IDB.getAll db "store1"
  liftEffect $ assertEqual { expected: 1, actual: length mixedAll }
  oldGone <- IDB.get db "store1" "old"
  liftEffect $ assert' "mixed: old key deleted" (isNothing oldGone)
  newAdded <- IDB.get db "store1" "new"
  liftEffect $ assert' "mixed: new key added" case newAdded of
    Just val -> (unsafeFromForeign val :: String) == "added"
    Nothing  -> false

  -----------------------------------------------------------------------
  -- putBatch
  -----------------------------------------------------------------------

  log "--- putBatch ---"
  IDB.clear db "store1"
  IDB.putBatch db "store1"
    [ Tuple "b1" (unsafeToForeign "batch1")
    , Tuple "b2" (unsafeToForeign "batch2")
    , Tuple "b3" (unsafeToForeign "batch3")
    ]
  batchAll <- IDB.getAll db "store1"
  liftEffect $ assertEqual { expected: 3, actual: length batchAll }
  b2 <- IDB.get db "store1" "b2"
  liftEffect $ assert' "putBatch wrote correct value" case b2 of
    Just val -> (unsafeFromForeign val :: String) == "batch2"
    Nothing  -> false

  log "--- putBatch empty array ---"
  IDB.putBatch db "store1" []
  stillThree <- IDB.getAll db "store1"
  liftEffect $ assertEqual { expected: 3, actual: length stillThree }

  log "--- putBatch overwrites existing keys ---"
  IDB.putBatch db "store1"
    [ Tuple "b1" (unsafeToForeign "overwritten")
    , Tuple "b4" (unsafeToForeign "new")
    ]
  afterOverwrite <- IDB.getAll db "store1"
  liftEffect $ assertEqual { expected: 4, actual: length afterOverwrite }
  ob1 <- IDB.get db "store1" "b1"
  liftEffect $ assert' "putBatch overwrote existing key" case ob1 of
    Just val -> (unsafeFromForeign val :: String) == "overwritten"
    Nothing  -> false

  log "--- putBatch duplicate keys uses last value ---"
  IDB.clear db "store1"
  IDB.putBatch db "store1"
    [ Tuple "dup" (unsafeToForeign "first")
    , Tuple "dup" (unsafeToForeign "second")
    ]
  dupAll <- IDB.getAll db "store1"
  liftEffect $ assertEqual { expected: 1, actual: length dupAll }
  dupVal <- IDB.get db "store1" "dup"
  liftEffect $ assert' "putBatch duplicate key keeps last value" case dupVal of
    Just val -> (unsafeFromForeign val :: String) == "second"
    Nothing  -> false

  -----------------------------------------------------------------------
  -- clearAndPutBatch
  -----------------------------------------------------------------------

  log "--- clearAndPutBatch ---"
  IDB.clearAndPutBatch db "store1"
    [ Tuple "r1" (unsafeToForeign "replaced1")
    , Tuple "r2" (unsafeToForeign "replaced2")
    ]
  replacedAll <- IDB.getAll db "store1"
  liftEffect $ assertEqual { expected: 2, actual: length replacedAll }
  oldB1 <- IDB.get db "store1" "b1"
  liftEffect $ assert' "clearAndPutBatch removed old keys" (isNothing oldB1)
  rr1 <- IDB.get db "store1" "r1"
  liftEffect $ assert' "clearAndPutBatch wrote new keys" case rr1 of
    Just val -> (unsafeFromForeign val :: String) == "replaced1"
    Nothing  -> false

  log "--- clearAndPutBatch with empty array clears store ---"
  IDB.clearAndPutBatch db "store1" []
  clearedAll <- IDB.getAll db "store1"
  liftEffect $ assertEqual { expected: 0, actual: length clearedAll }

  -----------------------------------------------------------------------
  -- deleteBatch
  -----------------------------------------------------------------------

  log "--- deleteBatch ---"
  IDB.put db "store1" "x1" (unsafeToForeign "keep")
  IDB.put db "store1" "x2" (unsafeToForeign "del")
  IDB.put db "store1" "x3" (unsafeToForeign "del")
  IDB.put db "store1" "x4" (unsafeToForeign "keep")
  IDB.deleteBatch db "store1" ["x2", "x3"]
  afterDeleteBatch <- IDB.getAll db "store1"
  liftEffect $ assertEqual { expected: 2, actual: length afterDeleteBatch }
  dx1 <- IDB.get db "store1" "x1"
  liftEffect $ assert' "deleteBatch kept x1" case dx1 of
    Just val -> (unsafeFromForeign val :: String) == "keep"
    Nothing  -> false
  dx2 <- IDB.get db "store1" "x2"
  liftEffect $ assert' "deleteBatch removed x2" (isNothing dx2)

  log "--- deleteBatch empty array ---"
  IDB.deleteBatch db "store1" []
  stillTwo <- IDB.getAll db "store1"
  liftEffect $ assertEqual { expected: 2, actual: length stillTwo }

  log "--- deleteBatch non-existent keys ---"
  IDB.deleteBatch db "store1" ["nope1", "nope2"]
  stillTwoAfter <- IDB.getAll db "store1"
  liftEffect $ assertEqual { expected: 2, actual: length stillTwoAfter }

  -----------------------------------------------------------------------
  -- withWriteTransaction: empty callback (no-op)
  -----------------------------------------------------------------------

  log "--- withWriteTransaction empty callback ---"
  IDB.clear db "store1"
  IDB.put db "store1" "survive" (unsafeToForeign "yes")
  IDB.withWriteTransaction db "store1" \_ -> pure unit
  survivor <- IDB.get db "store1" "survive"
  liftEffect $ assert' "empty transaction is a no-op" case survivor of
    Just val -> (unsafeFromForeign val :: String) == "yes"
    Nothing  -> false

  log "All tests passed"
