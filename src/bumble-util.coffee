
###
  utils for node.js scripts, cake tasks, grunt tasks

###


child_process = require "child_process"
path = require 'path'
fs = require 'fs'
_ = require 'underscore'
moment = require 'moment'

BStr = require 'bumble-strings'

HOME_DIR = process.env.HOME

systemCmd = (cmd, options={}) ->
  options = _.defaults options,
    failOnError: true
    echo: true
    showOutput: true

  console.log("$ " + cmd) if options.echo
  try
    out = child_process.execSync(cmd)
    process.stdout.write(out) if options.showOutput
  catch e
    console.error e if options.showOutput
    if options.failOnError
      throw e

  return out.toString()



handleError = (error) ->
  return unless error
  console.error(error)
  process.exit(1)


LAST_NPM_INSTALL_FILE = './.lastNpmInstall'
# runs an `npm install` if we see that the package.json is newer than the last time called
#   or if the node_modules directory doesn't exist
npmInstall = () ->
  return unless fs.existsSync('package.json')
  packageFileMtime = moment(fs.statSync('package.json').mtime)

  try lastTimeStamp = moment(parseInt(fs.readFileSync(LAST_NPM_INSTALL_FILE)))
  # console.log 'lastTimeStamp: ', lastTimeStamp
  # console.log 'node_modules exists: ', fs.existsSync('node_modules')
  # console.log 'packageFileMtime: ', packageFileMtime

  if !lastTimeStamp? || !fs.existsSync('node_modules') || packageFileMtime.isAfter(lastTimeStamp)
    console.log 'running npm install (this may take a while the first time)'
    systemCmd 'npm install'
    fs.writeFileSync(LAST_NPM_INSTALL_FILE, packageFileMtime.valueOf())


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
    fs.existsSync("/usr/local/lib/node_modules/#{packageName}") ||
    fs.existsSync("/opt/nodejs/current/lib/node_modules/#{packageName}") ||
    fs.existsSync("./node_modules/#{packageName}")
  )
  unless packageExists
    if options.global
      console.log 'you may be asked to enter your sudo password'
    systemCmd cmd


openTerminalTab = (cdPath = './', cmd='')->
  cdPath = path.resolve(cdPath)
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
