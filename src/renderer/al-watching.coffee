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

React = require('react')
{Router,Route,BrowserHistory,Link} = require('react-router')

Mixin = require './al-mixin'
{Table,Tr,Td} = require 'reactable'


#Views

WatchingList = React.createClass
  mixins: [Mixin],
  componentWillMount: ->
    @name = "watching"
  componentDidMount: ->
    if !window.chiika.isWaiting
      @setGrid()
  componentWillUnmount: () ->
    window.chiika.domManager.destroyGrid 'watching'
  render: () ->
    (<div id="watching" className="listCommon"></div>)

module.exports = WatchingList