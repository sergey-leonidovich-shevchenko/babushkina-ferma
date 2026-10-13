import test from 'node:test'
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import { join } from 'node:path'
import { wikiRoot, projectRoot } from '../scripts/runtime.mjs'

// Сценарий: wiki и игровые окна используют выбранную светлую тему B.
// Исходное состояние: доступны настоящие CSS-токены сайта и общая игровая палитра.
// Ожидаемый результат: фон, текст, выбор и акцент совпадают, а подписи сохраняют контраст 4,5:1.
test('wiki shares readable parchment roles with the game', async () => {
  const css = await readFile(join(wikiRoot, 'src/style.css'), 'utf8')
  const game = await readFile(join(projectRoot, 'scripts/presentation/paper_theme_palette.gd'), 'utf8')
  const roles = { paper: 'PANEL', inset: 'INSET', selected: 'SELECTED', ink: 'TEXT', muted: 'MUTED', green: 'ACCENT_TEXT', 'on-accent': 'ON_ACCENT' }
  const colors = {}
  for (const [token, role] of Object.entries(roles)) {
    colors[token] = css.match(new RegExp(`--${token}: #([a-f0-9]{6});`))?.[1]
    assert.equal(colors[token], game.match(new RegExp(`const ${role} := Color\\("([a-f0-9]{6})"\\)`))?.[1], token)
  }
  const brightness = (hex) => hex.match(/../g).map((x) => parseInt(x, 16) / 255).reduce((sum, x, i) => sum + (x <= .04045 ? x / 12.92 : ((x + .055) / 1.055) ** 2.4) * [.2126, .7152, .0722][i], 0)
  const contrast = (a, b) => (Math.max(brightness(a), brightness(b)) + .05) / (Math.min(brightness(a), brightness(b)) + .05)
  for (const surface of ['paper', 'inset', 'selected']) {
    for (const ink of ['ink', 'muted', 'green']) assert.ok(contrast(colors[ink], colors[surface]) >= 4.5, `${ink} on ${surface}`)
  }
  assert.ok(contrast(colors['on-accent'], colors.green) >= 4.5)
})
