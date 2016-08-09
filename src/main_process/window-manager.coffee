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

{BrowserWindow,ipcMain,globalShortcut,Tray,Menu} = require 'electron'
{Emitter}         = require 'event-kit'
_                 = require 'lodash'


module.exports = class WindowManager
  mainWindow: null

  loginWindow: null
  loginWindowInstance: null

  emitter: null

  windows: []
  #
  #
  #
  constructor: ->
    @emitter = new Emitter

  createWindowAndOpen: (options) ->
    windowOptions = {
      width: options.width,
      height: options.height,
      title: options.title,
      icon: options.icon,
      frame: false,
      show: options.show,
      backgroundColor: '#2e2c29'
    }

    if options.name == 'main'
      #Get window settings
      winProps = chiika.settingsManager.getOption('WindowProperties')
      remember = chiika.settingsManager.getOption('RememberWindowSizeAndPosition')

      if remember
        windowOptions.width = winProps.width
        windowOptions.height = winProps.height
        windowOptions.x = winProps.x
        windowOptions.y = winProps.y

    if !_.isUndefined options.x && !_.isUndefined options.y
      _.assign windowOptions, { x: option.x , y: options.y }

    window = new BrowserWindow(windowOptions)
    @handleWindowEvents(window)

    _.assign window, { name: options.name,rawWindowInstance: window, url: options.url }
    @windows.push window

    if options.name == 'main'
      @mainWindow = window

    if options.name == 'loading'
      @loadingWindow = window

    chiika.logger.info("Adding new window..")

    if options.loadImmediately
      window.loadURL(options.url)

    window


  createModalWindow: (options,returnCallback) ->
    if options.parent == 'main'
      parent = @getMainWindow()
    if options.parent == 'login'
      parent = @getLoginWindow()

    chiika.logger.info("Adding new modal window.. #{parent.name}")

    if parent?
      window = new BrowserWindow({ webPreferences: { nodeIntegration: false, preload: __dirname + "/preload.js" }, width:1400,height: 900,parent: parent, modal:true, show: false, frame: false })
      @handleWindowEvents(window)

      _.assign window, { name: options.name }
      @windows.push window

      @openDevTools(window)

      window.once 'ready-to-show', =>
        window.show()

      window.loadURL(options.url)

      window.on 'closed', =>
        chiika.logger.info("Modal window is closed")

        returnCallback()

      window.webContents.on 'dom-ready', =>
        @emitter.emit 'ui-dom-ready',window
        chiika.chiikaApi.emit 'ui-dom-ready',window

  removeWindow: (window) ->
    match = _.find @windows,window

    if match?
      chiika.logger.info("Removed window. #{match.name}")
      _.remove @windows,window

  rememberWindowProperties: ->
    window = @getMainWindow()

    if window?
      @emitter.on 'close', ->

        if window.name == 'main'
          winPosX = window.getPosition()[0]
          winPosY = window.getPosition()[1]
          width = window.getSize()[0]
          height = window.getSize()[1]

          chiika.settingsManager.setWindowProperties({ x: winPosX, y: winPosY,width: width, height: height })
    else
      chiika.logger.warn("Can't remember window properties because window is null.")

  handleWindowEvents: (window) ->
    window.on 'closed', =>
      @emitter.emit 'closed',window
      window = null

    window.on 'close', =>
      @emitter.emit 'close',window
      @removeWindow(window)

    window.webContents.on 'did-finish-load', =>
      @emitter.emit 'did-finish-load',window
      chiika.logger.info("[magenta](Window-Manager) Window has finished loading.")

    window.webContents.on 'ready-to-show', =>
      @emitter.emit 'ready-to-show',window
      chiika.logger.info("[magenta](Window-Manager) Window has finished loading.")

  createLoginWindow: ->
    loginWindow = chiika.windowManager.createWindowAndOpen({
      name: 'login',
      width: 1600,
      height: 900,
      title: 'login',
      icon: "resources/icon.png",
      url: "file://#{__dirname}/../static/LoginWindow.html",
      show: true,
      loadImmediately: true
      })
    @openDevTools(loginWindow)

  createMainWindow: ->
    mainWindow = chiika.windowManager.createWindowAndOpen({
      name: 'main',
      width: 1400,
      height: 900,
      title: 'main',
      icon: "resources/icon.png",
      url: "file://#{__dirname}/../static/index.html#Home"
      show: true,
      loadImmediately: true
      })
    @openDevTools(mainWindow)

  createLoadingWindow: ->
    loadingWindow = chiika.windowManager.createWindowAndOpen({
      name: 'loading',
      width: 600,
      height: 400,
      title: 'loading',
      icon: "resources/icon.png",
      url: "file://#{__dirname}/../static/LoadingWindow.html",
      show: true,
      loadImmediately: true
      })
    @openDevTools(loadingWindow)

  loadURL: (window) ->
    window.loadURL(window.url)

  openDevTools: (window) ->
    if chiika.runningTests
      chiika.logger.warn("Dev Tools has been requested but we're currently in Automated Testing environment.")
      return
    if chiika.devMode
      window.openDevTools()
    else
      chiika.logger.warn("Dev Tools has been requested but we're currently not in development environment.")


  getPosition: (window) ->
    window.getPosition()


  getSize: (window) ->
    window.getSize()

  getMainWindow: () ->
    @mainWindow

  getWindowByName: (name) ->
    match = _.find @windows, { name: name }

    if match?
      return match
    else
      chiika.logger.warn("Window named #{name} can't be found.")
      return undefined

  getLoginWindow: ->
    @getWindowByName('login')

  showMainWindow: (loadURL) ->
    if @mainWindow?
      if loadURL
        @loadURL(@mainWindow)
      @mainWindow.show()

  showLoadingWindow: ->
    if @loadingWindow?
      @loadingWindow.show()

  hideMainWindow: ->
    if @mainWindow?
      @mainWindow.hide()

  hideLoadingWindow: ->
    if @loadingWindow?
      @loadingWindow.hide()

  closeLoadingWindow: ->
    if @loadingWindow?
      @loadingWindow.close()
