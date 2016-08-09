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
    electronPath = path.join(__dirname, '..', 'node_modules','.bin','electron')
    if (process.platform == 'win32')
      electronPath += '.cmd'
    electronPath

  setupTimeout: (test) ->
    if (process.env.CI)
      test.timeout(100000)
    else
      test.timeout(20000)

  startApplication: (options) ->
    options.path = @getElectronPath()
    if (process.env.CI?)
      options.startTimeout = 100000
    else
      options.startTimeout = 20000


    app = new Application(options)
    app.start().then =>
      console.log "Hello?"
      assert.equal(app.isRunning(), true)
      chaiAsPromised.transferPromiseness = app.transferPromiseness
      app

  stopApplication:(app) ->
    if (!app || !app.isRunning())
      return

    console.log "Stopping"
    app.stop()
