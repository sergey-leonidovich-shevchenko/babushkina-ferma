import test from 'node:test'
import assert from 'node:assert/strict'
import { spawnSync, execFileSync } from 'node:child_process'
import {
  readFileSync,
  writeFileSync,
  existsSync,
  lstatSync,
  copyFileSync,
  constants,
  statSync,
  utimesSync,
  symlinkSync,
  mkdirSync,
  mkdtempSync,
  unlinkSync,
  rmSync,
  chmodSync,
} from 'node:fs'
import { dirname, join, resolve, isAbsolute } from 'node:path'
import { fileURLToPath } from 'node:url'
import { tmpdir } from 'node:os'
import { createHash } from 'node:crypto'
import { editorialGitEnvironment } from '../scripts/editorial-git.mjs'

const root = resolve(dirname(fileURLToPath(import.meta.url)), '../..')
// Данные закреплены на опубликованном срезе: будущие каталоги не запускаются
// старым предметным аудитом. Сам проверяемый helper и Git runner — текущие.
const profiles = [
  {
    file: 'editorial-review26-integration-audit.mjs',
    fixture: '14227c2ff625d711cd46ecffbd50bb5faa598667',
  },
  {
    file: 'editorial-review27-audit.mjs',
    fixture: 'c5b57e1b1c2a1371db43418644d0667fbbedf850',
  },
].filter((profile) => existsSync(join(root, 'wiki/scripts', profile.file)))
const environment = { ...editorialGitEnvironment(), GIT_OPTIONAL_LOCKS: '0' }
const git = (cwd, ...args) =>
  execFileSync('git', args, { cwd, env: environment, maxBuffer: 64 * 1024 * 1024 })
const digest = (data) => createHash('sha256').update(data).digest('hex')
const sourceGitPath = (kind) => {
  const value = git(root, 'rev-parse', '--git-path', kind).toString().trim()
  return isAbsolute(value) ? value : resolve(root, value)
}
const invoke = `
  import assert from 'node:assert/strict';
  import { pathToFileURL } from 'node:url';
  const before = JSON.stringify(process.env);
  try { await import(pathToFileURL(process.argv[1]).href); }
  catch (error) { console.error(error.stack); process.exitCode = 1; }
  finally {
    assert.equal(JSON.stringify(process.env), before, 'process.env mutated');
    console.error('EDITORIAL_ENV_UNCHANGED');
  }
`

