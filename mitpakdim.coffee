root = window.mit ?= {}

############### JQUERY UI EXTENSIONS ##############

$.widget "mit.agendaSlider", $.extend({}, $.ui.slider.prototype, {
    _create : (->
            cached_old_slider_create = $.ui.slider::_create
            new_create_func = ->
                @element.append '<div class="ui-slider-mid-marker"></div>'
                cached_old_slider_create.apply @
            new_create_func
        )()
    setMemberMarker : (value) ->
        member_marker_classname = "ui-slider-member-marker"
        if not @element.find(".#{member_marker_classname}").length
            handle = @element.find(".ui-slider-handle")
            handle.before "<div class='#{member_marker_classname}'></div>"
        @element.find(".#{member_marker_classname}").css
            left : value + "%"
})

############### SYNC ##############
root.JSONPSync = (method, model, options) ->
    options.dataType = "jsonp"
    return Backbone.sync(method, model, options)
############### MODELS ##############

class root.MiscModel extends Backbone.Model
class root.Agenda extends Backbone.Model
    defaults:
        uservalue: 0
class root.Member extends Backbone.Model
    defaults:
        score: 'N/A'

    class MemberAgenda extends Backbone.Model
        urlRoot: "http://api.dev.oknesset.org/api/v2/member-agendas/"
        sync: root.JSONPSync

    fetchAgendas: (force) ->
        if @agendas_fetching.state() != "resolved" or force
            @memberAgendas = new MemberAgenda
                id: @get 'id'
            @memberAgendas.fetch
                success: =>
                    @agendas_fetching.resolve()
                error: =>
                    console.log "Error fetching member agendas", @, arguments
                    @agendas_fetching.reject()

        return @agendas_fetching

    getAgendas: ->
        if @agendas_fetching.state() != "resolved"
            console.log "Trying to use member agendas before fetched", @, @agendas_fetching
            throw "Agendas not fetched yet!"
        @memberAgendas.get('agendas')

    initialize: ->
        @agendas_fetching = $.Deferred()


############### COLLECTIONS ##############

class root.LocalVarCollection extends Backbone.Collection
    initialize: (models, options) ->
        if options?.localObject
            console.log "Using local objects for ", this
            @localObject = options.localObject
        if options?.url
            @url = options.url
    sync: (method, model, options) =>
        if @localObject == undefined
            return @syncFunc arguments...

        setTimeout =>
            options.success @localObject, null # xhr
        return

    syncFunc: Backbone.sync

    parse: (response) ->
        return response.objects

class root.JSONPCollection extends root.LocalVarCollection
    syncFunc: root.JSONPSync

class root.MemberList extends root.JSONPCollection
    model: root.Member
    localObject: window.mit.members
    url: "http://api.dev.oknesset.org/api/v2/member/"
    fetchAgendas: ->
        fetches = []
        @each (member) =>
            fetches.push member.fetchAgendas()
        console.log "Waiting for " + fetches.length + " member agendas"
        @agendas_fetching = $.when(fetches...)
        .done =>
            console.log "Got results!", this, arguments
        .fail =>
            console.log "Error getting results!", this, arguments

############### VIEWS ##############

class root.TemplateView extends Backbone.View
    template: ->
        _.template( @get_template() )(arguments...)
    render: =>
        @$el.html( @template(@model.toJSON()) )
        @

class root.MemberView extends root.TemplateView
    className: "member_instance"
    get_template: ->
        $("#member_template").html()

class root.ListViewItem extends root.TemplateView
    tagName: "div"
    get_template: ->
        "<a href='#'><%= name %></a>"

class root.ListView extends root.TemplateView
    initialize: =>
        root.TemplateView.prototype.initialize.apply(this, arguments)
        @options.itemView ?= root.ListViewItem
        @options.autofetch ?= true
        if @options.collection
            @options.collection.bind "add", @addOne
            @options.collection.bind "reset", @addAll
            if @options.autofetch
                @options.collection.fetch()
    addOne: (modelInstance) =>
        view = new @options.itemView({ model:modelInstance })
        modelInstance.view = view
        @$el.append view.render().$el

    addAll: =>
        @initEmptyView()
        @options.collection.each(@addOne)
    initEmptyView: =>
        @$el.empty()

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
    initEmptyView: =>
        @$el.html("<option>-----</option>")

class root.AppView extends Backbone.View
    el: '#app_root'
    initialize: =>
        @memberList = new root.MemberList
        @memberList.fetch()
        @partyListView = new root.DropdownContainer
            collection: new root.JSONPCollection(null,
                model: root.MiscModel
                url: "http://api.dev.oknesset.org/api/v2/party/"
                localObject: window.mit.parties
            )
        @$(".parties").append(@partyListView.$el)
        @partyListView.$el.bind('change', @partyChange)

        @agendaListView = new root.ListView
            collection: new root.JSONPCollection(null,
                model: root.Agenda
                localObject: window.mit.agendas
                url: "http://api.dev.oknesset.org/api/v2/agenda/"
            )
            itemView: class extends root.ListViewItem
                className : "agenda_item"
                render : ->
                    super()
                    @.$('.slider').agendaSlider
                        min : -100
                        max : 100
                        value : @model.get "uservalue"
                        stop : @onStop
                    @
                onStop : (event, ui) =>
                    @model.set
                        uservalue : ui.value

                get_template: ->
                    $("#agenda_template").html()
        @agendaListView.collection.on 'change', =>
            console.log "Model changed", arguments
            if @recalc_timeout
                clearTimeout @recalc_timeout
            recalc_timeout = setTimeout =>
                @recalc_timeout = null
                @calculate()
            , 100
        @$(".agendas").append(@agendaListView.$el)
        @agendaListView.$el.bind('change', @agendaChange)

    partyChange: =>
        console.log "Changed: ", this, arguments
        @partyListView.options.selected = @partyListView.$('option:selected').text()
        @$('.agendas_container').show()
        @reevaluateMembers()

    reevaluateMembers: =>
        @filteredMemberList = new root.MemberList (@memberList.filter (object) =>
            object.get('party_name') == @partyListView.options.selected
        ),
            comparator: (member) ->
                return -member.get 'score'

        @filteredMemberList.fetchAgendas()

        @memberListView = new root.ListView
            collection: @filteredMemberList
            itemView: root.MemberView
            autofetch: false
        @$(".members").empty().append(@memberListView.$el)
        @memberListView.options.collection.trigger "reset"

    calculate: ->
        if not @filteredMemberList.agendas_fetching
            throw "Agenda data not present yet"
        @filteredMemberList.agendas_fetching.done =>
            @calculate_inner()
            @filteredMemberList.sort()

    calculate_inner: ->
        console.log "Calculate: ", this, arguments
        agendasInput = {}
        agendasSum = 0
        @agendaListView.collection.each (agenda) =>
            uservalue = agenda.get("uservalue")
            agendasInput[agenda.get('id')] = uservalue
            agendasSum += Math.abs(uservalue)

        console.log "Agendas input: ", agendasInput
        @memberListView.collection.each (member) =>
            member.set 'score', _.reduce member.getAgendas(), (memo, agenda) ->
                memo += agendasInput[agenda.id] * agenda.score / agendasSum
            , 0

############### INIT ##############

$ ->
    root.appView = new root.AppView
    return
