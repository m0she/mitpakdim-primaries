root = window.mit ?= {}
console.log 'init'
############### UTILITIES ##############

String::repeat = ( num ) ->
    new Array( num + 1 ).join( this )

root.facebookShare = (link) ->
    ga.social 'Facebook', 'share', link
    FB.ui
            app_id: '362298483856854'
            display: 'popup'
            redirect_uri: 'http://www.mitpakdim.co.il/site/primaries/redirect'
            method: 'feed'
            name: 'Mitpakdim Primarieser'
            link: link
            caption: 'The way to choose your candidates'
            description: 'Learn about your candidates by prioritizing the agendas you care about'
        ,
            -> console.log('Facebook callback', @, arguments)

root.twitterShare = (link) ->
    ga.social 'Twitter', 'share', link
    window.open "https://twitter.com/share?" + $.param(url: link),
        'tweet', 'width=575,height=400,left=672,top=320,scrollbars=1'

getShareLink = (weights) ->
    base = window.location.href.replace /#.*$/, ''
    party = root.global.party.id
    district = if root.global.district then root.global.district.id else 'x'
    fragment = "#{party}/#{district}/#{encode_weights(weights)}"
    base + '#' + fragment

parse_weights = (weights) ->
    if not _.isString weights
        return
    parsed = {}
    _.each weights.split('i'), (item) ->
        [key, value] = item.split('x')
        parsed[Number(key)] = Number(value)
    return parsed

encode_weights = (weights) ->
    ("#{key}x#{value}" for key,value of weights).join('i')

ga =
    event: (args...) ->
        _gaq.push ['_trackEvent'].concat args
    social: (args...) ->
        _gaq.push ['_trackSocial'].concat args

############### JQUERY UI EXTENSIONS ##############

$.widget "mit.agendaSlider", $.extend({}, $.ui.slider.prototype, {
    _create : ->
        @element.append '<div class="ui-slider-back"></div>'
        @element.append '<div class="ui-slider-mid-range"></div>'
        @element.append '<div class="ui-slider-minus-button"></div>'
        @element.append '<div class="ui-slider-plus-button"></div>'
        $.ui.slider::_create.apply @
    setCandidateMarker : (value) ->
        candidate_marker_classname = "ui-slider-candidate-marker"
        if not @element.find(".#{candidate_marker_classname}").length
            handle = @element.find(".ui-slider-handle")
            handle.before "<div class='#{candidate_marker_classname}'></div>"
        @element.find(".#{candidate_marker_classname}").css
            left : value + "%"
    resetSelection : ->
        $.ui.slider::_refreshValue.apply @
        handle = @element.find(".ui-slider-handle")
        range = @element.find ".ui-slider-mid-range"
        @element.removeClass "minus plus"
        handle.css
            left : "50%"
            right : "initial"
        range.css
            left : "50%"
            right: "initial"

    _refreshValue : ->
        console.log '_refreshValue'
        $.ui.slider::_refreshValue.apply @
        value = @value()
        range = @element.find ".ui-slider-mid-range"
        @element.removeClass "minus plus"
        if value < 0
            @element.addClass "minus"
            range.css
                left : (50 + value / 2) + "%"
                right : "50%"
        if value > 0
            @element.addClass "plus"
            range.css
                left : "50%"
                right : (50 - value / 2) + "%"
})

############### SYNC ##############

root.syncEx = (options_override) ->
    (method, model, options) ->
        Backbone.sync(method, model, _.extend({}, options, options_override))

root.JSONPCachableSync = (callback_name) ->
    collisionDict = {}
    collisionPrevention = ->
        callback = callback_name or 'cachable'
        callback_value = if _.isFunction callback then callback() else callback
        index = collisionDict[callback_value] or 0
        collisionDict[callback_value] = index + 1
        if index
            callback_value += "__#{index}"
        #console.log "jsonp callback: #{callback_value}"
        return callback_value

    root.syncEx
        cache: true
        dataType: 'jsonp'
        jsonpCallback: collisionPrevention

