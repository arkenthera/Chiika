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

React                               = require('react')
{Router,Route,BrowserHistory}       = require('react-router')

Modal                               = require 'react-modal'

SideMenu                            = require './side-menu'
Titlebar                            = require './titlebar'
Settings                            = require './settings'
LoadingScreen                       = require './loading-screen'
Home                                = require './home'
HistoryComponent                    = require './history'
SearchComponent                     = require './search'

TabGridView = require './view-tabGrid'
CardView = require './card-view'
DetailsCardView = require './card-view-details'

SettingsComponent = React.createClass
  getInitialState: ->
    modalOpen: false
    openModalName: ''

  openModal: (name) ->
    @setState { modalOpen: true, openModalName: name }

  closeModal: ->
    @setState { modalOpen: false }

  componentWillReceiveProps: (props) ->
    if props.props.location.query.settings
      @openModal('settings')
  render: ->
    <div>
      <Modal isOpen={@state.modalOpen}
      onRequestClose={this.closeModal}
      shouldCloseOnOverlayClick=true
      className="react-modal-content"
      overlayClassName="react-modal-overlay"
      >
      <Settings {...@props} />
      </Modal>
    </div>

Content = React.createClass
  render: () ->
    (<div className="main">
      <div id="titleBar">
        <Titlebar />
      </div>
      <div className="content">
        {this.props.props.children}
      </div>
      <div id="modal-stuff">
        <SettingsComponent {...this.props} />
      </div>
    </div>)

RouterContainer = React.createClass
  render: ->
    <div id="appMain"><SideMenu props={this.props} /><Content props={this.props}/></div>


ChiikaRouter = React.createClass
  routes: []
  currentRouteName: null
  getInitialState: ->
    test: false
    uiData: chiika.uiData
    routerConfig: @getRoutes(chiika.uiData)

  getRoutes: (uiData) ->
    routes = []
    uiData.map (route,i) =>
      if route?
        if route.type == "side-menu-item" && route.displayType == "TabGridView"
          routes.push {
          name: "/#{route.name}"
          path: "/#{route.name}"
          component:require(chiika.viewManager.getComponent(route.displayType))
          viewName: route.name
          onEnter: @onEnter}
          routes.push {
          name: "/#{route.name}_details"
          path: "/#{route.name}_details/:id"
          component:DetailsCardView
          viewName: route.name
          owner: route.owner
          onEnter: @onEnter}



    routerConfig = {
        component: RouterContainer,
        childRoutes: [
          { name:'Home', path: '/Home', component: Home, onEnter: @onEnter },
          { name:'Details', path: '/details/:id', component: DetailsCardView, onEnter: @onEnter }
          { name:'Settings', path: '/Settings', component: SettingsComponent, onEnter: @onEnter }
          { name:'History', path: '/History', component: HistoryComponent, onEnter: @onEnter }
          { name:'Search', path: '/Search/:searchString', component: SearchComponent, onEnter: @onEnter }
        ]
    }

    for route in routes
      routerConfig.childRoutes.push route
    routerConfig

  onEnter:(nextState) ->
    path = nextState.routes[1].name
    routerConfig = @state.routerConfig

    @currentRouteName = nextState.location.pathname
    # For testing purposes
    # We will get the current route from title when running tests
    document.title = @currentRouteName.replace('/','')



  render: () ->
    (<Router history={BrowserHistory} routes={@state.routerConfig}/>)

module.exports = ChiikaRouter
