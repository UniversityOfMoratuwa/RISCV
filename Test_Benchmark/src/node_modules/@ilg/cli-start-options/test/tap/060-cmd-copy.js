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
 * Test `xtest copy`.
 */

// ----------------------------------------------------------------------------

const assert = require('assert')
const path = require('path')
const os = require('os')
const fs = require('fs')

// The `[node-tap](http://www.node-tap.org)` framework.
const test = require('tap').test

const Common = require('../common.js').Common
const Promisifier = require('@ilg/es6-promisifier').Promisifier

// ES6: `import { CliExitCodes } from 'cli-start-options'
const CliExitCodes = require('../../index.js').CliExitCodes

assert(Common)
assert(Promisifier)
assert(CliExitCodes)

// ----------------------------------------------------------------------------

const fixtures = path.resolve(__dirname, '../fixtures')
const workFolder = path.resolve(os.tmpdir(), 'xtest-copy')
const rimrafPromise = Promisifier.promisify(require('rimraf'))
const mkdirpPromise = Promisifier.promisify(require('mkdirp'))

// Promisified functions from the Node.js callbacks library.
Promisifier.promisifyInPlace(fs, 'chmod')

// ----------------------------------------------------------------------------

/**
 * Test if with empty line fails with mandatory error and displays help.
 */
test('xtest copy',
  async (t) => {
    try {
      const { code, stdout, stderr } = await Common.xtestCli([
        'copy'
      ])
      // Check exit code.
      t.equal(code, CliExitCodes.ERROR.SYNTAX, 'exit code is syntax')
      const errLines = stderr.split(/\r?\n/)
      // console.log(errLines)
      t.equal(errLines.length, 2 + 1, 'has two errors')
      if (errLines.length === 3) {
        t.match(errLines[0], 'Mandatory \'--file\' not found',
          'has --file error')
        t.match(errLines[1], 'Mandatory \'--output\' not found',
          'has --output error')
      }
      t.match(stdout, 'Usage: xtest copy [options...]', 'has Usage')
    } catch (err) {
      t.fail(err.message)
    }
    t.end()
  })

/**
 * Test if help content includes convert options.
 */
test('xtest copy -h',
  async (t) => {
    try {
      const { code, stdout, stderr } = await Common.xtestCli([
        'copy',
        '-h'
      ])
      // Check exit code.
      t.equal(code, CliExitCodes.SUCCESS, 'exit code is success')
      const outLines = stdout.split(/\r?\n/)
      t.ok(outLines.length > 9, 'has enough output')
      if (outLines.length > 9) {
        // console.log(outLines)
        t.equal(outLines[1], 'Copy a file to another file',
          'has title')
        t.equal(outLines[2], 'Usage: xtest copy [options...] ' +
          '--file <file> --output <file>', 'has Usage')
        t.match(outLines[4], 'Copy options:', 'has copy options')
        t.match(outLines[5], '  --file <file>  ', 'has --file')
        t.match(outLines[6], '  --output <file>  ', 'has --output')
      }
      // There should be no error messages.
      t.equal(stderr, '', 'stderr is empty')
    } catch (err) {
      t.fail(err.message)
    }
    t.end()
  })

/**
 * Test if partial command recognised and expanded.
 */
test('xtest cop -h',
  async (t) => {
    try {
      const { code, stdout, stderr } = await Common.xtestCli([
        'cop',
        '-h'
      ])
      // Check exit code.
      t.equal(code, CliExitCodes.SUCCESS, 'exit code is success')
      const outLines = stdout.split(/\r?\n/)
      t.ok(outLines.length > 9, 'has enough output')
      if (outLines.length > 9) {
        // console.log(outLines)
        t.equal(outLines[1], 'Copy a file to another file',
          'has title')
        t.equal(outLines[2], 'Usage: xtest copy [options...] ' +
          '--file <file> --output <file>', 'has Usage')
      }
      // There should be no error messages.
      t.equal(stderr, '', 'stderr is empty')
    } catch (err) {
      t.fail(err.message)
    }
    t.end()
  })

/**
 * Test missing input file.
 */
