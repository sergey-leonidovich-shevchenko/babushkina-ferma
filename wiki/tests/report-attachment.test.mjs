import test from 'node:test'
import assert from 'node:assert/strict'
import { mkdtemp, mkdir, writeFile, readFile, symlink, rm } from 'node:fs/promises'
import { join } from 'node:path'
import { tmpdir } from 'node:os'
import { reportAttachment, reportComparison, reportVideo } from '../scripts/report-attachment.mjs'

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

test('diagnostic video is bounded, content-addressed and cannot be renamed HTML', async () => {
  await fixture(async (root, output) => {
    const path = join(root, 'docs/reports/walk.mp4')
    const header = Buffer.from([0, 0, 0, 24, 102, 116, 121, 112, 109, 112, 52, 50])
    await writeFile(path, header)
    const published = await reportAttachment(path, output, root)
    assert.match(published, /^generated\/attachments\/[a-f0-9]{64}\.mp4$/)
    assert.deepEqual(await readFile(join(root, 'dist', published)), header)
    await writeFile(path, '<script>renamed</script>')
    await assert.rejects(reportAttachment(path, output, root), /сигнатура MP4/)
    await writeFile(path, Buffer.concat([header, Buffer.alloc(8 * 1024 * 1024)]))
    await assert.rejects(reportAttachment(path, output, root), /8 MiB/)
  })
})

test('report video escapes labels and rejects arbitrary URLs without autoplay', () => {
  const path = `generated/attachments/${'a'.repeat(64)}.mp4`
  const player = reportVideo(path, '\"><script>untrusted</script>&')
  assert.match(player, /<video controls playsinline preload="metadata"/)
  assert.match(player, /&quot;&gt;&lt;script&gt;untrusted&lt;\/script&gt;&amp;/)
  assert.doesNotMatch(player, /<script>|autoplay/)
  assert.throws(() => reportVideo('https://example.test/movie.mp4', 'external'), /опубликованное/)
  assert.throws(() => reportVideo('../../private.mp4', 'private'), /опубликованное/)
})

const native = new URL('../../docs/reports/visual-overhaul/vrender-007/native/', import.meta.url)
const reference = {
  manifest: 'docs/reports/capture.json',
  case: '1-post',
  label: 'Западный мост · ближние перила',
}

test('native comparison serves the original verified PNGs used by both catalogs', async () => {
  await fixture(async (root, output) => {
    const snapshots = ['1-post-before.png', '1-post-after.png']
    for (const file of ['capture.json', ...snapshots])
      await writeFile(join(root, 'docs/reports', file), await readFile(new URL(file, native)))
    const published = join(root, 'dist')
    assert.equal(await reportComparison(reference, root, { published }), undefined)
    const result = await reportComparison(reference, root, { destination: output })
    assert.equal(result.label, reference.label)
    assert.deepEqual([result.width, result.height], [1152, 648])
    assert.deepEqual(await reportComparison(reference, root), result)
    assert.deepEqual(await reportComparison(reference, root, { published }), result)
    for (const [index, url] of [result.before, result.after].entries()) {
      assert.match(url, /^generated\/attachments\/[a-f0-9]{64}\.png$/)
      assert.deepEqual(
        await readFile(join(root, 'dist', url)),
        await readFile(new URL(snapshots[index], native))
      )
    }
    const servedAfter = join(published, result.after)
    await writeFile(servedAfter, await readFile(join(published, result.before)))
    assert.equal(await reportComparison(reference, root, { published }), undefined)
    await writeFile(servedAfter, await readFile(new URL('1-post-after.png', native)))
    const altered = await readFile(servedAfter)
    altered[altered.length - 2] ^= 1
    await writeFile(servedAfter, altered)
    assert.equal(await reportComparison(reference, root, { published }), undefined)
    await rm(servedAfter)
    assert.equal(await reportComparison(reference, root, { published }), undefined)
  })
})

test('native comparison omits absent, shifted, substituted and external images', async () => {
  await fixture(async (root, output) => {
    const manifest = JSON.parse(await readFile(new URL('capture.json', native)))
    const manifestPath = join(root, reference.manifest)
    const before = await readFile(new URL('1-post-before.png', native))
    const after = await readFile(new URL('1-post-after.png', native))
    const beforePath = join(root, 'docs/reports/1-post-before.png')
    const afterPath = join(root, 'docs/reports/1-post-after.png')
    const media = { destination: output }
    await writeFile(manifestPath, JSON.stringify(manifest))
    await writeFile(beforePath, before)
    assert.equal(await reportComparison(reference, root, media), undefined)
    await writeFile(afterPath, before)
    assert.equal(await reportComparison(reference, root, media), undefined)
    await writeFile(afterPath, after)
    const shifted = structuredClone(manifest)
    shifted.captures['1-post-after'].camera[0] += 1
    await writeFile(manifestPath, JSON.stringify(shifted))
    assert.equal(await reportComparison(reference, root, media), undefined)
    await writeFile(manifestPath, JSON.stringify(manifest))
    await rm(afterPath)
    await writeFile(join(root, 'outside.png'), after)
    await symlink(join(root, 'outside.png'), afterPath)
    assert.equal(await reportComparison(reference, root, media), undefined)
    assert.equal(
      await reportComparison({ ...reference, case: '../1-post' }, root, media),
      undefined
    )
  })
})
