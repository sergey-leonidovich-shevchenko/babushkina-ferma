import { mkdtemp, copyFile, rm } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { createWikiServer, listen } from './server.mjs'
import { createPlanningStore } from './planning-store.mjs'
import { wikiRoot } from './runtime.mjs'

if (!process.argv.includes('--fixture')) throw new Error('Для проверки нужен явный --fixture')
const temporary = await mkdtemp(join(tmpdir(), 'farm-wiki-browser-review-'))
const stateFile = join(temporary, 'state.json')
await copyFile(join(wikiRoot, 'planning/state.json'), stateFile)
const server = createWikiServer(join(wikiRoot, 'dist'), {
  project: 'wiki-browser-fixture',
  allowSameOriginFrames: process.argv.includes('--frame'),
  planning: process.argv.includes('--static') ? false : { store: createPlanningStore(stateFile) },
})
const port = await listen(server, 4350)
console.log(`WIKI REVIEW: http://127.0.0.1:${port}/#/development/epics`)
console.log(`WIKI REVIEW STATE: ${stateFile}`)
/** Закрывает только свой стенд и временные решения, не затрагивая рабочую Wiki. */
async function stop() {
  server.close()
  server.closeAllConnections()
  await rm(temporary, { recursive: true, force: true })
}
process.once('SIGINT', () => {
  stop().then(() => process.exit())
})
process.once('SIGTERM', () => {
  stop().then(() => process.exit())
})
