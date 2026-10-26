// Только QA: копия каталога на loopback; редакционные операции намеренно недоступны.
import { readFile } from 'node:fs/promises'
import { resolve } from 'node:path'
import { createWikiServer, listen } from '../../../wiki/scripts/server.mjs'

const root = process.cwd()
const fixture = resolve(root, 'tmp/wiki003-browser-catalog.json')
const seed = JSON.parse(await readFile(resolve(root, 'wiki/planning/state.json'), 'utf8'))
const server = createWikiServer(resolve(root, 'wiki/dist'), {
  project: 'WIKI-003-isolated-read-only-QA',
  allowSameOriginFrames: true,
  planning: {
    loadCatalog: async () => JSON.parse(await readFile(fixture, 'utf8')),
    store: {
      read: async () => seed,
      change: async () => { throw new Error('QA fixture is read only') },
    },
  },
})
console.log(`WIKI-003 QA: http://127.0.0.1:${await listen(server, 4186)}/#/development/first-location`)
