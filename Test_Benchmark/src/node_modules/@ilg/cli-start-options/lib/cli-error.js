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
 * CLI exit codes and erros used to throw exceptions.
 */

// ----------------------------------------------------------------------------
// Exit codes:

const ERROR = {}
ERROR.NONE = 0 // OK
ERROR.SYNTAX = 1 // Syntax error while parsing options.
ERROR.APPLICATION = 2 // Any functional error.
ERROR.INPUT = 3 // No file, wrong format, etc.
ERROR.OUTPUT = 4 // Cannot create file, cannot write, etc.
ERROR.CHILD = 5 // Child return error.
ERROR.PREREQUISITES = 6 // Prerequisites not met.

const CliExitCodes = {}
CliExitCodes.ERROR = ERROR
CliExitCodes.SUCCESS = ERROR.NONE

// ============================================================================

/**
 * @classdesc
 * Base class for all CLI triggered errors.
 */
// export
class CliError extends Error {
  // --------------------------------------------------------------------------

  /**
   * @summary Create a new syntax error instance.
   *
   * @param {string} message Error description.
   * @param {number} exitCode Integer value to be returned.
   *
   * @description
   * Remember the exit code.
   */
  constructor (message, exitCode = undefined) {
    super(message)

    this.exitCode = exitCode
  }
}

/**
 * @classdesc
 * CLI triggered syntax error.
 * Will try to be helpful (using help())
 */
// export
class CliErrorSyntax extends CliError {
  // --------------------------------------------------------------------------

  /**
   * @summary Create a new syntax error instance.
   *
   * @param {string} message Error description.
   *
   * @description
   * Create a CliError instance with the ERROR.SYNTAX error code.
   */
  constructor (message) {
    super(message, ERROR.SYNTAX)
  }
}

/**
 * @classdesc
 * CLI triggered application error.
 * Will try to be helpful (using help())
 */
// export
class CliErrorApplication extends CliError {
  // --------------------------------------------------------------------------

  /**
   * @summary Create a new syntax error instance.
   *
   * @param {string} message Error description.
   *
   * @description
   * Create a CliError instance with the ERROR.APPLICATION error code.
   */
  constructor (message) {
    super(message, ERROR.APPLICATION)
  }
}

// ----------------------------------------------------------------------------
// Node.js specific export definitions.

// By default, `module.exports = {}`.
// The CliApplication class is added as a property of this object.
module.exports.CliError = CliError
module.exports.CliErrorSyntax = CliErrorSyntax
module.exports.CliErrorApplication = CliErrorApplication
module.exports.CliExitCodes = CliExitCodes

// In ES6, it would be:
// export class CliApplication { ... }
// ...
// import { CliError } from 'cli-application.js'

// ----------------------------------------------------------------------------
