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
 * This file provides the CLI startup code. It prepares a context
 * and calls the module `main()` code.
 */

// ----------------------------------------------------------------------------

const os = require('os')
const assert = require('assert')
const path = require('path')
const fs = require('fs')

const vm = require('vm')
const repl = require('repl')

const util = require('util')
const process = require('process')

const latestVersion = require('latest-version')
const semver = require('semver')
const semverDiff = require('semver-diff')
const isInstalledGlobally = require('is-installed-globally')
const isPathInside = require('is-path-inside')
const isCi = require('is-ci')
const makeDir = require('make-dir')
const del = require('del')

// ES6: `import { Promisifier} from 'es6-promisifier'
const Promisifier = require('@ilg/es6-promisifier').Promisifier

// ES6: `import { WscriptAvoider} from 'wscript-avoider'
const WscriptAvoider = require('wscript-avoider').WscriptAvoider

// ES6: `import { CliCommand } from './cli-options.js'
const CliCommand = require('./cli-command.js').CliCommand

// ES6: `import { CliOptions } from './cli-options.js'
const CliOptions = require('./cli-options.js').CliOptions

// ES6: `import { CliHelp } from './cli-help.js'
const CliHelp = require('./cli-help.js').CliHelp

// ES6: `import { CliLogger } from './cli-logger.js'
const CliLogger = require('./cli-logger.js').CliLogger

// ES6: `import { CliExitCodes } from './cli-error.js'
const CliExitCodes = require('./cli-error.js').CliExitCodes

// ES6: `import { CliError } from './cli-error.js'
const CliError = require('./cli-error.js').CliError
const CliErrorSyntax = require('./cli-error.js').CliErrorSyntax

// ----------------------------------------------------------------------------

// Promisify a function with callback from the Node.js standard library.
Promisifier.promisifyInPlace(fs, 'readFile')
Promisifier.promisifyInPlace(fs, 'open')
Promisifier.promisifyInPlace(fs, 'close')
Promisifier.promisifyInPlace(fs, 'stat')

// ----------------------------------------------------------------------------

const userHome = require('user-home')
const timestampsPath = path.join(userHome, '.config', 'timestamps')
const timestampSuffix = '-update-check'

// ----------------------------------------------------------------------------
// Logger configuration
//
// `-s`, `--silent`: `--loglevel silent` (not even errors)
// `-q`, `--quiet`: `--loglevel warn` (errors and warnings)
// `--informative --loglevel info` (default)
// `-v`, `--verbose`: `--loglevel verbose`
// `-d`, '--debug': `--loglevel debug`
// `-dd`, '--trace': `--loglevel trace`

const defaultLogLevel = 'info'

// ----------------------------------------------------------------------------
// Exit codes:
// - 0 = Ok
// - 1 = Syntax error
// - 2 = Application error
// - 3 = Input error (no file, wrong format, etc)
// - 4 = Output error (cannot create file, cannot write, etc)
// - 5 = Child return error
// - 6 = Prerequisites (like node version)

// ============================================================================

/**
 * @classdesc
 * Base class for a CLI application.
 */
// export
class CliApplication {
  // --------------------------------------------------------------------------

  /**
   * @summary Application start().
   *
   * @returns {undefined} Does not return, it calls exit().
   *
   * @description
   * Start the CLI application, either in single shot
   * mode or interactive. (similar to _start() in POSIX)
   *
   * Called by the executable script in the bin folder.
   * Not much functionality here, just a wrapper to catch
   * global exceptions and call the CLI start implementation.
   *
   * For the exceptions to reach this top layer, all async functions
   * and all functions returning promises, must be called with `await`
   * otherwise the `UnhandledPromiseRejectionWarning` is currently
   * triggered.
   */
  static async start () {
    const Self = this

    // The actual minimum is 7.7, but conservatively use 8.x.
    if (semver.lt(process.version, '8.0.0')) {
      console.error('Please use a newer node (at least 8.x).\n')
      process.exit(CliError.ERROR.PREREQUISITES)
    }

    let exitCode = 0
    try {
      // Extract the name from the last path element; ignore extensions, if any.
      const programName = path.basename(process.argv[1]).split('.')[0]

      // Avoid running on WScript. The journey may abruptly end here.
      WscriptAvoider.quitIfWscript(programName)

      Self.log = new CliLogger(console)

      // Redirect to implementation code. After some common inits,
      // if not interactive, it'll call main().
      await Self.doStart()
      // Pass through. Do not exit, to allow REPL to run.
    } catch (ex) {
      // This should catch possible errors during inits, otherwise
      // in main(), another catch will apply.
      exitCode = isNaN(ex.exitCode) ? CliExitCodes.ERROR.APPLICATION
        : ex.exitCode
      if (ex instanceof CliError) {
        // CLI triggered error. Treat it gently.
        Self.log.error(ex.message)
      } else /* istanbul ignore next */ {
        // System error, probably due to a bug.
        // Show the full stack trace.
        console.error(ex)
      }
      Self.log.verbose(`exit(${exitCode})`)
      process.exit(exitCode)
    }
    // Pass through. Do not exit, to allow REPL to run.
  }