root.syncOptions =
    dataType: 'jsonp'

# Assume a repo has a key named objects with a list of objects identifiable by an id key
smartSync = (method, model, options) ->
    options = _.extend {}, root.syncOptions, model.syncOptions, options
    getLocalCopy = ->
        repo = options.repo
        repo = if _.isString(repo) then root[repo] else repo
        if method isnt 'read' or not repo
            return null
        if model instanceof Backbone.Collection
            return repo
        # Assume could only be a Model
        _.where(repo.objects, id: model.id)[0]

    if localCopy = _.clone getLocalCopy()
        promise = $.Deferred()
        _.defer ->
            if _.isFunction options.success
                options.success localCopy, null # xhr
            promise.resolve localCopy, null
        return promise
    return (options.sync or Backbone.sync)(method, model, options)

############### MODELS ##############

class root.MiscModel extends Backbone.Model
class root.Agenda extends Backbone.Model
    defaults:
        uservalue: 0

class root.Candidate extends Backbone.Model
    defaults :
        selected : false
        score : 'N/A'
        participating : true

    getAgendas: ->
        if @agendas_fetching.state() != "resolved" and not @get('agendas')
            console.log "Trying to use candidate agendas before fetched", @, @agendas_fetching
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

    fetchAgendas: () ->
        if @agendas_fetching.state() != "resolved"
            if @get('agendas')
                return @agendas_fetching.resolve()

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
    parse: (response) ->
        ret = super arguments...
        if _.isString ret.agendas
            ret.agendas = parse_weights ret.agendas
        ret

class root.Recommendation extends Backbone.Model

############### COLLECTIONS ##############

class root.JSONPCollection extends Backbone.Collection
    sync: smartSync
    initialize: ->
        super(arguments...)
    parse: (response) ->
        return response.objects

class root.PartyList extends root.JSONPCollection
    model: root.MiscModel
    url: "http://www.oknesset.org/api/v2/party/"
    syncOptions:
        disable_repo: window.mit.party
        sync: root.JSONPCachableSync('parties')

class root.AgendaList extends root.JSONPCollection
    model: root.Agenda
    url: "http://www.oknesset.org/api/v2/agenda/"
    syncOptions:
        disable_repo: window.mit.agenda
        sync: root.JSONPCachableSync('agendas')

class root.MemberList extends root.JSONPCollection
    model: root.Member
    url: "http://www.oknesset.org/api/v2/member/?extra_fields=current_role_descriptions,party_name,is_current"
    syncOptions:
        disable_repo: window.mit.combined_members
        sync: root.JSONPCachableSync('members')

    sync: (method, model, options) ->
        console.log 'MemberList sync', @, arguments
        members_options = _.extend {}, options,
            success: undefined,
            error: undefined,
        members = smartSync(method, model, options)
        extra_options = _.extend {}, members_options,
            repo: window.mit.member_extra
            url: "data/member_extra.jsonp"
        extra = smartSync(method, model, extra_options)

        $.when(members, extra).done (orig_args, extra_args) ->
            extendArrayWithId = (dest, sources...) ->
                for src in sources
                    for item in src
                        id = item.id
                        if dest_item = _.where(dest, id: id)[0]
                            _.extend dest_item, item
                        else
                            dest.push item
            extendArrayWithId orig_args[0].objects, extra_args[0].objects

            if _.isFunction options.success
                options.success orig_args...
        .fail (orig_args, extra_args) ->
            if _.isFunction options.error
                options.error orig_args...

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
    syncOptions:
        disable_repo: window.mit.combined_newbies
    url: "http://www.mitpakdim.co.il/site/primaries/candidates_new/json.php"
    fetchAgendas: ->
        @agendas_fetching = $.Deferred().resolve()

