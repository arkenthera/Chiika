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

path          = require 'path'
fs            = require 'fs'


getLibraryUrl = (type,user) ->
  return "http://myanimelist.net/malappinfo.php?u=#{user}&type=#{type}&status=all"


authUrl                       = 'http://myanimelist.net/api/account/verify_credentials.xml'
animePageUrl                  = 'http://myanimelist.net/anime/'
mangaPageUrl                  = 'http://myanimelist.net/manga/'
updateAnime                   = 'http://myanimelist.net/api/animelist/update/'
updateManga                   = 'http://myanimelist.net/api/mangalist/update/'
addAnime                      = 'http://myanimelist.net/api/animelist/add/'
addManga                      = 'http://myanimelist.net/api/mangalist/add/'
removeAnime                   = 'http://myanimelist.net/api/animelist/delete/'
removeManga                   = 'http://myanimelist.net/api/mangalist/delete/'

getSearchUrl = (type,keywords) ->
  "http://myanimelist.net/api/#{type}/search.xml?q=#{keywords}"

getSearchExtendedUrl = (type,id) ->
  if type == 'manga'
    "http://myanimelist.net/includes/ajax.inc.php?id=#{id}&t=65"
  else
    "http://myanimelist.net/includes/ajax.inc.php?id=#{id}&t=64"

_assign       = scriptRequire 'lodash.assign'
_find         = scriptRequire 'lodash/collection/find'
_isArray      = scriptRequire 'lodash.isarray'
_forEach      = scriptRequire 'lodash/collection/forEach'
_cloneDeep    = scriptRequire 'lodash.clonedeep'
_size         = scriptRequire 'lodash/collection/size'

_when         = scriptRequire 'when'
string        = scriptRequire 'string'
xml2js        = scriptRequire 'xml2js'
moment        = scriptRequire 'moment'
{shell}       = require 'electron'
Recognition   = require "#{mainProcessHome}/media-recognition"