  /**
   * @summary Implementation of a CLI starter.
   *
   * @returns {undefined} Nothing.
   *
   * @description
   * As for any CLI application, the main input comes from the
   * command line options, available in Node.js as the
   * `process.argv` array of strings.
   *
   * One important aspect that must not be ignored, is how to
   * differentiate when called from scripts with different names.
   *
   * `process.argv0`
   * On POSIX, it is 'node' (uninteresting).
   * On Windows, it is the node full path (uninteresting as well).
   *
   * `process.argv[0]` is the node full path.
   * On macOS it looks like `/usr/local/bin/node`.
   * On Ubuntu it looks like `/usr/bin/nodejs`
   * On Windows it looks like `C:\Program Files\nodejs\node.exe`.
   *
   * `process.argv[1]` is the full path of the invoking script.
   * On macOS it is either `/usr/local/bin/xyz` or `.../bin/xyz.js`.
   * On Ubuntu it is either `/usr/bin/xyz` or `.../bin/xyz.js`.
   * On Windows, it is a path inside the `AppData` folder
   * like `C:\Users\ilg\AppData\Roaming\npm\node_modules\xyz\bin\xyz.js`
   *
   * To call a program with different names, create multiple
   * executable scripts in the `bin` folder and by processing
   * `argv[1]` it is possible to differentiate between them.
   *
   * The communication with the actual CLI implementation is done via
   * the context object, which includes a logger, a configuration
   * object and a few more properties.
   */
  static async doStart () {
    // Save the current class to be captured in the callbacks.
    const Self = this

    // To differentiate between multiple invocations with different
    // names, extract the name from the last path element; ignore
    // extensions, if any.
    Self.programName = path.basename(process.argv[1]).split('.')[0]

    // Set the application name, to make `ps` output more readable.
    process.title = Self.programName

    // Initialise the application, including commands and options.
    const context = await Self.initialiseContext(null, Self.programName,
      console, null, null)

    const log = context.log
    Self.log.level = log.level

    // These are early messages, not shown immediately,
    // are delayed until the log level is known.
    log.verbose(`${context.package.description}`)
    log.debug(`argv0: ${process.argv[1]}`)

    const config = context.config
    Self.config = config

    // Parse the common options, for example the log level.
    CliOptions.parseOptions(process.argv, context)

    log.level = config.logLevel

    process.argv.forEach((arg, index) => {
      log.debug(`start arg${index}: '${arg}'`)
    })

    log.trace(util.inspect(config))

    const serverPort = config.interactiveServerPort
    if (!serverPort) {
      if (!config.isInteractive) {
        // Non interactive means single shot (batch mode);
        // execute the command received on the command line
        // and quit. This is the most common usage.

        config.invokedFromCli = true
        // App instances exist only within a given context.
        let app = new Self(context)

        const code = await app.main(process.argv.slice(2))
        await app.checkUpdate()
        process.exit(code)
      } else {
        // Interactive mode. Use the REPL (Read-Eval-Print-Loop)
        // to get a shell like prompt to enter sequences of commands.

        const domain = require('domain').create() // eslint-disable-line node/no-deprecated-api, max-len
        domain.on('error', Self.replErrorCallback.bind(Self))
        repl.start(
          {
            prompt: Self.programName + '> ',
            eval: Self.replEvaluatorCallback.bind(Self),
            completer: Self.replCompleter.bind(Self),
            domain: domain
          }).on('exit', () => {
            console.log('Done.')
            process.exit(0)
          })
        // Pass through...
      }
    } else /* istanbul ignore next */ {
      // ----------------------------------------------------------------------
      // Useful during development, to test if everything goes to the
      // correct stream.

      const net = require('net')

      console.log(`Listening on localhost:${serverPort}...`)

      const domainSock = require('domain').create() // eslint-disable-line node/no-deprecated-api, max-len
      domainSock.on('error', Self.replErrorCallback.bind())

      net.createServer((socket) => {
        console.log(`Connection opened from ${socket.address().address}.`)

        repl.start({
          prompt: Self.programName + '> ',
          input: socket,
          output: socket,
          eval: Self.replEvaluatorCallback.bind(Self),
          completer: Self.replCompleter.bind(Self),
          domain: domainSock
        }).on('exit', () => {
          console.log('Connection closed.')
          socket.end()
        })
      }).listen(serverPort)
      // Pass through...
    }
    // Be sure no exit() is called here, since it'll close the
    // process and prevent interactive usage, which is inherently
    // asynchronous.
    log.verbose('doStart() returns')
  }

