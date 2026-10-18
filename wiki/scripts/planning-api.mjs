import { readPlanningCatalog } from './planning-catalog.mjs'
import { agentBrief, createPlanningStore, PlanningError } from './planning-store.mjs'

/** Возвращает только JSON без кеширования редакционных решений. */
function json(response, status, value) {
  response.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Cache-Control': 'no-store',
  })
  response.end(JSON.stringify(value))
}

/** Обслуживает фиксированные локальные маршруты без произвольного чтения и записи файлов. */
export function createPlanningApi({
  store = createPlanningStore(),
  loadCatalog = readPlanningCatalog,
} = {}) {
  return async (request, response, pathname) => {
    if (!pathname.startsWith('/__wiki/planning')) return false
    try {
      const origin = `http://${request.headers.host}`
      if (
        !/^http:\/\/(?:127\.0\.0\.1|localhost):\d+$/.test(origin) ||
        (request.headers.origin && request.headers.origin !== origin)
      )
        throw new PlanningError('Запрос должен идти из локальной Wiki', 403)
      if (
        request.method === 'GET' &&
        ['/__wiki/planning', '/__wiki/planning/queue'].includes(pathname)
      ) {
        const catalog = await loadCatalog()
        const workspace = await store.read(catalog)
        json(
          response,
          200,
          pathname.endsWith('/queue')
            ? {
                schema: 1,
                revision: workspace.revision,
                ideas: workspace.ideas
                  .filter((idea) => ['approved', 'refining'].includes(idea.status))
                  .map((idea) => ({ ...idea, brief: agentBrief(idea) })),
              }
            : { schema: 1, catalog, workspace, readOnly: false }
        )
      } else if (request.method === 'POST' && pathname === '/__wiki/planning/change') {
        if (
          request.headers['x-wiki-planning'] !== '1' ||
          request.headers['content-type']?.split(';')[0] !== 'application/json'
        )
          throw new PlanningError('Нужен JSON-запрос из центра разработки', 403)
        let size = 0
        const chunks = []
        for await (const chunk of request) {
          size += chunk.length
          if (size > 262144) throw new PlanningError('Слишком большой запрос', 413)
          chunks.push(chunk)
        }
        let action
        try {
          action = JSON.parse(Buffer.concat(chunks).toString('utf8'))
        } catch {
          throw new PlanningError('Некорректный JSON')
        }
        const workspace = await store.change(action, await loadCatalog())
        json(response, 200, { workspace })
      } else json(response, 404, { error: 'Маршрут не найден' })
    } catch (error) {
      json(response, error instanceof PlanningError ? error.status : 503, {
        error:
          error instanceof PlanningError
            ? error.message
            : 'Не удалось прочитать или сохранить планы. Повторите загрузку.',
      })
    }
    return true
  }
}