for (const profile of profiles) {
  test(
    `active ${profile.file} rejects foreign worktree/index/config without mutating its caller`,
    { timeout: 180000 },
    () => {
      const callerEnvironment = JSON.stringify(process.env)
      const sourceFiles = [sourceGitPath('config'), join(root, 'tools/common/git.py')]
      const before = sourceFiles.map((file) => digest(readFileSync(file)))
      const sourceIndexEntries = git(root, 'ls-files', '--stage', '-z')
      const temporary = mkdtempSync(join(tmpdir(), 'editorial guard with spaces '))
      const candidate = join(temporary, 'candidate checkout')
      const results = []
      try {
        git(root, 'clone', '-q', '--shared', '--no-checkout', root, candidate)
        writeFileSync(join(candidate, '.git/index'), readFileSync(sourceGitPath('index')))
        git(
          candidate,
          'read-tree',
          '-m',
          git(root, 'rev-parse', 'HEAD').toString().trim(),
          profile.fixture
        )
        git(candidate, 'config', 'core.trustctime', 'false')
        git(candidate, 'config', 'core.checkStat', 'minimal')
        const changed = new Set(
          git(root, 'diff', '--name-only', '-z', profile.fixture, '--').toString().split('\0')
        )
        const tree = git(root, 'ls-tree', '-rz', profile.fixture)
          .toString()
          .split('\0')
          .filter(Boolean)
        for (const row of tree) {
          const [header, name] = row.split('\t')
          const [mode, type] = header.split(' ')
          assert.equal(type, 'blob')
          const source = join(root, name),
            target = join(candidate, name)
          mkdirSync(dirname(target), { recursive: true })
          if (mode === '120000')
            symlinkSync(git(root, 'show', `${profile.fixture}:${name}`).toString(), target)
          else if (
            name !== 'tools/common/git.py' &&
            !changed.has(name) &&
            existsSync(source) &&
            !lstatSync(source).isSymbolicLink()
          ) {
            copyFileSync(source, target, constants.COPYFILE_FICLONE)
            const stamp = statSync(source)
            utimesSync(target, stamp.atime, stamp.mtime)
          } else {
            writeFileSync(target, git(root, 'show', `${profile.fixture}:${name}`))
            chmodSync(target, mode === '100755' ? 0o755 : 0o644)
          }
        }
        // Используем отдельные копии: source inode/index/config не меняются. Подменяется
        // только текущий активный entrypoint и общий Git runner в фикстуре.
        for (const file of [profile.file, 'editorial-git.mjs']) {
          const target = join(candidate, 'wiki/scripts', file)
          if (existsSync(target)) unlinkSync(target)
          writeFileSync(target, readFileSync(join(root, 'wiki/scripts', file)))
        }
        symlinkSync(join(root, 'wiki/node_modules'), join(candidate, 'wiki/node_modules'), 'dir')
        git(candidate, 'config', 'core.filemode', 'true')
        const helper = join(candidate, 'wiki/scripts', profile.file)
        const index = join(candidate, '.git/index'),
          alternate = join(temporary, 'alternate index')
        writeFileSync(alternate, readFileSync(index))
        const foreign = {
          GIT_DIR: sourceGitPath('.'),
          GIT_WORK_TREE: root,
          GIT_INDEX_FILE: alternate,
          GIT_CONFIG_COUNT: '1',
          GIT_CONFIG_KEY_0: 'core.bare',
          GIT_CONFIG_VALUE_0: 'true',
        }
        const run = (label, overrides, reject) => {
          const started = Date.now()
          const alternateBefore = digest(readFileSync(alternate))
          const result = spawnSync(
            process.execPath,
            ['--input-type=module', '-e', invoke, helper, '--committed-range'],
            {
              cwd: candidate,
              env: { ...environment, ...overrides },
              encoding: 'utf8',
              maxBuffer: 4 * 1024 * 1024,
              timeout: 90000,
            }
          )
          assert.ifError(result.error)
          assert.match(result.stderr, /EDITORIAL_ENV_UNCHANGED/)
          if (reject) {
            assert.notEqual(result.status, 0, label)
            assert.match(
              result.stderr,
              /accepted source changed: tools\/common\/git.py|unrelated existing source: tools\/common\/git.py/,
              label
            )
          } else {
            assert.equal(result.status, 0, `${label}: ${result.stderr}`)
            assert.equal(JSON.parse(result.stdout.trim()).status, 'pass')
          }
          assert.equal(
            digest(readFileSync(alternate)),
            alternateBefore,
            `${label}: foreign index changed`
          )
          results.push({
            label,
            exitCode: result.status,
            rejected: reject,
            callerEnvironmentUnchanged: true,
            elapsedMs: Date.now() - started,
          })
        }
        run('clean', {}, false)
        run('clean with foreign worktree/index/config', foreign, false)
        const probe = join(candidate, 'tools/common/git.py'),
          original = readFileSync(probe)
        writeFileSync(
          probe,
          Buffer.concat([original, Buffer.from('\n# forbidden disposable edit\n')])
        )
        run('damaged candidate', {}, true)
        // Только явный авторский replay сравнивает старый опубликованный guard.
        // Обычный CI проверяет текущий helper на восьми случаях ниже.
        if (process.env.EDITORIAL_GIT_VERIFY_LEGACY === '1') {
          const fixed = readFileSync(helper)
          try {
            writeFileSync(
              helper,
              git(root, 'show', `${profile.fixture}:wiki/scripts/${profile.file}`)
            )
            const red = spawnSync(
              process.execPath,
              ['--input-type=module', '-e', invoke, helper, '--committed-range'],
              {
                cwd: candidate,
                env: {
                  ...environment,
                  GIT_DIR: join(candidate, '.git'),
                  GIT_WORK_TREE: root,
                  GIT_INDEX_FILE: alternate,
                },
                encoding: 'utf8',
                timeout: 90000,
              }
            )
            assert.ifError(red.error)
            assert.equal(red.status, 0, red.stderr)
            assert.equal(JSON.parse(red.stdout.trim()).status, 'pass')
            console.log(
              JSON.stringify({
                legacyGuard: profile.fixture,
                forbiddenProbeChanged: true,
                inheritedOverrideFalsePass: red.status,
                stdout: red.stdout,
                environmentUnchanged: red.stderr.includes('EDITORIAL_ENV_UNCHANGED'),
              })
            )
          } finally {
            writeFileSync(helper, fixed)
          }
        }
        run('damaged with foreign worktree/index/config', foreign, true)
        git(candidate, 'update-index', '--assume-unchanged', '--', 'tools/common/git.py')
        // Переносим flag в чужой index, настоящий индекс фикстуры восстанавливаем.
        writeFileSync(alternate, readFileSync(index))
        git(candidate, 'update-index', '--no-assume-unchanged', '--', 'tools/common/git.py')
        run('damaged with foreign assume-unchanged index', { GIT_INDEX_FILE: alternate }, true)
        writeFileSync(probe, original)
        chmodSync(probe, 0o755)
        run('forbidden executable mode', {}, true)
        run(
          'forbidden mode with core.filemode override',
          { GIT_CONFIG_COUNT: '1', GIT_CONFIG_KEY_0: 'core.filemode', GIT_CONFIG_VALUE_0: 'false' },
          true
        )
        chmodSync(probe, 0o644)
        run('restored clean', {}, false)
        console.log(
          JSON.stringify({ profile: profile.file, fixture: profile.fixture, cases: results })
        )
      } finally {
        rmSync(temporary, { recursive: true, force: true })
        sourceFiles.forEach((file, index) =>
          assert.equal(
            digest(readFileSync(file)),
            before[index],
            `parent source/index/config changed: ${file}`
          )
        )
        assert.deepEqual(
          git(root, 'ls-files', '--stage', '-z'),
          sourceIndexEntries,
          'parent staged entries changed'
        )
        assert.equal(JSON.stringify(process.env), callerEnvironment)
      }
    }
  )
}