  /**
   * @summary Explicit initialiser for the class object. Kind of a
   *  static constructor.
   *
   * @returns {undefined}.
   *
   * @description
   * Must override it in the derived implementation.
   */
  static initialise () {
    // Make uppercase explicit, to know it is a static method.
    const Self = this

    // ------------------------------------------------------------------------
    // Initialise the common options, that apply to all commands,
    // like options to set logger level, to display help, etc.
    CliOptions.addOptionGroups(
      [
        {
          title: 'Common options',
          optionDefs: [
            {
              options: ['-h', '--help'],
              action: (context) => {
                context.config.isHelpRequest = true
              },
              init: (context) => {
                context.config.isHelpRequest = false
              },
              isHelp: true
            },
            {
              options: ['--version'],
              msg: 'Show version',
              action: (context) => {
                context.config.isVersionRequest = true
              },
              init: (context) => {
                context.config.isVersionRequest = false
              },
              doProcessEarly: true
            },
            {
              options: ['--loglevel'],
              msg: 'Set log level',
              action: (context, val) => {
                context.config.logLevel = val
              },
              init: (context) => {
                context.config.logLevel = defaultLogLevel
              },
              values: ['silent', 'warn', 'info', 'verbose', 'debug', 'trace'],
              param: 'level'
            },
            {
              options: ['-s', '--silent'],
              msg: 'Disable all messages (--loglevel silent)',
              action: (context) => {
                context.config.logLevel = 'silent'
              },
              init: () => { }
            },
            {
              options: ['-q', '--quiet'],
              msg: 'Mostly quiet, warnings and errors (--loglevel warn)',
              action: (context) => {
                context.config.logLevel = 'warn'
              },
              init: () => { }
            },
            {
              options: ['--informative'],
              msg: 'Informative (--loglevel info)',
              action: (context) => {
                context.config.logLevel = 'info'
              },
              init: () => { }
            },
            {
              options: ['-v', '--verbose'],
              msg: 'Verbose (--loglevel verbose)',
              action: (context) => {
                context.config.logLevel = 'verbose'
              },
              init: () => { }
            },
            {
              options: ['-d', '--debug'],
              msg: 'Debug messages (--loglevel debug)',
              action: (context) => {
                const config = context.config
                if (config.logLevel === 'debug') {
                  config.logLevel = 'trace'
                } else {
                  config.logLevel = 'debug'
                }
              },
              init: () => { }
            },
            {
              options: ['-dd', '--trace'],
              msg: 'Trace messages (--loglevel trace, -d -d)',
              action: (context) => {
                context.config.logLevel = 'trace'
              },
              init: () => { }
            },
            {
              options: ['--no-update-notifier'],
              msg: 'Skip check for a more recent version',
              action: (context) => {
                context.config.noUpdateNotifier = true
              },
              init: () => { }
            },
            {
              options: ['-C'],
              msg: 'Set current folder',
              action: (context, val) => {
                const config = context.config
                if (path.isAbsolute(val)) {
                  config.cwd = val
                } else if (config.cwd) {
                  config.cwd = path.resolve(config.cwd, val)
                } else /* istanbul ignore next */ {
                  config.cwd = path.resolve(val)
                }
                context.log.debug(`set cwd: '${config.cwd}'`)
              },
              init: (context) => {
                context.config.cwd = context.processCwd
              },
              param: 'folder'
            }
          ]
        }
      ]
    )

    Self.doInitialise()

    if (Self.hasInteractiveMode) {
      CliOptions.appendToOptionGroups('Common options',
        [
          {
            options: ['-i', '--interactive'],
            msg: 'Enter interactive mode',
            action: (context) => {
              context.config.isInteractive = true
            },
            init: (context) => {
              context.config.isInteractive = false
            },
            doProcessEarly: true
          },
          {
            options: ['--interactive-server-port'],
            action: (context, val) => /* istanbul ignore next */ {
              context.config.interactiveServerPort = val
            },
            init: (context) => {
              context.config.interactiveServerPort = undefined
            },
            hasValue: true,
            doProcessEarly: true
          }
        ]
      )
    }

    assert(Self.rootPath, 'mandatory rootPath not set')
  }

