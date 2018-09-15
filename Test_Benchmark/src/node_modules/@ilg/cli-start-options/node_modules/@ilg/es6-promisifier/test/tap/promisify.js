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
 * Test the promisify() function.
 */

// ----------------------------------------------------------------------------

const fs = require('fs')

// The `[node-tap](http://www.node-tap.org)` framework.
const test = require('tap').test

const Promisifier = require('../../index.js').Promisifier

// ----------------------------------------------------------------------------

const mock = function (delay, isOk, value, callback) {
  setTimeout(() => {
    if (isOk) {
      callback(null, value)
    } else {
      callback(new Error(value))
    }
  }, delay)
}

const mockPromise = Promisifier.promisify(mock)

const multi = function (delay, isOk, value1, value2, callback) {
  setTimeout(() => {
    if (isOk) {
      callback(null, value1, value2)
    } else {
      callback(new Error(value1))
    }
  }, delay)
}

const multiPromise = Promisifier.promisify(multi, { multiArgs: true })
const singlePromise = Promisifier.promisify(multi)

const already = function (delay, isOk, value) {
  return new Promise((resolve, reject) => {
    setTimeout(() => {
      if (isOk) {
        resolve(value)
      } else {
        reject(new Error(value))
      }
    }, delay)
  })
}

const alreadyPromise = Promisifier.promisify(already)

const thisArg = function (delay, isOk, value, callback) {
  const self = this
  setTimeout(() => {
    if (isOk) {
      self.value = value
      callback(null, value)
    } else {
      callback(new Error(value))
    }
  }, delay)
}

const context = {
  xyz: true
}
const thisArgPromise = Promisifier.promisify(thisArg, { thisArg: context })

// ----------------------------------------------------------------------------

test('original success', (t) => {
  mock(10, true, 7, (err, result) => {
    t.isEqual(err, null, 'null error')
    t.isEqual(result, 7, 'returned value')
    t.end()
  })
})

test('original error', (t) => {
  mock(10, false, 'Boom!', (err, result) => {
    t.ok(err, 'have error')
    t.equal(err.message, 'Boom!', 'error message match')
    t.equal(result, undefined, 'no returned value')
    t.end()
  })
})

test('promisify success', (t) => {
  mockPromise(10, true, 7)
    .then((result) => {
      t.equal(result, 7, 'returned value')
      t.end()
    }).catch((reason) => {
      t.fail('resolve exception')
      t.end()
    })
})

test('promisify error', (t) => {
  mockPromise(10, false, 'Bang!')
    .then((result) => {
      t.fail('no exception')
      t.end()
    }).catch((reason) => {
      t.equal(reason.message, 'Bang!', 'exception message')
      t.end()
    })
})

test('promisify success await', async (t) => {
  try {
    const result = await mockPromise(10, true, 7)
    t.equal(result, 7, 'returned value')
  } catch (err) {
    t.fail('resolve exception')
  }
  t.end()
})

test('promisify error await', async (t) => {
  try {
    await mockPromise(10, false, 'Bang!')
    t.fail('no exception')
  } catch (err) {
    t.equal(err.message, 'Bang!', 'exception message')
  }
  t.end()
})

test('promisify multi success', (t) => {
  multiPromise(10, true, 7, 8)
    .then((result) => {
      t.ok(Array.isArray(result), 'result is array')
      t.equal(result[0], 7, 'first value')
      t.equal(result[1], 8, 'second value')
      t.end()
    }).catch((reason) => {
      t.fail('resolve exception')
      t.end()
    })
})

test('promisify multi error', (t) => {
  multiPromise(10, false, 'Bang!', 'Boom!')
    .then((result) => {
      t.fail('no exception')
      t.end()
    }).catch((reason) => {
      t.equal(reason.message, 'Bang!', 'exception message')
      t.end()
    })
})

test('promisify multi success await', async (t) => {
  try {
    const result = await multiPromise(10, true, 7, 8)
    t.ok(Array.isArray(result), 'result is array')
    t.equal(result[0], 7, 'first value')
    t.equal(result[1], 8, 'second value')
  } catch (reason) {
    t.fail('resolve exception')
  }
  t.end()
})

test('promisify multi error await', async (t) => {
  try {
    await multiPromise(10, false, 'Bang!', 'Boom!')
    t.fail('no exception')
  } catch (reason) {
    t.equal(reason.message, 'Bang!', 'exception message')
  }
  t.end()
})

test('promisify single success', (t) => {
  singlePromise(10, true, 7, 8)
    .then((result) => {
      t.notOk(Array.isArray(result), 'result is not array')
      t.equal(result, 7, 'value')
      t.end()
    }).catch((reason) => {
      t.fail('resolve exception')
      t.end()
    })
})

test('promisify single error', (t) => {
  singlePromise(10, false, 'Bang!', 'Boom!')
    .then((result) => {
      t.fail('no exception')
      t.end()
    }).catch((reason) => {
      t.equal(reason.message, 'Bang!', 'exception message')
      t.end()
    })
})

test('promisify single success await', async (t) => {
  try {
    const result = await singlePromise(10, true, 7, 8)
    t.notOk(Array.isArray(result), 'result is not array')
    t.equal(result, 7, 'value')
  } catch (reason) {
    t.fail('resolve exception')
  }
  t.end()
})

test('promisify single error await', async (t) => {
  try {
    await singlePromise(10, false, 'Bang!', 'Boom!')
    t.fail('no exception')
  } catch (reason) {
    t.equal(reason.message, 'Bang!', 'exception message')
  }
  t.end()
})

test('promisify already success await', async (t) => {
  try {
    const result = await alreadyPromise(10, true, 7)
    t.equal(result, 7, 'returned value')
  } catch (err) {
    t.fail('resolve exception')
  }
  t.end()
})

test('promisify already error await', async (t) => {
  try {
    await alreadyPromise(10, false, 'Bang!')
    t.fail('no exception')
  } catch (err) {
    t.equal(err.message, 'Bang!', 'exception message')
  }
  t.end()
})

test('promisify thisArg success await', async (t) => {
  try {
    context.value = 1
    const result = await thisArgPromise(10, true, 7)
    t.equal(result, 7, 'returned value')
    t.equal(context.value, 7, 'context value')
  } catch (err) {
    t.fail('resolve exception')
  }
  t.end()
})

test('promisify thisArg error await', async (t) => {
  try {
    await thisArgPromise(10, false, 'Bang!')
    t.fail('no exception')
  } catch (err) {
    t.equal(err.message, 'Bang!', 'exception message')
  }
  t.end()
})

test('constructor', (t) => {
  try {
    var obj = new Promisifier()
    t.notOk(obj, 'no return')
  } catch (err) {
    t.match(err.name, 'AssertionError', 'assert')
  }
  t.end()
})

test('promisify in place', (t) => {
  t.notOk(fs.readFilePromise, 'promise not there')
  Promisifier.promisifyInPlace(fs, 'readFile')
  t.ok(fs.readFilePromise, 'promise now available')
  Promisifier.promisifyInPlace(fs, 'readFile')
  t.ok(fs.readFilePromise, 'promise still there')

  t.end()
})

// ----------------------------------------------------------------------------
