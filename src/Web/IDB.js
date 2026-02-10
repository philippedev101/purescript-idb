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

export const _put = (db) => (store) => (key) => (value) => () =>
  db.put(store, value, key);

export const _delete = (db) => (store) => (key) => () =>
  db.delete(store, key);

export const _clear = (db) => (store) => () =>
  db.clear(store);