  /**
   * @summary Default implementation for the static class initialiser.
   *
   * @returns {undefined} Nothing.
   *
   * @description
   * Override it in the derived implementation.
   */
  static doInitialise () /* istanbul ignore next */ {
    assert(false, 'Must override in derived implementation!')
  }

  /**
   * @summary Default initialiser for the configuration options.
   *
   * @param {Object} context Reference to the context object.
   * @returns {undefined} Nothing
   *
   * @description
   * If further inits are needed, override `doInitialiseConfiguration()`
   * in the derived implementation.
   */
  static initialiseConfiguration (context) {
    // Make uppercase explicit, to know it is a static method.
    const Self = this
    const config = context.config
    assert(config, 'Configuration')

    config.isInteractive = false
    config.interactiveServerPort = undefined

    config.logLevel = defaultLogLevel

    const optionGroups = CliOptions.getCommonOptionGroups()
    optionGroups.forEach((optionGroup) => {
      optionGroup.optionDefs.forEach((optionDef) => {
        optionDef.init(context)
      })
    })

    Self.doInitialiseConfiguration(context)
  }

  /**
   * @summary Custome initialiser for the configuration options.
   *
   * @param {Object} context Reference to the context object.
   * @returns {undefined} Nothing.
   *
   * @description
   * Override it in the derived implementation.
   */
  static doInitialiseConfiguration (context) {
    const config = context.config
    assert(config, 'Configuration')
  }

  /**
   * @summary Initialise a minimal context object.
   *
   * @param {Object} ctx Reference to a context, or null to create an
   *   empty context.
   * @param {string} programName The invocation name of the program.
   * @param {Object} console_ Reference to a node console.
   * @param {Object} log_ Reference to a npm log instance.
   * @param {Object} config Reference to a configuration.
   * @returns {Object} Reference to context.
   */
  static async initialiseContext (ctx, programName, console_ = null,
    log_ = null, config = null) {
    // Make uppercase explicit, to know it is a static method.
    const Self = this

    // Call the application initialisation callback, to prepare
    // the structure needed to manage the commands and option.
    if (!Self.isInitialised) {
      Self.initialise()

      Self.isInitialised = true
    }

    // Use the given context, or create an empty one.
    const context = ctx || vm.createContext()

    // REPL should always set the console, be careful not to
    // overwrite it.
    if (!context.console) {
      // Cannot use || because REPL context has only a getter.
      context.console = console_ || console
    }

    assert(context.console)
    context.programName = programName

    context.cmdPath = process.argv[1]
    context.processCwd = process.cwd()
    context.processEnv = process.env
    context.processArgv = process.argv

    // For convenience, copy root path from class to instance.
    context.rootPath = Self.rootPath

    if (!context.package) {
      context.package = await Self.readPackageJson()
    }

    // Initialise configuration.
    context.config = config || {}
    Self.initialiseConfiguration(context)
    if (!context.config.cwd) /* istanbul ignore next */ {
      context.config.cwd = context.processCwd
    }

    context.log = log_ || new CliLogger(context.console,
      context.config.logLevel)

    assert(context.log)

    CliOptions.initialise(context)

    return context
  }

