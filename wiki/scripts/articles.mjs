import { readFile } from 'node:fs/promises'
import { resolve, sep } from 'node:path'
import { wikiRoot } from './runtime.mjs'

/** Загружает самостоятельные статьи с постоянными адресами из явного редакционного списка. */
export async function articles(root = resolve(wikiRoot, 'articles')) {
  const rows = JSON.parse(await readFile(resolve(root, 'index.json'), 'utf8'))
  if (!Array.isArray(rows)) throw new Error('Список статей должен быть массивом')
  const ids = new Set()
  return Promise.all(rows.map(async (row) => {
    if (!/^(?:IDEA-[0-9]{3,}|[a-z][a-z0-9-]+)$/.test(row.id) || ids.has(row.id))
      throw new Error(`Неверный или повторный адрес статьи: ${row.id}`)
    ids.add(row.id)
    const path = resolve(root, row.file ?? '')
    if (!path.startsWith(`${resolve(root)}${sep}`) || !path.endsWith('.md'))
      throw new Error(`Статья выходит за свою папку: ${row.id}`)
    if (!row.title?.trim() || !row.summary?.trim() || !Array.isArray(row.tags))
      throw new Error(`Нет описания статьи: ${row.id}`)
    const markdown = await readFile(path, 'utf8')
    if (!markdown.trim()) throw new Error(`Пустая статья: ${row.id}`)
    return {
      category: 'guides', id: row.id, title: row.title, summary: row.summary,
      tags: row.tags, markdown: markdown.replace(/^# [^\n]+\r?\n+/, ''), source: `wiki/articles/${row.file}`,
      facts: [], sections: [], relations: [], ingredients: [], yields: [],
    }
  }))
}
