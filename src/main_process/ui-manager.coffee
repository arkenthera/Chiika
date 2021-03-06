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

_find                   = require 'lodash/collection/find'
_indexOf                = require 'lodash/array/indexOf'
_forEach                = require 'lodash/collection/forEach'
_remove                 = require 'lodash/array/remove'
_assign                 = require 'lodash.assign'
_when           = require 'when'


module.exports = class UIManager
  uiItems: []
  preloadPromises: []


  #
  # Returns a UI item
  # @param {String} itemName Name of the UI item
  # @return {Object} UI Item
  getUIItem: (itemName) ->
    instance = _find @uiItems, { name: itemName }

    if instance?
      instance
    else
      chiika.logger.error("getUIItem UI item not found #{itemName}")
      return null

  addUIItem: (item) ->
    instance = _find @uiItems, { name: item.name }
    index    = _indexOf @uiItems, instance

    if index == -1
      @uiItems.push item
    else
      @uiItems.splice(index,1,instance)

  #
  # Returns the total number of UI items stored on DB
  # @returm {Integer}
  getUIItemsCount: ->
    @uiItems.length

  getUIItems: ->
    @uiItems

  #
  #
  #
  saveUIItem: (item) ->
    config = chiika.settingsManager.readConfigFile('view')

    findConfig = _find config.views,(o) -> o.name == item.name
    indexConfig = _indexOf config.views,findConfig
    if indexConfig > -1
      config.views.splice(indexConfig,1,item)
      chiika.settingsManager.saveConfigFile('view',config)

      match = _find @uiItems,(o) -> o.name == item.name
      index = _indexOf @uiItems,match


      match.displayConfig = item[item.displayType]
      @uiItems.splice(index,1,match)


  removeUIItem: (name) ->
    match = _find @uiItems,(o) -> o.name == name
    index = _indexOf @uiItems,match

    if match?
      _remove @uiItems,match
      chiika.logger.verbose("[magenta](UI-Manager) Removed a UI Item #{name}")
