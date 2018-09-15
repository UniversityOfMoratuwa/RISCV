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
 * This file provides support for displaying the application and
 * command specific help.
 */

// ============================================================================

// export
class CliHelp {
  // --------------------------------------------------------------------------

  constructor (ctx) {
    this.context = ctx
    this.middleLimit = 40
    this.rightLimit = 79 // Do not write in col 80
  }

  outputCommands (commands, description, msg = '[<args>...]') {
    const log = this.context.log
    let programName = this.context.programName

    log.output()
    if (!description) {
      const pkgJson = this.context.package
      description = pkgJson.description
    }
    log.output(`${description}`)

    this.commands = commands
    if (commands) {
      // Deep copy & sort
      let cmds = commands.slice()
      cmds.sort()

      log.output(`Usage: ${programName} <command> [<subcommand>...]` +
        ` [<options> ...] ${msg}`)
      log.output()
      log.output('where <command> is one of:')
      let buf = null
      cmds.forEach((cmd, i) => {
        if (buf === null) {
          buf = '  '
        }
        buf += cmd
        if (i !== (cmds.length - 1)) {
          buf += ', '
        }
        if (buf.length > this.rightLimit) {
          log.output(buf)
          buf = null
        }
      })
      if (buf != null) {
        log.output(buf)
        buf = null
      }
    } else {
      log.output(`Usage: ${programName} ` + ` [<options> ...] ${msg}`)
    }
  }

  static padRight (str, n) {
    str += ' '.repeat(n)
    return str.substr(0, n)
  }

  outputHelpDetails (options, more = this.more) {
    const log = this.context.log
    const programName = this.context.programName

    const s1 = `${programName} -h|--help`
    const s2 = `${programName} <command> -h|--help`
    if (more.isFirstPass) {
      if (s1.length > more.width) {
        more.width = s1.length
      }
      if (this.commands) {
        if (s2.length > more.width) {
          more.width = s2.length
        }
      }
    } else {
      log.output()
      this.outputMaybeLongLine(s1, 'Quick help', more)
      if (this.commands) {
        this.outputMaybeLongLine(s2, 'Quick help on command', more)
      }
    }
  }

  outputMaybeLongLine (out, msg, more = this.more) {
    const log = this.context.log
    if (out.length >= more.limit) {
      log.output(out)
      out = ''
    }
    out += ' '.repeat(more.width)
    let desc = ''
    if (msg) {
      desc = msg + ' '
    }
    log.output(`${CliHelp.padRight(out, more.width)} ${desc}`)
  }

  outputEarlyDetails (optionGroups, more = this.more) {
    const programName = this.context.programName

    if (!more.isFirstPass) {
      // log.output()
    }

    optionGroups.forEach((optionGroup) => {
      optionGroup.optionDefs.forEach((optionDef) => {
        if (optionDef.msg && optionDef.doProcessEarly) {
          let out = `${programName} `
          optionDef.options.forEach((opt, index) => {
            out += opt
            if (index < (optionDef.options.length - 1)) {
              out += '|'
            }
          })
          if (more.isFirstPass) {
            if (out.length > more.width) {
              more.width = out.length
            }
          } else {
            this.outputMaybeLongLine(out, optionDef.msg, more)
          }
        }
      })
    })
  }

  outputOptionGroups (optionGroups, more = this.more) {
    optionGroups.forEach((optionGroup) => {
      this.outputOptions(optionGroup.optionDefs, optionGroup.title, more)
    })
  }

  outputOptions (optionDefs, title, more = this.more) {
    const log = this.context.log

    let hasContent = false
    optionDefs.forEach((optionDef) => {
      if (optionDef.msg && !optionDef.doProcessEarly && !optionDef.isHelp) {
        hasContent = true
      }
    })
    if (!hasContent) {
      return
    }

    if (!more.isFirstPass && title) {
      log.output()
      log.output(title + ':')
    }

    optionDefs.forEach((optionDef) => {
      if (optionDef.msg && !optionDef.doProcessEarly && !optionDef.isHelp) {
        let strOpts = '  '
        optionDef.options.forEach((opt, index) => {
          strOpts += opt
          if (index < (optionDef.options.length - 1)) {
            strOpts += '|'
          }
        })
        if (optionDef.hasValue || optionDef.values || optionDef.param) {
          if (optionDef.param) {
            strOpts += ` <${optionDef.param}>`
          } else {
            strOpts += ' <s>'
          }
        }

        if (more.isFirstPass) {
          if (strOpts.length > more.width) {
            more.width = strOpts.length
          }
        } else {
          if (strOpts.length >= more.limit) {
            log.output(strOpts)
            strOpts = ''
          }
          strOpts += ' '.repeat(more.width)
          let desc = ''
          if (optionDef.msg.length > 0) {
            desc = optionDef.msg + ' '
          }
          if (Array.isArray(optionDef.values)) {
            desc += '('
            optionDef.values.forEach((value, index) => {
              desc += value
              if (index < (optionDef.values.length - 1)) {
                desc += '|'
              }
            })
            desc += ') '
          }
          const msgDefault = optionDef.msgDefault
            ? `, default ${optionDef.msgDefault}` : ''
          if (optionDef.isOptional && optionDef.isMultiple) {
            desc += `(optional, multiple${msgDefault})`
          } else if (optionDef.isOptional) {
            desc += `(optional${msgDefault})`
          } else if (optionDef.isMultiple) {
            desc += `(multiple)`
          }
          log.output(`${CliHelp.padRight(strOpts, more.width)} ${desc}`)
        }
      }
    })
  }

