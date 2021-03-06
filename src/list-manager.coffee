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
{Emitter}                                 = require 'event-kit'
{ipcRenderer,remote,shell}                = require 'electron'
remote                                    = require('electron').remote
{Menu,MenuItem}                           = require('electron').remote

_when                                     = require 'when'
Logger                                    = require './main_process/logger'
_find                                     = require 'lodash/collection/find'
_indexOf                                  = require 'lodash/array/indexOf'
_forEach                                  = require 'lodash/collection/forEach'

module.exports = class ListManager
  updateProgress: (type,id,owner,item,viewName,callback) ->
    onActionCompete = (params) =>
      if params.args.success
        callback?()
        chiika.closeLastToast()
        chiika.toastSuccess('Updated!',2000)


    chiika.toastLoading('Updating..',10000)
    @listAction 'progress-update',{ layoutType: type, id: id,owner:owner,item:item,viewName: viewName },onActionCompete

  updateStatus: (type,id,owner,item,viewName,callback) ->
    onActionCompete = (params) =>
      if params.args.success
        callback?()
        chiika.closeLastToast()
        chiika.toastSuccess('Updated!',2000)


    chiika.toastLoading('Updating..',3000)
    @listAction 'status-update',{ layoutType: type, id: id,owner:owner, item:item,viewName: viewName },onActionCompete

  updateScore: (type,id,owner,item,viewName,callback) ->
    onActionCompete = (params) =>
      if params.args.success
        callback?()
        chiika.closeLastToast()
        chiika.toastSuccess('Updated!',2000)


    chiika.toastLoading('Updating..',3000)
    @listAction 'score-update',{ layoutType: type, id: id,owner:owner, item:item,viewName: viewName },onActionCompete

  addToList: (type,id,owner,entry,callback) ->
    onActionCompete = (params) =>
      if params.args.success
        callback?()
        chiika.closeLastToast()
        chiika.toastSuccess('Added!',2000)


    chiika.toastLoading('Adding..',3000)
    @listAction 'add-entry',{ layoutType: type, id: id,owner:owner, rawEntry: entry },onActionCompete

  deleteFromList: (type,id,owner,callback) ->
    chiika.notificationManager.deleteFromListConfirmation id, =>
      chiika.toastLoading('Deleting..',3000)
      onDeleteReturn = (params) =>
        if params.args.success
          callback?(params.args)
          chiika.toastSuccess('Deleted!',2000)
          chiika.closeLastToast()

        else
          chiika.toastError("Could not delete. #{params.args.response}",2000)
      @listAction('delete-entry', { layoutType: type, id: id,owner:owner }, onDeleteReturn)


  listAction: (action,params,callback) ->
    chiika.ipc.sendMessage 'list-action', { action: action, params: params }

    chiika.ipc.receive "list-action-response-#{action}",(event,args) =>
      callback?(args)

      chiika.ipc.disposeListeners("list-action-response-#{action}")
