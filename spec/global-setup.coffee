#----------------------------------------------------------------------------
#Chiika
#Copyright (C) 2016 arkenthera
#This program is free software; you can redistribute it and/or modify
#it under the terms of the GNU General Public License as published by
#the Free Software Foundation; either version 2 of the License, or
#(at your option) any later version.
#This program is distributed in the hope that it will be useful,
#but WITHOUT ANY WARRANTY; without even the implied warranty of
#MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#GNU General Public License for more details.
#Date: 23.1.2016
#authors: arkenthera
#Description:
#----------------------------------------------------------------------------
{Application}           = require 'spectron'
assert                = require 'assert'
chai                  = require 'chai'
chaiAsPromised        = require 'chai-as-promised'
path                  = require 'path'
os                    = require 'os'
rimraf                = require 'rimraf'
_                     = require 'lodash'
_when                 = require 'when'
ncp                   = require 'ncp'
fsextra               = require 'fs-extra'

global.before =>
  chai.should()
  chai.use(chaiAsPromised)

module.exports = class Setup
  getElectronPath: ->
    electronPath = path.join(__dirname, '..', 'node_modules','.bin','electron')
    if (process.platform == 'win32')
      electronPath += '.cmd'
    electronPath

  getDataPath: ->
    if process.env.CHIIKA_DATA_HOME?
      process.env.CHIIKA_DATA_HOME
    else
      if process.platform == 'darwin'
        osSpecificDir = path.join(process.env.HOME,'Library/Application Support')
      else if process.platform == 'linux'
        osSpecificDir = path.join(process.env.HOME,'.config')
      else
        osSpecificDir = process.env.APPDATA

      process.env.CHIIKA_DATA_HOME = path.join(osSpecificDir,"chiika","data")
      process.env.CHIIKA_DATA_HOME

  chiikaPath: ->
    path.join(__dirname, '..')


  removeAppData: ->
    new Promise (resolve) =>
      rimraf @getDataPath(), resolve

  copyTestData: (folder) ->
    new Promise (resolve) =>
      source = path.join(__dirname,folder)
      dest = path.join(@getDataPath(),"..")
      console.log "Copying from #{source} to #{dest}"

      fsextra.copy path.join(__dirname,folder), path.join(@getDataPath(),".."), { clobber:true }, (err) =>
        if err
          throw err

        console.log "Success!"
        resolve()

  setupTimeout: (test) ->
    if (process.env.CI)
      test.timeout(100000)
    else
      test.timeout(20000)

  startApplication: (options) ->
    options.path = @getElectronPath()


    options.env = Object.create(process.env)

    if (process.env.CI)
      options.env.CI_MODE = true
      options.startTimeout = 100000
    else
      options.startTimeout = 20000
      options.env.CI_MODE = false

    if options.DEV_MODE?
      options.env.DEV_MODE = options.DEV_MODE
    else
      options.env.DEV_MODE = false

    if options.RUNNING_TESTS?
      options.env.RUNNING_TESTS = options.RUNNING_TESTS
    else
      options.env.RUNNING_TESTS = true

    app = new Application(options)

    app.start().then =>
      console.log "Launched app."
      assert.equal(app.isRunning(), true)
      chaiAsPromised.transferPromiseness = app.transferPromiseness
      app

  prettyPrintMainProcessLogs: (client) ->
    client.getMainProcessLogs().then (logs) =>
      _.forEach logs, (v,k) =>
        console.log v

  prettyPrintRendererProcessLogs: (client) ->
    client.getRendererProcessLogs().then (logs) =>
      _.forEach logs, (v,k) =>
        console.log v

  stopApplication:(app) ->
    if (!app || !app.isRunning())
      return

    app.stop()
