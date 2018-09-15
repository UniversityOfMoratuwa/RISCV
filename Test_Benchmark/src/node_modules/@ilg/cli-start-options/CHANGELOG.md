## Change log

Changes in reverse chronological order.

## v0.4.12 (2018-07-31)

- rename exception in catch() as `ex`

## v0.4.11 (2018-04-30)

- [#5] check if the install path is below /usr/local

## v0.4.10 (2018-04-24)

- cli-error: add ERROR.PREREQUISITES
- deps: add semver@5.5.0
- [#4] Check node version >= 8.x

## v0.4.9 (2018-04-17)

- fix typo in trace message

## v0.4.8 (2018-04-13)

- split update message on two lines.

## v0.4.6 (2018-04-13)

- add force to delete

## v0.4.5 (2018-04-07)

- improve logic to save the timestamp

## v0.4.4 (2018-04-07)

- add 'sudo' to message, if installed globally

## v0.4.3 (2018-04-07)

- cli-application: check for updates

## v0.4.2 (2017-11-12)

- cli-options: fix cmds split

## v0.4.1 (2017-10-10)

- README: add How to publish
- cli-commands: in outputDoneDuration () also display the actual command after the program name

## v0.4.0 (2017-09-19)

- cli-commands: add formatDuration()

## v0.3.1 (2017-09-18)

- add 'npm run link'
- add support for single command
- add chdir() to -C path
- update tsts for tar 4.x
- update tests for node 8.5 AsserionError with cause

## v0.2.2 (2017-05-15)

- CliCommand: add unparsedArgs property
- CliCommand.addGenerator() uses unparsedArgs

## v0.2.1 (2017-04-29)

- CliError: add ERROR.CHILD
- CliOptions: add filterOtherArguments()

## v0.2.0 (2017-04-29)

- still not perfect, but more ready for prime time
- logger default level is 'info'
- logger without prefixes for normal output; warnings/errors/debug with prefixes
- -s (silent), -q (quiet), -v (verbose), -d (debug), -dd (trace) intuitive options

## v0.1.1-19 (2017-04-07)

- development versions, mostly experimental.