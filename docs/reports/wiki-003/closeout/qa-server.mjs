// Только чтение настоящего канонического каталога: QA не создаёт свой реестр статусов.
import { readFile } from 'node:fs/promises'
import { resolve } from 'node:path'
import { createWikiServer, listen } from '../../../../wiki/scripts/server.mjs'
import { readPlanningCatalog } from '../../../../wiki/scripts/planning-catalog.mjs'

const root = process.cwd()
const seed = JSON.parse(await readFile(resolve(root, 'wiki/planning/state.json'), 'utf8'))
const server = createWikiServer(resolve(root, 'wiki/dist'), {
  project: 'WIKI-003-closeout-read-only-QA',
  allowSameOriginFrames: true,
  planning: {
    loadCatalog: readPlanningCatalog,
    store: {
      read: async () => seed,
      change: async () => {
        throw new Error('QA is read only')
      },
    },
  },
})
console.log(
  `WIKI-003 closeout QA: http://127.0.0.1:${await listen(server, 4190)}/#/development/first-location`
)