module.exports = class MyAnimelist
  # Description for this script
  # Will be visible on app
  displayDescription: "MyAnimelist"

  # Unique identifier for the app
  #
  name: "myanimelist"

  # Logo which will be seen at the login screen
  #
  logo: '../assets/images/login/mal1.png'

  # Chiika lets you define multiple users
  # In the methods below you can use whatever user you want
  # For the default we use the user when you login.
  #
  malUser: null

  #
  #
  #
  isService: true

  #
  #
  #
  isActive: true


  order: 0

  #
  # The time limit between Chiika should scrape the entry's MAL page
  #
  detailsSyncTimeRestriction:9

  animeView: 'myanimelist_animelist'

  mangaView: 'myanimelist_mangalist'

  views: ['myanimelist_animelist','myanimelist_mangalist']

  useInSearch: true

  #
  moveToWatchingOnDetection: true
  alwaysUpdateOnDetection: true
  moveToCompletedWhenFinished: true

  # Will be called by Chiika with the API object
  # you can do whatever you want with this object
  # See the documentation for this object's methods,properties etc.
  constructor: (chiika) ->
    @chiika = chiika
    @recognition = new Recognition()

  # This method is controls the communication between app and script
  # If you change this method things will break
  #
  on: (event,args...) ->
    try
      @chiika.on @name,event,args...
    catch error
      console.log error
      throw error



  # myanimelist.net/malappinfo.php?u=#user&type=anime&status=all
  # Retrieves library
  # @param type {String} anime-manga
  retrieveLibrary: (type,userName,callback) ->
    userName = string(userName).chompRight("_" + @name).s
    @chiika.logger.info("Retrieving user library for #{userName} - #{type}")
    onGetUserLibrary = (error,response,body) =>

      if response.statusCode == 200 or response.statusCode == 201
        @chiika.parser.parseXml(body)
                      .then (result) =>
                        callback { success:true,response: response, library: result }
      else
        @chiika.logger.warn("There was a problem retrieving library.")
        callback { success:false,response: response }

    @chiika.makeGetRequest getLibraryUrl(type,userName),null, onGetUserLibrary

  #
  #
  #
  getAnimelistData: (callback) ->
    if !@malUser?
      @chiika.logger.error("User can't be retrieved.Aborting anime list request.")
      callback( {success: false })
    else
      @retrieveLibrary 'anime',@malUser.realUserName, (result) =>
           userInfo = result.library.myanimelist.myinfo

           _assign @malUser, { malAnimeInfo: userInfo }
           @chiika.users.updateUser @malUser

           callback(result)

  #
  #
  #
  getMangalistData: (callback) ->
    if @malUser?
      @retrieveLibrary 'manga',@malUser.realUserName, (result) =>
           userInfo = result.library.myanimelist.myinfo

           _assign @malUser, { malMangaInfo: userInfo }
           @chiika.users.updateUser @malUser

           callback(result)

    else
      @chiika.logger.error("User can't be retrieved.Aborting manga list request.")
      callback( { success: false })


  authorizedPost: (url,body,callback) ->
    onAuthorizedPostComplete = (error,response,body) =>
      if error
        callback( { success: false , response: body, statusCode: response.statusCode })

      else if response.statusCode != 200
        callback( { success: false , response: body, statusCode: response.statusCode })

      else
        callback( { success: true, response: body, statusCode: response.statusCode })

    @chiika.makePostRequestAuth( url, { userName: @malUser.realUserName, password: @malUser.password },null,body, onAuthorizedPostComplete )

  #
  #
  #
  updateAnime: (anime,callback) ->
    anime.animeLastUpdated = moment().unix()
    data = @buildAnimeXmlForUpdating(anime)
    @authorizedPost "#{updateAnime}#{anime.mal_id}.xml",data,(result) =>
      if result.success && result.response == "Updated"
        callback(result)

        @chiika.requestViewDataUpdate('myanimelist','myanimelist_animelist')

        #Save history
        historyView = @chiika.viewManager.getViewByName('myanimelist_animelist_history')

        if historyView?
          historyData = historyView.getData()

          historyItem =
            history_id: historyData.length
            updated: moment().valueOf()
            mal_id: anime.mal_id
            owner: 'myanimelist'
            episode: anime.animeWatchedEpisodes



          historyView.setData( historyItem, 'history_id').then (args) =>
            @chiika.requestViewDataUpdate('cards','cards_continueWatching')
            @chiika.requestViewDataUpdate('cards','cards_statistics')
      else
        # It can return status code 200 but if the body isn't updated,it failed.
        result.success = false
        callback(result)

  #
  #
  #
  addAnime: (anime,callback) ->
    data = @buildAnimeXmlForUpdating(anime)
    @authorizedPost "#{addAnime}#{anime.mal_id}.xml",data,(result) =>
      if result.statusCode == 201
        callback?(result)
      else
        callback?(result)

        # Problems

  addManga: (manga,callback) ->
    data = @buildMangaXmlForUpdating(manga)
    @authorizedPost "#{addManga}#{manga.mal_id}.xml",data,(result) =>
      if result.statusCode == 201
        callback?(result)
      else
        callback?(result)

  removeAnime: (anime,callback) ->
    data = @buildAnimeXmlForUpdating(anime)
    @authorizedPost "#{removeAnime}#{anime.mal_id}.xml",data,(result) =>
      if result.statusCode == 201
        callback?(result)
      else
        callback?(result)

        # Problems

  removeManga: (manga,callback) ->
    data = @buildMangaXmlForUpdating(manga)
    @authorizedPost "#{removeManga}#{manga.mal_id}.xml",data,(result) =>
      if result.statusCode == 201
        callback?(result)
      else
        callback?(result)

        # Problems

  #
  #
  #
  updateManga: (manga,callback) ->
    manga.mangaLastUpdated = moment().unix()
    data = @buildMangaXmlForUpdating(manga)
    @authorizedPost "#{updateManga}#{manga.mal_id}.xml",data,(result) =>
      if result.success && result.response == "Updated"
        callback(result)

        # Statistics update on history method
        @chiika.requestViewDataUpdate('myanimelist','myanimelist_mangalist')
      else
        # It can return status code 200 but if the body isn't updated,it failed.
        result.success = false
        callback(result)

  #
  # Searches animelist either manga or anime
  #
  search: (type,keywords,callback) ->
    if @malUser?
      onSearchComplete = (error,response,body) =>
        if error?
          callback( { success: false,error: 'request' })
          return
        if response.statusCode != 200
          callback( { success: false,error: 'request' })
        else
          @chiika.parser.parseXml(body)
                        .then (result) =>
                          if type == 'anime'
                            callback({ success: true, results: result.anime.entry })
                          else if type == 'manga'
                            callback({ success: true, results: result.manga.entry})
    else
      @chiika.logger.error("User can't be retrieved.Aborting search request.")
      callback( { success: false,error: 'no-user' })


     @chiika.makeGetRequestAuth getSearchUrl(type,keywords.split(" ").join("+")),{ userName: @malUser.realUserName, password: @malUser.password },null, onSearchComplete



  #
  #
  #
  searchExtended: (type,id,callback) ->
    onSearchComplete = (error,response,body) =>
      if type == 'anime'
        callback(@chiika.parser.parseMyAnimelistExtendedSearch(body))
      else if type == 'manga'
        callback(@chiika.parser.parseMyAnimelistMangaExtendedSearch(body))

    @chiika.makeGetRequest getSearchExtendedUrl(type,id),null, onSearchComplete


  animePageScrape: (id,callback) ->
    onRequest = (error,response,body) =>
      callback(@chiika.parser.parseAnimeDetailsMalPage(body))

    @chiika.makeGetRequest animePageUrl + id,null,onRequest


  mangaPageScrape: (id,callback) ->
    onRequest = (error,response,body) =>
      callback(@chiika.parser.parseMangaDetailsMalPage(body))

    @chiika.makeGetRequest mangaPageUrl + id,null,onRequest

  initialize: ->
    @malUser = @chiika.users.getDefaultUser(@name)

    if @malUser?
      @chiika.logger.info("Default user : #{@malUser.realUserName}")
    else
      @chiika.logger.warn("Default user for myanimelist doesn't exist. If this is the first time launch, you can ignore this.")

    animelistView   = @chiika.viewManager.getViewByName('myanimelist_animelist')
    animeDbView  = @chiika.viewManager.getViewByName('anime_db')

    mangalistView = @chiika.viewManager.getViewByName('myanimelist_mangalist')
    mangaDbView  = @chiika.viewManager.getViewByName('manga_db')

    if animelistView?
      @animelist = animelistView.getData()
      @chiika.logger.script("[yellow](#{@name}) Animelist data length #{@animelist.length} #{@name}")

    if mangalistView?
      @mangalist = mangalistView.getData()
      @chiika.logger.script("[yellow](#{@name}) Mangalist data length #{@mangalist.length} #{@name}")


    if animeDbView?
      @animedb = animeDbView.getData()
      @chiika.logger.script("[yellow](#{@name}) Anime DB data length #{@animedb.length} #{@name}")

    if mangaDbView?
      @mangadb = mangaDbView.getData()
      @chiika.logger.script("[yellow](#{@name}) Manga DB data length #{@mangadb.length} #{@name}")

  # After the constructor run() method will be called immediately after.
  # Use this method to do what you will
  #
  run: () ->
    @on 'initialize', =>
      @initialize()

    @on 'post-init',(init) =>
      init.defer.resolve()

      malConfig = @chiika.settingsManager.readConfigFile('myanimelist')

      if !malConfig?
        #Create config file
        config =
          moveToWatchingOnDetection: @moveToWatchingOnDetection
          alwaysUpdateOnDetection: @alwaysUpdateOnDetection
          moveToCompletedWhenFinished: @moveToCompletedWhenFinished

        @chiika.settingsManager.saveConfigFile('myanimelist',config)

    # This method will be called if there are no UI elements in the database
    # or the user wants to refresh the views
    @on 'reconstruct-ui', (update) =>
      @chiika.logger.script("[yellow](#{@name}) reconstruct-ui #{@name}")

      @createViewAnimelist()
      @createViewMangalist()

    @on 'get-user', (args) =>
      @malUser = @chiika.users.getDefaultUser(@name)

      if @malUser?
        @malUser.profileImage = "https://myanimelist.cdn-dena.com/images/userimages/#{@malUser.malID}.jpg"
        args.return(@malUser)


    @on 'get-config', () =>
      malConfig = @chiika.settingsManager.readConfigFile('myanimelist')
      if malConfig?
        args.return(malConfig)

    @on 'get-option', (args) =>
      option = args.option

      malConfig = @chiika.settingsManager.readConfigFile('myanimelist')

      if malConfig?
        if option == 'move-to-watching-on-detection'
          args.return(malConfig.moveToWatchingOnDetection)

        if option == 'always-update-on-detection'
          args.return(malConfig.alwaysUpdateOnDetection)

        if option == 'move-to-completed-when-finished'
          args.return(malConfig.moveToCompletedWhenFinished)


    @on 'set-option', (args) =>
      option = args.option
      value = args.value

      malConfig = @chiika.settingsManager.readConfigFile('myanimelist')

      if !malConfig?
        chiika.logger.error("Could not read config file for #{@name}. Something is seriosly wrong. Contact developer.")
        return

      if option == 'move-to-watching-on-detection'
        malConfig.moveToWatchingOnDetection = value

      if option == 'always-update-on-detection'
        malConfig.alwaysUpdateOnDetection = value

      if option == 'move-to-completed-when-finished'
        malConfig.moveToCompletedWhenFinished = value





    @on 'sync', (args) =>

      syncAnimelist = (resolve) =>

        @chiika.requestViewUpdate 'myanimelist_animelist',@name,(params) =>
          error = !params.success
          if params.success
            @chiika.requestViewDataUpdate('myanimelist','myanimelist_animelist')

          resolve(error)

      syncMangalist = (resolve) =>
        @chiika.requestViewUpdate 'myanimelist_mangalist',@name,(params) =>
          error = !params.success
          if params.success
            @chiika.requestViewDataUpdate('myanimelist','myanimelist_mangalist')


          resolve(error)

      syncAnimelistPromise = _when.promise(syncAnimelist)
      syncMangalistPromise = _when.promise(syncMangalist)

      sync = _when.join(syncAnimelistPromise,syncMangalistPromise).then (error) =>
        args.return(error)







    # This event is called each time the associated view needs to be updated then saved to DB
    # Note that its the actual data refreshing. Meaning for example, you need to SYNC your data to the remote one, this event occurs
    # This event won't be called each application launch unless "RefreshUponLaunch" option is ticked
    # You should update your data here
    # This event will then save the data to the view's local DB to use it locally.
    @on 'view-update', (update) =>
      @chiika.logger.script("[yellow](#{@name}) Updating view for #{update.view.name} - #{@name}")

      if update.view.name == 'myanimelist_animelist'
        #view.setData(@getAnimelistData())
        @getAnimelistData (result) =>
          if result.success
            if !result.library.myanimelist.anime?
              update.return({ success: true })
              return
            @setAnimelistTabViewData(result.library.myanimelist.anime,update.view).then =>
              update.return({ success: result.success })

              # Save the date of this process
              @chiika.custom.addKey { name: "#{update.view.name}_updated", value:moment() }

            update.return({ success: result.success })
          else
            @chiika.logger.warn("[yellow](#{@name}) view-update has failed.")
            update.return({ success: result.success })


      else if update.view.name == 'myanimelist_mangalist'
        @getMangalistData (result) =>
          if result.success
            if !result.library.myanimelist.manga?
              update.return({ success: true })
              return

            @setMangalistTabViewData(result.library.myanimelist.manga,update.view).then =>
              update.return({ success: result.success })

              @chiika.custom.addKey { name: "#{update.view.name}_updated", value:moment() }
          else
            update.return({ success: result.success })
            @chiika.logger.warn("[yellow](#{@name}) view-update has failed.")


    @on 'details-layout', (args) =>
      @chiika.logger.script("[yellow](#{@name}) Details-Layout #{args.id}")

      id        = args.id
      viewName  = args.viewName
      params    = args.params

      if viewName == 'myanimelist_animelist'
        @onAnimeDetailsLayout id,params, (result) =>
          @currentDetailsLayout = result.layout
          args.return(result)

      if viewName == 'myanimelist_mangalist'
        @onMangaDetailsLayout id,params, (result) =>
          args.return(result)

    @on 'list-action', (args) =>
      action = args.action
      params = args.params

      @chiika.logger.script("Receiving details-action - #{action} for #{@name}")

      onActionError = (error) =>
        @chiika.logger.script("Could not perform action #{action}")
        if error?
          @chiika.logger.script(error)

        args.return({ success: false, error: error })

      switch action
        when 'progress-update'
          item = params.item

          if params.viewName == 'myanimelist_animelist'
            id = params.id
            if !id? # If coming from media, there wont be an id, but title
              title = params.title
              @chiika.logger.script("Id not found for #{title}. Using title instead.")

              findInList = _find @animedb, (o) -> o.animeTitle == title
              if findInList?
                id = findInList.mal_id
            if id?
              @updateProgress id,'anime',item.current, (result) =>
                args.return(result)

          if params.viewName == 'myanimelist_mangalist'
            mangaEntry = _find @mangalist, (o) -> o.mal_id == params.id
            newProgress = { }
            if item.title == 'Chapters'
              newProgress = { chapters: item.current, volumes: mangaEntry.mangaUserReadVolumes,type: item.title }
            if item.title == 'Volumes'
              newProgress = { volumes: item.current, chapters: mangaEntry.mangaUserReadChapters,type: item.title }

            @updateProgress params.id,'manga',newProgress, (result) =>
              args.return(result)

        when 'score-update'
          item = params.item
          if params.viewName == 'myanimelist_animelist'
            @updateScore params.id,'anime',item.current, (result) =>
              args.return(result)

          if params.viewName == 'myanimelist_mangalist'
            @updateScore params.id,'manga',item.current, (result) =>
              args.return(result)

        when 'status-update'
          item = params.item
          id = params.id

          if item.identifier == 'watching'
            item.identifier = "1"

          if params.viewName == 'myanimelist_animelist'
            if !id? # If coming from media, there wont be an id, but title
              title = params.title
              @chiika.logger.script("Id not found for #{title}. Using title instead.")

              findInList = _find @animedb, (o) -> o.animeTitle == title
              if findInList?
                id = findInList.mal_id
            if id?
              @updateStatus id,'anime',item.identifier, (result) =>
                args.return(result)

          if params.viewName == 'myanimelist_mangalist'
            @updateStatus params.id,'manga',item.identifier, (result) =>
              args.return(result)

        when 'cover-click'
          id = params.id
          if id?
            if params.viewName == 'myanimelist_animelist'
              result = shell.openExternal("http://myanimelist.net/anime/#{id}")
            else
              result = shell.openExternal("http://myanimelist.net/manga/#{id}")
            args.return({ success:result })
          else
            @onActionError("Need ID for cover-click")


        when 'character-click'
          if !params.id?
            onActionError("Need ID for character-click")
          else
            result = shell.openExternal("http://myanimelist.net/character/#{params.id}")
            args.return({ success:result })

        when 'delete-entry'
          if !params.id?
            onActionError("Need ID for delete-entry")
          else
            if params.layoutType == 'anime'
              animeView = @chiika.viewManager.getViewByName('myanimelist_animelist')
              if animeView?
                entry = _find animeView.getData(), (o) -> o.mal_id == params.id
                if entry?
                  @removeAnime entry, (response) =>
                    if response.success
                      animeView.remove 'mal_id',params.id, (dbop) =>
                        if dbop.count > 0
                          # Update the local list
                          @animelist = animeView.getData()
                          @chiika.requestViewDataUpdate('myanimelist','myanimelist_animelist')
                          args.return(response)

            if params.layoutType == 'manga'
              mangaView = @chiika.viewManager.getViewByName('myanimelist_mangalist')
              if mangaView?
                entry = _find mangaView.getData(), (o) -> o.mal_id == params.id
                if entry?
                  @removeManga entry, (response) =>
                    if response.success
                      mangaView.remove 'mal_id',params.id, (dbop) =>
                        if dbop.count > 0
                          @mangalist = mangaView.getData()
                          @chiika.requestViewDataUpdate('myanimelist','myanimelist_mangalist')
                          args.return(response)

        when 'add-entry'
          if !params.id?
            onActionError("Need ID for add-entry")
          else
            if params.layoutType == 'anime'
              animeView = @chiika.viewManager.getViewByName('myanimelist_animelist')
              if animeView?
                entry = @createAddedAnimeEntry(params.id)
                @addAnime entry, (result) =>
                  if result.statusCode == 201
                    @updateViewAndRefresh 'myanimelist_animelist',entry,'mal_id', (result) =>
                      if result.updated > 0
                        @chiika.requestViewDataUpdate('myanimelist','myanimelist_animelist')
                        args.return(result)
            if params.layoutType == 'manga'
              mangaView = @chiika.viewManager.getViewByName('myanimelist_mangalist')
              if mangaView?
                entry = @createAddedMangaEntry(params.id)
                @addManga entry, (result) =>
                  if result.statusCode == 201
                    @updateViewAndRefresh 'myanimelist_mangalist',entry,'mal_id', (result) =>
                      if result.updated > 0
                        @chiika.requestViewDataUpdate('myanimelist','myanimelist_mangalist')
                        args.return(result)




    @on 'get-view-data', (args,callback) =>
      view = args.view
      data = args.data

      @chiika.logger.script("[yellow](#{@name}) Requesting View Data for #{view.name}")
      if !@malUser?
        return

      if view.name == 'myanimelist_animelist'
        watching    = []
        ptw         = []
        onhold      = []
        dropped     = []
        completed   = []

        cacheEpisodeData = []

        detectCacheView = @chiika.viewManager.getViewByName('anime_detect_cache')

        if detectCacheView?
          cacheEpisodeData = detectCacheView.getData()

        _forEach data, (anime) =>
          status = anime.animeUserStatus

          animeValues = @getAnimeValues(anime)
          title  = animeValues.title

          newAnime = _cloneDeep anime

          newAnime.id                            = animeValues.id # Renderer should not know which ID its dealing with.
          newAnime.animeTitle                    = animeValues.title
          newAnime.animeProgress                 = (parseInt(anime.animeWatchedEpisodes) / parseInt(anime.animeTotalEpisodes)) * 100
          newAnime.animeWatchedEpisodes          = animeValues.watchedEpisodes
          newAnime.animeTotalEpisodes            = animeValues.totalEpisodes
          newAnime.animeImage                    = animeValues.image
          newAnime.animeScoreAverage             = animeValues.averageScore
          newAnime.animeTypeText                 = animeValues.typeText
          newAnime.animeSeason                   = animeValues.season
          newAnime.animeScore                    = animeValues.score
          newAnime.animeScoreText                = animeValues.score
          newAnime.animeSeasonText               = animeValues.seasonText
          newAnime.animeLastUpdatedText          = animeValues.lastUpdatedText
          newAnime.animeSeriesStatusText         = @getAnimeStatus('text',animeValues.seriesStatus)

          if parseInt(newAnime.animeScore) == 0
            newAnime.animeScoreText = "-"


          green = "grid-airing-color-green" #success-main
          red   = "grid-airing-color-red" #danger-main
          gray  = "grid-airing-color-gray"
          blue  = "grid-airing-color-blue"

          airingColor = gray
          if animeValues.seriesStatus == "1"
            airingColor = gray
          if animeValues.seriesStatus == "2"
            airingColor = gray
          if animeValues.seriesStatus == "3"
            airingColor = red

          # To-do torrent available


          #newAnime.animeAiringColor = airingColor
          # Get episode stuff
          if cacheEpisodeData.length > 0
            findInCache = _find cacheEpisodeData, (o) => o.title == @recognition.clear(title)

            if findInCache?
              newAnime.animeEpisodes = findInCache.files

              _forEach newAnime.animeEpisodes, (episodes) =>
                episode = parseInt(episodes.episode,10)

                if episode > parseInt(animeValues.watchedEpisodes,10) && episode <= parseInt(animeValues.totalEpisodes,10)
                  airingColor = green



          newAnime.listBorderColor = airingColor
          if status == "1"
            watching.push newAnime
          else if status == "2"
            completed.push newAnime
          else if status == "3"
            onhold.push newAnime
          else if status == "4"
            dropped.push newAnime
          else if status == "6"
            ptw.push newAnime

        animelistData = []

        animelistData.push { name: 'al_watching',data: watching }
        animelistData.push { name: 'al_ptw',data: ptw }
        animelistData.push { name: 'al_dropped',data: dropped }
        animelistData.push { name: 'al_onhold',data: onhold }
        animelistData.push { name: 'al_completed',data: completed }
        args.return(animelistData)


      else if view.name == 'myanimelist_mangalist'
        reading     = []
        ptr         = []
        onhold      = []
        dropped     = []
        completed   = []

        _forEach data, (manga) =>
          status = manga.mangaUserStatus

          mangaValues = @getMangaValues(manga)

          newManga = _cloneDeep manga


          newManga.id                            = mangaValues.id # Renderer should not know which ID its dealing with.
          newManga.mangaTitle                    = mangaValues.title
          newManga.mangaUserReadChapters         = mangaValues.readChapters
          newManga.mangaUserReadVolumes          = mangaValues.readVolumes
          newManga.mangaSeriesVolumes            = mangaValues.volumes
          newManga.mangaSeriesChapters           = mangaValues.chapters
          newManga.mangaImage                    = mangaValues.image
          newManga.mangaScoreAverage             = mangaValues.averageScore
          newManga.mangaLastUpdatedText          = mangaValues.lastUpdatedText

          if newManga.mangaScore == "0"
            newManga.mangaScore = "-"


          if status == "1"
            reading.push newManga
          else if status == "2"
            completed.push newManga
          else if status == "3"
            onhold.push newManga
          else if status == "4"
            dropped.push newManga
          else if status == "6"
            ptr.push newManga

        mangalistData = []

        mangalistData.push { name: 'ml_reading',data: reading }
        mangalistData.push { name: 'ml_ptr',data: ptr }
        mangalistData.push { name: 'ml_dropped',data: dropped }
        mangalistData.push { name: 'ml_onhold',data: onhold }
        mangalistData.push { name: 'ml_completed',data: completed }
        args.return(mangalistData)

      else if args.view.name == 'myanimelist_animelist_history'
        animelistView = @chiika.viewManager.getViewByName('myanimelist_animelist')

        historyView = @chiika.viewManager.getViewByName('myanimelist_animelist_history')

        if historyView?
          historyData = historyView.getData()

          currentMonth = moment().month()
          currentYear  = moment().year()
          sixWeeksAgo  = moment().subtract(6,'weeks')

          monthNumbers = [0,0,0,0,0,0,0,0,0,0,0,0]
          sixWeeks = [0,0,0,0,0,0]
          watchedByMonth = monthNumbers


          _forEach historyData, (history) ->
            lastUpdated = history.updated

            date = moment(lastUpdated)

            if date.isValid() && date.year() == currentYear
              month = date.month()
              watchedByMonth[month] += 1

            if date.isValid() && date.isAfter(sixWeeksAgo)
              howManyWeeks = (moment.duration(date.diff(sixWeeksAgo)).asWeeks())

              if howManyWeeks < 6
                round = Math.round(howManyWeeks)
                sixWeeks[6 - round] += 1

            #else
              #console.log date.format("YYYY/MM/DD HH:mm") + " was not at least six weeks ago!"

            if !date.isValid()
              console.log "WARNING #{history.id} DATE IS NOT VALID!!"


          nonZeroDataPoints = 0
          chartLabels = []
          dataPoints  = []
          for i in [0...watchedByMonth.length+1]
            if watchedByMonth[i] != 0
              nonZeroDataPoints++

          if nonZeroDataPoints > 3
            for i in [0...watchedByMonth.length]
              if watchedByMonth[i] != 0
                chartLabels.push moment.months()[i]
                dataPoints.push watchedByMonth[i]
          else
            # Show last 6 weeks?
            for i in [5...-1]
              if i == 0
                chartLabels.push "This Week"
              else if i == 5
                chartLabels.push moment.months()[moment().month() - 1 ]
              else if i == 2
                chartLabels.push moment.months()[moment().month() ]
              else
                chartLabels.push ""
              dataPoints.push sixWeeks[i]

          chartEpisodesWatched =
            labels: chartLabels
            mode: nonZeroDataPoints
            datasets: [
              { name: 'Episodes Watched since 6 weeks',
              labels: chartLabels,
              data: dataPoints,
              backgroundColor: 'rgba(75,192,192,0.4)',
              borderColor: 'rgba(75,192,192,1)',
              pointBorderColor: 'rgba(75,192,192,1)',
              pointHoverBackgroundColor: 'rgba(75,192,192,1)',
              pointHoverBorderColor: 'rgba(220,220,220,1)'}
            ]
          args.return([chartEpisodesWatched])

    # This function is called from the login window.
    # For example, if you need a token, retrieve it here then store it by calling chiika.custom.addkey
    # Note that you dont have to do anything here if you want
    # But storing a user to avoid logging in each time you launch the app is a good practice
    # Another note is , you MUST call the  'args.return' or the app wont continue executing
    #
    @on 'set-user-login', (args,callback) =>
      @chiika.logger.script("[yellow](#{@name}) Auth in process " + args.user)

      onAuthComplete = (error,response,body) =>
        if error?
          @chiika.logger.error(error)
        else
          if response.statusCode == 200 or response.statusCode == 201
            userAdded = =>
              async = []

              deferUpdate1 = _when.defer()
              deferUpdate2 = _when.defer()
              async.push deferUpdate1.promise
              async.push deferUpdate2.promise



              @chiika.requestViewUpdate 'myanimelist_animelist',@name,() => deferUpdate1.resolve()
              @chiika.requestViewUpdate('myanimelist_mangalist',@name,() => deferUpdate2.resolve())

              _when.all(async).then =>
                args.return( { success: true })
                @initialize()

            newUser = { userName: args.user + "_" + @name,owner: @name, password: args.pass, realUserName: args.user }

            @chiika.parser.parseXml(body).then (xmlObject) =>
              assignNewUser = =>
                users = @chiika.users.getUsers()
                if users.length == 0
                  _assign newUser, { isDefault: true }
                _assign newUser, { malID: xmlObject.user.id }
                if @malUser?
                  _assign @malUser,newUser
                  @chiika.users.updateUser @malUser,userAdded
                else
                  @malUser = newUser
                  @chiika.users.addUser @malUser,userAdded

              if !@malUser?
                @malUser = @chiika.users.getUser(args.user + "_" + @name)
                assignNewUser()
              else
                onRemovePreviousUser = () =>
                  @malUser = null
                  assignNewUser()
                @chiika.users.removeUser @malUser,onRemovePreviousUser



            #  if chiika.users.getUser(malUser.userName)?
            #    chiika.users.updateUser malUser
            #  else
            #  chiika.users.addUser malUser
          else
            #Login failed, use the callback to tell the app that login isn't succesful.
            #
            args.return( { success: false, response: response })

      @chiika.makePostRequestAuth( authUrl, { userName: args.user, password: args.pass },null,null, onAuthComplete )


    @on 'system-event', (event) =>
      if event.name == 'shortcut-pressed'
        if event.params.action == 'test3'
          @chiika.emit 'scan-library', { calling: 'media' }



    @on 'get-anime-values', (args) =>
      @chiika.logger.debug("[yellow](#{@name}) get-anime-values #{args.entry.mal_id}")
      if args.entry.mal_id?
        args.return @getAnimeValues(args.entry)

    @on 'make-search', (args) =>
      @chiika.logger.script("[yellow](#{@name}) make-search #{args.title}")

      title = args.title
      type  = args.type
      @doSearch type,title, (results) =>
        args.return(results)

    @on 'add-anime', (args) =>
      entry = args.entry
      status = args.status

      entry.animeWatchedEpisodes = "0"
      entry.animeUserStatus = status
      entry.animeScore = "0"

      @addAnime entry, (result) =>
        if result.statusCode == 201
          args.return()
          # @updateViewAndRefresh 'myanimelist_animelist',entry,'id', (result) =>
          #   @chiika.showToast("#{entry.animeTitle} has been added succesfully!",3000,'success')
          #
          #   @chiika.requestViewDataUpdate(@name,'myanimelist_animelist')
          #
          #   args.return()

    @on 'is-in-list', (args) =>
      entry = args.entry
      listType = args.type

      inList = false

      if listType == 'anime'
        animeEntry = _find @animelist, (o) -> (o.mal_id) == entry.mal_id
        if animeEntry?
          inList = true
      if listType == 'manga'
        mangaEntry = _find @mangalist, (o) -> (o.mal_id) == entry.mal_id
        if mangaEntry?
          inList = true

      @chiika.logger.script("[yellow](#{@name}) #{entry.mal_id} - is-in-list #{args.type} -> #{inList}")
      args.return(inList)

    @on 'get-entry-user-status', (args) =>
      @chiika.logger.script("[yellow](#{@name}) get-entry-user-status #{args.type} - #{args.statusType}")
      entry = args.entry
      type = args.type
      statusType = args.statusType

      if type == 'anime'
        animeEntry = _find @animelist, (o) -> (o.mal_id) == entry.mal_id
        if animeEntry?
          status = animeEntry.animeUserStatus
          args.return(@getAnimeUserStatus(statusType,status))

      if type == 'manga'
        mangaEntry = _find @mangalist, (o) -> (o.mal_id) == entry.mal_id
        if mangaEntry?
          status = mangaEntry.mangaUserStatus
          args.return(@getMangaUserStatus(statusType,status))

    @on 'get-entry-type', (args) =>
      @chiika.logger.script("[yellow](#{@name}) get-entry-type #{args.type} - #{args.statusType}")
      entry = args.entry
      type = args.type
      statusType = args.statusType

      if type == 'anime'
        args.return(@getAnimeType(statusType,entry.animeType))

      if type == 'manga'
        args.return(@getMangaType(statusType,entry.mangaType))




  saveMangaHistory: (type,manga) ->
    #Save history
    historyView = @chiika.viewManager.getViewByName('myanimelist_mangalist_history')

    if historyView?
      historyData = historyView.getData()
      historyItem = {}

      if type == 'chapters'
        historyItem =
          history_id: historyData.length
          updated: moment().valueOf()
          mal_id: manga.id
          owner: 'myanimelist'
          chapters: manga.mangaUserReadChapters

      if type == 'volumes'
        historyItem =
          history_id: historyData.length
          updated: moment().valueOf()
          mal_id: manga.mal_id
          owner: 'myanimelist'
          volumes: manga.mangaUserReadVolumes

      historyView.setData( historyItem, 'updated').then (args) =>
        @chiika.requestViewDataUpdate('cards','cards_statistics')

  onAnimeDetailsLayout: (id,params,callback) ->
    #If its on the list, it will have this entry
    animeEntry = _find @animelist, (o) -> (o.mal_id) == id
    animeDbEntry = _find @animedb, (o) -> o.mal_id == id

    needUpdate = true

    timeSinceLastUpdate = @detailsSyncTimeRestriction
    if animeDbEntry? && animeDbEntry.lastSync?
      lastSync = animeDbEntry.lastSync
      now = moment()
      diff = moment.duration(now.diff(lastSync)).asHours()
      timeSinceLastUpdate = diff

      if timeSinceLastUpdate < @detailsSyncTimeRestriction - 1
        needUpdate = false


    if !needUpdate
      @chiika.logger.script("#{id} was last updated #{timeSinceLastUpdate} hours ago.There is no need to update")
      callback({ updated: false, layout: @getAnimeDetailsLayout(animeDbEntry)})
      return
    else
      @handleAnimeDetailsRequest id,params, (response) =>
        if response.success && response.updated > 0 && response.list
          entry = _find @animelist, (o) -> o.mal_id == id
          callback({ updated: true, layout: @getAnimeDetailsLayout(entry)})

          #@chiika.requestViewDataUpdate('myanimelist','myanimelist_animelist')

        if response.success && !response.list
          callback({ updated: false, layout: @getAnimeDetailsLayout(response.entry)})

          #@chiika.requestViewDataUpdate('myanimelist','myanimelist_animelist')

    if animeEntry?
      callback({ updated: false, layout: @getAnimeDetailsLayout(animeEntry)})
    #callback({ updated: false, layout: @getAnimeDetailsLayout({})})

  onMangaDetailsLayout: (id,params,callback) ->
    mangaEntry = _find @mangalist, (o) -> (o.mal_id) == id
    mangaDbEntry = _find @mangadb, (o) -> o.mal_id == id

    needUpdate = true

    timeSinceLastUpdate = @detailsSyncTimeRestriction
    if mangaDbEntry? && mangaDbEntry.lastSync?
      lastSync = mangaDbEntry.lastSync
      now = moment()
      diff = moment.duration(now.diff(lastSync)).asHours()
      timeSinceLastUpdate = diff

      if timeSinceLastUpdate < @detailsSyncTimeRestriction - 1
        needUpdate = false

    if !needUpdate
      @chiika.logger.script("#{id} was last updated #{timeSinceLastUpdate} hours ago.There is no need to update")
      callback?({ updated: false, layout: @getMangaDetailsLayout(mangaDbEntry)})
      return
    else
      @handleMangaDetailsRequest id, params, (response) =>
        if response.success && response.updated > 0 && response.list
          entry = _find @mangalist, (o) -> o.mal_id == id
          callback?({ updated: false, layout: @getMangaDetailsLayout(entry)})

          @chiika.requestViewDataUpdate('myanimelist','myanimelist_mangalist')

        if response.success && !response.list
          callback?({ updated: false, layout: @getMangaDetailsLayout(response.entry)})

          @chiika.requestViewDataUpdate('myanimelist','myanimelist_mangalist')

    if mangaEntry?
      callback?({ updated: false, layout: @getMangaDetailsLayout(mangaEntry)})


  doSearch: (type,title,callback) ->
    searchMatchAnime = (v) =>
      newAnimeEntry = {}
      newAnimeEntry.mal_id = v.id
      newAnimeEntry.animeEnglish = v.english
      newAnimeEntry.animeTitle = v.title
      newAnimeEntry.animeSynonyms = v.synonyms
      newAnimeEntry.animeType = @getAnimeType('number',v.type)
      newAnimeEntry.animeSeriesStartDate = v.start_date
      newAnimeEntry.animeSeriesEndDate = v.end_date
      newAnimeEntry.animeSeriesStatus = @getAnimeStatus('number',v.status)
      newAnimeEntry.animeImage = v.image
      newAnimeEntry.animeScoreAverage = v.score
      newAnimeEntry.animeSynopsis = v.synopsis
      newAnimeEntry.animeTotalEpisodes = v.episodes
      newAnimeEntry

    searchMatchManga = (v) =>
      newMangaEntry = {}
      newMangaEntry.mal_id = v.id
      newMangaEntry.mangaEnglish = v.english
      newMangaEntry.mangaTitle = v.title
      newMangaEntry.mangaSynonyms = v.synonyms
      newMangaEntry.mangaType = @getMangaType('number',v.type)
      newMangaEntry.mangaSeriesStartDate = v.start_date
      newMangaEntry.mangaSeriesEndDate = v.end_date
      newMangaEntry.mangaSeriesStatus = @getMangaStatus('number',v.status)
      newMangaEntry.mangaSeriesChapters = v.chapters
      newMangaEntry.mangaSeriesVolumes = v.volumes
      newMangaEntry.mangaImage = v.image
      newMangaEntry.mangaScoreAverage = v.score
      newMangaEntry.mangaSynopsis = v.synopsis
      newMangaEntry

    results = []

    @search type,title, (list) =>
      if list.success
        if _isArray list.results
          _forEach list.results, (entry) =>
            if type == 'anime'
              results.push searchMatchAnime(entry)
            else
              results.push searchMatchManga(entry)
        else
          if type == 'anime'
            results.push searchMatchAnime(list.results)
          else
            results.push searchMatchManga(list.results)

        if type == 'anime'
          @lastAnimeSearch = results
          # Save to anime db
          animeDbView = @chiika.viewManager.getViewByName('anime_db')

          if animeDbView?
            animeDbData = animeDbView.getData()

            animeDbFormat = []
            _forEach results, (anime) =>
              newAnime = {}
              mal_id = anime.mal_id
              # Check if this exists on db
              findInDb = _find animeDbData, (o) -> o.mal_id == mal_id
              if findInDb?
                newAnime.id = findInDb.id
              else
                newAnime.id = (animeDbData.length + animeDbFormat.length).toString()
              _assign newAnime,anime

              animeDbFormat.push newAnime

            animeDbView.setDataArray(animeDbFormat).then =>
              # Update local animedb
              animeDbView = @chiika.viewManager.getViewByName('anime_db')
              @animedb = animeDbView.getData()
              callback?({ success: list.success, error: list.error, results: results })

        if type == 'manga'
          @lastMangaSearch = results
          # Save to manga db
          mangaDbView = @chiika.viewManager.getViewByName('manga_db')

          if mangaDbView?
            mangaDbData = mangaDbView.getData()

            mangaDbFormat = []
            _forEach results, (manga) =>
              newManga = {}
              mal_id = manga.mal_id
              # Check if this exists on db
              findInDb = _find mangaDbData, (o) -> o.mal_id == mal_id
              if findInDb?
                newManga.id = findInDb.id
              else
                newManga.id = (mangaDbData.length + mangaDbFormat.length).toString()
              _assign newManga,manga

              mangaDbFormat.push newManga

            mangaDbView.setDataArray(mangaDbFormat).then =>
              # Update local animedb
              mangaDbView = @chiika.viewManager.getViewByName('manga_db')
              @mangadb = mangaDbView.getData()
              callback?({ success: list.success, error: list.error, results: results })

      else
        callback?({ success: list.success, error: list.error})


  doSearchExtended: (type,id,callback) ->
    matchManga = (v) ->
      newMangaEntry = {}
      newMangaEntry.mal_id = id
      newMangaEntry.mangaGenres = v.genres
      newMangaEntry.mangaScoreAverage = v.score
      newMangaEntry.mangaRanked = v.rank
      newMangaEntry.mangaPopularity = v.popularity
      newMangaEntry.scoredBy = v.scoredBy
      newMangaEntry

    matchAnime = (v) ->
      newAnimeEntry = {}
      newAnimeEntry.mal_id = id
      newAnimeEntry.animeGenres = v.genres
      newAnimeEntry.animeScoreAverage = v.score
      newAnimeEntry.animeRanked = v.rank
      newAnimeEntry.animePopularity = v.popularity
      newAnimeEntry.scoredBy = v.scoredBy
      newAnimeEntry

    @searchExtended type, id, (result) ->
      if result?
        if type == 'manga'
          matchedEntry = matchManga(result)
          # Save to anime db
          mangaDbView = @chiika.viewManager.getViewByName('manga_db')

          if mangaDbView?
            mangaDbData = mangaDbView.getData()

            # Check if this entry exists
            findInDb = _find mangaDbData, (o) -> o.mal_id == id

            newMangaEntry = {}
            if findInDb?
              newMangaEntry.id = findInDb.id
              _assign newMangaEntry,findInDb
              _assign newMangaEntry,matchedEntry
            else
              newMangaEntry.id = mangaDbData.length
              _assign newMangaEntry,matchedEntry

            newMangaEntry.lastSync = moment().valueOf()
            mangaDbView.setData(newMangaEntry,'id').then =>
              mangaDbView = @chiika.viewManager.getViewByName('manga_db')
              @mangadb = mangaDbView.getData()

              callback?({ entry: newMangaEntry })


        if type == 'anime'
          matchedEntry = matchAnime(result)
          # Save to anime db
          animeDbView = @chiika.viewManager.getViewByName('anime_db')

          if animeDbView?
            animeDbData = animeDbView.getData()

            # Check if this entry exists
            findInDb = _find animeDbData, (o) -> o.mal_id == id

            newAnimeEntry = {}
            if findInDb?
              newAnimeEntry.id = findInDb.id
              _assign newAnimeEntry,findInDb
              _assign newAnimeEntry,matchedEntry
            else
              newAnimeEntry.id = animeDbData.length
              _assign newAnimeEntry,matchedEntry

            newAnimeEntry.lastSync = moment().valueOf()
            animeDbView.setData(newAnimeEntry,'id').then =>
              animeDbView = @chiika.viewManager.getViewByName('anime_db')
              @animedb = animeDbView.getData()

              callback?({ entry: newAnimeEntry })


  doPageScrape: (type,id,callback) ->
    if type == 'manga'
      @mangaPageScrape id, (result) ->
        if result?
          matchedEntry = {}
          matchedEntry.mal_id = id
          matchedEntry.mangaJapanese = result.japanese
          matchedEntry.mangaPublished = result.published
          matchedEntry.mangaCharacters = result.characters
          matchedEntry.mangaSerialization = result.serialization
          matchedEntry.mangaAuthor = result.author

          # Save to manga db
          mangaDbView = @chiika.viewManager.getViewByName('manga_db')

          if mangaDbView?
            mangaDbData = mangaDbView.getData()

            # Check if this entry exists
            findInDb = _find mangaDbData, (o) -> o.mal_id == id

            newMangaEntry = {}
            if findInDb?
              newMangaEntry.id = findInDb.id
              _assign newMangaEntry,findInDb
              _assign newMangaEntry,matchedEntry
            else
              newMangaEntry.id = mangaDbData.length
              _assign newMangaEntry,matchedEntry

            newMangaEntry.lastSync = moment().valueOf()
            mangaDbView.setData(newMangaEntry,'id').then =>
              mangaDbView = @chiika.viewManager.getViewByName('manga_db')
              @mangadb = mangaDbView.getData()

              callback?({ entry: newMangaEntry })

    if type == 'anime'
      @animePageScrape id, (result) ->
        if result?
          matchedEntry = {}
          matchedEntry.mal_id = id
          matchedEntry.animeStudio = result.studio
          matchedEntry.animeSource = result.source
          matchedEntry.animeJapanese = result.japanese
          matchedEntry.animeBroadcast = result.broadcast
          matchedEntry.animeDuration = result.duration
          matchedEntry.animeAired = result.aired
          matchedEntry.animeCharacters = result.characters

          # Save to anime db
          animeDbView = @chiika.viewManager.getViewByName('anime_db')

          if animeDbView?
            animeDbData = animeDbView.getData()

            # Check if this entry exists
            findInDb = _find animeDbData, (o) -> o.mal_id == id

            newAnimeEntry = {}
            if findInDb?
              newAnimeEntry.id = findInDb.id
              _assign newAnimeEntry,findInDb
              _assign newAnimeEntry,matchedEntry
            else
              newAnimeEntry.id = animeDbData.length
              _assign newAnimeEntry,matchedEntry

            newAnimeEntry.lastSync = moment().valueOf()
            animeDbView.setData(newAnimeEntry,'id').then =>
              animeDbView = @chiika.viewManager.getViewByName('anime_db')
              @animedb = animeDbView.getData()

              callback?({ entry: newAnimeEntry })

  handleAnimeDetailsRequest: (animeId,params,callback) ->
    @chiika.logger.script("[yellow](#{@name}-Anime-Search) Searching for #{animeId}!")

    animeEntry = _find @animelist, (o) -> (o.mal_id) == animeId
    animeDbEntry = _find @animedb, (o) -> o.mal_id == animeId

    if animeEntry? && animeDbEntry?
      #Searching
      #
      # For search to occur, we need a title
      #
      newAnimeEntry = {}
      entryFound = false
      #
      #
      # Mal API Search
      #
      #
      @doSearch 'anime',animeDbEntry.animeTitle, (list) =>
        callback?({ success: true, updated: 1, list: true })

      @doSearchExtended 'anime',animeId, (result) =>
        callback?({ success: true, updated: 1, list: true })

      @doPageScrape 'anime',animeId, (result) =>
        callback?({ success: true, updated: 1, list: true })

    else
      # Not in list
      # ID is not enough alone, there must be something else!
      title = params.title
      cover = params.cover
      id    = params.id

      # Look through last searchs to find ID

      findInLastSearch = _find @lastAnimeSearch, (o) -> o.mal_id == id

      if findInLastSearch?
        callback({ success: true, entry: findInLastSearch, updated: 1,list: false })

      @doSearchExtended 'anime',animeId, (result) =>
        callback?({ success: true, updated: 1, list: false, entry: result.entry  })
      # #
      # @doPageScrape 'anime',animeId, (result) =>
      #   _assign newAnimeEntry, result.entry
      #   callback?({ success: true, entry: newAnimeEntry, updated: 1,list: false })

  handleMangaDetailsRequest: (mangaId,params,callback) ->
    @chiika.logger.script("[yellow](#{@name}-Manga-Search) Searching for #{mangaId}!")

    mangaEntry = _find @mangalist, (o) -> (o.mal_id) == mangaId
    mangaDbEntry = _find @mangadb, (o) -> (o.mal_id) == mangaId

    if mangaEntry?
      #Searching
      #
      # For search to occur, we need a title
      #

      newMangaEntry = {}
      entryFound = false
      #
      #
      # Mal API Search
      #
      #
      @doSearch 'manga',mangaDbEntry.mangaTitle, (list) =>
        callback?({ success: true, updated: 1, list: true })

      @doSearchExtended 'manga',mangaId, (result) =>
        callback?({ success: true, updated: 1, list: true })

      @doPageScrape 'manga',mangaId, (result) =>
        callback?({ success: true, updated: 1, list: true })



    else
      # Not in list
      # ID is not enough alone, there must be something else!
      title = params.title
      newMangaEntry = {}
      newMangaEntry.animeTitle = title

      @doSearch 'manga',title, (results) =>
        _forEach results, (entry) =>
          if entry.id == mangaId
            _assign newMangaEntry, entry
            callback?({ success: true, entry: newMangaEntry, updated: 1,list: false })

      @doSearchExtended 'manga',mangaId, (result) =>
        _assign newMangaEntry, result.entry
        callback?({ success: true, entry: newMangaEntry, updated: 1,list: false })

      @doPageScrape 'manga',mangaId, (result) =>
        _assign newMangaEntry, result.entry
        callback?({ success: true, entry: newMangaEntry, updated: 1,list: false })

  getMangaDetailsLayout: (entry) ->
    mv    = @getMangaValues(entry)


    if mv.synonyms?
      mv.synonyms = mv.synonyms.split(";")[0]
    else
      mv.synonyms = ""

    if mv.genres == ""
      mv.genres = mv.synonyms
    else
      genresText = ""
      mv.genres.map (genre,i) => genresText += genre + ","
      mv.genres = genresText

    typeCard =
      name: 'typeMiniCard'
      title: 'Type'
      content: mv.typeText
      type: 'miniCard'

    serializationCard =
      name: 'serializationMiniCard'
      title: 'Serialization'
      content: mv.serialization
      type: 'miniCard'

    cards = [typeCard]

    if mv.serialization.length > 0?
      cards.push serializationCard

    userStatusText = ""
    if mv.userStatus == "1"
      userStatusText = "Reading"
    else if mv.userStatus == "2"
      userStatusText = "Completed"
    else if mv.userStatus == "3"
      userStatusText = "On Hold"
    else if mv.userStatus == "4"
      userStatusText = "Dropped"
    else if mv.userStatus == "6"
      userStatusText = "Plan to Read"

    detailsLayout =
      id: mv.id
      layoutType: 'manga'
      title: mv.title
      genres: mv.genres
      list: mv.list
      status:
        items:
          [
            { title: 'Chapters', current: mv.readChapters, total: mv.chapters },
            { title: 'Volumes', current: mv.readVolumes, total: mv.volumes }
          ]
        user: mv.userStatus
        series: mv.seriesStatus
        defaultAction: userStatusText
        actions:[
          { name: 'Reading', action: 'status-action-watching', identifier:"1" },
          { name: 'Completed', action: 'status-action-completed', identifier:"2" }
          { name: 'Plan to Read', action: 'status-action-ptw',identifier:"6" },
          { name: 'On Hold', action: 'status-action-onhold',identifier:"3" },
          { name: 'Dropped', action: 'status-action-dropped',identifier:"4" }
        ]
      synopsis: mv.synopsis
      cover: mv.image
      english: mv.english
      voted: mv.scoredBy
      characters: mv.characters
      japanese: mv.japanese
      params:
        author: mv.author
        serialization: mv.serialization
        published: mv.published
      owner: @name
      actionButtons: [
        { name: 'Torrent', action: 'torrent',color: 'lightblue' },
        { name: 'Library', action: 'library',color: 'purple' }
        { name: 'Play Next', action: 'playnext',color: 'teal' }
        { name: 'Search', action: 'search',color: 'green' }
      ]
      scoring:
        type: 'normal'
        userScore: mv.score
        average: mv.averageScore
      miniCards: cards
    if !detailsLayout.list
      detailsLayout.rawEntry = entry
    detailsLayout


  getAnimeDetailsLayout: (entry) ->
    av    = @getAnimeValues(entry)

    if av.synonyms?
      av.synonyms = av.synonyms.split(";")[0]
    else
      av.synonyms = ""

    if av.synopsis?
      #Replace html stuff
      av.synopsis = av.synopsis.split("[i]").join("<i>")
      av.synopsis = av.synopsis.split("[/i]").join("</i>")



    typeCard =
      name: 'typeMiniCard'
      title: 'Type'
      content: av.typeText
      type: 'miniCard'

    seasonCard =
      name: 'seasonMiniCard'
      title: 'Season'
      content: av.season
      type: 'miniCard'

    sourceCard =
      name: 'sourceMiniCard'
      title: 'Source'
      content: av.source
      type: 'miniCard'

    if av.studio?
      studioCard =
        name: 'studioMiniCard'
        title: 'Studio'
        content: av.studio.name
        type: 'miniCard'

    durationCard =
      name: 'durationMiniCard'
      title: 'Duration'
      content: av.duration
      type: 'miniCard'

    cards = [typeCard,seasonCard]

    if av.source != ""
      cards.push sourceCard

    if av.studio?
      cards.push studioCard

    if av.duration != ""
      cards.push durationCard

    if av.genres == ""
      av.genres = av.synonyms
    else
      genresText = ""
      av.genres.map (genre,i) => genresText += genre + ","
      av.genres = genresText


    userStatusText = ""
    if av.userStatus == "1"
      userStatusText = "Watching"
    else if av.userStatus == "2"
      userStatusText = "Completed"
    else if av.userStatus == "3"
      userStatusText = "On Hold"
    else if av.userStatus == "4"
      userStatusText = "Dropped"
    else if av.userStatus == "6"
      userStatusText = "Plan to Watch"


    detailsLayout =
      id: av.id
      layoutType: 'anime'
      title: av.title
      genres: av.genres
      list: av.list
      status:
        items:
          [
            { title: 'Episodes', current: av.watchedEpisodes, total: av.totalEpisodes },
          ]
        user: av.userStatus
        series: av.seriesStatus
        defaultAction: userStatusText
        actions:[
          { name: 'Watching', action: 'status-action-watching', identifier:"1" },
          { name: 'Completed', action: 'status-action-completed', identifier:"2" }
          { name: 'Plan to Watch', action: 'status-action-ptw',identifier:"6" },
          { name: 'On Hold', action: 'status-action-onhold',identifier:"3" },
          { name: 'Dropped', action: 'status-action-dropped',identifier:"4" }
        ]
      synopsis: av.synopsis
      cover: av.image
      english: av.english
      voted: av.scoredBy
      characters: av.characters
      owner: @name
      actionButtons: [
        { name: 'Torrent', action: 'torrent',color: 'lightblue' },
        { name: 'Library', action: 'library',color: 'purple' }
        { name: 'Play Next', action: 'playnext',color: 'teal' }
        { name: 'Search', action: 'search',color: 'green' }
      ]
      scoring:
        type: 'normal'
        userScore: av.score
        average: av.averageScore
      miniCards: cards

    if !av.list
      detailsLayout.rawEntry = entry
    detailsLayout
  #
  # In the @createViewAnimelist, we created 5 tab
  # Here we supply the data of the tabs
  # The format is { name: 'tabname', data: [] }
  # The data array has to follow the grid rules in order to appear in the grid correctly.
  # Also they need to have a unique ID
  # For animeList object, see myanimelist.net/malappinfo.php?u=arkenthera&type=anime&status=all
  setAnimelistTabViewData: (animeList,view) ->
    animeDbArray = []
    animeDb = @chiika.viewManager.getViewByName('anime_db')

    if animeDb?
      data = animeDb.getData()

      if data.length > 0
        animeDbArray = data
      else
        animeDbArray = []

    commonFormatList = []
    try
      _forEach animeList, (anime) =>
        newAnime = {}
        newAnime.id = animeDbArray.length
        _assign newAnime, @toAnimeDbFormat(anime)
        animeDbArray.push newAnime

        commonFormatList.push @animeToCommonFormat(anime)
    catch error
      console.log error

    @animedb = animeDbArray
    @animelist = commonFormatList

    animeDb.setDataArray(animeDbArray)
    view.setDataArray(commonFormatList)

  toAnimeDbFormat: (v) ->
    anime = {}

    anime.mal_id                    = v.series_animedb_id
    anime.animeTitle                = v.series_title
    anime.animeSynonyms             = v.series_synonyms
    anime.animeType                 = v.series_type
    anime.animeTotalEpisodes        = v.series_episodes
    anime.animeSeriesStatus         = v.series_status
    anime.animeSeriesStartDate      = v.series_start
    anime.animeSeriesEndDate        = v.series_end
    anime.animeImage                = v.series_image
    anime.owner                     = 'myanimelist'

    anime

  toMangaDbFormat: (v) ->
    manga = {}

    manga.mal_id                      = v.series_mangadb_id
    manga.mangaTitle                  = v.series_title
    manga.mangaSynonyms               = v.series_synonyms
    manga.mangaSeriesStatus           = v.series_status
    manga.mangaType                   = v.series_type
    manga.mangaSeriesChapters         = v.series_chapters
    manga.mangaSeriesVolumes          = v.series_volumes
    manga.mangaSeriesStartDate        = v.series_start
    manga.mangaSeriesEndDate          = v.series_end
    manga.mangaImage                  = v.series_image
    manga.owner                     = 'myanimelist'

    manga

  saveToAnimeDb: (mal_id,entry) ->
    new Promise (resolve) =>
      animeDbView = @chiika.viewManager.getViewByName('anime_db')

      #Find DB id
      dbEntry = _find animeDbView.getData(), (o) -> o.mal_id == mal_id

      if dbEntry?
        id = dbEntry.id
        _assign dbEntry,entry
        dbEntry.id = id
        animeDbView.setData(entry,'id').then (args) =>
          resolve(args)
  #
  # In the @createViewAnimelist, we created 5 tab
  # Here we supply the data of the tabs
  # The format is { name: 'tabname', data: [] }
  # The data array has to follow the grid rules in order to appear in the grid correctly.
  # Also they need to have a unique ID
  # For animeList object, see myanimelist.net/malappinfo.php?u=arkenthera&type=anime&status=all
  setMangalistTabViewData: (mangaList,view) ->
    mangaDbArray = []
    mangaDb = @chiika.viewManager.getViewByName('manga_db')

    if mangaDb?
      data = mangaDb.getData()

      if data.length > 0
        mangaDbArray = data
      else
        mangaDbArray = []

    commonFormatList = []
    try
      _forEach mangaList, (manga) =>
        newManga = {}
        newManga.id = mangaDbArray.length
        _assign newManga, @toMangaDbFormat(manga)
        mangaDbArray.push newManga

        commonFormatList.push @mangaToCommonFormat(manga)
    catch error
      console.log error


    mangaDb.setDataArray(mangaDbArray)
    view.setDataArray(commonFormatList)

  #
  #
  #
  updateViewAndRefresh: (viewName,newEntry,key,callback) ->
    view = @chiika.viewManager.getViewByName(viewName)
    view.setData(newEntry,key).then =>
      callback?({ success: true,updated: 1 })

  #
  #
  #
  updateProgress:(id,type,newProgress,callback) ->
    @chiika.logger.script("Updating #{type} progress - #{id} - to #{newProgress}")
    switch type
      when 'anime'
        animeEntry = _find @animelist, (o) -> (o.mal_id) == id
        if animeEntry?
          animeEntry.animeWatchedEpisodes = newProgress
          @updateAnime animeEntry, (result) =>
            if result.success
              @updateViewAndRefresh 'myanimelist_animelist',animeEntry,'mal_id', (result) =>
                if result.updated > 0
                  callback({ success: true, updated: result.updated })

                  malConfig = @chiika.settingsManager.readConfigFile('myanimelist')

                  if malConfig.moveToCompletedWhenFinished && parseInt(animeEntry.animeWatchedEpisodes,10) == parseInt(animeEntry.animeTotalEpisodes,10)
                    @updateStatus(id,type,"2", ->)
                else
                  callback({ success: false, updated: result.updated, error:"Update request has failed.", response: result.response, errorDetailed: "Something went wrong when saving to database." })
            else
              callback({ success: false, updated: 0, error: "Update request has failed.",errorDetailed: "Something went wrong with the http request.", response: result.response })


      when 'manga'
        mangaEntry = _find @mangalist, (o) -> (o.mal_id) == id
        if mangaEntry?
          mangaEntry.mangaUserReadVolumes = newProgress.volumes
          mangaEntry.mangaUserReadChapters = newProgress.chapters

          @updateManga mangaEntry, (result) =>
            if result.success
              if newProgress.type == 'Chapters'
                @saveMangaHistory('chapters',mangaEntry)
              else
                @saveMangaHistory('volumes',mangaEntry)

              @updateViewAndRefresh 'myanimelist_mangalist',mangaEntry,'mal_id', (result) =>
                if result.updated > 0
                  callback({ success: true, updated: result.updated })
                else
                  callback({ success: false, updated: result.updated, error:"Update request has failed.", errorDetailed: "Something went wrong when saving to database." })
            else
              callback({ success: false, updated: 0, error: "Update request has failed.",errorDetailed: "Something went wrong with the http request. #{result.response}" })


  #
  #
  #
  updateScore:(id,type,newScore,callback) ->
    onUpdateView = (result) =>
      if result.updated > 0
        callback({ success: true, updated: result.updated })
      else
        callback({ success: false, updated: result.updated, error:"Update request has failed.", errorDetailed: "Something went wrong when saving to database." })


    @chiika.logger.script("Updating #{type} score - #{id} - to #{newScore}")
    switch type
      when 'anime'
        animeEntry = _find @animelist, (o) -> (o.mal_id) == id
        if animeEntry?
          animeEntry.animeScore = newScore
          @updateAnime animeEntry, (result) =>
            if result.success
              @updateViewAndRefresh 'myanimelist_animelist',animeEntry,'mal_id', (result) =>
                onUpdateView(result)
            else
              callback({ success: false, updated: 0, error: "Update request has failed.",errorDetailed: "Something went wrong with the http request. #{result.response}" })


      when 'manga'
        mangaEntry = _find @mangalist, (o) -> (o.mal_id) == id
        if mangaEntry?
          mangaEntry.mangaScore = newScore
          @updateManga mangaEntry, (result) =>
            if result.success
              @updateViewAndRefresh 'myanimelist_mangalist',mangaEntry,'mal_id', (result) =>
                onUpdateView(result)
            else
              callback({ success: false, updated: 0, error: "Update request has failed.",errorDetailed: "Something went wrong with the http request. #{result.response}" })

  #
  #
  #
  updateStatus:(id,type,newStatus,callback) ->
    @chiika.logger.script("Updating #{type} status - #{id} - to #{newStatus}")

    entry = { }
    newTabName = ""
    oldTabName = ""

    switch type
      when 'anime'
        entry = _find @animelist, (o) -> (o.mal_id) == id
      when 'manga'
        entry = _find @mangalist, (o) -> (o.mal_id) == id

    switch type
      when 'anime'
        if entry?
          # Update the entry's status
          entry.animeUserStatus = newStatus

          @updateAnime entry, (result) =>
            if result.success
              @updateViewAndRefresh 'myanimelist_animelist',entry,'mal_id', (result) =>
                if result.updated > 0
                  callback({ success: true, updated: result.updated })
                else
                  callback({ success: false, updated: result.updated, error:"Update request has failed.", errorDetailed: "Something went wrong when saving to database." })
            else
              callback({ success: false, updated: 0, error: "Update request has failed.",errorDetailed: "Something went wrong with the http request. #{result.response}" })

      when 'manga'
        if entry?
          # Update the entry's status
          entry.mangaUserStatus = newStatus

          @updateManga entry, (result) =>
            if result.success
              @updateViewAndRefresh 'myanimelist_mangalist',entry,'mal_id', (result) =>
                if result.updated > 0
                  callback({ success: true, updated: result.updated })
                else
                  callback({ success: false, updated: result.updated, error:"Update request has failed.", errorDetailed: "Something went wrong when saving to database." })
            else
              callback({ success: false, updated: 0, error: "Update request has failed.",errorDetailed: "Something went wrong with the http request. #{result.response}" })

  #
  #
  #
  getAnimeValues: (entry) ->
    if entry?
      findInAnimelist = _find @animelist, (o) -> o.mal_id == entry.mal_id
      animeDbEntry = _find @animedb, (o) -> o.mal_id == entry.mal_id


    if findInAnimelist?
      list = true
    else
      list = false

    if !animeDbEntry?
      animeDbEntry = {}

    if !findInAnimelist?
      findInAnimelist = {}

    title               = animeDbEntry.animeTitle ? ""                       #MalApi
    synonyms            = animeDbEntry.animeSynonyms ? ""                    #MalApi
    type                = animeDbEntry.animeType ? ""                        #MalApi
    totalEpisodes       = animeDbEntry.animeTotalEpisodes ? "0"              #MalApi
    seriesStatus        = animeDbEntry.animeSeriesStatus ? "0"               #MalApi
    seriesStartDate     = animeDbEntry.animeSeriesStartDate ? ""             #MalApi
    seriesEndDate       = animeDbEntry.animeSeriesEndDate ? ""               #MalApi
    image               = animeDbEntry.animeImage ? "../assets/images/chitoge.png"#MalApi
    watchedEpisodes     = findInAnimelist.animeWatchedEpisodes ? "0"            #MalApi
    userStartDate       = findInAnimelist.animeUserStartDate ? ""               #MalApi
    userEndDate         = findInAnimelist.animeUserEndDate ? ""                 #MalApi
    score               = findInAnimelist.animeScore ? "0"                      #MalApi
    userStatus          = findInAnimelist.animeUserStatus ? "0"                 #MalApi
    userRewatching      = findInAnimelist.animeUserRewatching ? ""              #MalApi
    userRewatchingEp    = findInAnimelist.animeUserRewatchingEp ? ""            #MalApi
    lastUpdated         = findInAnimelist.animeLastUpdated ? ""                 #MalApi
    tags                = findInAnimelist.animeUserTags ? ""                    #MalApi
    averageScore        = animeDbEntry.animeScoreAverage ? "-"               #Ajax.inc
    ranked              = animeDbEntry.animeRanked ? ""                      #Ajax.inc
    genres              = animeDbEntry.animeGenres ? ""                      #Ajax.inc
    synopsis            = animeDbEntry.animeSynopsis ? ""                    #Search
    english             = animeDbEntry.animeEnglish ? ""                     #Search
    popularity          = animeDbEntry.animePopularity ? ""                  #Ajax.inc
    scoredBy            = animeDbEntry.scoredBy ? "0"                        #Ajax.inc
    studio              = animeDbEntry.animeStudio ? null                    #PageScrape
    broadcastDate       = animeDbEntry.animeBroadcast ? ""                   #PageScrape
    aired               = animeDbEntry.animeAired ? ""                       #PageScrape
    japanese            = animeDbEntry.animeJapanese ? ""                    #PageScrape
    source              = animeDbEntry.animeSource ? ""                      #PageScrape
    duration            = animeDbEntry.animeDuration ? ""                    #PageScrape
    characters          = animeDbEntry.animeCharacters ? []                  #PageScrape


    # Change the type from a number to a common format
    typeText = "Unknown"
    typeText = @getAnimeType('text',type)


    userStatusText = "Not In List"
    if userStatus == "1"
      userStatusText = "Watching"
    else if userStatus == "2"
      userStatusText = "Completed"
    else if userStatus == "3"
      userStatusText = "On Hold"
    else if userStatus == "4"
      userStatusText = "Dropped"
    else if userStatus == "6"
      userStatusText = "Plan to Watch"

    # Change the season from date to text
    startDate = animeDbEntry.animeSeriesStartDate

    if startDate?
      parts = startDate.split("-");
      year = parts[0];
      month = parts[1];

      iMonth = parseInt(month);

      season = "Unknown"
      if iMonth > 0 && iMonth < 4
        season =  "Winter " + year
      if iMonth > 3 && iMonth < 7
        season =  "Spring " + year
      if iMonth > 6 && iMonth < 10
        season =  "Summer " + year
      if iMonth > 9 && iMonth <= 12
        season = "Fall " + year

    # change last updated from unix timestamp to text
    date = moment.unix(parseInt(lastUpdated))
    now = moment()
    diffSeconds = Math.floor(moment.duration(now.diff(date)).asSeconds())
    diffMinutes = Math.floor(moment.duration(now.diff(date)).asMinutes())
    diffHours = Math.floor(moment.duration(now.diff(date)).asHours())
    diffDays = Math.floor(moment.duration(now.diff(date)).asDays())
    diffWeeks = Math.floor(moment.duration(now.diff(date)).asWeeks())
    diffMonths = Math.floor(moment.duration(now.diff(date)).asMonths())
    diffYears = Math.floor(moment.duration(now.diff(date)).asYears())

    lastUpdatedText = "a moment ago"

    if diffMinutes > 0
      lastUpdatedText = "#{diffMinutes} minutes ago"


    if diffHours > 0
      lastUpdatedText = "#{diffHours} hours ago"

    if diffDays > 0
      lastUpdatedText = "#{diffDays} days ago"

    if diffWeeks > 0
      lastUpdatedText = "#{diffWeeks} weeks ago"

    if diffMonths > 0
      lastUpdatedText = "#{diffMonths} months ago"

    if diffYears > 0
      lastUpdatedText = "#{diffYears} years ago"

    anime =
      id: entry.mal_id
      list: list
      title: title
      synonyms: synonyms
      type: type
      totalEpisodes: totalEpisodes
      seriesStatus: seriesStatus
      seriesStartDate: seriesStartDate
      seriesEndDate: seriesEndDate
      image: image
      watchedEpisodes: watchedEpisodes
      userStartDate: userStartDate
      userEndDate: userEndDate
      score: score
      userStatus: userStatus
      userStatusText: userStatusText
      userRewatching: userRewatching
      userRewatchingEp: userRewatchingEp
      lastUpdated: lastUpdated
      lastUpdatedText: lastUpdatedText
      tags: tags
      typeText: typeText
      seasonText: season
      season: startDate
      score: score
      averageScore: averageScore
      ranked: ranked
      genres: genres
      synopsis: synopsis
      english: english
      popularity: popularity
      scoredBy: scoredBy
      studio: studio
      broadcastDate: broadcastDate
      aired: aired
      japanese: japanese
      source: source
      duration: duration
      characters: characters

  #
  #
  #
  getMangaValues: (entry) ->
    if entry?
      findInMangalist = _find @mangalist, (o) -> o.mal_id == entry.mal_id
      mangaDbEntry = _find @mangadb, (o) -> o.mal_id == entry.mal_id

    if !mangaDbEntry?
      mangaDbEntry = {}


    list = false
    if findInMangalist?
      list = true
    else
      list = false

    if !findInMangalist?
      findInMangalist = {}



    title               = mangaDbEntry.mangaTitle ? ""                       #MalApi
    synonyms            = mangaDbEntry.mangaSynonyms ? ""                    #MalApi
    type                = mangaDbEntry.mangaType ? ""                        #MalApi
    seriesStatus        = mangaDbEntry.mangaSeriesStatus ? "0"               #MalApi
    volumes             = mangaDbEntry.mangaSeriesVolumes ? "0"              #MalApi
    chapters            = mangaDbEntry.mangaSeriesChapters ? "0"             #MalApi
    seriesStart         = mangaDbEntry.mangaSeriesStartDate ? ""             #MalApi
    seriesEnd           = mangaDbEntry.mangaSeriesEndDate? ""                #MalApi
    image               = mangaDbEntry.mangaImage ? "../assets/images/chitoge.png"#MalApi
    readVolumes         = findInMangalist.mangaUserReadVolumes ? "0"            #MalApi
    readChapters        = findInMangalist.mangaUserReadChapters ? "0"           #MalApi
    userStart           = findInMangalist.mangaUserStart ? ""                   #MalApi
    userEnd             = findInMangalist.mangaUserEnd ? ""                     #MalApi
    userStatus          = findInMangalist.mangaUserStatus ? "0"                 #MalApi
    score               = findInMangalist.mangaScore ? "0"                    #MalApi
    tags                = findInMangalist.mangaTags ? ""                     #MalApi
    rereading           = findInMangalist.mangaUserRereading ? ""               #MalApi
    rereadingChapter    = findInMangalist.mangaUserRereadingChapter ? ""        #MalApi
    lastUpdated         = findInMangalist.mangaLastUpdated ? "0"              #MalApi
    averageScore        = mangaDbEntry.mangaScoreAverage ? "-"               #Ajax.inc
    ranked              = mangaDbEntry.mangaRanked ? ""                      #Ajax.inc
    genres              = mangaDbEntry.mangaGenres ? ""                      #Ajax.inc
    popularity          = mangaDbEntry.mangaPopularity ? ""                  #Ajax.inc
    scoredBy            = mangaDbEntry.scoredBy ? "0"                        #Ajax.inc
    synopsis            = mangaDbEntry.mangaSynopsis ? ""                    #Search
    english             = mangaDbEntry.mangaEnglish ? ""                     #Search
    serialization       = mangaDbEntry.mangaSerialization ? ""               #PageScrape
    published           = mangaDbEntry.mangaPublished ? ""                   #PageScrape
    japanese            = mangaDbEntry.mangaJapanese ? ""                    #PageScrape
    author              = mangaDbEntry.mangaAuthor ? ""                      #PageScrape
    characters          = mangaDbEntry.mangaCharacters ? []                  #PageScrape

    # Change the type from a number to a common format
    typeText = "Unknown"
    typeText = @getMangaType('text',type)

    date = moment.unix(parseInt(lastUpdated))
    now = moment()
    diffSeconds = Math.floor(moment.duration(now.diff(date)).asSeconds())
    diffMinutes = Math.floor(moment.duration(now.diff(date)).asMinutes())
    diffHours = Math.floor(moment.duration(now.diff(date)).asHours())
    diffDays = Math.floor(moment.duration(now.diff(date)).asDays())
    diffWeeks = Math.floor(moment.duration(now.diff(date)).asWeeks())
    diffMonths = Math.floor(moment.duration(now.diff(date)).asMonths())
    diffYears = Math.floor(moment.duration(now.diff(date)).asYears())

    lastUpdatedText = "a moment ago"

    if diffMinutes > 0
      lastUpdatedText = "#{diffMinutes} minutes ago"


    if diffHours > 0
      lastUpdatedText = "#{diffHours} hours ago"

    if diffDays > 0
      lastUpdatedText = "#{diffDays} days ago"

    if diffWeeks > 0
      lastUpdatedText = "#{diffWeeks} weeks ago"

    if diffMonths > 0
      lastUpdatedText = "#{diffMonths} months ago"

    if diffYears > 0
      lastUpdatedText = "#{diffYears} years ago"

    manga =
      id: entry.mal_id
      title: title
      synonyms: synonyms
      list: list
      type: type
      seriesStatus: seriesStatus
      chapters: chapters
      volumes: volumes
      seriesStart: seriesStart
      seriesEnd: seriesEnd
      image: image
      readVolumes: readVolumes
      readChapters: readChapters
      userStart: userStart
      userEnd: userEnd
      userStatus: userStatus
      score: score
      tags: tags
      userRereading: rereading
      userRereadingChapter: rereadingChapter
      lastUpdated: lastUpdated
      lastUpdatedText: lastUpdatedText
      typeText: typeText
      averageScore: averageScore
      ranked: ranked
      genres: genres
      popularity: popularity
      scoredBy: scoredBy
      synopsis: synopsis
      english: english
      serialization: serialization
      japanese: japanese
      author: author
      published:published
      characters: characters
    manga

  #
  #
  #
  animeToCommonFormat: (v) ->
    anime = {}

    anime.mal_id                      = v.series_animedb_id
    anime.animeWatchedEpisodes      = v.my_watched_episodes
    anime.animeUserStartDate        = v.my_start_date
    anime.animeUserEndDate          = v.my_finish_date
    anime.animeScore                = parseInt(v.my_score)
    anime.animeUserStatus           = v.my_status
    anime.animeUserRewatching       = v.my_rewatching
    anime.animeUserRewatchingEp     = v.my_rewatching_ep
    anime.animeLastUpdated          = v.my_last_updated
    anime.animeUserTags             = v.my_tags
    anime


  #
  #
  #
  mangaToCommonFormat: (v) ->
    manga = {}

    manga.mal_id                      = v.series_mangadb_id
    manga.mangaUserReadChapters       = v.my_read_chapters
    manga.mangaUserReadVolumes        = v.my_read_volumes
    manga.mangaUserStartDate          = v.my_start_date
    manga.mangaUserEndDate            = v.my_finish_date
    manga.mangaScore                  = v.my_score
    manga.mangaUserStatus             = v.my_status
    manga.mangaLastUpdated            = v.my_last_updated
    manga.mangaUserRereading          = v.my_rereadingg # ?
    manga.mangaUserRereadingChapter   = v.my_rereading_chap
    manga.mangaTags                   = v.my_tags

    manga

  #
  # Type is what you want in return.
  #
  getAnimeStatus: (type,status) ->
    statusMap = [
      { api: "1", text: "Currently Airing"},
      { api: "2", text: "Finished Airing"},
      { api: "3", text: "Not yet aired"}
    ]
    if type == 'text'
      find = _find statusMap, (o) -> o.api == status
      if find?
        return find.text
      else
        return 'Unknown'

    if type == 'number'
      find = _find statusMap, (o) -> o.text == status
      if find?
        return find.api
      else
        return '0'

  #
  # Type is what you want in return.
  #
  getAnimeUserStatus: (type,status) ->
    statusMap = [
      { api: "1", text: "Watching"},
      { api: "2", text: "Completed"},
      { api: "3", text: "On Hold"},
      { api: "4", text: "Dropped"},
      { api: "6", text: "Plan to Watch"}
    ]

    if type == 'text'
      find = _find statusMap, (o) -> o.api == status
      return find.text
    if type == 'number'
      find = _find statusMap, (o) -> o.text == status
      return find.api

  getAnimeType: (r,type) ->
    typeMap = [
      { api: '0', text: 'Unknown' },
      { api: '1', text: 'TV' },
      { api: '2', text: 'OVA' },
      { api: '3', text: 'Movie' },
      { api: '4', text: 'Special' },
      { api: '5', text: 'ONA' },
      { api: '6', text: 'Music' }
    ]

    if r == 'text'
      find = _find typeMap, (o) -> o.api == type
      if find?
        return find.text
      else
        return 'Unknown'
    if r == 'number'
      find = _find typeMap, (o) -> o.text == type
      if find?
        return find.api
      else
        return '0'

  getMangaType: (r,type) ->
    typeMap = [
      { api: '0', text: 'Unknown' },
      { api: '1', text: 'Manga' },
      { api: '2', text: 'Novel' },
      { api: '3', text: 'One-shot' },
      { api: '4', text: 'Doujinshi' },
      { api: '5', text: 'Manwha' },
      { api: '6', text: 'Manhua' }
    ]
    if r == 'text'
      find = _find typeMap, (o) -> o.api == type
      if find?
        return find.text
      else
        return 'Unknown'
    if r == 'number'
      find = _find typeMap, (o) -> o.text == type
      if find?
        return find.api
      else
        return '0'

  getMangaStatus: (type,status) ->
    statusMap = [
      { api: "1", text: "Publishing"},
      { api: "2", text: "Finished"}
    ]
    if type == 'text'
      find = _find statusMap, (o) -> o.api == status
      if find?
        return find.text
      else
        return 'Unknown'

    if type == 'number'
      find = _find statusMap, (o) -> o.text == status
      if find?
        return find.api
      else
        return '0'

  #
  # Type is what you want in return.
  #
  getMangaUserStatus: (type,status) ->
    statusMap = [
      { api: "1", text: "Reading"},
      { api: "2", text: "Completed"},
      { api: "3", text: "On Hold"},
      { api: "4", text: "Dropped"},
      { api: "6", text: "Plan to Read"}
    ]


    if type == 'text'
      find = _find statusMap, (o) -> o.api == status
      return find.text
    if type == 'number'
      find = _find statusMap, (o) -> o.text == status
      return find.api

  createAddedAnimeEntry: (id) ->
    entry =
      mal_id: id
      animeWatchedEpisodes: "0"
      animeUserStartDate: "0000-00-00"
      animeUserEndDate: "0000-00-00"
      animeUserStatus: "6" # Ptw
      animeScore:"0"
      animeUserRewatching: ""
      animeUserRewatchingEp: ""
      animeLastUpdated: moment().valueOf()
      animeUserTags: ""
    entry

  createAddedMangaEntry: (id) ->
    entry =
      mal_id: id
      mangaUserReadChapters: "0"
      mangaUserReadVolumes: "0"
      mangaScore:"0"
      mangaUserStatus: "6" #Ptr
      animeUserStartDate: "0000-00-00"
      animeUserEndDate: "0000-00-00"
      mangaUserRereading: ""
      mangaUserRereadingChapter: ""
      mangaLastUpdated: moment().valueOf()
      mangaTags: ""

    entry
  #
  #
  #
  buildAnimeXmlForUpdating: (animeEntry) ->
    entry =
      entry:
        episode: animeEntry.animeWatchedEpisodes
        status: animeEntry.animeUserStatus
        score: animeEntry.animeScore
        storage_type: ""
        storage_value: ""
        times_rewatched: ""
        rewatch_value:""
        date_start: ""
        date_finish: ""
        priority: ""
        enable_discussion: ""
        enable_rewatching:""
        comments:""
        fansub_group: ""
        tags:""

    builder = new xml2js.Builder()
    buildXml = builder.buildObject(entry)
    buildXml

  #
  #
  #
  buildMangaXmlForUpdating: (mangaEntry) ->
    entry =
      entry:
        volume: mangaEntry.mangaUserReadVolumes
        chapter: mangaEntry.mangaUserReadChapters
        status: mangaEntry.mangaUserStatus
        score: mangaEntry.mangaScore
        reread_value:""
        date_start: ""
        date_finish: ""
        priority: ""
        enable_discussion: ""
        enable_rereading:""
        comments:""
        scan_group: ""
        retail_volumes: ""
        tags:""

    builder = new xml2js.Builder()
    buildXml = builder.buildObject(entry)
    buildXml


  #
  #
  #
  createViewMangaExtra: ->
    mangaExtraView =
      name: "myanimelist_mangaextra"
      owner: @name
      displayName: 'subview'
      displayType: 'subview'
      noUpdate: true
      subview:{}

    @chiika.viewManager.addView mangaExtraView

  #
  #
  #
  createViewAnimelist: () ->
    defaultView = {
      name: 'myanimelist_animelist',
      displayName: 'Anime List',
      displayType: 'TabGridView',
      owner: @name, #Script name, the updates for this view will always be called at 'owner'
      category: 'MyAnimelist',
      TabGridView: {
        sortBy: 'animeTitle',
        sortingPrefCol: 'animeTitle',
        sortingPrefDir: 'asc',
        lastTabIndex: 0,
        tabList: [
          { name:'al_watching', display: 'Watching' },
          { name:'al_completed', display: 'Completed'},
          { name:'al_onhold', display: 'On Hold'},
          { name:'al_dropped', display: 'Dropped'},
          { name:'al_ptw', display: 'Plan to Watch'}
          ],
        gridColumnList: [
          { name: 'animeTypeText',display: 'Type', sort: 'int', css: 'grid-40'},
          { name: 'animeTitle',display: 'Title', sort: 'str',css: 'grid-title'},
          { name: 'animeProgress',display: 'Progress', sort: 'float', css: 'grid-progress'},
          { name: 'animeScoreText',display: 'Score', sort: 'int', css: 'grid-80'},
          { name: 'animeScoreAverage',display: 'Avg Score', sort: 'float',css: 'grid-80'},
          { name: 'animeSeasonText',display: 'Season', sort: 'date', css: 'grid-160'},
          { name: 'animeSeriesStatusText',display: 'Airing Status', sort: 'int', css: 'grid-160'},
          { name: 'animeLastUpdatedText',display: 'Last Updated', sort: 'int', css: 'grid-160'}
        ]
      }
     }
    historyView =
      name: 'myanimelist_animelist_history'
      owner: @name
      displayName: 'AnimeList History'
      displayType: 'none'
      noUpdate: true

    @chiika.viewManager.addView defaultView
    @chiika.viewManager.addView historyView




  #
  #
  #
  createViewMangalist: () ->
    defaultView = {
      name: 'myanimelist_mangalist',
      displayName: 'Manga List',
      displayType: 'TabGridView',
      owner: @name, #Script name, the updates for this view will always be called at 'owner'
      category: 'MyAnimelist',
      TabGridView: { #Must be the same name with displayType
        sortingPrefCol: 'mangaTitle',
        sortingPrefDir: 'asc',
        lastTabIndex: 0,
        tabList: [
          { name:'ml_reading', display: 'Reading' },
          { name:'ml_completed', display: 'Completed'},
          { name:'ml_onhold', display: 'On Hold'},
          { name:'ml_dropped', display: 'Dropped'},
          { name:'ml_ptr', display: 'Plan to Read'}
          ],
        gridColumnList: [
          { name: 'mangaTitle',display: 'Title', sort: 'str',css: 'grid-title'},
          { name: 'mangaProgress',display: 'Progress', sort: 'int', css: 'grid-progress'},
          { name: 'mangaScore',display: 'Score', sort: 'int', css: 'grid-80'},
          { name: 'mangaScoreAverage',display: 'Avg Score', sort: 'int', css: 'grid-80'},
          { name: 'mangaLastUpdatedText',display: 'Last Updated', sort: 'int', css: 'grid-160'}
        ]
      }
     }
    historyView =
      name: 'myanimelist_mangalist_history'
      owner: @name
      displayName: 'MangaList History'
      displayType: 'none'
      noUpdate: true

    @chiika.viewManager.addView defaultView
    @chiika.viewManager.addView historyView

  importHistoryFromMAL: (type,callback) ->
    userHistoryUrl = "http://myanimelist.net/history/#{@malUser.realUserName}/#{type}"

    historyView = @chiika.viewManager.getViewByName("myanimelist_#{type}list_history")

    if type == 'anime'
      animeIdPlusTitleRegex = /<td class="borderClass"\s><a href="\/anime.php\?id=(.*)">(.*)<\/a> ep.\s<strong>(.*)<\/strong>/g
      dateRegex = /<td class="borderClass"\s\salign="right">\s(.*)<\/td>/g
    else
      animeIdPlusTitleRegex = /<td class="borderClass"\s><a href="\/manga.php\?id=(.*)">(.*)<\/a> chap.\s<strong>(.*)<\/strong>/g
      dateRegex = /<td class="borderClass"\s\salign="right">\s(.*)<\/td>/g

    onRequestReturn = (error,response,body) =>
      idTitleMap = []

      while idtitleMatch = animeIdPlusTitleRegex.exec body
        id = idtitleMatch[1]
        title = idtitleMatch[2]
        ep = idtitleMatch[3]

        if type == 'anime'
          idTitleMap.push { id: id, title: title,ep: ep }
        else
          idTitleMap.push { id: id, title: title,chapter: ep }

      counter = 0
      while dateMatch = dateRegex.exec body
        date = dateMatch[1]

        idTitleMap[counter].updated = date
        counter++


      historyData = []
      counter = 0
      _forEach idTitleMap, (history) =>
        time = history.updated
        momentDate = {}
        # Do some tests
        indexOfMinutes = time.indexOf 'minutes ago'
        indexOfHours = time.indexOf 'hours ago'
        indexOfYesterday = time.indexOf 'Yesterday'
        indexOfSpace = time.indexOf ' '
        indexOfComma = time.indexOf ','
        indexOfColon = time.indexOf ':'

        if indexOfMinutes >= 0
          digitCount = indexOfSpace

          minute = time.substring(0,digitCount)
          momentDate = moment().subtract(parseInt(minute),'minutes')


        if indexOfHours >= 0
          digitCount = indexOfSpace

          hour = time.substring(0,digitCount)
          momentDate = moment().subtract(parseInt(hour),'hours')

        if indexOfYesterday >= 0
          hourDigitCount = indexOfColon - (indexOfComma + 1)
          hour  = time.substring(indexOfComma + 1,indexOfComma + 1 + hourDigitCount)
          minute = time.substring( indexOfColon + 1, indexOfColon + 1 + 2)
          momentDate = moment().subtract(1,'days')
          momentDate.set('hour',parseInt(hour))
          momentDate.set('minute',parseInt(minute))

        if indexOfMinutes == -1 && indexOfHours == -1 && indexOfYesterday == -1
          digits       = indexOfComma - indexOfSpace - 1
          month = time.substring(0,indexOfSpace)
          day = time.substring(indexOfSpace + 1,indexOfSpace+digits+1)

          hourDigitCount = indexOfColon - (indexOfComma + 1)
          hour  = time.substring(indexOfComma + 1,indexOfComma + 1 + hourDigitCount)
          minute = time.substring( indexOfColon + 1, indexOfColon + 1 + 2)

          momentDate = moment("#{moment().year()} #{month} #{day} #{hour} #{minute}",'YYYY MMM DD HH mm')
        if momentDate.isValid()
          if historyView?
            if type == 'anime'
              historyItem =
                history_id: counter
                updated: momentDate.valueOf()
                mal_id: history.id
                owner: 'myanimelist'
                episode: history.ep
            else
              historyItem =
                history_id: counter
                updated: momentDate.valueOf()
                mal_id: history.id
                owner: 'myanimelist'
                chapters: history.chapter
            historyData.push historyItem
            counter++
      historyView.clear().then =>
        if historyData.length == 0
          callback()
          return
        historyView.setDataArray(historyData).then(callback)




    @chiika.makeGetRequest userHistoryUrl,null,onRequestReturn

  importHistoryFromTaiga: ->
    # Optional - Win Only - Import Taiga history
    # Path : %AppData%/Taiga/user/userName@service/history.xml
    historyFile = path.join process.env.CHIIKA_APPDATA, 'Taiga', 'data','user',"#{@malUser.realUserName}@myanimelist",'history.xml'

    if @chiika.utility.fileExists historyFile
      historyData = @chiika.utility.readFileSync historyFile

      indexOfHistoryElement = historyData.indexOf('<history>')
      historyData =  historyData.substring(indexOfHistoryElement,historyData.length)

      @chiika.parser.parseXml(historyData).then (result) =>
        historyXml  = result
        _forEach historyXml.history.items.item, (item) =>
          convertToMoment = moment(item.time)

          if convertToMoment.isValid()
            id = item.anime_id
            episode = item.episode
            time = convertToMoment.valueOf()

            historyView = @chiika.viewManager.getViewByName('myanimelist_animelist_history')

            if historyView?
              historyData = historyView.getData()

              historyItem =
                history_id: historyData.length
                updated: time
                mal_id: id
                owner: 'myanimelist'
                episode: episode
              historyView.setData( historyItem, 'updated')
