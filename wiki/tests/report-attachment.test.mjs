import test from 'node:test'
import assert from 'node:assert/strict'
import { mkdtemp, mkdir, writeFile, readFile, symlink, rm } from 'node:fs/promises'
import { join } from 'node:path'
import { tmpdir } from 'node:os'
import { reportAttachment } from '../scripts/report-attachment.mjs'

/** Создаёт отдельный проект и output для проверки ссылок без рабочих файлов. */
async function fixture(run) {
  const root = await mkdtemp(join(tmpdir(), 'wiki-report-attachment-'))
  try {
    await mkdir(join(root, 'docs/reports'), { recursive: true })
    await run(root, join(root, 'dist/generated'))
  } finally {
    await rm(root, { recursive: true, force: true })
  }
}

test('report download preserves bytes and has a content-bound address', async () => {
  await fixture(async (root, output) => {
    const path = join(root, 'docs/reports/inventory.csv')
    await writeFile(path, 'path,bytes\nassets/game/a.png,10\n')
    const first = await reportAttachment(path, output, root)
    assert.match(first, /^generated\/attachments\/[a-f0-9]{64}\.csv$/)
    assert.equal(await readFile(join(root, 'dist', first), 'utf8'), await readFile(path, 'utf8'))
    await writeFile(path, 'changed')
    assert.notEqual(await reportAttachment(path, output, root), first)
  })
})

test('report attachments reject traversal, siblings, symlinks and executable formats', async () => {
  await fixture(async (root, output) => {
    const outside = join(root, 'private.json')
    await writeFile(outside, '{}')
    await symlink(outside, join(root, 'docs/reports/link.json'))
    await writeFile(join(root, 'docs/reports/page.html'), '<script>example</script>')
    await mkdir(join(root, 'docs/reports-other'))
    await writeFile(join(root, 'docs/reports-other/a.json'), '{}')
    for (const path of [
      outside,
      join(root, 'docs/reports/link.json'),
      join(root, 'docs/reports/page.html'),
      join(root, 'docs/reports-other/a.json'),
    ])
      await assert.rejects(reportAttachment(path, output, root), /внутри docs\/reports/)
  })
})

test('oversized report attachments fail explicitly', async () => {
  await fixture(async (root, output) => {
    const path = join(root, 'docs/reports/large.json')
    await writeFile(path, Buffer.alloc(8 * 1024 * 1024 + 1))
    await assert.rejects(reportAttachment(path, output, root), /8 MiB/)
  })
})
