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


module.exports =
class ApplicationWindow
  window: null

  constructor: (path, options) ->
    @window = new BrowserWindow options
    @window.loadURL(path)

    @window.on 'closed', () =>
      @window = null
  getWindow: () ->
    @window

  on: (args...) ->
    @window.on(args...)
  openDevTools: () ->
    @window.openDevTools();
  enableReactDevTools: ->
    #
  loadURL: (url) ->
    @window.loadURL(url)
  getPosition: ->
    @window.getPosition()
  getSize: ->
    @window.getSize()
  showWindow: ->
    @window.show()