class root.RecommendationList extends root.JSONPCollection
    model: root.Recommendation
    syncOptions:
        repo: window.mit.recommendations
    url: "http://www.mitpakdim.co.il/site/primaries/data/recommendations.jsonp"

############### VIEWS ##############

class root.TemplateView extends Backbone.View
    template: ->
        _.template( @get_template() )(arguments...)
    digestData : (data) ->
        data
    render: =>
        @$el.html( @template(@digestData @model.toJSON()) )
        @

class root.ListViewItem extends root.TemplateView
    tagName: "div"
    get_template: ->
        "<a href='#'><%= name %></a>"
    events :
        click : "onClick"
    onClick : ->
        @trigger 'click', @model, @

class root.CandidateView extends root.ListViewItem
    className: "candidate_instance"
    initialize: ->
        super(arguments...)
        @model.on 'change', @render
    get_template: ->
        $("#candidate_template").html()
    digestData : (data) ->
        if _.isString data.score
            data.simplified_score = ""
        else
            data.simplified_score = Math.round(data.score)
            if data.simplified_score > 0
                data.simplified_score += "+"
        data
    render : =>
        super()
        @.$el.toggleClass "selected", @model.get "selected"
        @
    onClick : ->
        super arguments...
        @model.set selected : true

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
        else
            @addAll()

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
        itemView: root.DropdownItem,
        show_null_option: true
    initEmptyView: =>
        if @options.show_null_option
            @$el.html("<option>-----</option>")
    current: {}
    events: 'change': ->
        console.log 'selection changed'
        index = @$el.children().index @$('option:selected')
        index -= 1 if @options.show_null_option
        @current = if index >= 0 then @collection.at index else {}
        @trigger 'change', @current

class root.CurrentPartyView extends Backbone.View
    el: ".current_party"
    render: =>
        @$('.current_party_name').text root.global.party.get('name')

class root.CandidatesMainView extends Backbone.View
    el: ".candidates_container"
    initialize: ->
        @currentPartyView = new root.CurrentPartyView
        root.global.on 'change_party', =>
            @currentPartyView.render()
        @filteringView = new root.FilterView
        @membersView = new root.CandidateListView
            el: ".members"
            collection: @.options.members
            autofetch: false
        @newbiesView = new root.CandidateListView
            el: ".newbies"
            collection: @.options.newbies
            autofetch: false

        @membersView.on 'all', @propagate
        @newbiesView.on 'all', @propagate
        @filteringView.on 'change', (filter) =>
            @filterChange filter

    propagate: =>
        @trigger arguments...

root.CandidatesMainView.create_delegation = (func_name) ->
    delegate = ->
        @membersView[func_name](arguments...)
        @newbiesView[func_name](arguments...)
    @::[func_name] = delegate

root.CandidatesMainView.create_delegation 'calculate'
root.CandidatesMainView.create_delegation 'filterChange'

class root.PartyFilteredListView extends root.ListView
    initialize: ->
        super(arguments...)
        @unfilteredCollection = @.collection
        @setCollection new @unfilteredCollection.constructor undefined,
            comparator: (candidate) ->
                return -candidate.get 'score'
        root.global.on 'change_party', @partyChange

    filterByParty: (party) ->
        @unfilteredCollection.where party_name: party.get('name')

    partyChange: (party) =>
        @collection.reset @filterByParty party

