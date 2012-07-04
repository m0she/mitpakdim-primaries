root = window.mit ?= {}
class root.Agenda extends Backbone.Model
class root.Member extends Backbone.Model
class root.MemberList extends Backbone.Collection
    model: root.Member
    url: "http://api.dev.oknesset.org/api/v2/member/?format=jsonp"
    sync: (method, model, options) ->
        options.dataType = "jsonp"
        return Backbone.sync(method, model, options)
    parse: (response) ->
        return response.objects

class root.MemberView extends Backbone.View
    template: ->
        _.template( $("#member_template").html() )(arguments...)
    render: =>
        console.log "t: ", @template(@model.toJSON()), "el:", @$el
        @$el.html( @template(@model.toJSON()) )
        console.log "z: ", @, "z html", @$el.html()
        @

class root.AppView extends Backbone.View
    el: '#app_root'
    initialize: =>
        @memberList = new root.MemberList()
        @memberList.bind "add", @addOne
        @memberList.bind "reset", @addAll
        @memberList.fetch()

    addOne: (member) =>
        console.log 'Adding', member
        view = new root.MemberView({ model:member })
        @$(".members").append view.render().$el

    addAll: =>
        @memberList.each(@addOne)

$ ->
    root.appView = new root.AppView
    return
