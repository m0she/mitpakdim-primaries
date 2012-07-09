root = window.mit ?= {}

############### MODELS ##############

class root.MiscModel extends Backbone.Model
class root.Agenda extends Backbone.Model
class root.Member extends Backbone.Model

############### COLLECTIONS ##############

class root.JSONCollection extends Backbone.Collection
    initialize: (options) ->
        if options?.url
            @url = options.url
    parse: (response) ->
        return response.objects

class root.JSONPCollection extends root.JSONCollection
    sync: (method, model, options) ->
        options.dataType = "jsonp"
        return Backbone.sync(method, model, options)

class root.LocalVarCollection extends root.JSONCollection
    initialize: (options) ->
        if options?.localObject
            @localObject = options.localObject
    sync: (method, model, options) ->
        setTimeout =>
            options.success @localObject, null # xhr
        return

class root.MemberList extends root.JSONPCollection
    model: root.Member
    url: "http://api.dev.oknesset.org/api/v2/member/?format=jsonp"

############### VIEWS ##############

class root.TemplateView extends Backbone.View
    render: =>
        @$el.html( @template(@model.toJSON()) )
        @

class root.MemberView extends root.TemplateView
    className: "member_instance"
    template: ->
        _.template( $("#member_template").html() )(arguments...)

class root.ListViewItem extends root.TemplateView
    tagName: "div"
    template: ->
        _.template("<a href='#'><%= name %></a>")(arguments...)

class root.ListView extends root.TemplateView
    initialize: =>
        @options.itemView ?= root.ListViewItem
        if @options.collection
            @options.collection.bind "add", @addOne
            @options.collection.bind "reset", @addAll
            @options.collection.fetch()
    addOne: (modelInstance) =>
        view = new @options.itemView({ model:modelInstance })
        @$el.append view.render().$el

    addAll: =>
        @options.collection.each(@addOne)

class root.DropdownItem extends Backbone.View
    tagName: "option"
    render: =>
        json = @model.toJSON()
        @$el.html( json.name )
        @$el.attr({ value: json.id })
        @

class root.DropdownContainer extends root.ListView
    tagName: "select"
    options:
        itemView: root.DropdownItem

class root.AppView extends Backbone.View
    el: '#app_root'
    initialize: =>
        @memberList = new root.ListView
            collection: new root.MemberList
            itemView: root.MemberView
        @$(".members").append(@memberList.$el)

        @partyList = new root.DropdownContainer
            collection: new root.JSONPCollection
                model: root.MiscModel
                url: "http://api.dev.oknesset.org/api/v2/party/?format=jsonp"
        @$(".parties").append(@partyList.$el)
        @partyList.$el.bind('change', @partyChange)

        @agendaList = new root.ListView
            collection: new root.LocalVarCollection
                model: root.MiscModel
                url: "data/agendas.jsonp" # not used yet
                localObject: window.mit_agendas
        @$(".agendas").append(@agendaList.$el)
        @agendaList.$el.bind('change', @agendaChange)

    partyChange: =>
        console.log "Changed: ", this, arguments

############### INIT ##############

$ ->
    root.appView = new root.AppView
    return
