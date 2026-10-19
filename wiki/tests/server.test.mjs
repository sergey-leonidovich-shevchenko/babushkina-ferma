import test from 'node:test'
import assert from 'node:assert/strict'
import { mkdir, writeFile, mkdtemp, rm, symlink, readFile } from 'node:fs/promises'
import { join } from 'node:path'
import { tmpdir } from 'node:os'
import { once } from 'node:events'
import { createServer } from 'node:http'
import { createWikiServer, resolveAsset, listen } from '../scripts/server.mjs'
import { publishBuild } from '../scripts/launch.mjs'

// Сценарий: браузер запрашивает главную страницу, PNG, версию и файл вне сборки.
// Исходное состояние: временный сервер на loopback с независимой папкой сайта.
// Ожидаемый результат: правильные MIME и адреса, только свой каталог, без чтения соседних файлов или остановки чужим запросом.
test('static server serves assets and denies escape or unauthenticated control', async () => {
  const root = await mkdtemp(join(tmpdir(), 'farm wiki test '))
  const dist = join(root, 'dist')
  await mkdir(dist)
  await writeFile(join(dist, 'index.html'), '<h1>Wiki</h1>')
  await writeFile(join(dist, 'walk.mp4'), 'video fixture')
  await writeFile(join(root, 'private.txt'), 'private')
  await symlink(join(root, 'private.txt'), join(dist, 'outside.txt'))
  const server = createWikiServer(dist, { project: 'fixture-project', token: 'fixture-token' })
  server.listen(0, '127.0.0.1')
  await once(server, 'listening')
  const url = `http://127.0.0.1:${server.address().port}`
  try {
    const response = await fetch(url)
    assert.equal(response.status, 200)
    assert.equal(response.headers.get('x-frame-options'), 'DENY')
    assert.match(response.headers.get('content-type'), /text\/html/)
    assert.match(await response.text(), /Wiki/)
    const movie = await fetch(`${url}/walk.mp4`)
    assert.equal(movie.headers.get('content-type'), 'video/mp4')
    assert.equal(await movie.text(), 'video fixture')
    assert.deepEqual(await (await fetch(`${url}/__wiki/status`)).json(), {
      app: 'moon-valley-wiki',
      project: 'fixture-project',
      pid: process.pid,
      planning: 1,
    })
    assert.equal((await resolveAsset(dist, '/%2e%2e%2fprivate.txt')).error, 403)
    assert.equal((await fetch(`${url}/outside.txt`)).status, 403)
    assert.equal((await fetch(`${url}/__wiki/stop`, { method: 'POST' })).status, 403)
    assert.equal((await fetch(`${url}/missing.js`)).status, 404)
    assert.equal((await fetch(url, { method: 'POST' })).status, 405)
  } finally {
    server.close()
    server.closeAllConnections()
    await rm(root, { recursive: true, force: true })
  }
})

// Сценарий: стандартный порт wiki занят другим приложением.
// Исходное состояние: два независимых сервера на loopback.
// Ожидаемый результат: wiki выбирает соседний свободный порт, чужой сервер продолжает работать.
test('occupied ports are skipped without stopping another application', async () => {
  const foreign = createServer((_req, res) => res.end('foreign'))
  foreign.listen(0, '127.0.0.1')
  await once(foreign, 'listening')
  const server = createWikiServer('/unused')
  try {
    const first = foreign.address().port
    const port = await listen(server, first)
    assert.notEqual(port, first)
    assert.equal(await (await fetch(`http://127.0.0.1:${first}`)).text(), 'foreign')
  } finally {
    foreign.close()
    foreign.closeAllConnections()
    server.close()
    server.closeAllConnections()
  }
})

// Сценарий: сборка заменяет прежний сайт, затем повторная попытка публикации ломается.
// Исходное состояние: старая рабочая версия и отдельная новая папка.
// Ожидаемый результат: новая версия публикуется целиком, а неудачная попытка не удаляет последнюю рабочую версию.
test('build publication is complete and failed replacement restores the working version', async () => {
  const root = await mkdtemp(join(tmpdir(), 'farm wiki publication '))
  const old = join(root, 'dist')
  const next = join(root, 'next')
  await mkdir(old)
  await mkdir(next)
  await writeFile(join(old, 'index.html'), 'old')
  await writeFile(join(next, 'index.html'), 'new')
  try {
    await publishBuild(next, old)
    assert.equal(await readFile(join(old, 'index.html'), 'utf8'), 'new')
    await assert.rejects(() => publishBuild(join(root, 'missing'), old))
    assert.equal(await readFile(join(old, 'index.html'), 'utf8'), 'new')
  } finally {
    await rm(root, { recursive: true, force: true })
  }
})
