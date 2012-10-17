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

root.syncEx = (options_override) ->
    (method, model, options) ->
        Backbone.sync(method, model, _.extend({}, options, options_override))

root.JSONPSync = root.syncEx({dataType: 'jsonp'})
root.JSONPCachableSync = (callback_name) ->
    root.syncEx
        cache: true
        dataType: 'jsonp'
        jsonpCallback: callback_name or 'cachable'
############### MODELS ##############

class root.MiscModel extends Backbone.Model
class root.Agenda extends Backbone.Model
    defaults:
        uservalue: 0

class root.Candidate extends Backbone.Model
    defaults:
        score: 'N/A'

    getAgendas: ->
        if @agendas_fetching.state() != "resolved"
            console.log "Trying to use member agendas before fetched", @, @agendas_fetching
            throw "Agendas not fetched yet!"
        @get('agendas')

    initialize: ->
        @agendas_fetching = $.Deferred()

        set_default = (attr, val) =>
            # Good for not sharing same object for all instances
            if @get(attr) is undefined
                @set(attr, val)
        set_default 'recommendation_positive', {}
        set_default 'recommendation_negative', {}

class root.Member extends root.Candidate
    class MemberAgenda extends Backbone.Model
        urlRoot: "http://www.oknesset.org/api/v2/member-agendas/"
        url: ->
            super(arguments...) + '/'
        sync: =>
            root.JSONPCachableSync("memberagenda_#{ @id }")(arguments...)
        getAgendas: ->
            ret = {}
            _.each @get('agendas'), (agenda) ->
                ret[agenda.id] = agenda.score
            ret

    fetchAgendas: (force) ->
        if @agendas_fetching.state() != "resolved" or force
            @memberAgendas = new MemberAgenda
                id: @id
            @memberAgendas.fetch
                success: =>
                    @set 'agendas', @memberAgendas.getAgendas()
                    @agendas_fetching.resolve()
                error: =>
                    console.log "Error fetching member agendas", @, arguments
                    @agendas_fetching.reject()

        return @agendas_fetching

class root.Newbie extends root.Candidate
    initialize: ->
        super(arguments...)
        @agendas_fetching.resolve()

class root.Recommendation extends Backbone.Model

############### COLLECTIONS ##############

class root.LocalVarCollection extends Backbone.Collection
    initialize: (models, options) ->
        if options?.localObject
            @localObject = options.localObject
        if @localObject
            console.log "Using local objects for ", this
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
    url: "http://www.oknesset.org/api/v2/member/?extra_fields=current_role_descriptions,party_name"
    localObject: window.mit.member

    syncFunc: root.syncEx
        cache: true
        dataType: 'jsonp'
        jsonpCallback: 'members'

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

class root.NewbiesList extends root.JSONPCollection
    model: root.Newbie
    localObject: window.mit.combined_newbies
    url: "http://www.mitpakdim.co.il/site/primaries/data/newbies.jsonp"
    fetchAgendas: ->
        @agendas_fetching = $.Deferred().resolve()

class root.RecommendationList extends root.JSONPCollection
    model: root.Recommendation
    localObject: window.mit.recommendations
    url: "http://www.mitpakdim.co.il/site/primaries/data/recommendations.jsonp"

############### VIEWS ##############

class root.TemplateView extends Backbone.View
    template: ->
        _.template( @get_template() )(arguments...)
    render: =>
        @$el.html( @template(@model.toJSON()) )
        @

class root.CandidateView extends root.TemplateView
    className: "member_instance"
    initialize: ->
        super(arguments...)
        @model.on 'change', ->
            console.log 'candidate changed: ', @, arguments
    get_template: ->
        $("#member_template").html()
    events:
        'click': ->
            @trigger 'click', @model

class root.ListViewItem extends root.TemplateView
    tagName: "div"
    get_template: ->
        "<a href='#'><%= name %></a>"

class root.ListView extends root.TemplateView
    initialize: ->
        super(arguments...)
        @options.itemView ?= root.ListViewItem
        @options.autofetch ?= true
        if @options.collection
            @setCollection(@options.collection)

    setCollection: (collection) ->
        @collection = collection
        @collection.on "add", @addOne
        @collection.on "reset", @addAll
        if @options.autofetch
            @collection.fetch()

    addOne: (modelInstance) =>
        view = new @options.itemView({ model:modelInstance })
        view.on 'all', @itemEvent
        @$el.append view.render().$el

    addAll: =>
        @initEmptyView()
        @collection.each(@addOne)

    initEmptyView: =>
        @$el.empty()

    itemEvent: =>
        @trigger arguments...


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

class root.CandidatesMainView extends Backbone.View
    el: ".candidates_container"
    initialize: ->
        @membersView = new root.CandidateListView
            el: ".members"
            collection: @.options.members
        @newbiesView = new root.CandidateListView
            el: ".newbies"
            collection: @.options.newbies

        @membersView.on 'all', @propagate
        @newbiesView.on 'all', @propagate

    propagate: =>
        @trigger arguments...

