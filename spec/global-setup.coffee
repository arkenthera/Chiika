Application = require('spectron').Application
assert = require('assert')
chai = require('chai')
chaiAsPromised = require('chai-as-promised')
path = require('path')

global.before =>
  chai.should()
  chai.use(chaiAsPromised)

module.exports = class Setup
  getElectronPath: ->
    electronPath = path.join(__dirname, '..', 'node_modules', '.bin', 'electron')
    if (process.platform == 'win32')
      electronPath += '.cmd'
    electronPath

  setupTimeout: (test) ->
    if (process.env.CI)
      test.timeout(30000)
    else
      test.timeout(10000)

  startApplication: (options) ->
    options.path = @getElectronPath()
    if (process.env.CI?)
      options.startTimeout = 30000
    else
      options.startTimeout = 10000
    options.chromeDriverLogPath = process.cwd() + "/logs/log.txt"
    console.log options
    app = new Application(options)
    try
      app.start().then =>
        console.log "started"
        @stopApplication(app)
    catch error
      console.log error

  stopApplication:(app) ->
    if (!app || !app.isRunning())
      return

    console.log "Stopping"
    app.stop()