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
 * Test custom errors.
 */

// ----------------------------------------------------------------------------

const assert = require('assert')

// The `[node-tap](http://www.node-tap.org)` framework.
const test = require('tap').test

const CliExitCodes = require('../../index.js').CliExitCodes
const CliError = require('../../index.js').CliError
const CliErrorSyntax = require('../../index.js').CliErrorSyntax
const CliErrorApplication = require('../../index.js').CliErrorApplication

assert(CliExitCodes)
assert(CliError)
assert(CliErrorSyntax)
assert(CliErrorApplication)

// ----------------------------------------------------------------------------

test('types', (t) => {
  t.ok(Error.isPrototypeOf(CliError), 'CliError is Error')
  t.ok(Error.isPrototypeOf(CliErrorSyntax), 'CliErrorSyntax is Error')
  t.ok(Error.isPrototypeOf(CliErrorApplication), 'CliErrorApplication is Error')

  t.ok(CliExitCodes instanceof Object, 'CliExitCodes is Object')
  t.ok(CliExitCodes.ERROR instanceof Object, 'CliExitCodes.ERROR is Object')

  t.ok(!isNaN(CliExitCodes.SUCCESS), 'SUCCESS is a number')
  t.ok(!isNaN(CliExitCodes.ERROR.SYNTAX), 'ERROR.SYNTAX is a number')
  t.ok(!isNaN(CliExitCodes.ERROR.APPLICATION), 'ERROR.APPLICATION is a number')
  t.ok(!isNaN(CliExitCodes.ERROR.INPUT), 'ERROR.INPUT is a number')
  t.ok(!isNaN(CliExitCodes.ERROR.OUTPUT), 'ERROR.OUTPUT is a number')

  t.end()
})

test('exitCodes', (t) => {
  t.test('CliError', (t) => {
    try {
      throw new CliError('one')
    } catch (err) {
      t.equal(err.message, 'one', 'message is one')
      t.equal(err.exitCode, undefined, 'exit code is undefined')
    }
    try {
      throw new CliError('two', 7)
    } catch (err) {
      t.equal(err.message, 'two', 'message is two')
      t.equal(err.exitCode, 7, 'exit code is 7')
    }
    t.end()
  })

  t.test('CliErrorSyntax', (t) => {
    try {
      throw new CliErrorSyntax('one')
    } catch (err) {
      t.equal(err.message, 'one', 'message is one')
      t.equal(err.exitCode, CliExitCodes.ERROR.SYNTAX, 'exit code is syntax')
    }
    t.end()
  })

  t.test('CliErrorApplication', (t) => {
    try {
      throw new CliErrorApplication('one')
    } catch (err) {
      t.equal(err.message, 'one', 'message is one')
      t.equal(err.exitCode, CliExitCodes.ERROR.APPLICATION,
        'exit code is app')
    }
    t.end()
  })

  t.end()
})

// ----------------------------------------------------------------------------
