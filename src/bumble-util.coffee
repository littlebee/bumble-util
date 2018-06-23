
###
  utils for node.js scripts, cake tasks, grunt tasks

###


Shell = require "shelljs"
Path = require 'path'
Fs = require 'fs'
_ = require 'underscore'
Moment = require 'moment'

BStr = require 'bumble-strings'

HOME_DIR = process.env.HOME

###
  Syncronously executes a system command with command and output echo to console.
  
  Returns the output of the command as a string.
###
systemCmd = (cmd, options={}) ->
  options = _.defaults options,
    failOnError: true
    echo: true
    showOutput: true

  console.log("$ " + cmd) if options.echo
  try
    out = Shell.exec(cmd, {silent: !options.showOutput})
    if out.code != 0
      if options.showOutput
        console.error("command exited with nonzero exit code (#{out.code})")
      if options.failOnError
        throw out
  catch e
    if options.failOnError
      throw new Error('systemCmd fail')

  return out?.stdout ? null


###
  Generic error handler that checks passed in error, from node Fs functions for example, 
  and if there is an error, send it to console.error() and exit this process.
###
handleError = (error) ->
  return unless error
  console.error(error)
  process.exit(1)


LAST_NPM_INSTALL_FILE = './.lastNpmInstall'
###
  runs an `npm install` if we see that the package.json is newer than the last time called
  or if the node_modules directory doesn't exist
###
npmInstall = () ->
  return unless Fs.existsSync('package.json')
  packageFileMtime = Moment(Fs.statSync('package.json').mtime)

  try lastTimeStamp = Moment(parseInt(Fs.readFileSync(LAST_NPM_INSTALL_FILE)))
  # console.log 'lastTimeStamp: ', lastTimeStamp
  # console.log 'node_modules exists: ', Fs.existsSync('node_modules')
  # console.log 'packageFileMtime: ', packageFileMtime

  if !lastTimeStamp? || !Fs.existsSync('node_modules') || packageFileMtime.isAfter(lastTimeStamp)
    console.log 'running npm install (this may take a while the first time)'
    systemCmd 'npm install'
    Fs.writeFileSync(LAST_NPM_INSTALL_FILE, packageFileMtime.valueOf())
  else
    console.log 'no newer changes to package.json'


# only installs if not alread installed
installNodePackage = (packageName, options={}) ->
  options = _.defaults options,
    global: false
    addFlags: ""     # specify additional flags like --save-dev

  cmd = ""
  cmd += "sudo " if options.global
  cmd += "npm install "
  cmd += "-g " if options.global
  cmd += options.addFlags
  cmd += " " unless BStr.endsWith(options.addFlags, " ")
  cmd += packageName

  packageExists = ( 
    Fs.existsSync("/usr/local/lib/node_modules/#{packageName}") ||
    Fs.existsSync("/opt/nodejs/current/lib/node_modules/#{packageName}") ||
    Fs.existsSync("./node_modules/#{packageName}")
  )
  unless packageExists
    if options.global
      console.log 'you may be asked to enter your sudo password'
    systemCmd cmd

###
  Open a terminal tab (ONLY WORKS ON iterm2 or terminal apps on OSX) 
###
openTerminalTab = (cdPath = './', cmd='')->
  cdPath = Path.resolve(cdPath)
  console.log "opening terminal tab. maybe. to #{cdPath}. TERM_PROGRAM='#{process.env.TERM_PROGRAM}'"
  switch process.env.TERM_PROGRAM
    when 'iTerm.app'
      systemCmd """osascript 2>/dev/null -e '
        tell application "iTerm"
          tell current terminal
            launch session "Default Session"
            delay .5
            tell the last session
              write text "cd #{cdPath}"
              if "#{cmd}" is not equal "" then
                write text "#{cmd}"
              end if
            end tell
          end tell
        end tell
      '""", echo: false
    when 'Apple_Terminal'
      systemCmd """osascript 2>/dev/null -e '
        tell application "Terminal"
          activate
          tell application "System Events" to keystroke "t" using command down
          repeat while contents of selected tab of window 1 starts with linefeed
            delay 0.01
          end repeat
          do script "cd #{cdPath}" in window 1
          if "#{cmd}" is not equal "" then
            do script "#{cmd}" in window 1
          end if
        end tell
      '""", echo: false
    else
      console.log "Sorry... unknown terminal type: #{process.env.TERM_PROGRAM}"

module.exports =
  systemCmd: systemCmd
  handleError: handleError
  npmInstall: npmInstall
  installNodePackage: installNodePackage
  openTerminalTab: openTerminalTab
