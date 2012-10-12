root = window.mit ?= {}

############### SYNC ##############
root.JSONPSync = (method, model, options) ->
    options.dataType = "jsonp"
    return Backbone.sync(method, model, options)
############### MODELS ##############

class root.MiscModel extends Backbone.Model
class root.Agenda extends Backbone.Model
class root.Member extends Backbone.Model
    defaults:
        score: 'N/A'
class root.MemberAgenda extends Backbone.Model
    urlRoot: "http://api.dev.oknesset.org/api/v2/member-agendas/"
    sync: root.JSONPSync

############### COLLECTIONS ##############

class root.LocalVarCollection extends Backbone.Collection
    initialize: (models, options) ->
        if options?.localObject
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
                model: root.MiscModel
                url: "http://api.dev.oknesset.org/api/v2/agenda/"
                localObject: window.mit.agendas
            )
            itemView: class extends root.ListViewItem
                render : ->
                    super()
                    @.$('.slider').slider
                        value : 50
                    @
                get_template: ->
                    $("#agenda_template").html()
        @$(".agendas").append(@agendaListView.$el)
        @agendaListView.$el.bind('change', @agendaChange)
        @$("input:button").click(@calculate)

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

        @memberListView = new root.ListView
            collection: @filteredMemberList
            itemView: root.MemberView
            autofetch: false
        @$(".members").empty().append(@memberListView.$el)
        @memberListView.options.collection.trigger "reset"

    calculate: =>
        @$(".members_container").hide()
        console.log "Calculate: ", this, arguments
        agendasInput = {}
        @agendaListView.collection.each (agenda) =>
            agendasInput[agenda.get('id')] = agenda.view.$('input:checked').val() || 0
        console.log "Agendas input: ", agendasInput
        calcs = []
        @memberListView.collection.each (member) =>
            calcs.push @calcOneAsync member, agendasInput
        console.log "Waiting for " + calcs.length + " member agendas"
        $.when(calcs...).done =>
            console.log "Got results!", this, arguments
            @filteredMemberList.sort()
            @$(".members_container").show()
        .fail =>
            console.log "Error getting results!", this, arguments

    calcOneAsync: (member, agendasInput) ->
        calcOne = () ->
            member.set 'score', _.reduce member.get('agendas'), (memo, agenda) ->
                memo += agendasInput[agenda.id] * agenda.score
            , 0

        if member.get 'agendas'
            console.log 'Already got agendas for ' + member.get 'id'
            calcOne()
            return $.Deferred().resolve()

        memberAgendas = new root.MemberAgenda
            id: member.get 'id'
        memberAgendas.fetch
            success: ->
                member.set 'agendas', memberAgendas.get('agendas')
                calcOne()


############### INIT ##############

$ ->
    root.appView = new root.AppView
    return