  /**
   * @summary Read package JSON file.
   *
   * @param {string} rootPath The absolute path of the package.
   * @returns {Object} The package definition, unmodified.
   * @throws Error from `fs.readFile()` or `JSON.parse()`.
   *
   * @description
   * By default, this function uses the package root path
   * stored in the class property during initialisation.
   * When called from tests, the path must be passed explicitly.
   */
  static async readPackageJson (rootPath = this.rootPath) {
    const filePath = path.join(rootPath, 'package.json')
    const fileContent = await fs.readFilePromise(filePath)
    assert(fileContent !== null)
    return JSON.parse(fileContent.toString())
  }

  // --------------------------------------------------------------------------

  /**
   * @summary Node.js callback.
   *
   * @callback nodeCallback
   * @param {number} responseCode
   * @param {string} responseMessage
   */

  /**
   * @summary A REPL completer.
   *
   * @param {string} linePartial The incomplete line.
   * @param {nodeCallback} callback Called on completion or error.
   * @returns {undefined} Nothing.
   *
   * @description
   * TODO: Add code.
   */
  static replCompleter (linePartial, callback) /* istanbul ignore next */ {
    // callback(null, [['babu', 'riba'], linePartial])
    // console.log(linePartial)
    // If no completion available, return error (an empty string does it too).
    // callback(null, [[''], linePartial])
    callback(new Error('no completion'))
  }

  /**
   * @summary REPL callback.
   *
   * @callback replCallback
   * @param {number} responseCode or null
   * @param {string} [responseMessage] If present, the string will
   *  be displayed.
   */

  /**
   * @summary Callback used by REPL when a line is entered.
   *
   * @param {string} cmdLine The entire line, unparsed.
   * @param {Object} context Reference to a context.
   * @param {string} filename The name of the file.
   * @param {replCallback} callback Called on completion or error.
   * @returns {undefined} Nothing
   *
   * @description
   * The function is passed to REPL with `.bind(Self)`, so it'll have
   * access to all class properties, like Self.programName.
   */
  static async replEvaluatorCallback (cmdLine, context, filename, callback) {
    // REPL always sets the console to point to its input/output.
    // Be sure it is so.
    assert(context.console !== undefined)
    const Self = this

    let app = null

    // It is mandatory to catch errors, this is an old style callback.
    try {
      // Fill in the given context, created by the REPL interpreter.
      // Start with an empty config, not the Self.config.
      // With the current non-reentrant log, use the global object.
      await Self.initialiseContext(context, Self.programName, null, null, null)

      // Definitely an interactive session.
      context.config.isInteractive = true

      // And definitely the module was invoked from CLI, not from
      // another module.
      context.config.invokedFromCli = true

      // Create an instance of the application class, for the given context.
      app = new Self(context)

      // Split command line and remove any number of spaces.
      const args = cmdLine.trim().split(/\s+/)

      await app.main(args)

      app = null // Pale attempt to help the GC.

      // Success, but do not return any value, since REPL thinks it
      // is a string that must be displayed.
      callback(null)
    } catch (ex) /* istanbul ignore next */ {
      app = null
      // Failure, will display `Error: ${ex.message}`.
      callback(ex)
    }
  }

  /**
   * @summary Error callback used by REPL.
   *
   * @param {Object} err Reference to error triggered inside REPL.
   * @returns {undefined} Nothing.
   *
   * @description
   * This is tricky and took some time to find a workaround to avoid
   * displaying the stack trace on error.
   */
  static replErrorCallback (err) /* istanbul ignore next */ {
    // if (!(err instanceof SyntaxError)) {
    // System errors deserve their stack trace.
    if (!(err instanceof EvalError) && !(err instanceof SyntaxError) &&
      !(err instanceof RangeError) && !(err instanceof ReferenceError) &&
      !(err instanceof TypeError) && !(err instanceof URIError)) {
      // For regular errors it makes no sense to display the stack trace.
      err.stack = null
      console.log(err)
      // The error message will be displayed shortly, in the next handler,
      // registered by the REPL server.
    }
  }

  // --------------------------------------------------------------------------