test('xtest cop --file xxx --output yyy -q',
  async (t) => {
    try {
      const { code, stdout, stderr } = await Common.xtestCli([
        'cop',
        '--file',
        'xxx',
        '--output',
        'yyy',
        '-q'
      ])
      // Check exit code.
      t.equal(code, CliExitCodes.ERROR.INPUT, 'exit code is input')
      // There should be no output.
      t.equal(stdout, '', 'stdout is empty')
      t.match(stderr, 'ENOENT: no such file or directory', 'strerr is ENOENT')
    } catch (err) {
      t.fail(err.message)
    }
    t.end()
  })

test('unpack',
  async (t) => {
    const tgzPath = path.resolve(fixtures, 'cmd-code.tgz')
    try {
      await Common.extractTgz(tgzPath, workFolder)
      t.pass('cmd-code.tgz unpacked into ' + workFolder)
      await fs.chmodPromise(filePath, 0o444)
      t.pass('chmod ro file')
      await mkdirpPromise(readOnlyFolder)
      t.pass('mkdir folder')
      await fs.chmodPromise(readOnlyFolder, 0o444)
      t.pass('chmod ro folder')
    } catch (err) {
      t.fail(err)
    }
    t.end()
  })

const filePath = path.resolve(workFolder, 'input.json')
const readOnlyFolder = path.resolve(workFolder, 'ro')

test('xtest cop --file input.json --output output.json',
  async (t) => {
    try {
      const outPath = path.resolve(workFolder, 'output.json')
      const { code, stdout, stderr } = await Common.xtestCli([
        'cop',
        '--file',
        filePath,
        '--output',
        outPath
      ])
      // Check exit code.
      t.equal(code, CliExitCodes.SUCCESS, 'exit code is success')
      t.match(stdout, 'Done', 'stdout is done')
      // console.log(stdout)
      t.equal(stderr, '', 'stderr is empty')
      // console.log(stderr)

      const fileContent = await fs.readFilePromise(outPath)
      t.ok(fileContent, 'content is read in')
      const json = JSON.parse(fileContent.toString())
      t.ok(json, 'json was parsed')
      t.match(json.name, '@ilg/cli-start-options', 'has name')
    } catch (err) {
      t.fail(err.message)
    }
    t.end()
  })

test('xtest cop --file input --output output -v',
  async (t) => {
    try {
      const { code, stdout, stderr } = await Common.xtestCli([
        'cop',
        '-C',
        workFolder,
        '--file',
        filePath,
        '--output',
        'output.json',
        '-v'
      ])
      // Check exit code.
      t.equal(code, CliExitCodes.SUCCESS, 'exit code')
      t.match(stdout, 'Done.', 'message is Done')
      // console.log(stdout)
      t.equal(stderr, '', 'stderr is empty')
      // console.log(stderr)
    } catch (err) {
      t.fail(err.message)
    }
    t.end()
  })

// Windows R/O folders do not prevent creating new files.
if (os.platform() !== 'win32') {
  /**
   * Test output error.
   */
  test('xtest cop --file input --output ro/output -v',
    async (t) => {
      try {
        const outPath = path.resolve(workFolder, 'ro', 'output.json')
        const { code, stdout, stderr } = await Common.xtestCli([
          'cop',
          '--file',
          filePath,
          '--output',
          outPath,
          '-v'
        ])
        // Check exit code.
        t.equal(code, CliExitCodes.ERROR.OUTPUT, 'exit code is output')
        // Output should go up to Writing...
        // console.log(stdout)
        t.match(stdout, 'Writing ', 'up to writing')
        // console.log(stderr)
        t.match(stderr, 'EACCES: permission denied', 'stderr is EACCES')
      } catch (err) {
        t.fail(err.message)
      }
      t.end()
    })
}

test('cleanup', async (t) => {
  await fs.chmodPromise(filePath, 0o666)
  t.pass('chmod rw file')
  await fs.chmodPromise(readOnlyFolder, 0o666)
  t.pass('chmod rw folder')
  await rimrafPromise(workFolder)
  t.pass('remove tmpdir')
})

// ----------------------------------------------------------------------------
