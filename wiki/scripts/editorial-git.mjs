import { execFileSync } from 'node:child_process'

/** Читаем свой repo: Git overrides из hook/соседнего worktree не наследуются. */
export function editorialGitEnvironment(environment = process.env) {
  return Object.fromEntries(Object.entries(environment).filter(([key]) => !key.startsWith('GIT_')))
}

export function editorialGit(root, ...args) {
  return execFileSync('git', ['--no-optional-locks', ...args], {
    cwd: root,
    env: editorialGitEnvironment(),
    encoding: 'utf8',
    maxBuffer: 32 * 1024 * 1024,
  })
}
