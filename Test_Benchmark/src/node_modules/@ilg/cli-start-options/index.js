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
 * This is the module entry point, the file that is processed when
 * `require('@ilg/cli-start-options')` is called.
 *
 * For this to work, it must be linked from `package.json` as
 * `"main": "./index.js",`, which is, BTW, the default behaviour.
 *
 * This file does not define the classes itself, but imports them
 * from various implementation files, and re-exports them.
 *
 * To import classes from this module into Node.js applications, use:
 *
 * ```javascript
 * const CliOptions = require('@ilg/cli-start-options').CliOptions
 * const CliCommand = require('./lib/cli-command.js').CliCommand
 * const CliHelp = require('./lib/cli-help.js').CliHelp
 * const CliOptions = require('./lib/cli-options.js').CliOptions
 * ```
 */

// ES6: `import { CliApplication } from './lib/cli-application.js'
const CliApplication = require('./lib/cli-application.js').CliApplication

// ES6: `import { CliCommand } from './lib/cli-command.js'
const CliCommand = require('./lib/cli-command.js').CliCommand

// ES6: `import { CliHelp } from './lib/cli-help.js'
const CliHelp = require('./lib/cli-help.js').CliHelp

// ES6: `import { CliOptions } from './lib/cli-options.js'
const CliOptions = require('./lib/cli-options.js').CliOptions

// ES6: `import { CliExitCodes } from './lib/cli-error.js'
const CliExitCodes = require('./lib/cli-error.js').CliExitCodes

// ES6: `import { CliError } from './lib/cli-error.js'
const CliError = require('./lib/cli-error.js').CliError

// ES6: `import { CliErrorSyntax } from './lib/cli-error.js'
const CliErrorSyntax = require('./lib/cli-error.js').CliErrorSyntax

// ES6: `import { CliErrorApplication } from './lib/cli-error.js'
const CliErrorApplication = require('./lib/cli-error.js').CliErrorApplication

// ES6: `import { CliLogger } from './lib/cli-error.js'
const CliLogger = require('./lib/cli-logger.js').CliLogger

// ----------------------------------------------------------------------------
// Node.js specific export definitions.

// By default, `module.exports = {}`.
// The Main class is added as a property with the same name to this object.

module.exports.CliApplication = CliApplication
module.exports.CliCommand = CliCommand
module.exports.CliHelp = CliHelp
module.exports.CliOptions = CliOptions
module.exports.CliExitCodes = CliExitCodes
module.exports.CliError = CliError
module.exports.CliErrorSyntax = CliErrorSyntax
module.exports.CliErrorApplication = CliErrorApplication
module.exports.CliLogger = CliLogger

// In ES6, it would be:
// export class CliApplication { ... }
// ...
// import { CliApplication, CliCommand, CliHelp, CliOptions, ... }
// from 'cli-start-options.js'

// ----------------------------------------------------------------------------
