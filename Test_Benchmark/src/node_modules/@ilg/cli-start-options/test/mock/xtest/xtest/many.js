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
 * The `xtest many` command implementation.
 */

// ----------------------------------------------------------------------------

// ES6: `import { CliCommand, CliExitCodes, CliError } from 'cli-start-options'
const CliCommand = require('../../../../index.js').CliCommand
const CliExitCodes = require('../../../../index.js').CliExitCodes

// ============================================================================

class Long extends CliCommand {
  // --------------------------------------------------------------------------

  /**
   * @summary Constructor, to set help definitions.
   *
   * @param {Object} context Reference to a context.
   */
  constructor (context) {
    super(context)

    // Title displayed with the help message.
    this.title = 'Test many options'
    this.optionGroups = [
      {
        title: 'Long options',
        preOptions: '[<name1> <name2> <name3>...]',
        optionDefs: [
          {
            options: ['--one'],
            action: (context, val) => {
              context.config.one = val
            },
            init: (context) => {
              context.config.one = undefined
            },
            msg: 'Option one',
            param: 'name',
            isMandatory: true
          },
          {
            options: ['--two'],
            action: (context, val) => {
              context.config.two = val
            },
            init: (context) => {
              context.config.two = undefined
            },
            msg: 'Option two',
            param: 'name',
            isMandatory: true,
            isMultiple: true
          },
          {
            options: ['--three'],
            action: (context, val) => {
              context.config.three = val
            },
            init: (context) => {
              context.config.three = undefined
            },
            msg: 'Option three',
            param: 'name',
            isOptional: true,
            isMultiple: true
          },
          {
            options: ['--four'],
            action: (context, val) => {
              context.config.four = val
            },
            init: (context) => {
              context.config.four = undefined
            },
            msg: 'Option four',
            // Has no param.
            hasValue: true,
            isOptional: true
          }
        ]
      }
    ]
  }

  /**
   * @summary Execute the `copy` command.
   *
   * @param {string[]} args Command line arguments.
   * @returns {number} Return code.
   *
   * @override
   */
  async doRun (args) {
    const log = this.log
    log.trace(`${this.constructor.name}.doRun()`)

    log.info(this.title)
    // const config = this.context.config

    log.info('Done.')
    return CliExitCodes.SUCCESS
  }
}

// ----------------------------------------------------------------------------
// Node.js specific export definitions.

// By default, `module.exports = {}`.
// The Copy class is added as a property of this object.
module.exports.Long = Long

// In ES6, it would be:
// export class Long { ... }
// ...
// import { Long } from 'long.js'

// ----------------------------------------------------------------------------
