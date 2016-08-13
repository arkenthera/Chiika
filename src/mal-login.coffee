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
ReactDOM                            = require("react-dom")
{Router,Route,BrowserHistory,Link}  = require('react-router')

{electron,ipcRenderer,remote}       = require 'electron'

IPC                                 = require '../chiika-ipc'
LoadingScreen                       = require '../loading-screen'

_                                   = require 'lodash'
string                              = require 'string'

#Views


window.$ = window.jQuery            = require('jquery')

MalLogin = React.createClass
  getInitialState: ->
    services: []
    loggingInTo: null
  componentDidMount: ->
    window.chiika = this

    @logger = remote.getGlobal('logger')

    fullpage = require('fullpage.js')

    $("#fullpage").fullpage()

    @ipcManager = new IPC()

    window.ipcManager = @ipcManager

    #
    # For testing
    #
    @ipcManager.receive 'spectron-set-login', (event,args) =>
      console.log "Receiving spectron-set-login"
      console.log args
      $("#userName").val(args.params.userName)
      $("#password").val(args.params.password)
    #
    #
    #


    @ipcManager.sendReceiveIPC 'get-services',null,(event,defer,args) =>
      if args?
        console.log args
        @setState { services: args,loggingTo: args[0] }




    # #This callback only gets called if error on login
    ipcRenderer.on 'login-response',(event,response) =>
      @setContinueState(false)

      if !response.success
        message = "We couldn't login you with the selected service!"
        window.yuiToast(message,'top',5000,'dark')
        console.log response

        @highlightElement("red","userName")
        @highlightElement("red","password")
      else
        console.log response
        @highlightElement("green","userName")
        @highlightElement("green","password")
    #
    #
    # ipcRenderer.on 'inform-login-response', (event,response) =>
    #   console.log response
    #   if response.status
    #     $("#authPin-#{response.owner}").val(response.authPin)
    #
    #     $("#gotoBtn-#{response.owner}").hide()
    #     $("#verifyBtn-#{response.owner}").show()
    #   else
    #     @highlightFormByParent("red","#authPin-#{response.owner}")
    #
    #   $("#continue").prop("disabled",false)
    #
    # ipcRenderer.on 'inform-login-set-form-value', (event,response) =>
    #   parent = "#loginForm-#{response.owner} "
    #   $(parent + "##{response.target}").val(response.value)
    #   console.log response

  highlightElement: (color,element) ->
    e = $("##{element}")

    if color == 'clear'
      e.css({ "border": "1px solid rgba(0,0,0,0.2)"})
      e.removeClass("highlightred")
      e.removeClass("highlightgreen")
    else
      #Fix this
      e.css({ "border": "#{color} 1px solid"})

      if color == "red"
        e.addClass("highlightred")
      else if color == "green"
        e.addClass("highlightgreen")

  setContinueState: (state) ->
    if state
      $("#continue").addClass("is-disabled")
      $("#continue").prop("disabled",state)
    else
      delay = ->
        $("#continue").prop("disabled",state)
        $("#continue").removeClass("is-disabled")
      setTimeout(delay,2000)

  componentDidUpdate: ->
    $("#loginForm")
    .submit( (e) =>
      e.preventDefault()
      false
      )

  onSubmit: (e) ->
    user = $("#userName").val()
    pass = $("#password").val()


    if _.isEmpty user
      #Do something here
      @highlightElement('red','userName')
    else
      @highlightElement('clear','userName')

    if _.isEmpty pass
      @highlightElement('red','password')
    else
      @highlightElement('clear','password')

    if (user != "" && pass != "")
      loginData = { user: user, pass: pass }
      console.log loginData
      ipcRenderer.send 'set-user-login',{ login: loginData, service: @state.loggingTo.name }
      @setContinueState(true)




  onSubmitAuthPin: (e) ->
    id = $(e.target).parent().attr("id")
    serviceName = string(id).chompLeft('loginForm-').s
    ipcRenderer.send 'set-user-auth-pin',{ service: serviceName }

    $("#continue").prop('disabled',true)

  onSubmitAuthPinStep2: (e) ->
    id = $(e.target).parent().attr("id")
    parent = "#" + $(e.target).parent().attr('id') + " "
    serviceName = string(id).chompLeft('loginForm-').s
    authPin = $("#authPin-#{serviceName}").val()
    user = $(parent + "#userName").val()

    ipcRenderer.send 'set-user-login',{ authPin: authPin, service: serviceName, user: user }

    $("#continue").prop('disabled',true)

  continueToApp: (e) ->
    @ipcManager.sendMessage 'call-window-method','close'
    @ipcManager.sendMessage 'continue-from-login'


  loginBody: (key,service) ->
    (<div className="card" id="login-container" key=key>
        <img src={service.logo} id="mal-logo" style={{width: 200 , height: 200}} alt="" />
        <form className="" id="loginForm">
          <label htmlFor="log-usr">Username</label>
          <input type="text" className="text-input" id="userName" required autofocus/>
          <label htmlFor="log-psw">Password</label>
          <input type="Password" className="text-input" id="password" required />
          <input type="submit" onClick={this.onSubmit} className="button raised indigo log-btn" id="log-btn" value="Verify"/>
        </form>
      </div>)
  authPinBody: (key,service) ->
    (<div className="card" id="login-container" key=key>
        <img src={service.logo} id="mal-logo" style={{width: 200 , height: 200}} alt="" />
        <form className="" id="loginForm-#{service.name}">
        <label htmlFor="log-usr" id="usrnmlbl">User Name</label>
        <input type="text" className="text-input" id="userName" placeholder="Will be automatically replaced. If not, type your display name" required autofocus/>
          <label htmlFor="log-usr">Auth Pin</label>
          <input type="text" className="text-input" id="authPin-#{service.name}" required autofocus disabled placeholder="Will be automatically replaced"/>
          <input type="submit" onClick={this.onSubmitAuthPin} className="button raised indigo log-btn" id="gotoBtn-#{service.name}" value="Go to #{service.description}"/>
          <input type="submit" onClick={this.onSubmitAuthPinStep2} className="button raised indigo log-btn" id="verifyBtn-#{service.name}" value="Verify"/>
        </form>
      </div>)
  render: () ->
    <div className="login-body-outer">
      <div id="fullpage">
        <div className="section">
          <span className="divider left"></span>
          <span className="divider right"></span>
          <h1>Welcome To Chiika</h1>
          <span className="nextPage"></span>
        </div>
        <div className="section">
        <h1>Please Select a Service Provider</h1>
          <div className="serviceProviders">
            <div className="provider">
              <img src="icon.png" width="140" height="140" alt="" />
              <h2>Myanimelist</h2>
            </div>
          </div>
        </div>
        <div className="section">
          <div id="login-container">
            <form className="" id="loginForm">
              <img src="icon.png" width="250" height="250" alt="" />
              <label htmlFor="log-usr">Username</label>
              <input type="text" className="text-input light" id="userName" required autofocus/>
              <label htmlFor="log-psw">Password</label>
              <input type="Password" className="text-input light" id="password" required />
              <input type="submit" onClick={this.onSubmit} className="button raised indigo log-btn" id="log-btn" value="Verify" />
            </form>
          </div>
        </div>
      </div>
    </div>


ReactDOM.render(React.createElement(MalLogin), document.getElementById('app'))
