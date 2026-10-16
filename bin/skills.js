#!/usr/bin/env node
// Install skills from this package into the local agent skill directories.
//
//   npx github:liuylo/skills install [name...]
//   npx github:liuylo/skills list
//   npx github:liuylo/skills uninstall <name...>
//
// Skills are copied, not symlinked: npx runs the package from a temporary
// cache that npm is free to delete, which would leave symlinks dangling.
// Every copied skill gets a marker file so uninstall only ever removes
// directories this tool created.

import { existsSync, readdirSync, rmSync, cpSync, mkdirSync, readFileSync, writeFileSync, lstatSync, symlinkSync } from 'node:fs'
import { homedir } from 'node:os'
import { dirname, join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const PKG_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const SKILLS_SRC = join(PKG_ROOT, 'skills')
const MARKER = '.installed-by-liuylo-skills'

const CANONICAL_DIR = join(homedir(), '.agents', 'skills')
const MIRROR_DIR = join(homedir(), '.claude', 'skills')

const pkg = JSON.parse(readFileSync(join(PKG_ROOT, 'package.json'), 'utf8'))

function availableSkills() {
  if (!existsSync(SKILLS_SRC)) return []
  return readdirSync(SKILLS_SRC, { withFileTypes: true })
    .filter((e) => e.isDirectory() && existsSync(join(SKILLS_SRC, e.name, 'SKILL.md')))
    .map((e) => e.name)
    .sort()
}

// A directory we own: ours if it carries the marker. A symlink counts as ours
// too — it never holds unique content, so replacing it destroys nothing.
function ownedness(path) {
  if (!existsSync(path) && !isSymlink(path)) return 'absent'
  if (isSymlink(path)) return 'ours'
  const marker = join(path, MARKER)
  if (!existsSync(marker)) return 'foreign'
  try {
    return JSON.parse(readFileSync(marker, 'utf8')).package === pkg.name ? 'ours' : 'foreign'
  } catch {
    return 'foreign'
  }
}

function isSymlink(path) {
  try {
    return lstatSync(path).isSymbolicLink()
  } catch {
    return false
  }
}

function install(names, force) {
  const targets = names.length > 0 ? names : availableSkills()
  if (targets.length === 0) {
    console.error('no skills found in this package')
    process.exit(1)
  }

  let failed = false
  for (const name of targets) {
    const src = join(SKILLS_SRC, name)
    if (!existsSync(join(src, 'SKILL.md'))) {
      console.error(`skip  ${name} — not in this package`)
      failed = true
      continue
    }

    const dest = join(CANONICAL_DIR, name)
    const state = ownedness(dest)
    if (state === 'foreign' && !force) {
      console.error(`skip  ${name} — ${dest} is not ours (${state}); pass --force to replace`)
      failed = true
      continue
    }

    rmSync(dest, { recursive: true, force: true })
    mkdirSync(CANONICAL_DIR, { recursive: true })
    cpSync(src, dest, { recursive: true })
    writeFileSync(
      join(dest, MARKER),
      JSON.stringify({ package: pkg.name, version: pkg.version, skill: name }, null, 2) + '\n',
    )

    // Mirror into ~/.claude/skills with the relative-link layout this machine
    // already uses, so a copy lives in exactly one place.
    const mirror = join(MIRROR_DIR, name)
    if (isSymlink(mirror) || !existsSync(mirror)) {
      mkdirSync(MIRROR_DIR, { recursive: true })
      rmSync(mirror, { force: true })
      symlinkSync(`../../.agents/skills/${name}`, mirror)
    } else if (force) {
      rmSync(mirror, { recursive: true, force: true })
      symlinkSync(`../../.agents/skills/${name}`, mirror)
    } else {
      console.error(`warn  ${name} — ${mirror} is a real directory, left alone`)
    }

    console.log(`install ${name} ${pkg.version} -> ${dest}`)
  }
  process.exit(failed ? 1 : 0)
}

function uninstall(names) {
  if (names.length === 0) {
    console.error('usage: skills uninstall <name...>')
    process.exit(1)
  }

  for (const name of names) {
    for (const path of [join(MIRROR_DIR, name), join(CANONICAL_DIR, name)]) {
      if (isSymlink(path)) {
        rmSync(path, { force: true })
        console.log(`unlink ${path}`)
        continue
      }
      if (!existsSync(path)) continue
      if (ownedness(path) === 'ours') {
        rmSync(path, { recursive: true, force: true })
        console.log(`remove ${path}`)
      } else {
        console.error(`skip  ${path} — not installed by ${pkg.name}`)
      }
    }
  }
}

function list() {
  for (const name of availableSkills()) {
    const state = ownedness(join(CANONICAL_DIR, name))
    console.log(`${name.padEnd(20)} ${state === 'ours' ? 'installed' : state}`)
  }
}

function usage() {
  console.log(`usage: skills <command>

  install [name...]     install every skill in the package, or the named ones
  list                  show skills in the package and whether they are installed
  uninstall <name...>   remove previously installed skills

flags:
  --force               replace a directory at the target path that this tool
                        did not create`)
}

const [command, ...rest] = process.argv.slice(2)
const force = rest.includes('--force')
const names = rest.filter((a) => !a.startsWith('--'))

switch (command) {
  case 'install':
    install(names, force)
    break
  case 'uninstall':
    uninstall(names)
    break
  case 'list':
    list()
    break
  case undefined:
  case '-h':
  case '--help':
  case 'help':
    usage()
    break
  default:
    console.error(`unknown command: ${command}`)
    usage()
    process.exit(1)
}