class root.CandidateListView extends root.PartyFilteredListView
    options:
        itemView: root.CandidateView

    partyChange: (party) =>
        super(arguments...)
        @collection.fetchAgendas()

    filterChange: (filter_model) ->
        filtered = @filterByParty root.global.party
        @collection.reset _.filter(filtered, filter_model.get('func'))

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
        return if not weight_sum

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
        collection: new root.AgendaList

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
                if ui.value <= 5 and ui.value >= -5
                    $(ui.handle).closest('.slider').agendaSlider "value", 0
                    ui.value = 0
                @model.set
                    uservalue : ui.value
            get_template: ->
                $("#agenda_template").html()

    reset: (weights) ->
        @collection.each (agenda, index) ->
            if _.isNumber(value = weights[agenda.id])
                agenda.set "uservalue", value
                @.$(".slider").eq(index).agendaSlider "value", value

    getWeights: ->
        weights = {}
        @collection.each (agenda) =>
            weights[agenda.id] = agenda.get("uservalue")
        weights

    resetMarkers: () ->
      console.log 'resetMarkers'
      @collection.each (agenda, index) ->
          console.log 'resetMarkers', agenda, index
          @.$(".slider").eq(index).agendaSlider "resetSelection"

    showMarkersForCandidate: (candidate_model) ->
        candidate_agendas = candidate_model.getAgendas()
        @collection.each (agenda, index) ->
            value = candidate_agendas[agenda.id] or 0
            value = 50 + value / 2
            @.$(".slider").eq(index).agendaSlider "setCandidateMarker", value

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
                list = _.clone model.get attribute
                if recommendation.get('status')
                    list[recommendation.id] = true
                else
                    delete list[recommendation.id]
                model.set attribute, list
        _.each recommendation.get('positive_list')['members'], changeModelFunc(@options.members, 'recommendation_positive')
        _.each recommendation.get('negative_list')['members'], changeModelFunc(@options.members, 'recommendation_negative')
        _.each recommendation.get('positive_list')['newbies'], changeModelFunc(@options.newbies, 'recommendation_positive')
        _.each recommendation.get('negative_list')['newbies'], changeModelFunc(@options.newbies, 'recommendation_negative')

filter_data = [
    id: "all"
    name: "All"
    func: (obj) -> true
  ,
    id: "district"
    name: "District"
    func: (obj) ->
        obj.get('district') == root.global.district.get('id')
]

class root.FilterView extends root.DropdownContainer
    el: '.filtering'
    options: _.extend({}, @__super__.options,
        collection: new Backbone.Collection(filter_data)
        autofetch: false
        show_null_option: false
    )

class root.EntranceView extends Backbone.View
    el: '.entrance_page'
    initialize: =>
        @partyListView = new root.DropdownContainer
            el: '.parties'
            collection: root.lists.partyList
            autofetch: false
        @partyListView.on 'change', (model) =>
            console.log "Party changed: ", this, arguments
        @districtListView = new root.DropdownContainer
            el: '.districts'
            collection: new Backbone.Collection
            autofetch: false
        @districtListView.on 'change', (model) =>
            root.global.district = model

        @$el.on 'click', '#party_selected', =>
            [party,district] = [@partyListView.current, @districtListView.current]
            if district.id
                ga.event 'party', 'choose', "party_#{party.id}_district_#{district.id}"
            else
                ga.event 'party', 'choose', "party_#{party.id}"

            root.router.navigate party.id.toString(), trigger: true

        @partyListView.on 'change', (party) =>
            # Assume members are already fetched - TODO - fix
            districts_names = _.chain(_.union(
                    root.lists.members.where party_name: party.get('name'),
                    root.lists.newbies.where party_name: party.get('name')
                )).pluck('attributes').pluck('district').uniq().value()
            districts = []
            for district in districts_names
                if not district
                    continue
                districts.push
                    id: district
                    name: district

            @districtListView.collection.reset districts

