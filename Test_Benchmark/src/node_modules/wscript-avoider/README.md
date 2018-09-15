[![npm (scoped)](https://img.shields.io/npm/v/wscript-avoider.svg)](https://www.npmjs.com/package/wscript-avoider) 
[![npm](https://img.shields.io/npm/dt/wscript-avoider.svg)](https://www.npmjs.com/package/wscript-avoider)
[![license](https://img.shields.io/github/license/xpack/wscript-avoider-js.svg)](https://github.com/xpack/wscript-avoider-js/blob/xpack/LICENSE) 
[![Standard](https://img.shields.io/badge/code_style-standard-brightgreen.svg)](https://standardjs.com/)
[![Travis](https://img.shields.io/travis/xpack/wscript-avoider-js.svg?label=linux)](https://travis-ci.org/xpack/wscript-avoider-js)

## Windows Script Host avoider

A Node.js module to avoid running on [Windows Script Host](https://msdn.microsoft.com/en-us/library/9bbdkx3k.aspx).

The module exports a class `WscriptAvoider` with a single static function `quitIfWscript(name)`, that checks if the global object `WScript` is defined and quits if true.

## Prerequisites

A recent Node.js (>7.x), since the ECMAScript 6 class syntax is used.

## Easy install

The module is available as [**wscript-avoider**](https://www.npmjs.com/package/wscript-avoider) from the public repository, use `npm` to install it in the module where it is needed:

```bash
$ npm install wscript-avoider --save
```

The module does not provide any executables, and generaly should not be installed globally.

The development repository is available from the GitHub [xpack/wscript-avoider-js](https://github.com/xpack/wscript-avoider-js) project.


## How to use

The module has only one function; call it with the application name as argument and normally it should return. If bad luck struck and **Windows Script Host** grabbed the script, a message is displayed and the application abruptly terminates.

```javascript
const appName = 'name'
// Equivalent of import { WscriptAvoider } from 'wscript-avoider'
const WscriptAvoider = require('wscript-avoider').WscriptAvoider
WscriptAvoider.quitIfWscript(appName)
```

The string `name` should be the name of the current Node.js application, as launched from a terminal window (for example `xpm`).

## Tests

As for any `npm` package, the standard way to run the project tests is via `npm test`:

```bash
$ cd wscript-avoider.git
$ npm test
```

## Standard compliance

The module uses ECMAScript 6 class definitions.

As style, it uses the [JavaScript Standard Style](https://standardjs.com/), automatically checked at each commit via Travis CI.

Known and accepted exceptions:

- `/* global WScript */` to test if the global `WScript` is defined

## License

The original content is released under the MIT License, with
all rights reserved to Liviu Ionescu.