  /**
   * Constructor, to remember the context.
   *
   * @param {Object} context Reference to a context.
   */
  constructor (context) {
    assert(context)
    assert(context.console)
    assert(context.log)
    assert(context.config)

    this.context = context
    const log = this.context.log

    log.trace(`${this.constructor.name}.constructor()`)
  }

  /**
   * @summary Display the main help page.
   *
   * @returns {undefined}
   *
   * @description
   * Override it in the application if custom content is desired.
   */
  help () {
    // Make uppercase explicit, to know it is a static method.
    const Self = this.constructor

    const log = this.context.log
    log.trace(`${this.constructor.name}.help()`)

    const help = new CliHelp(this.context)

    if (Self.command) {
      const optionGroups = Self.command.optionGroups
        .concat(CliOptions.getCommonOptionGroups())

      help.outputMainHelp(undefined, optionGroups, Self.command.title)
    } else {
      help.outputMainHelp(CliOptions.getCommandsFirstArray(),
        CliOptions.getCommonOptionGroups())
    }
  }

  async didIntervalExpire (deltaSeconds) {
    const context = this.context
    const log = context.log

    const fpath = path.join(timestampsPath, context.package.name +
      timestampSuffix)
    try {
      const stats = await fs.statPromise(fpath)
      if (stats.mtime) {
        const crtDelta = Date.now() - stats.mtime
        if (crtDelta < (deltaSeconds * 1000)) {
          log.trace('update timeout did not expire ' +
            `${Math.floor(crtDelta / 1000)} < ${deltaSeconds}`)
          return false
        }
      }
    } catch (ex) {
      log.trace('no previous update timestamp')
    }
    return true
  }

  async getLatestVersion () {
    const Self = this.constructor
    const context = this.context
    const config = context.config
    const log = context.log

    if (!Self.checkUpdatesIntervalSeconds ||
      Self.checkUpdatesIntervalSeconds === 0 ||
      isCi ||
      config.isVersionRequest ||
      !process.stdout.isTTY ||
      'NO_UPDATE_NOTIFIER' in process.env ||
      config.noUpdateNotifier) {
      log.trace('do not fetch latest version number.')
      return
    }

    if (await this.didIntervalExpire(Self.checkUpdatesIntervalSeconds)) {
      log.trace('fetching latest version number...')
      // At this step only create the promise,
      // its result is checked before exit.
      this.latestVersionPromise = latestVersion(context.package.name)
    }
  }

  async checkUpdate () {
    const context = this.context
    const log = context.log

    if (!this.latestVersionPromise) {
      // If the promise was not created, no action.
      return
    }

    const ver = await this.latestVersionPromise
    log.trace(`${context.package.version} → ${ver}`)

    if (semverDiff(context.package.version, ver)) {
      // If versions differ, notify user.
      let isGlobal = isInstalledGlobally ? ' --global' : ''

      let msg = '\n'
      msg += `>>> New version ${context.package.version} -> `
      msg += `${ver} available. <<<\n`
      msg += ">>> Run '"
      if (os.platform() !== 'win32') {
        if (isInstalledGlobally && isPathInside(__dirname, '/usr/local')) {
          // May not be very reliable if installed in another system location.
          msg += 'sudo '
        }
      }
      msg += `npm install ${context.package.name}${isGlobal}' to update. <<<`
      log.info(msg)
    }

    if (process.geteuid && process.geteuid() !== process.getuid()) {
      // If running as root, skip writing the timestamp to avoid
      // later EACCES or EPERM.
      log.trace(`geteuid() ${process.geteuid()} != ${process.getuid()}`)
      return
    }

    await makeDir(timestampsPath)

    const fpath = path.join(timestampsPath, context.package.name +
      timestampSuffix)
    await del(fpath, {force: true})

    // Create an empty file, only the modified date is checked.
    const fd = await fs.openPromise(fpath, 'w')
    await fs.closePromise(fd)

    log.debug('timestamp created')
  }

