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

/*
 * This file implements a simple CLI logger.
 *
 * Use `log.always()` instead of the `console.log()`, since it accounts for
 * different contexts, created for instance when using REPL.
 *
 * The messages may include formatting directives, with additional
 * arguments, as defined by the Node.js console (not really necessary
 * with ES6).
 *
 * There is no `critical` level, corresponding to errors that prevent
 * the program to run, since these are actually related to bugs;
 * use `assert()` instead.
 */

// ----------------------------------------------------------------------------

const assert = require('assert')

// ============================================================================

const numLevel = {
  silent: -Infinity,
  error: 10,
  warn: 20,
  info: 30,
  verbose: 40,
  debug: 50,
  trace: 60,
  all: Infinity
}

// export
class CliLogger {
  // --------------------------------------------------------------------------

  /**
   * @summary Create a logger instance for a given console.
   *
   * @param {Object} console_ Reference to console.
   * @param {string} level_ A log level.
   */
  constructor (console_, level_ = 'info') {
    assert(console)
    assert(level_ in numLevel)

    this._console = console_
    this.level = level_
  }

  /**
   * @summary Output always.
   *
   * @param {string} msg Message.
   * @param {*} args Possible arguments.
   * @returns {undefined} Nothing.
   *
   * @description
   * The message is always passed to the console, regardless the
   * log level.
   *
   * Use this instead of console.log(), which in Node.js always
   * refers to the process console, not the possible REPL streams.
   */
  always (msg = '', ...args) {
    this._console.log(msg, ...args)
  }

  error (msg = '', ...args) {
    if (this._numLevel >= numLevel.error) {
      if (msg instanceof Error) {
        this._console.error(msg, ...args)
      } else {
        this._console.error('error: ' + msg, ...args)
      }
    }
  }

  output (msg = '', ...args) {
    if (this._numLevel >= numLevel.error) {
      this._console.log(msg, ...args)
    }
  }

  warn (msg = '', ...args) {
    if (this._numLevel >= numLevel.warn) {
      this._console.error('warning: ' + msg, ...args)
    }
  }

  info (msg = '', ...args) {
    if (this._numLevel >= numLevel.info) {
      this._console.log(msg, ...args)
    }
  }

  verbose (msg = '', ...args) {
    if (this._numLevel >= numLevel.verbose) {
      this._console.log(msg, ...args)
    }
  }

  debug (msg = '', ...args) {
    if (this._numLevel >= numLevel.debug) {
      this._console.log('debug: ' + msg, ...args)
    }
  }

  trace (msg = '', ...args) {
    if (this._numLevel >= numLevel.trace) {
      this._console.log('trace: ' + msg, ...args)
    }
  }

  set level (level_) {
    assert(numLevel[level_] !== undefined,
      `Log level '${level_}' not supported.`)

    this._numLevel = numLevel[level_]
    this._level = level_
  }

  get level () {
    return this._level
  }

  isVerbose () {
    return this._numLevel >= numLevel.verbose
  }
}

// ----------------------------------------------------------------------------
// Node.js specific export definitions.

// By default, `module.exports = {}`.
// The CliLogger class is added as a property of this object.
module.exports.CliLogger = CliLogger

// In ES6, it would be:
// export class CliLogger { ... }
// ...
// import { CliLogger } from 'cli-logger.js'

// ----------------------------------------------------------------------------