class root.AppView extends Backbone.View
    el: '#app_root'

    initialize: =>
        @agendaListView = new root.AgendaListView
        @agendaListView.collection.on 'reset', @resetSelection, @
        @agendaListView.collection.on 'change:uservalue', _.debounce @calculate, 500

        @candidatesView = new root.CandidatesMainView
            members: root.lists.members
            newbies: root.lists.newbies

        root.lists.members.on "change:selected", @updateSelectedCandidate
        root.lists.newbies.on "change:selected", @updateSelectedCandidate

        @recommendations = new root.RecommendationList
        @recommendationsView = new root.RecommendationsView
            collection: @recommendations
            members: root.lists.members
            newbies: root.lists.newbies

    events:
        'click input:button#fb_share': (event) ->
            root.facebookShare getShareLink @agendaListView.getWeights()
        'click input:button#tweet_share': (event) ->
            root.twitterShare getShareLink @agendaListView.getWeights()
        'click input:button#show_weights': (event) ->
            instructions = "\u05DC\u05D4\u05E2\u05EA\u05E7\u05D4\u0020\u05DC\u05D7\u05E5\u0020\u05E2\u05DC\u0020\u05E6\u05D9\u05E8\u05D5\u05E3\u0020\u05D4\u05DE\u05E7\u05E9\u05D9\u05DD\u000A\u0043\u0074\u0072\u006C\u002B\u0043"
            window.prompt instructions, encode_weights @agendaListView.getWeights()
        'click input:button#change_party': (event) ->
            root.router.navigate '', trigger: true

    calculate: (agenda) =>
        @candidatesView.calculate @agendaListView.getWeights()
        ga.event 'weight', 'change', 'agenda_' + agenda.id, agenda.get('uservalue')

    updateSelectedCandidate : (candidate_model, selected_attr_value) =>
        if not selected_attr_value
            return
        @agendaListView.showMarkersForCandidate candidate_model
        @deselectCandidates candidate_model

    resetSelection : () ->
        console.log 'resetSelection'
        @agendaListView.resetMarkers()

    deselectCandidates : (exclude_model) ->
        for collection in [root.lists.members, root.lists.newbies]
            _.each collection.where(selected : true), (model) ->
                if (not exclude_model) or (model isnt exclude_model)
                    model.set selected : false
        return

############### ROUTERS ##############
class root.Router extends Backbone.Router
    routes:
        '': 'entrance'
        ':party': 'party'
        ':party/:district': 'party'
        ':party/:district/:weights': 'party'
        ':party//:weights': 'partyNoDistrict'

    entrance: ->
        console.log 'entrance'
        $('.entrance_page').show()
        $('.party_page').hide()

    partyNoDistrict: (party_id, weights) -> @party(party_id, undefined, weights)
    party: (party_id, district_id, weights) ->
        console.log 'party', arguments
        # Reset markers (bugfix), perhaps better to use pubsub
        root.appView.agendaListView.resetMarkers()

        model = root.lists.partyList.where(id: Number(party_id))[0]
        if not model
            return root.router.navigate '', trigger: true
        root.global.party = model
        root.global.trigger 'change_party', model

        if district_model = root.lists.partyList.where(id: Number(district_id))[0]
            root.global.district = district_model

        if weights = parse_weights(weights)
            root.appView.agendaListView.reset weights
        $('.party_page').show()
        $('.entrance_page').hide()

############### INIT ##############

setupPartyList = ->
    root.lists ?= {}
    root.lists.partyList = new root.PartyList
    root.lists.members = new root.MemberList
    root.lists.newbies = new root.NewbiesList
    return [
        root.lists.newbies.fetch()
        root.lists.members.fetch()
        root.lists.partyList.fetch()
    ]

$ ->
    root.global = _.extend({}, Backbone.Events)
    root.router = new root.Router
    partyListFetching = setupPartyList()
    root.appView = new root.AppView
    root.entranceView = new root.EntranceView
    $.when(partyListFetching...).done ->
        Backbone.history.start()

        # Hack, filtering the members list here to remove inactive members (bugfix)
        filteredMembers = root.lists.members.filter((m) ->
          m.get("is_current") is true
        )
        root.lists.members.reset filteredMembers
        console.log 'Filtered members list', root.lists.members.models.length, filteredMembers

        $('#loading').hide()
        $('#app_root').show()
    FB.init()
    FB.Event.subscribe 'message.send', (targetUrl) ->
        ga.social 'facebook', 'send', targetUrl
    return
