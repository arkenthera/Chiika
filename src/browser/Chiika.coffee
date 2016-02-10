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
#Date: 25.1.2016
#authors: arkenthera
#Description:
#----------------------------------------------------------------------------

path = require('path')
fs = require('fs')
path = require 'path'
electron = require 'electron'
ipcMain = electron.ipcMain
BrowserWindow = electron.BrowserWindow

RequestManager = require './common/RequestManager'

class Chiika
  rootOptions:{
    logLevel:1,
    appMode:true
  }
  @chiika: null
  @root:null
  @db:null
  @request:null
  @nativeUser:null
  @modulePath:''
  @mainWinId:-1
  @mainWindow:null
  @malLoginWindow:null
  @requestCallbackCounter:0
  @requestCallbackStop:4
  @requestManager:null
  init: () ->
    if process.env.CHIIKA_ENV == 'debug'
      @chiika = require("./../../lib/chiika-node")
    else
      @chiika = require("./../lib/chiika-node")
    @modulePath = process.env.CHIIKA_HOME
    @rootOptions.modulePath = @modulePath
    @rootOptions.dataPath = path.join(@modulePath,"Data")
    @rootOptions.imagePath = path.join(@rootOptions.dataPath,"Images")
    @root = @chiika.Root(@rootOptions)

    @db = @chiika.Database()
    @request = @chiika.Request()
    @nativeUser = @db.User

    @requestCallbackCounter = 0

    @requestManager = new RequestManager this

    console.log "Browser process init successful"

  destroy: () ->
    @chiika.DestroyChiika()

  setMainWindow: (wnd) ->
    @mainWindow = wnd

  sendAsyncMessageToRenderer:(msg,arg) ->
    @mainWindow.webContents.send msg,arg
    console.log "Browser process sending message: " + msg
  sendRendererData:() ->
    al = @getMyAnimelist()
    ml = @getMyMangalist()
    ui = @getUserInfo()
    cn =  { rootOptions:@rootOptions }
    db = { animeList: al,mangaList:ml,userInfo:ui,chiikaNode:cn }
    @sendAsyncMessageToRenderer 'databaseRequest',db
  signalRendererToRerender:() ->
    @sendAsyncMessageToRenderer 'reRender','42'
  setRendererStatusText: (text,fade) ->
    msg = {message:text,fadeOut:fade}
    chiikaNode.sendAsyncMessageToRenderer 'setStatusText',msg

  requestAnimeScrapeSuccess:(ret) =>
    @sendRendererData()

  requestAnimeScrapeError:(ret) ->
    console.log ret

  requestRefreshAnimeSuccess:(ret) =>
    if ret.request_name == "GetAnimePageScrapeSuccess"
      @sendAsyncMessageToRenderer 'requestRefreshAnimeDetailsSuccess',true
    @sendRendererData()

  requestRefreshAnimeError:(ret) ->
    console.log ret

  requestAnimeDetailsSuccess:(ret) =>
    if ret.request_name == "FakeRequestSuccess"
      @sendAsyncMessageToRenderer 'requestAnimeDetailsNotRequired',true
    else
      @sendRendererData() #Need optimizations later

  requestAnimeDetailsError:(ret) ->
    console.log ret

  requestUpdateAnimeSuccess:(ret) =>
    @sendAsyncMessageToRenderer 'requestUpdateAnimeStatus',true
    @sendRendererData()
  requestUpdateAnimeError:(ret) ->
    @sendAsyncMessageToRenderer 'requestUpdateAnimeStatus',ret

  RequestAnimeUpdate:(Id,score,progress,status) =>
    @request.UpdateAnime(@requestUpdateAnimeSuccess,@requestUpdateAnimeError,{animeId: Id,score:score,progress:progress,status:status})

  RequestAnimeDetails:(Id) =>
    @requestManager.GetAnimeDetails Id
  RequestAnimeDetailsRefresh:(Id) =>
    @requestManager.RefreshAnime Id

  RequestVerifyUser: () =>
    @requestManager.UserVerify()

  RequestAnimeScrape: (Id) =>
    @request.AnimeScrape(@requestAnimeScrapeSuccess,@requestAnimeScrapeError,{ animeId: Id })

  RequestMyAnimelist: () =>
    @requestManager.GetMyAnimelist()

  RequestMyMangalist: =>
    @requestManager.GetMyMangalist()

  SetUser: (user,pass) ->
    @db.SetUser( { userName: user,password: pass} )
  #Native Database JS Wrappers
  #These synchronous functions will only load related data into v8 structures and send it back.
  #See https://github.com/arkenthera/chiika-node/blob/master/src/DatabaseWrapper.cc for more info.
  getMyAnimelist:() ->
    @db.Animelist
  getMyMangalist:() ->
    @db.Mangalist
  getUserInfo:() ->
    @db.User
  onKeyPressed:(arg) ->
    @sendAsyncMessageToRenderer 'browserKeyboardEvent',arg

chiikaNode = new Chiika

ipcMain.on 'registerShortcuts', (event,arg) ->
  console.log "Registering " + arg

ipcMain.on 'unregisterShortcuts', (event,arg) ->
  console.log "Un-Registering " + arg

ipcMain.on 'setRootOpts',(event,arg) ->
  userName = arg.user;
  pass     = arg.pass;
  chiikaNode.malLoginWindow = event.sender

  chiikaNode.SetUser userName,pass
  chiikaNode.RequestVerifyUser()

ipcMain.on 'requestAnimeDetails',(event,arg) ->
  console.log "Receiving IPC message from renderer process! Args: " + arg
  chiikaNode.RequestAnimeDetails(arg)

ipcMain.on 'requestAnimeRefresh',(event,arg) ->
  console.log "Receiving IPC message from renderer process! Args: " + arg
  chiikaNode.RequestAnimeDetailsRefresh(arg)


ipcMain.on 'requestAnimeScrape', (event,arg) ->
  chiikaNode.RequestAnimeScrape(arg)

ipcMain.on 'requestAnimeUpdate', (event,arg) ->
  animeId = arg.animeId
  score = arg.score
  progress = arg.progress
  status = arg.status
  chiikaNode.RequestAnimeUpdate(animeId,score,progress,status)


ipcMain.on 'rendererPing',(event,arg) ->
  console.log "Receiving IPC message from renderer process! Args: " + arg

  if arg == 'requestVerify'
    chiikaNode.RequestVerifyUser()



  if arg == 'requestMyAnimelist'
    chiikaNode.RequestMyAnimelist()


  if arg == 'requestMyMangalist'
    chiikaNode.RequestMyMangalist()

  if arg == 'databaseRequest'
    chiikaNode.sendRendererData()

process.on 'exit', (code) ->
  chiikaNode.destroy()

module.exports = chiikaNode
