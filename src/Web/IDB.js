import { openDB } from 'idb';

export const _open = (name) => (version) => (stores) => () =>
  openDB(name, version, {
    upgrade(db) {
      for (const store of stores) {
        if (!db.objectStoreNames.contains(store))
          db.createObjectStore(store);
      }
    }
  });

export const _get = (db) => (store) => (key) => () =>
  db.get(store, key).then(v => v === undefined ? null : v);

export const _getAll = (db) => (store) => () =>
  db.getAll(store);

export const _getAllKeys = (db) => (store) => () =>
  db.getAllKeys(store).then(keys => keys.map(String));

export const _getAllEntries = (db) => (store) => () => {
  const tx = db.transaction(store, 'readonly');
  return Promise.all([tx.store.getAllKeys(), tx.store.getAll()])
    .then(([keys, values]) => ({ keys: keys.map(String), values }));
};

export const _put = (db) => (store) => (key) => (value) => () =>
  db.put(store, value, key);

export const _delete = (db) => (store) => (key) => () =>
  db.delete(store, key);

export const _clear = (db) => (store) => () =>
  db.clear(store);

export const _withWriteTransaction = (db) => (store) => (callback) => () => {
  const tx = db.transaction(store, 'readwrite');
  callback(tx.store)();
  return tx.done;
};

export const _txPut = (txStore) => (key) => (value) => () => {
  txStore.put(value, key);
};

export const _txDelete = (txStore) => (key) => () => {
  txStore.delete(key);
};

export const _txClear = (txStore) => () => {
  txStore.clear();
};
