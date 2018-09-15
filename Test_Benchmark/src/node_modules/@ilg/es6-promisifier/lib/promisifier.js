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

const assert = require('assert')

// ----------------------------------------------------------------------------

// Inspired by:
// https://github.com/digitaldesignlabs/es6-promisify/blob/master/lib/promisify.js

// Another possible implementations:
// - https://github.com/kriskowal/q (a bit oldish)
// - https://github.com/jeandesravines/promisify/blob/master/lib/helper/promisify.js
// - https://github.com/urban/promisify/blob/master/src/index.js

// ============================================================================

// export
class Promisifier {
  /**
   * @summary Promisify a callback function.
   *
   * @param {function} original - The function to promisify
   * @param {Object} settings - Settings object.
   * @param {Object} settings.thisArg - A `this` context to use.
   *  If not set, assume `settings` _is_ `thisArg`.
   * @param {bool} settings.multiArgs - Should multiple arguments
   *  be returned as an array?
   * @returns {function} A promisified version of `original`.
   *
   * @description
   * Transform a callback-based function
   * `func(arg1, arg2 .. argN, callback)` into
   * an ES6-compatible Promise. Promisify provides a default callback
   * of the form (error, result)
   * and rejects when `error` is truthy. You can also supply settings
   * object as the second argument.
   */
  static promisify (original, settings) {
    // Explicit upper case to know it is a class.
    const Self = this

    return function (...args) {
      const returnMultipleArguments = settings && settings.multiArgs

      let target
      if (settings && settings.thisArg) {
        target = settings.thisArg
      } else if (settings) {
        target = settings
      }

      // Return the promisified function.
      return new Promise(function (resolve, reject) {
        // Append the callback bound to the context
        args.push(function callback (err, ...values) {
          if (err) {
            return reject(err)
          }

          if (!!returnMultipleArguments === false) {
            return resolve(values[0])
          }

          resolve(values)
        })

        // Call the function.
        const response = original.apply(target, args)

        // If it looks like original already returns a promise,
        // then just resolve with that promise. Hopefully, the callback
        // function we added will just be ignored.
        if (Self.thatLooksLikeAPromiseToMe(response)) {
          resolve(response)
        }
      })
    }
  }

  /**
   * @summary Promisify an existing function directly in the module.
   *
   * @param {object} object The module where the function is defined.
   * @param {string} originalName The function name.
   * @param {object} settings Possible settings, see before.
   * @returns {undefined} Nothing.
   *
   * @description
   * Create a new function, named similarly but suffixed with `Promise`
   * and add it to the object.
   * Also add the function below a`promises` object, with the original name.
   *
   * If the function is already there from a previous call, do nothing.
   */
  static promisifyInPlace (object, originalName, settings) {
    let Self = this
    assert(object[originalName])
    assert(typeof object[originalName] === 'function')

    const promiseName = originalName + 'Promise'
    // If already there, from a previous call, not much to do.
    if (!object[promiseName]) {
      object[promiseName] = Self.promisify(object[originalName], settings)
    }
    assert(typeof object[promiseName] === 'function')

    if (!object.promises) {
      // On first call add an empty `promises` object.
      object.promises = {}
    }

    if (!object.promises[originalName]) {
      // Add another instance of the promisified function below `promises`.
      object.promises[originalName] = object[promiseName]
    }
    assert(typeof object.promises[originalName] === 'function')
  }

  /**
   * Scope: local
   * thatLooksLikeAPromiseToMe()
   *
   * Duck-types a promise.
   *
   * @param {Object} o Reference to object to check.
   * @returns {boolean} True if this resembles a promise
   */
  static thatLooksLikeAPromiseToMe (o) {
    return o && typeof o.then === 'function' && typeof o.catch === 'function'
  }

  // --------------------------------------------------------------------------

  constructor () {
    assert(false, 'The Promisifier is a static object, no instances allowed.')
  }
}

// ----------------------------------------------------------------------------
// Node.js specific export definitions.

// By default, `module.exports = {}`.
// The Promisifier class is added as a property of this object.
module.exports.Promisifier = Promisifier

// In ES6, it would be:
// export class Promisifier { ... }
// ...
// import { Promisifier } from 'promisifier.js'

// ----------------------------------------------------------------------------