  /**
   * @summary The main entry point for the `xyz` command.
   *
   * @param {string[]} argv Arguments array.
   * @returns {number} The exit code.
   *
   * @description
   * Override it in the application if custom behaviour is desired.
   */
  async main (argv) {
    const Self = this.constructor

    const context = this.context
    context.startTime = Date.now()

    const log = context.log
    log.trace(`${this.constructor.name}.main()`)

    const config = context.config

    argv.forEach((arg, index) => {
      log.trace(`main arg${index}: '${arg}'`)
    })

    Self.doInitialiseConfiguration(context)
    const remaining = CliOptions.parseOptions(argv, context)

    log.trace(util.inspect(context.config))

    await this.getLatestVersion()

    // Early detection of `--version`, since it makes
    // all other irrelevant.
    if (config.isVersionRequest) {
      log.always(context.package.version)
      return CliExitCodes.SUCCESS
    }

    // Copy relevant args to local array.
    // Start with 0, possibly end with `--`.
    const mainArgs = CliOptions.filterOwnArguments(argv)

    // Isolate commands as words with letters and inner dashes.
    // First non word (probably option) ends the list.
    const cmds = []
    if (CliOptions.hasCommands()) {
      for (const arg of mainArgs) {
        const lowerCaseArg = arg.toLowerCase()
        if (lowerCaseArg.match(/^[a-z][a-z-]*/)) {
          cmds.push(lowerCaseArg)
        } else {
          break
        }
      }
    }

    // Save the commands in the context, for possible later use, since
    // they are skiped when calling the command implementation.
    context.commands = cmds

    // Must be executed before help().
    if (Self.Command) {
      Self.command = new Self.Command(context)
    }

    // If no commands and -h, output help message.
    if ((cmds.length === 0) && config.isHelpRequest) {
      this.help()
      return CliExitCodes.SUCCESS // Help explicitly called.
    }

    if (CliOptions.hasCommands()) {
      // If no commands, output help message and return error.
      if (cmds.length === 0) {
        log.error('Missing mandatory command.')
        this.help()
        return CliExitCodes.ERROR.SYNTAX // No commands.
      }
    }

    await makeDir(config.cwd)
    process.chdir(config.cwd)
    log.debug(`cwd()='${process.cwd()}'`)

    let exitCode = CliExitCodes.SUCCESS
    try {
      if (Self.command) {
        log.debug(`'${context.programName}' ` +
          `started`)

        exitCode = await Self.command.run(remaining)
        log.debug(`'${context.programName}' - returned ${exitCode}`)
      } else {
        const found = CliOptions.findCommandClass(cmds, Self.rootPath,
          CliCommand)
        const CmdDerivedClass = found.CmdClass

        // Full name commands, not the actual encountered shortcuts.
        context.fullCommands = found.fullCommands

        log.debug(`Command(s): '${context.fullCommands.join(' ')}'`)

        // Use the original array, since we might have `--` options,
        // and skip already processed commands.
        const cmdArgs = remaining.slice(cmds.length - found.rest.length)
        cmdArgs.forEach((arg, index) => {
          log.trace(`cmd arg${index}: '${arg}'`)
        })

        Self.doInitialiseConfiguration(context)
        const cmdImpl = new CmdDerivedClass(context)

        log.debug(`'${context.programName} ` +
          `${context.fullCommands.join(' ')}' started`)

        exitCode = await cmdImpl.run(cmdArgs)
        log.debug(`'${context.programName} ` +
          `${context.fullCommands.join(' ')}' - returned ${exitCode}`)
      }
      return exitCode
    } catch (ex) {
      exitCode = isNaN(ex.exitCode) ? CliExitCodes.ERROR.APPLICATION
        : ex.exitCode
      if (ex instanceof CliErrorSyntax) {
        // CLI triggered error. Treat it gently and try to be helpful.
        log.error(ex.message)
        this.help()
        exitCode = isNaN(ex.exitCode) ? CliExitCodes.ERROR.SYNTAX
          : ex.exitCode
      } else if (ex instanceof CliError) {
        // Other CLI triggered error. Treat it gently.
        log.error(ex.message)
      } else {
        // System error, probably due to a bug.
        // Show the full stack trace.
        log.error(ex)
      }
      log.verbose(`exit(${exitCode})`)
      return exitCode
    }
  }
}

// ----------------------------------------------------------------------------
// Node.js specific export definitions.

// By default, `module.exports = {}`.
// The CliApplication class is added as a property of this object.
module.exports.CliApplication = CliApplication

// In ES6, it would be:
// export class CliApplication { ... }
// ...
// import { CliApplication } from 'cli-application.js'

// ----------------------------------------------------------------------------
