root = window.mit ?= {}

############### MODELS ##############

class root.MiscModel extends Backbone.Model
class root.Agenda extends Backbone.Model
class root.Member extends Backbone.Model

############### COLLECTIONS ##############

class root.JSONPCollection extends Backbone.Collection
    initialize: (options) ->
        if options?.url
            @url = options.url
    sync: (method, model, options) ->
        options.dataType = "jsonp"
        return Backbone.sync(method, model, options)
    parse: (response) ->
        return response.objects

class root.MemberList extends root.JSONPCollection
    model: root.Member
    url: "http://api.dev.oknesset.org/api/v2/member/?format=jsonp"

############### VIEWS ##############

class root.TemplateView extends Backbone.View
    className: "member_instance"
    render: =>
        @$el.html( @template(@model.toJSON()) )
        @

class root.MemberView extends root.TemplateView
    template: ->
        _.template( $("#member_template").html() )(arguments...)

class root.ListView extends root.TemplateView
    initialize: =>
        if @options.collection
            @options.collection.bind "add", @addOne
            @options.collection.bind "reset", @addAll
            @options.collection.fetch()
    addOne: (modelInstance) =>
        view = new @options.itemView({ model:modelInstance })
        @$el.append view.render().$el

    addAll: =>
        @options.collection.each(@addOne)

class root.DropdownItem extends root.TemplateView
    tagName: "option"
    render: =>
        json = @model.toJSON()
        @$el.html( json.name )
        @$el.attr({ value: json.id })
        @

class root.DropdownContainer extends root.ListView
    tagName: "select"
    initialize: =>
        @options.itemView = root.DropdownItem
        root.ListView.prototype.initialize.apply this, arguments

class root.AppView extends Backbone.View
    el: '#app_root'
    initialize: =>
        @memberList = new root.MemberList()
        @memberList.bind "add", @addOne
        @memberList.bind "reset", @addAll
        @memberList.fetch()
        @partyList = new root.DropdownContainer({collection: new root.JSONPCollection({
            model: root.MiscModel,
            url: "http://api.dev.oknesset.org/api/v2/party/?format=jsonp"
        })})
        @$(".parties").append(@partyList.$el)
        @partyList.$el.bind('change', @partyChange)

    addOne: (member) =>
        view = new root.MemberView({ model:member })
        @$(".members").append view.render().$el

    addAll: =>
        @memberList.each(@addOne)

    partyChange: =>
        console.log "Changed: ", this, arguments

############### INIT ##############

$ ->
    root.appView = new root.AppView
    return
