import test from 'node:test'
import assert from 'node:assert/strict'
import { refreshIdeaDraft } from '../src/lib/planning-draft.ts'

// Сценарий: две вкладки изменили разные поля, затем устаревшая вкладка обновила данные.
// Исходное состояние: местный заголовок и новые заметки в проекте.
// Ожидаемый результат: местный заголовок сохраняется, чужие заметки не затираются старым текстом.
test('refresh after conflict preserves local edits and accepts independent remote fields', () => {
  const previous = {
    title: 'Прежнее название',
    description: 'Описание',
    notes: 'Прежние заметки',
    group: 'world',
  }
  const current = { ...previous, title: 'Название из второй вкладки' }
  const incoming = {
    ...previous,
    title: 'Название из первой вкладки',
    notes: 'Новые заметки в проекте',
  }
  assert.deepEqual(refreshIdeaDraft(current, previous, incoming), {
    ...incoming,
    title: current.title,
  })
  assert.deepEqual(refreshIdeaDraft(previous, previous, incoming), incoming)
})
