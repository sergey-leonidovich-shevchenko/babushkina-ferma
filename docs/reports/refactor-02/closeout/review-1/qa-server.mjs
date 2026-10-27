// The actual candidate catalog is readable; this QA server cannot save planning changes.
import { readFile } from 'node:fs/promises'
import { resolve } from 'node:path'
import { createWikiServer, listen } from '../../../../../wiki/scripts/server.mjs'
import { readPlanningCatalog } from '../../../../../wiki/scripts/planning-catalog.mjs'

const root = process.cwd()
const state = JSON.parse(await readFile(resolve(root, 'wiki/planning/state.json'), 'utf8'))
const project = 'REFACTOR-02-review1-QA'
const server = createWikiServer(resolve(root, 'wiki/dist'), {
  project,
  planning: {
    loadCatalog: readPlanningCatalog,
    store: {
      read: async () => state,
      change: async () => { throw new Error('QA is read only') },
    },
  },
})
const port = await listen(server, 4192)
console.log(JSON.stringify({ project, port, pid: process.pid, url: `http://127.0.0.1:${port}/` }))
