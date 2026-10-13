import { readFile, mkdir, writeFile } from 'node:fs/promises'
import { createRequire } from 'node:module'
import { homedir } from 'node:os'
import { join } from 'node:path'
import { wikiRoot, projectRoot } from './runtime.mjs'

/** Растеризует собственный SVG для стандартных размеров значка macOS, оставляя источник редактируемым. */
async function main() {
  const require = createRequire(import.meta.url)
  const sharp = require(
    require.resolve('sharp', {
      paths: [
        wikiRoot,
        join(
          homedir(),
          '.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules'
        ),
      ],
    })
  )
  const destination = join(projectRoot, 'Лунная долина Wiki.app/Contents/Resources')
  await mkdir(destination, { recursive: true })
  const source = await readFile(join(wikiRoot, 'public/wiki-icon.svg'))
  const chunks = []
  for (const [kind, size] of [
    ['ic07', 128],
    ['ic08', 256],
    ['ic09', 512],
    ['ic10', 1024],
  ]) {
    const bytes = await sharp(source, { density: 144 }).resize(size, size).png().toBuffer()
    const header = Buffer.alloc(8)
    header.write(kind, 0, 4, 'ascii')
    header.writeUInt32BE(bytes.length + 8, 4)
    chunks.push(header, bytes)
  }
  const header = Buffer.alloc(8)
  header.write('icns')
  header.writeUInt32BE(8 + chunks.reduce((sum, chunk) => sum + chunk.length, 0), 4)
  await writeFile(join(destination, 'AppIcon.icns'), Buffer.concat([header, ...chunks]))
  console.log('WIKI ICON: AppIcon.icns ready')
}
main().catch((error) => {
  console.error(error.message)
  process.exitCode = 1
})
