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
#Date: 24.1.2016
#authors: arkenthera
#Description:
#----------------------------------------------------------------------------
React = require 'react'
cn = require './../../../ChiikaNode'
Mixin = require './Common'


#Dropped List
OnHoldList = React.createClass
  mixins:[Mixin]
  componentDidMount: ->
    list = chiika.chiika.getAnimeListByUserStatus(3)
    @setGridName("gridOnHoldList")
    @setList(list)
    @addColumns()
    $("#gridOnHoldList").w2grid(@getGrid())

  componentWillUnmount: ->
    $('#gridOnHoldList').w2destroy()
  refreshDataSource: ->
    list = chiika.chiika.getAnimeListByUserStatus(3)
    @setList(list)
    w2ui["gridOnHoldList"].records = list
  render: () ->
    (<div id="gridOnHoldList" className="listCommon"></div>);

module.exports = OnHoldList