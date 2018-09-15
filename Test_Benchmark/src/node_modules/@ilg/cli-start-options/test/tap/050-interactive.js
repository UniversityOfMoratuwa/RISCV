/*
 * This file is part of the xPack distribution
 *   (http://xpack.github.io).
 * Copyright (c) 2017 Liviu Ionescu.
 *
 * Permission is hereby granted, free of charge, to any person
 * obtaining a copy of this software and associated documentation
 * files (the "Software"), to deal in the Software without
 * restriction, including without limitation the rights to use,
 * copy, modify, merge, publish, distribute, sublicense, and/or
 * sell copies of the Software, and to permit persons to whom
 * the Software is furnished to do so, subject to the following
 * conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 * OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 * HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 * OTHER DEALINGS IN THE SOFTWARE.
 */

'use strict'
/* eslint valid-jsdoc: "error" */
/* eslint max-len: [ "error", 80, { "ignoreUrls": true } ] */

// ----------------------------------------------------------------------------

/**
 * Test common options, like --version, --help, etc.
 */

// ----------------------------------------------------------------------------

const assert = require('assert')
const spawn = require('child_process').spawn
const path = require('path')

// The `[node-tap](http://www.node-tap.org)` framework.
const test = require('tap').test

const Common = require('../common.js').Common

const CliApplication = require('../../index.js').CliApplication
const CliExitCodes = require('../../index.js').CliExitCodes

assert(CliApplication)
assert(CliExitCodes)

// ----------------------------------------------------------------------------

const debug = false

// ----------------------------------------------------------------------------

const nodeBin = process.env.npm_node_execpath || process.env.NODE ||
  process.execPath
const executableName = Common.xtest.executableName

let pack = null
const rootPath = path.resolve(path.dirname(__dirname), Common.xtest.mockPath)

// ----------------------------------------------------------------------------

test('setup', async (t) => {
  // Read in the package.json, to later compare version.
  pack = await CliApplication.readPackageJson(rootPath)
  t.ok(pack, 'package was parsed')
  t.ok(pack.version.length > 0, 'version length > 0')
  t.pass(`package ${pack.name}@${pack.version}`)
  t.end()
})

test('xtest -i (spawn)', (t) => {
  const cmd = [executableName, '-i']
  const opts = {}
  opts.env = process.env
  const child = spawn(nodeBin, cmd, opts)

  child.on('error', (err) => {
    if (debug) {
      console.log('error')
    }
    t.fail(err.message)
    t.end()
  })

  child.on('close', (code) => {
    // Check exit code.
    if (debug) {
      console.log('close')
    }
    t.equal(code, CliExitCodes.SUCCESS, 'exit code success')
    t.end()
  })

  // For unknown reasons, REPL stderr is not forwarded here,
  // but to stdout.
  let stderr = ''
  if (child.stderr) {
    child.stderr.on('data', (chunk) => {
      if (debug) {
        console.log(chunk)
      }
      stderr += chunk
    })
  }

  let stdout = ''
  let count = 0
  if (child.stdout) {
    child.stdout.on('data', (chunk) => {
      // console.log(chunk)
      stdout += chunk
      let ostr = null
      if (stdout.endsWith('xtest> ')) {
        stdout = stdout.replace('xtest> ', '')
        if (debug) {
          // console.log(stdout)
        }
        // A small state machine to check the conditions after each
        // new prompt identified.
        if (count === 0) {
          t.test('first prompt', (t) => {
            t.ok(true, 'prompt ok')
            t.equal(stderr, '', 'stderr is empty')
            t.end()
          })

          ostr = '--version'
        } else if (count === 1) {
          t.test('--version', (t) => {
            t.equal(stdout, pack.version + '\n', 'version value')
            t.end()
          })

          ostr = '-h'
        } else if (count === 2) {
          t.test('-h', (t) => {
            t.match(stdout, 'Usage: xtest <command> [<subcommand>...]',
              'has Usage')
            // t.equal(stderr, '', 'stderr empty')
            t.end()
          })

          ostr = '--version'
        } else if (count === 3) {
          t.test('--version again', (t) => {
            t.equal(stdout, pack.version + '\n', 'version value')
            t.end()
          })

          ostr = 'copy -h'
        } else if (count === 4) {
          t.test('copy -h', (t) => {
            // console.log(stdout)
            t.match(stdout, 'Usage: xtest copy [options...] --file <file> ' +
              '--output <file>', 'has code Usage')
            // t.equal(stderr, '', 'stderr empty')
            t.end()
          })

          ostr = 'copy'
        } else if (count === 5) {
          t.test('copy', (t) => {
            t.match(stdout, 'Usage: xtest copy [options...] --file <file> ' +
              '--output <file>', 'has code Usage')
            t.match(stdout, 'Mandatory \'--file\' not found',
              '--file not found')
            t.end()
          })

          ostr = 'xyz'
        } else if (count === 6) {
          t.test('xyz', (t) => {
            t.match(stdout, `Command 'xyz' not supported.`,
              'xyz is not supported')
            t.match(stdout, 'Usage: xtest <command> [<subcommand>...]',
              'has Usage')
            // t.equal(stderr, '', 'stderr empty')
            t.end()
          })

          ostr = '.exit'
        }
        if (ostr) {
          if (debug) {
            console.log(`sent ${ostr}`)
          }
          child.stdin.write(ostr + '\n')
        }
        count++
        if (debug) {
          console.log(count)
        }
        stdout = ''
        stderr = ''
      }
    })
  }
})

// ----------------------------------------------------------------------------
