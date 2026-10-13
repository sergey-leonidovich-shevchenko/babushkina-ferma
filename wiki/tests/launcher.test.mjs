import test from 'node:test'
import assert from 'node:assert/strict'
import { readFile, stat } from 'node:fs/promises'
import { spawnSync } from 'node:child_process'
import { join } from 'node:path'
import { projectRoot } from '../scripts/runtime.mjs'

// Сценарий: пользователь открывает приложение рядом с игрой, когда путь содержит пробел и кириллицу.
// Исходное состояние: стандартный bundle с собственным исполняемым файлом и иконкой.
// Ожидаемый результат: правильная папка wiki, executable-bit и распознаваемый значок macOS.
test('desktop bundle contains a real ICNS and a portable executable launcher', async () => {
  const bundle = join(projectRoot, 'Лунная долина Wiki.app/Contents')
  const info = await readFile(join(bundle, 'Info.plist'), 'utf8')
  assert.match(info, /<string>launch<\/string>/)
  assert.match(info, /<string>AppIcon<\/string>/)
  const icon = await readFile(join(bundle, 'Resources/AppIcon.icns'))
  assert.equal(icon.subarray(0, 4).toString(), 'icns')
  assert.equal(icon.readUInt32BE(4), icon.length)
  assert.ok((await stat(join(bundle, 'MacOS/launch'))).mode & 0o111)
  if (process.platform === 'darwin') {
    const result = spawnSync('/bin/zsh', [join(bundle, 'MacOS/launch')], {
      env: { ...process.env, WIKI_LAUNCHER_CHECK: '1', WIKI_NODE_BIN: process.execPath },
      encoding: 'utf8',
    })
    assert.equal(result.status, 0)
    assert.ok(result.stdout.includes(join(projectRoot, 'wiki/scripts/launch.mjs')))
  }
})