root.CandidatesMainView.create_delegation = (func_name) ->
    delegate = ->
        @membersView[func_name](arguments...)
        @newbiesView[func_name](arguments...)
    @::[func_name] = delegate

root.CandidatesMainView.create_delegation 'calculate'

class root.PartyFilteredListView extends root.ListView
    options:
        autofetch: false

    initialize: ->
        super(arguments...)
        @unfilteredCollection = @.collection
        @unfilteredCollection.fetch()
        @setCollection new @unfilteredCollection.constructor undefined,
            comparator: (candidate) ->
                return -candidate.get 'score'
        root.global_events.on 'change_party', @partyChange

    partyChange: (party) =>
        @collection.reset @unfilteredCollection.where(party_name: party)

class root.CandidateListView extends root.PartyFilteredListView
    options:
        itemView: root.CandidateView

    partyChange: (party) =>
        super(party)
        @collection.fetchAgendas()

    calculate: (weights) ->
        if not @collection.agendas_fetching
            throw "Agenda data not present yet"
        @collection.agendas_fetching.done =>
            @calculate_inner(weights)
            @collection.sort()

    calculate_inner: (weights) ->
        abs_sum = (arr) ->
            do_sum = (memo, item) ->
                memo += Math.abs item
            _.reduce(arr, do_sum, 0)
        weight_sum = abs_sum(weights)

        console.log "Weights: ", weights, weight_sum
        @collection.each (candidate) =>
            #console.log "calc: ", candidate, candidate.get('name')
            candidate.set 'score', _.reduce candidate.getAgendas(), (memo, score, id) ->
                #console.log "agenda: ", (weights[id] or 0), score, weight_sum, (weights[id] or 0) * score / weight_sum
                memo += (weights[id] or 0) * score / weight_sum
            , 0

class root.AgendaListView extends root.ListView
    el: '.agendas'
    options:
        collection: new root.JSONPCollection(null,
            model: root.Agenda
            localObject: window.mit.agenda
            url: "http://www.oknesset.org/api/v2/agenda/"
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

    showMarkersForMember: (member_model) ->
        member_agendas = member_model.getAgendas()
        @collection.each (agenda, index) ->
            value = member_agendas[agenda.id] or 0
            value = 50 + value / 2
            @.$(".slider").eq(index).agendaSlider "setMemberMarker", value

class root.RecommendationsView extends root.PartyFilteredListView
    el: '.recommendations'
    options:
        itemView: class extends root.ListViewItem
            catchEvents: =>
                console.log 'change', @, arguments
                status = Boolean(@$el.find(':checkbox:checked').length)
                @model.set('status', status)
            events:
                'change': 'catchEvents'
            get_template: ->
                $("#recommendation_template").html()
    initialize: ->
        super(arguments...)
        @collection.on 'change', @applyChange, @

    applyChange: (recommendation) ->
        changeModelFunc = (candidates, attribute) ->
            (model_id, status) ->
                model = candidates.get(model_id)
                list = _.extend {}, model.get attribute
                if recommendation.get('status')
                    list[recommendation.id] = true
                else
                    delete list[recommendation.id]
                model.set attribute, list
        _.each recommendation.get('positive_list')['members'], changeModelFunc(@options.members, 'recommendation_positive')
        _.each recommendation.get('negative_list')['members'], changeModelFunc(@options.members, 'recommendation_negative')
        _.each recommendation.get('positive_list')['newbies'], changeModelFunc(@options.newbies, 'recommendation_positive')
        _.each recommendation.get('negative_list')['newbies'], changeModelFunc(@options.newbies, 'recommendation_negative')

class root.AppView extends Backbone.View
    el: '#app_root'
    initialize: =>
        @partyListView = new root.DropdownContainer
            collection: new root.JSONPCollection(null,
                model: root.MiscModel
                url: "http://www.oknesset.org/api/v2/party/"
                localObject: window.mit.party
            )
        @$(".parties").append(@partyListView.$el)
        @partyListView.$el.on 'change', @partyChange

        @agendaListView = new root.AgendaListView

        @agendaListView.collection.on 'change', =>
            console.log "Model changed", arguments
            if @recalc_timeout
                clearTimeout @recalc_timeout
            recalc_timeout = setTimeout =>
                @recalc_timeout = null
                @calculate()
            , 100

        @members = new root.MemberList
        @newbies = new root.NewbiesList
        @candidatesView = new root.CandidatesMainView
            members: @members
            newbies: @newbies

        @candidatesView.on 'click', (member) =>
            @agendaListView.showMarkersForMember member
        @recommendations = new root.RecommendationList
        @recommendationsView = new root.RecommendationsView
            collection: @recommendations
            members: @members
            newbies: @newbies

    partyChange: =>
        console.log "Changed: ", this, arguments
        root.global_events.trigger 'change_party', @partyListView.$('option:selected').text()

    calculate: ->
        weights = {}
        @agendaListView.collection.each (agenda) =>
            uservalue = agenda.get("uservalue")
            weights[agenda.id] = uservalue
        @candidatesView.calculate(weights)


############### INIT ##############

$ ->
    root.global_events = _.extend({}, Backbone.Events)
    root.appView = new root.AppView
    return