  outputCommandLine (title, optionGroups) {
    const log = this.context.log
    const programName = this.context.programName

    log.output()
    log.output(title)
    const commands = this.context.fullCommands
    const usage = `Usage: ${programName} ${commands}`
    let str = usage

    let optionDefs = []
    if (optionGroups && (optionGroups.length > 0) &&
      optionGroups[0].preOptions) {
      str += ' ' + optionGroups[0].preOptions
    }
    str += ' [options...]'
    optionGroups.forEach((optionGroup) => {
      optionDefs = optionDefs.concat(optionGroup.optionDefs)
    })
    let optStr
    optionDefs.forEach((optionDef) => {
      optStr = ''
      optionDef.options.forEach((val) => {
        // Assume the longest option is the more readable.
        if (val.length > optStr.length) {
          optStr = val
        }
      })
      if (optionDef.param) {
        optStr += ` <${optionDef.param}>`
      } else if (optionDef.hasValue) {
        optStr += ` <s>`
      }
      if (optionDef.isOptional) {
        optStr = `[${optStr}]`
        if (optionDef.isMultiple) {
          optStr += '*'
        }
      } else if (optionDef.isMultiple) {
        optStr = `[${optStr}]+`
      }

      // log.output(optStr)
      if (str.length + optStr.length + 1 > this.rightLimit) {
        log.output(str)
        str = ' '.repeat(usage.length)
      }
      str += ' ' + optStr
    })
    if (optionGroups && (optionGroups.length > 0) &&
      optionGroups[0].postOptions) {
      optStr = optionGroups[0].postOptions
      if (str.length + optStr.length + 1 > this.rightLimit) {
        log.output(str)
        str = ' '.repeat(usage.length)
      }
      str += ' ' + optStr
    }
    if (str.length > usage.length) {
      log.output(str)
    }
  }

  outputFooter () {
    const log = this.context.log
    const pkgJson = this.context.package

    log.output()
    const pkgPath = this.context.rootPath
    log.output(`npm ${pkgJson.name}@${pkgJson.version} '${pkgPath}'`)
    if (pkgJson.homepage) {
      log.output(`Home page: <${pkgJson.homepage}>`)
    }
    const br = 'Bug reports:'
    if (pkgJson.bugs && pkgJson.bugs.url) {
      log.output(`${br} <${pkgJson.bugs.url}>`)
    } else if (pkgJson.author) {
      if (typeof pkgJson.author === 'object') {
        log.output(`${br} ${pkgJson.author.name} <${pkgJson.author.email}>`)
      } else if (typeof pkgJson.author === 'string') {
        log.output(`${br} ${pkgJson.author}`)
      }
    }
  }

  outputMainHelp (cmds, optionGroups, description) {
    // Try to get a message from the first group.
    this.outputCommands(cmds, description, optionGroups[0].msg)

    // The special trick here is how to align the right column.
    // For this two steps are needed, with the first to compute
    // the max width of the first column, and then to output text.

    this.twoPassAlign(() => {
      this.outputOptionGroups(optionGroups)
      this.outputHelpDetails(optionGroups)
      this.outputEarlyDetails(optionGroups)
    })

    this.outputFooter()
  }

  twoPassAlign (f) {
    let more = this.firstPass()
    f()
    this.secondPass(more)
    f()
  }

  firstPass () {
    this.more = {
      isFirstPass: true,
      width: 0,
      limit: this.middleLimit
    }
    return this.more
  }

  secondPass (more = this.more) {
    more.isFirstPass = false
    // One more is implicit, so a total 2 spaces between columns.
    more.width += 1
    if (more.width > more.limit) {
      more.width = more.limit
    }
    return more
  }
}

// ----------------------------------------------------------------------------
// Node.js specific export definitions.

// By default, `module.exports = {}`.
// The CliHelp class is added as a property of this object.
module.exports.CliHelp = CliHelp

// In ES6, it would be:
// export class CliHelp { ... }
// ...
// import { CliHelp } from 'cli-help.js'

// ----------------------------------------------------------------------------
