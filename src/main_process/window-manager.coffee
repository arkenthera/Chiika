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
  emitter: null

  windows: []
  #
  #
  #
  constructor: ->
    @emitter = new Emitter

  createWindowAndOpen: (isMain,isLoading,options) ->
    windowOptions = {
      width: options.width,
      height: options.height,
      title: options.title,
      icon: options.icon,
      frame: false,
      show: options.show,
      backgroundColor: '#2e2c29'
    }

    if isMain
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

    _.assign window, { name: options.name }
    @windows.push window

    if isMain
      @mainWindow = window

    if isLoading
      @loadingWindow = window

    chiika.logger.info("Adding new window..")

    window.loadURL(options.url)
    window

  removeWindow: (window) ->
    match = _.find @windows,window

    if match?
      _.remove @windows,window
      chiika.logger.info("Removed window.")

  rememberWindowProperties: ->
    window = @getMainWindow()

    if window?
      @emitter.on 'close', ->
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
      @removeWindow(window)

    window.on 'close', =>
      @emitter.emit 'close',window

    window.on 'did-finish-load', =>
      @emitter.emit 'did-finish-load'
      chiika.logger.info("[magenta](Window-Manager) Window has finished loading.")

    window.on 'ready-to-show', =>
      @emitter.emit 'ready-to-show'
      chiika.logger.info("[magenta](Window-Manager) Window has finished loading.")

  openDevTools: (window) ->
    window.openDevTools()


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
      return undefined

  getLoginWindow: ->
    @getWindowByName('login')

  showMainWindow: ->
    if @mainWindow?
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