############### UTILITIES ##############
root = (window.mit = window.mit || {})

String::repeat = ( num ) ->
    new Array( num + 1 ).join( this )

root.facebookShare = (link) ->
    ga.social 'Facebook', 'share', link
    base_url = location.href.replace /(\/)?(index.html)?(\/)?(#.*)?$/, ''
    FB.ui
            display: 'popup'
            method: 'feed'
            name: 'בחירומטר'
            link: link
            caption: 'הפעם בוחרים חכם'
            description: 'בואו תראו איזה מהמפלגות באמת עובדת בשבילכם'
            picture: 'http://oknesset.org/static/img/oknesset-logo-small.png'
        ,
            -> console.log('Facebook callback', @, arguments)

root.twitterShare = (link) ->
    ga.social 'Twitter', 'share', link
    window.open "https://twitter.com/share?" + $.param(
        url: link
        text: "ראו את דירוג המפלגות שלי לבחירות"
    ), 'tweet', 'width=575,height=400,left=672,top=320,scrollbars=1'

getShareLink = (weights) ->
    base = window.location.href.replace /#.*$/, ''
    district = if root.global.district then root.global.district.id else 'x'
    fragment = "#{encode_weights(weights)}"
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

    candidate_marker_classname: "ui-slider-candidate-marker"
    setCandidateMarker: (value) ->
        if not @element.find(".#{@candidate_marker_classname}").length
            handle = @element.find(".ui-slider-handle")
            handle.before "<div class='#{@candidate_marker_classname}'></div>"
        @element.find(".#{@candidate_marker_classname}").css
            left : value + "%"
    clearCandidateMarker: ->
        @element.find(".#{@candidate_marker_classname}").remove()

    _refreshValue : ->
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
    timeout: 20000

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

extendArrayWithId = (dest, sources...) ->
    for src in sources
        for item in src
            id = item.id
            if dest_item = _.where(dest, id: id)[0]
                _.extend dest_item, item
            else
                dest.push item

multiSync = (method, model, options) ->
    multiSyncOptions = model?.multiSync or options?.multiSync
    requests = for multi_options in multiSyncOptions
        smartSync method, model, _.extend({}, multi_options,
            success: undefined,
            error: undefined,
        )
    $.when(requests...).done (responses...) ->
        parsed = for response, index in responses
            (multiSyncOptions[index].parse or model.parse) response[0]
        extendArrayWithId parsed...

        if _.isFunction options.success
            options.success responses[0]...
    .fail (orig_args) ->
        if _.isFunction options.error
            options.error responses[0]...

############### MODELS ##############

class root.MiscModel extends Backbone.Model
class root.Agenda extends Backbone.Model
    defaults:
        uservalue: 0

class root.Party extends Backbone.Model
    defaults:
        score : 'N/A'
        selected: false
    parseLinks : (data) ->
        if data.links and _.isArray data.links
            _.each data.links, (link) ->
                if link?.title?.search('פייסבוק') isnt -1 or link?.title?.search(/facebook/i) isnt -1
                    data.facebook_link_url = link.url

        data.facebook_link_url = data.facebook_link_url || data.CA_FACEBOOK;
        data.homepage_link_url = data.CA_WEBSITE;

        if data.absolute_url
            data.oknesset_link_url = "http://oknesset.org" + data.absolute_url
        data

    parse : (data, xhr) ->
        data = super(data)
        @parseLinks data
        data

    getAgendas: ->
        ret = {}
        name = @get 'name'
        root.lists.agendas.each (agenda) ->
            matching_party = _.filter agenda.get('parties'), (item) ->
                item.name == name
            if matching_party.length == 1
                ret[agenda.id] = matching_party[0].score
            else
                console.log "No party #{name} in agenda #{agenda.get('name')}"
        ret

class root.Candidate extends Backbone.Model
    defaults :
        score : 'N/A'
        participating : true
        is_placeholder : false

    parseLinks : (data) ->
        if data.links and _.isArray data.links
            _.each data.links, (link) ->
                if link?.title?.search('פייסבוק') isnt -1 or link?.title?.search(/facebook/i) isnt -1
                    data.facebook_link_url = link.url
                if link?.title?.search('הכנסת') isnt -1
                    data.resume_link_url = link.url
        if data.absolute_url
            data.oknesset_link_url = "http://oknesset.org" + data.absolute_url
        data

    parse : (data, xhr) ->
        data = super(data)
        @parseLinks data
        data

    getAgendas: ->
        if not @get('agendas')
            console.log "Trying to use candidate agendas before fetched", @
            throw "Agendas not fetched yet!"
        @get('agendas')

    initialize: ->
        set_default = (attr, val) =>
            # Good for not sharing same object for all instances
            if @get(attr) is undefined
                @set(attr, val)
        set_default 'recommendation_positive', {}
        set_default 'recommendation_negative', {}

class root.Member extends root.Candidate
class root.Newbie extends root.Candidate
    parse: (response, xhr) ->
        ret = super arguments...
        if _.isString ret.agendas
            ret.agendas = parse_weights ret.agendas
        ret
class root.PartyDeclaration extends root.Newbie
    parseLinks : (data) ->
        if data.links and _.isArray data.links
            _.each data.links, (link) ->
                if link?.title?.search('פייסבוק') isnt -1 or link?.title?.search(/facebook/i) isnt -1
                    data.facebook_link_url = link.url

        data.facebook_link_url = data.facebook_link_url || data.CA_FACEBOOK;
        data.homepage_link_url = data.CA_WEBSITE;

        if data.absolute_url
            data.oknesset_link_url = "http://oknesset.org" + data.absolute_url
        data

    parse: (response, xhr) ->
        ret = super arguments...
        if party = root.lists.parties.where({ name: ret.name })[0]
            ret = _.extend party.toJSON(), ret
        ret

class root.Recommendation extends Backbone.Model
    defaults:
        url: ''
        img_url: ''
    isSelected: (collection, options) ->
        (collection or @collection).getSelected options?.attr_name == @

############### COLLECTIONS ##############

class root.SelectableCollection extends Backbone.Collection
    default_attr_name = 'selected'
    initialize: ->
        super arguments...
        @on 'select', (new_model, collection, options) =>
            if collection == 'all'
                collection = @
            if not collection
                collection = new_model.collection
            if collection != @
                return

            attr_name = options?.attr_name ? default_attr_name
            @selecteds ?= {}
            old_model = @selecteds[attr_name]
            @selecteds[attr_name] = new_model
            info =
                attr_name:attr_name,
                new_selected:new_model
            if old_model == new_model or options?.trigger == false
                return
            if old_model
                old_model.trigger 'deselected', old_model, @, info
            if new_model
                new_model.trigger 'selected', new_model, @, info
            @trigger 'selected_change', @, info

    getSelected: (attr_name) ->
        attr_name ?= default_attr_name
        @selecteds?[attr_name]

class root.PromisedCollection extends root.SelectableCollection
    initialize: ->
        super arguments...
        @data_ready = $.Deferred()
        @data_ready.promise @
        @on "reset", =>
            @data_ready.resolve()
        if @models.length
            @data_ready.resolve()

class root.JSONPCollection extends root.PromisedCollection
    sync: smartSync
    initialize: ->
        super(arguments...)
    parse: (response, xhr) ->
        return response.objects

class root.PartyList extends root.JSONPCollection
    model: root.Party
    multiSync: [{
        url: "http://www.oknesset.org/api/v2/party/"
        repo: window.mit.party
        sync: root.JSONPCachableSync('parties')
    }, {
        repo: window.mit.party_extra
        sync: root.JSONPCachableSync('parties_extra')
    }]
    sync: multiSync
    initialize: ->
        super arguments...
        @agendas_fetching = $.Deferred().resolve()

class root.AgendaList extends root.JSONPCollection
    model: root.Agenda
    url: "http://www.oknesset.org/api/v2/agenda/?extra_fields=num_followers,image,parties"
    comparator: (agenda) ->
        -agenda.get 'num_followers'
    syncOptions:
        xxrepo: window.mit.agenda
        sync: root.JSONPCachableSync('agendas')

    resetWeights: (weights) ->
        @done =>
            @each (agenda, index) ->
                if _.isNumber(value = weights[agenda.id])
                    agenda.set "uservalue", value

    getWeights: ->
        weights = {}
        @each (agenda) =>
            weights[agenda.id] = agenda.get("uservalue")
        weights

class root.CandidatesList extends root.JSONPCollection
    comparator: (src, dst) ->
        is_placeholder = Number(src.get 'is_placeholder') - Number(dst.get 'is_placeholder')
        if is_placeholder != 0
            return is_placeholder
        last_name = (agenda) ->
            agenda.get('name').split(/\s+/).pop()
        last_name(src).localeCompare(last_name(dst))

class root.MemberList extends root.CandidatesList
    model: root.Member
    multiSync: [{
        url: "http://www.oknesset.org/api/v2/member/?extra_fields=current_role_descriptions,party_name,links"
        repo: window.mit.combined_members
        sync: root.JSONPCachableSync('members')
    }, {
        repo: window.mit.member_extra
        sync: root.JSONPCachableSync('members_extra')
    }]
    sync: multiSync

    parse: (data, xhr) ->
        _.filter super(arguments...), (obj) ->
            obj.participating ? true

    fetchAgendas: ->
        fetches = []
        no_agendas = @filter (model) -> not model.get('agendas')
        if no_agendas.length == 0
            @agendas_fetching = $.Deferred().resolve()
            return
        ids = _.pluck no_agendas, 'id'

        bulkUrl = "http://www.oknesset.org/api/v2/member-agendas/set/" + ids.join(';') + '/'
        @agendas_fetching = root.JSONPCachableSync('memberagendas') 'read', @,
            url: bulkUrl
            error: ->
                console.log 'error fetching agendas', @, arguments
            success: (resp) =>
                if resp.not_found
                    console.log 'Got not_found data, aborting', resp
                    return
                agendas_to_hashmap = (agendas) ->
                    ret = {}
                    _.each agendas, (agenda) ->
                        ret[agenda.id] = agenda.score
                    ret
                _.each resp.objects, (obj, index) =>
                    @get(ids[index]).set agendas: agendas_to_hashmap(obj.agendas), silent: true

class root.NewbiesList extends root.CandidatesList
    model: root.Newbie
    syncOptions:
        disable_repo: window.mit.combined_newbies
    url: "http://www.mitpakdim.co.il/site/primaries/candidates_new/json.php"
    fetchAgendas: ->
        @agendas_fetching = $.Deferred().resolve()

class root.PartyDeclarationList extends root.NewbiesList
    model: root.PartyDeclaration 
    DECLARATION_PARTY_ID: "רשימת המפלגות"
    multiSync: [{
        url: root.NewbiesList::url
        repo: root.NewbiesList::syncOptions.repo
        sync: root.NewbiesList::syncOptions.sync
    }, {
        repo: window.mit.party_declarations_extra
    }]
    sync: multiSync
    parse: (data, xhr) =>
        ret = _.filter super(arguments...), (obj) =>
            not obj.party_name? or obj.party_name == @DECLARATION_PARTY_ID
        _.each ret, (obj) ->
            obj.id = parseInt obj.id
        ret
    initialize: ->
        super arguments...
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
        @model.on 'selected', @changeSelection
        @model.on 'deselected', @changeSelection
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
    changeSelection: (model, collection, info) =>
        @.$el.toggleClass "selected", info.new_selected == @model
        @
    events:
        'click': (event) ->
            console.log 1
            @trigger 'click', @model, @            
            @model.trigger "select", @model
        'click .mdhk': (event) ->
            id = this.model.id
            weights = encode_weights root.lists.agendas.getWeights()
            window.location = 'index.html#'+id+'//'+weights
            event.stopPropagation

class root.PartyCandidateView extends root.CandidateView
    get_template: ->
        $("#party_candidate_template").html()     

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
        index = @$el.children().index @$('option:selected')
        index -= 1 if @options.show_null_option
        @current = if index >= 0 then @collection.at index else {}
        @trigger 'change', @current, @collection

class root.CurrentPartyView extends Backbone.View
    el: ".current_party"
    render: =>
        if root.global.party
            @$('.current_party_logo_back').html "<img class='current_party_logo' src='#{root.global.party.get('picture_url')}'/>"

class root.CandidatesMultiView extends Backbone.View
    initialize: ->
        for sublist in @sublists
            sublist.on 'all', @propagate

    propagate: =>
        @trigger arguments...

create_delegation = (func_name) ->
    delegate = ->
        for sublist in @sublists
            sublist[func_name](arguments...)
    @::[func_name] = delegate

root.CandidatesMultiView.create_delegation = create_delegation
root.CandidatesMultiView.create_delegation 'calculate'
root.CandidatesMultiView.create_delegation 'filterChange'

class root.CandidatesMainView extends root.CandidatesMultiView
    el: ".candidates_container"
    initialize: ->
        @sublists = [
            new root.CandidateListView
                el: ".members"
                collection: @.options.members
                autofetch: false
            new root.CandidateListView
                el: ".newbies"
                collection: @.options.newbies
                autofetch: false
        ]

        super arguments...
        @currentPartyView = new root.CurrentPartyView
        root.global.on 'change_party', =>
            @currentPartyView.render()
        #@filteringView = new root.FilterView
        #@filteringView.on 'change', (filter) =>
        #    @filterChange filter

class root.PartyCandidatesView extends root.CandidatesMultiView
    initialize: ->
        @sublists = [
            new root.PartyCandidatesListView
                el: ".parties_activity"
                collection: @.options.activity
                autofetch: false
            new root.PartyCandidatesListView
                el: ".parties_declaration"
                collection: @.options.declarations
                autofetch: false
        ]

        super arguments...

class root.PartyFilteredListView extends root.ListView
    initialize: ->
        super arguments...
        @unfilteredCollection = @.collection
        @setCollection new @unfilteredCollection.constructor undefined,
            comparator: (candidate) ->
                return -candidate.get 'score'
        root.global.on 'change_party', @partyChange

    filterByParty: (party) ->
        @unfilteredCollection.where party_name: party.get('name')

    partyChangeFilter: @::filterByParty
    partyChange: (party) =>
        if not party?
            return
        @collection.reset @partyChangeFilter party

class root.CandidateListView extends root.PartyFilteredListView
    options:
        itemView: root.CandidateView

    partyChange: (party) =>
        super arguments...
        if not party?
            return
        @collection.fetchAgendas()
        @calculate()

    filterChange: (filter_model) ->
        filtered = @filterByParty root.global.party
        @collection.reset _.filter(filtered, filter_model.get('func'))

    calculate: () ->
        if not @collection.agendas_fetching
            throw "Agenda data not present yet"
        @collection.agendas_fetching.done =>
            @calculate_inner()
            @collection.sort()

    getCandidateAgendas: (candidate) ->
        candidate.getAgendas()

    calculate_inner: () ->
        weights = root.lists.agendas.getWeights()
        abs_sum = (arr) ->
            do_sum = (memo, item) ->
                memo += Math.abs item
            _.reduce(arr, do_sum, 0)
        weight_sum = abs_sum(weights) 
        return if not weight_sum

        console.log "Weights: ", weights, weight_sum
        @collection.each (candidate) =>
            #console.log "calc: ", candidate, candidate.get('name')
            if not candidate.get('is_placeholder')
                candidate.set 'score', _.reduce @getCandidateAgendas(candidate), (memo, score, id) ->
                    #console.log "agenda: ", (weights[id] or 0), score, weight_sum, (weights[id] or 0) * score / weight_sum
                    memo += (weights[id] or 0) * score / weight_sum
                , 0

class root.PartyCandidatesListView extends root.CandidateListView
    el: ".party_candidates_container .parties"
    options:
        itemView: root.PartyCandidateView

    # disable partyChange stuff
    initialize: ->
        super arguments...
    partyChange: (party) =>
        @collection.reset @unfilteredCollection.models

class root.AgendaListView extends root.ListView
    el: '.agendas'
    options:
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

    initialize: ->
        super arguments...
        @collection.on 'change', @changeModel

    changeModel: (model) =>
        @.$(".slider").eq(@collection.indexOf model).agendaSlider "value", model.get("uservalue")

    showMarkersForCandidate: (candidate_model) ->
        candidate_agendas = candidate_model.getAgendas()
        @collection.each (agenda, index) ->
            value = candidate_agendas[agenda.id] or 0
            value = 50 + value / 2
            @.$(".slider").eq(index).agendaSlider "setCandidateMarker", value
    clearMarkers: ->
        @collection.each (agenda, index) ->
            @.$(".slider").eq(index).agendaSlider "clearCandidateMarker"

class root.RecommendationsItemView extends root.ListViewItem
    initialize: ->
        super arguments...
        @model.on 'selected', =>
            @$('.recommendation_item').addClass 'selected'
        @model.on 'deselected', =>
            @$('.recommendation_item').removeClass 'selected'

    events:
        'click .recommendation_item': ->
            @model.trigger 'select', @model

    get_template: ->
        $("#recommendation_template").html()

    digestData : (data) ->
        _.extend {}, data, model: @model

class root.RecommendationsView extends root.PartyFilteredListView
    el: '.recommendations'
    options:
        itemView: root.RecommendationsItemView

    initialize: ->
        super arguments...
        @collection.on 'selected_change', @applyChange, @

    partyChangeFilter: (party) ->
        super(party).concat @unfilteredCollection.where party_name: undefined

    applyChange: (recommendation, collection) ->
        is_selected = recommendation == collection.getSelected()
        changeModelFunc = (candidates, attribute) ->
            (model_id, status) ->
                model = candidates.get(model_id)
                list = _.clone model.get attribute
                if is_selected
                    list[recommendation.id] = true
                else
                    delete list[recommendation.id]
                model.set attribute, list
        _.each recommendation.get('positive_list')['members'], changeModelFunc(@options.members, 'recommendation_positive')
        _.each recommendation.get('negative_list')['members'], changeModelFunc(@options.members, 'recommendation_negative')
        _.each recommendation.get('positive_list')['newbies'], changeModelFunc(@options.newbies, 'recommendation_positive')
        _.each recommendation.get('negative_list')['newbies'], changeModelFunc(@options.newbies, 'recommendation_negative')
        if is_selected and weights = recommendation.get('agendas')
            if _.isString weights
                weights = parse_weights weights
            root.lists.agendas.resetWeights weights

        ga.event 'recommendation',
            "party_#{root.global.party.id}_recommendation_#{recommendation.id}",
            "#{recommendation.get('status')}"

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
            el: '.parties_choose'
            collection: root.lists.parties
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
            if not party?.id?
                return
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
            collection: root.lists.agendas

        @candidatesView = new root.CandidatesMainView
            members: root.lists.members
            newbies: root.lists.newbies
        @partyCandidatesView = new root.PartyCandidatesView
            activity: root.lists.parties
            declarations: root.lists.party_declarations

        @recommendations = new root.RecommendationList
        @recommendationsView = new root.RecommendationsView
            collection: @recommendations
            members: root.lists.members
            newbies: root.lists.newbies

        root.lists.agendas.on 'change:uservalue', _.debounce @calculate, 500
        @candidates = @multiSelectedSetup([root.lists.members, root.lists.newbies, root.lists.parties, root.lists.party_declarations])
        @candidates.on 'selected_change', @updateSelectedCandidate

    multiSelectedSetup: (collections) ->
        updateSelected = (changed_collection, options) ->
            if not options.new_selected
                return
            for collection in collections
                if collection != changed_collection
                    collection.trigger 'select', undefined, collection
        create_delegate = (object, func_names...) ->
            _.each func_names, (func_name) ->
                object[func_name] = (args...) ->
                    collect = []
                    for collection in collections
                        new_args = _.map args, (item) ->
                            if item == "REPLACE_COLLECTION" then collection else item
                        collect.push collection[func_name].apply(collection, new_args)
                    collect
        create_delegate (delegator = {}), 'on', 'trigger'

        delegator.getSelected = (args...) ->
            for collection in collections
                if selected = collection.getSelected()
                    return selected
            return undefined

        delegator.on 'selected_change', updateSelected
        delegator

    events:
        'click .fb_share': (event) ->
            root.facebookShare getShareLink root.lists.agendas.getWeights()
        'click .tweet_share': (event) ->
            root.twitterShare getShareLink root.lists.agendas.getWeights()
        'click .print': (event) ->
            ga.event 'print', "party_#{root.global.party.id}"
            $('.page_top_bar').add('.agendas_container').add('.main_top').hide()
            window.print()
            $('.page_top_bar').add('.agendas_container').add('.main_top').show()
        'click input:button#show_weights': (event) ->
            instructions = "להעתקה לחץ על צירוף המקשים\nCtrl+C"
            window.prompt instructions, encode_weights root.lists.agendas.getWeights()
        'click #change_party': (event) ->
            @candidates.trigger 'select', undefined, "REPLACE_COLLECTION"
            root.router.navigate '', trigger: true

    getSelected: ->
        root.lists.members.getSelected() or root.lists.newbies.getSelected()

    calculate: (agenda) =>
        if root.router.mode == root.router.MODE_PARTIES
            @partyCandidatesView.calculate()
            event_category = 'change'
        else
            @candidatesView.calculate()
            event_category = 'change_party_' + root.global.party.id

        ga.event 'weight',
            event_category,
            'agenda_' + agenda.id, agenda.get('uservalue')

    updateSelectedCandidate : (collection, options) =>
        if not options.new_selected
            @agendaListView.clearMarkers()
            return

        @agendaListView.showMarkersForCandidate options.new_selected

        is_party = options.new_selected instanceof root.Party
        is_party_declaration = options.new_selected instanceof root.PartyDeclaration
        if is_party or is_party_declaration
            type = if is_party then "activity" else "declaration"
            ga.event 'candidates', "select", "party_#{type}_#{options.new_selected.id}"
            return
        type = if options.new_selected instanceof root.Member then 'member' else 'newbie'
        ga.event 'candidates',
            "select_party_#{root.global.party.id}",
            "#{type}_#{options.new_selected.id}"

############### ROUTERS ##############
class root.Router extends Backbone.Router
    MODE_ENTRANCE: 1
    MODE_MEMBERS: 2
    MODE_PARTIES: 3

    routes:
        '': 'parties'        
        'parties': 'parties'
        ':weights': 'parties'


    entrance: ->
        console.log 'entrance'
        @setMode @MODE_ENTRANCE

    setMode: (mode) ->
        $('.entrance_page').toggle mode==@MODE_ENTRANCE
        $('.party_page').toggle mode!=@MODE_ENTRANCE
        $('.party_candidates_container').toggle mode==@MODE_PARTIES
        $('.candidates_container').toggle mode==@MODE_MEMBERS
        @mode = mode

    parties: (weights) ->
        if weights = parse_weights(weights)
            root.lists.agendas.resetWeights weights        
        root.global.trigger 'change_party', undefined
        @setMode @MODE_PARTIES

############### INIT ##############

setupPartyList = ->
    root.lists ?= {}
    root.lists.agendas = new root.AgendaList
    root.lists.parties = new root.PartyList
    root.lists.party_declarations = new root.PartyDeclarationList
    root.lists.members = new root.MemberList
    root.lists.newbies = new root.NewbiesList
    return [
        root.lists.agendas.fetch()
        root.lists.parties.fetch()
        root.lists.party_declarations.fetch()
        root.lists.members.fetch()
        root.lists.newbies.fetch()
    ]

$ ->
    root.global = _.extend({}, Backbone.Events)
    root.router = new root.Router
    partyListFetching = setupPartyList()
    root.appView = new root.AppView
    root.entranceView = new root.EntranceView
    $.when(partyListFetching...).done ->
        Backbone.history.start()
        $('#loading').hide()
        $('#app_root').show()
    .fail ->
        $('#loading').text 'הורדת נתונים מהשרת נכשלה... נסיון נוסף עוד מספר שניות'
        setTimeout ->
            window.location.reload()
        , 6*1000
    if window.location.protocol != "file:"
        FB.init
            appId: 362298483856854
        FB.Event.subscribe 'message.send', (targetUrl) ->
            ga.social 'facebook', 'send', targetUrl
        FB.XFBML.parse()
    return
