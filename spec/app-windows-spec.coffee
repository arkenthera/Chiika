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

GlobalSetup               = require './global-setup'
path                      = require 'path'
_                         = require 'lodash'


describe 'Application Window Control', ->
  setup = new GlobalSetup()
  setup.setupTimeout(this)

  app = null

  before () =>
    console.log "Electron path #{setup.getDataPath()}"
    setup.startApplication({
      args: [path.join(__dirname, '..')]})
    .then (startedApp) =>
        app = startedApp

  after =>
    setup.stopApplication(app)

  #
  describe 'No AppData First Launch',->
    it 'launch Chiika', () =>
      setup.removeAppData().then =>
        app.client.getWindowCount().should.eventually.equal(2).pause(500)
        .then =>
           app.client.getMainProcessLogs().then (logs) =>
             _.forEach logs, (v,k) =>
               console.log v
        #  app.client.getWindowCount().should.eventually.equal(2)
        #  .pause(2000)
        #  .then =>
        #    app.client.getMainProcessLogs().then (logs) =>
        #      _.forEach logs, (v,k) =>
        #        console.log v
       # .browserWindow.isMinimized().should.eventually.be.false
       # .browserWindow.isDevToolsOpened().should.eventually.be.false
       # .browserWindow.isVisible().should.eventually.be.true
       # .browserWindow.isFocused().should.eventually.be.true
       # .browserWindow.getBounds().should.eventually.have.property('width').and.be.above(0)
       # .browserWindow.getBounds().should.eventually.have.property('height').and.be.above(0)