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

class root.AppView extends Backbone.View
    initialize: =>
        @memberList = new root.MemberList()
        @memberList.bind "add", @addOne
        @memberList.bind "reset", @addAll

    addOne: (member) =>
        view = new MemberView(member)
        @$(".members").append view.render().el

    addAll: =>
        @memberList.each(@addOne)

$ ->
    root.appView = new root.Appview
