// Generated by CoffeeScript 1.3.3
(function() {
  var root, sum, _ref,
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
    __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };

  root = (_ref = window.mit) != null ? _ref : window.mit = {};

  sum = function(arr) {
    var do_sum;
    do_sum = function(item, memo) {
      return memo += item;
    };
    return _.reduce(arr, do_sum, 0);
  };

  $.widget("mit.agendaSlider", $.extend({}, $.ui.slider.prototype, {
    _create: (function() {
      var cached_old_slider_create, new_create_func;
      cached_old_slider_create = $.ui.slider.prototype._create;
      new_create_func = function() {
        this.element.append('<div class="ui-slider-mid-marker"></div>');
        return cached_old_slider_create.apply(this);
      };
      return new_create_func;
    })(),
    setMemberMarker: function(value) {
      var handle, member_marker_classname;
      member_marker_classname = "ui-slider-member-marker";
      if (!this.element.find("." + member_marker_classname).length) {
        handle = this.element.find(".ui-slider-handle");
        handle.before("<div class='" + member_marker_classname + "'></div>");
      }
      return this.element.find("." + member_marker_classname).css({
        left: value + "%"
      });
    }
  }));

  root.syncEx = function(options_override) {
    return function(method, model, options) {
      return Backbone.sync(method, model, _.extend({}, options, options_override));
    };
  };

  root.JSONPSync = root.syncEx({
    dataType: 'jsonp'
  });

  root.JSONPCachableSync = function(callback_name) {
    return root.syncEx({
      cache: true,
      dataType: 'jsonp',
      jsonpCallback: callback_name || 'cachable'
    });
  };

  root.MiscModel = (function(_super) {

    __extends(MiscModel, _super);

    function MiscModel() {
      return MiscModel.__super__.constructor.apply(this, arguments);
    }

    return MiscModel;

  })(Backbone.Model);

  root.Agenda = (function(_super) {

    __extends(Agenda, _super);

    function Agenda() {
      return Agenda.__super__.constructor.apply(this, arguments);
    }

    Agenda.prototype.defaults = {
      uservalue: 0
    };

    return Agenda;

  })(Backbone.Model);

  root.Candidate = (function(_super) {

    __extends(Candidate, _super);

    function Candidate() {
      return Candidate.__super__.constructor.apply(this, arguments);
    }

    return Candidate;

  })(Backbone.Model);

  root.Member = (function(_super) {
    var MemberAgenda;

    __extends(Member, _super);

    function Member() {
      return Member.__super__.constructor.apply(this, arguments);
    }

    Member.prototype.defaults = {
      score: 'N/A'
    };

    MemberAgenda = (function(_super1) {

      __extends(MemberAgenda, _super1);

      function MemberAgenda() {
        this.sync = __bind(this.sync, this);
        return MemberAgenda.__super__.constructor.apply(this, arguments);
      }

      MemberAgenda.prototype.urlRoot = "http://www.oknesset.org/api/v2/member-agendas/";

      MemberAgenda.prototype.url = function() {
        return MemberAgenda.__super__.url.apply(this, arguments) + '/';
      };

      MemberAgenda.prototype.sync = function() {
        return root.JSONPCachableSync("memberagenda_" + (this.get('id'))).apply(null, arguments);
      };

      return MemberAgenda;

    })(Backbone.Model);

    Member.prototype.fetchAgendas = function(force) {
      var _this = this;
      if (this.agendas_fetching.state() !== "resolved" || force) {
        this.memberAgendas = new MemberAgenda({
          id: this.get('id')
        });
        this.memberAgendas.fetch({
          success: function() {
            return _this.agendas_fetching.resolve();
          },
          error: function() {
            console.log("Error fetching member agendas", _this, arguments);
            return _this.agendas_fetching.reject();
          }
        });
      }
      return this.agendas_fetching;
    };

    Member.prototype.getAgendas = function() {
      if (this.agendas_fetching.state() !== "resolved") {
        console.log("Trying to use member agendas before fetched", this, this.agendas_fetching);
        throw "Agendas not fetched yet!";
      }
      return this.memberAgendas.get('agendas');
    };

    Member.prototype.initialize = function() {
      return this.agendas_fetching = $.Deferred();
    };

    return Member;

  }).call(this, root.Candidate);

  root.NewCandidate = (function(_super) {

    __extends(NewCandidate, _super);

    function NewCandidate() {
      return NewCandidate.__super__.constructor.apply(this, arguments);
    }

    return NewCandidate;

  })(root.Candidate);

  root.LocalVarCollection = (function(_super) {

    __extends(LocalVarCollection, _super);

    function LocalVarCollection() {
      this.sync = __bind(this.sync, this);
      return LocalVarCollection.__super__.constructor.apply(this, arguments);
    }

    LocalVarCollection.prototype.initialize = function(models, options) {
      if (options != null ? options.localObject : void 0) {
        this.localObject = options.localObject;
      }
      if (this.localObject) {
        console.log("Using local objects for ", this);
      }
      if (options != null ? options.url : void 0) {
        return this.url = options.url;
      }
    };

    LocalVarCollection.prototype.sync = function(method, model, options) {
      var _this = this;
      if (this.localObject === void 0) {
        return this.syncFunc.apply(this, arguments);
      }
      setTimeout(function() {
        return options.success(_this.localObject, null);
      });
    };

    LocalVarCollection.prototype.syncFunc = Backbone.sync;

    LocalVarCollection.prototype.parse = function(response) {
      return response.objects;
    };

    return LocalVarCollection;

  })(Backbone.Collection);

  root.JSONPCollection = (function(_super) {

    __extends(JSONPCollection, _super);

    function JSONPCollection() {
      return JSONPCollection.__super__.constructor.apply(this, arguments);
    }

    JSONPCollection.prototype.syncFunc = root.JSONPSync;

    return JSONPCollection;

  })(root.LocalVarCollection);

  root.MemberList = (function(_super) {

    __extends(MemberList, _super);

    function MemberList() {
      return MemberList.__super__.constructor.apply(this, arguments);
    }

    MemberList.prototype.model = root.Member;

    MemberList.prototype.url = "http://www.oknesset.org/api/v2/member/?extra_fields=current_role_descriptions,party_name";

    MemberList.prototype.localObject = window.mit.member;

    MemberList.prototype.syncFunc = root.syncEx({
      cache: true,
      dataType: 'jsonp',
      jsonpCallback: 'members'
    });

    MemberList.prototype.fetchAgendas = function() {
      var fetches,
        _this = this;
      fetches = [];
      this.each(function(member) {
        return fetches.push(member.fetchAgendas());
      });
      console.log("Waiting for " + fetches.length + " member agendas");
      return this.agendas_fetching = $.when.apply($, fetches).done(function() {
        return console.log("Got results!", _this, arguments);
      }).fail(function() {
        return console.log("Error getting results!", _this, arguments);
      });
    };

    return MemberList;

  })(root.JSONPCollection);

  root.TemplateView = (function(_super) {

    __extends(TemplateView, _super);

    function TemplateView() {
      this.render = __bind(this.render, this);
      return TemplateView.__super__.constructor.apply(this, arguments);
    }

    TemplateView.prototype.template = function() {
      return _.template(this.get_template()).apply(null, arguments);
    };

    TemplateView.prototype.render = function() {
      this.$el.html(this.template(this.model.toJSON()));
      return this;
    };

    return TemplateView;

  })(Backbone.View);

  root.MemberView = (function(_super) {

    __extends(MemberView, _super);

    function MemberView() {
      this.click = __bind(this.click, this);
      return MemberView.__super__.constructor.apply(this, arguments);
    }

    MemberView.prototype.className = "member_instance";

    MemberView.prototype.initialize = function() {
      MemberView.__super__.initialize.apply(this, arguments);
      return this.$el.on('click', this.click);
    };

    MemberView.prototype.get_template = function() {
      return $("#member_template").html();
    };

    MemberView.prototype.click = function() {
      return this.trigger('click', this.model);
    };

    return MemberView;

  })(root.TemplateView);

  root.ListViewItem = (function(_super) {

    __extends(ListViewItem, _super);

    function ListViewItem() {
      return ListViewItem.__super__.constructor.apply(this, arguments);
    }

    ListViewItem.prototype.tagName = "div";

    ListViewItem.prototype.get_template = function() {
      return "<a href='#'><%= name %></a>";
    };

    return ListViewItem;

  })(root.TemplateView);

  root.ListView = (function(_super) {

    __extends(ListView, _super);

    function ListView() {
      this.itemEvent = __bind(this.itemEvent, this);

      this.initEmptyView = __bind(this.initEmptyView, this);

      this.addAll = __bind(this.addAll, this);

      this.addOne = __bind(this.addOne, this);
      return ListView.__super__.constructor.apply(this, arguments);
    }

    ListView.prototype.initialize = function() {
      var _base, _base1, _ref1, _ref2;
      ListView.__super__.initialize.apply(this, arguments);
      if ((_ref1 = (_base = this.options).itemView) == null) {
        _base.itemView = root.ListViewItem;
      }
      if ((_ref2 = (_base1 = this.options).autofetch) == null) {
        _base1.autofetch = true;
      }
      if (this.options.collection) {
        return this.setCollection(this.options.collection);
      }
    };

    ListView.prototype.setCollection = function(collection) {
      this.collection = collection;
      this.collection.on("add", this.addOne);
      this.collection.on("reset", this.addAll);
      if (this.options.autofetch) {
        return this.collection.fetch();
      }
    };

    ListView.prototype.addOne = function(modelInstance) {
      var view;
      view = new this.options.itemView({
        model: modelInstance
      });
      view.on('all', this.itemEvent);
      return this.$el.append(view.render().$el);
    };

    ListView.prototype.addAll = function() {
      this.initEmptyView();
      return this.collection.each(this.addOne);
    };

    ListView.prototype.initEmptyView = function() {
      return this.$el.empty();
    };

    ListView.prototype.itemEvent = function() {
      return this.trigger.apply(this, arguments);
    };

    return ListView;

  })(root.TemplateView);

  root.DropdownItem = (function(_super) {

    __extends(DropdownItem, _super);

    function DropdownItem() {
      this.render = __bind(this.render, this);
      return DropdownItem.__super__.constructor.apply(this, arguments);
    }

    DropdownItem.prototype.tagName = "option";

    DropdownItem.prototype.render = function() {
      var json;
      json = this.model.toJSON();
      this.$el.html(json.name);
      this.$el.attr({
        value: json.id
      });
      return this;
    };

    return DropdownItem;

  })(Backbone.View);

  root.DropdownContainer = (function(_super) {

    __extends(DropdownContainer, _super);

    function DropdownContainer() {
      this.initEmptyView = __bind(this.initEmptyView, this);
      return DropdownContainer.__super__.constructor.apply(this, arguments);
    }

    DropdownContainer.prototype.tagName = "select";

    DropdownContainer.prototype.options = {
      itemView: root.DropdownItem
    };

    DropdownContainer.prototype.initEmptyView = function() {
      return this.$el.html("<option>-----</option>");
    };

    return DropdownContainer;

  })(root.ListView);

  root.CandidatesMainView = (function(_super) {

    __extends(CandidatesMainView, _super);

    function CandidatesMainView() {
      return CandidatesMainView.__super__.constructor.apply(this, arguments);
    }

    CandidatesMainView.prototype.el = ".candidates_container";

    CandidatesMainView.prototype.initialize = function() {};

    return CandidatesMainView;

  })(Backbone.View);

  root.MembersView = (function(_super) {

    __extends(MembersView, _super);

    function MembersView() {
      return MembersView.__super__.constructor.apply(this, arguments);
    }

    MembersView.prototype.el = ".members";

    MembersView.prototype.options = {
      itemView: root.MemberView,
      autofetch: false
    };

    MembersView.prototype.initialize = function() {
      MembersView.__super__.initialize.apply(this, arguments);
      this.memberList = new root.MemberList;
      this.memberList.fetch();
      return this.setCollection(new root.MemberList(void 0, {
        comparator: function(member) {
          return -member.get('score');
        }
      }));
    };

    MembersView.prototype.changeParty = function(party) {
      this.collection.reset(this.memberList.where({
        party_name: party
      }));
      return this.collection.fetchAgendas();
    };

    MembersView.prototype.calculate = function(weights) {
      var _this = this;
      if (!this.collection.agendas_fetching) {
        throw "Agenda data not present yet";
      }
      return this.collection.agendas_fetching.done(function() {
        _this.calculate_inner(weights);
        return _this.collection.sort();
      });
    };

    MembersView.prototype.calculate_inner = function(weights) {
      var weight_sum,
        _this = this;
      weight_sum = sum(weights);
      console.log("Weights: ", weights);
      return this.collection.each(function(member) {
        return member.set('score', _.reduce(member.getAgendas(), function(memo, agenda) {
          return memo += weights[agenda.id] * agenda.score / weight_sum;
        }, 0));
      });
    };

    return MembersView;

  })(root.ListView);

  root.AgendaListView = (function(_super) {

    __extends(AgendaListView, _super);

    function AgendaListView() {
      return AgendaListView.__super__.constructor.apply(this, arguments);
    }

    AgendaListView.prototype.options = {
      collection: new root.JSONPCollection(null, {
        model: root.Agenda,
        localObject: window.mit.agenda,
        url: "http://www.oknesset.org/api/v2/agenda/"
      }),
      itemView: (function(_super1) {

        __extends(_Class, _super1);

        function _Class() {
          this.onStop = __bind(this.onStop, this);
          return _Class.__super__.constructor.apply(this, arguments);
        }

        _Class.prototype.className = "agenda_item";

        _Class.prototype.render = function() {
          _Class.__super__.render.call(this);
          this.$('.slider').agendaSlider({
            min: -100,
            max: 100,
            value: this.model.get("uservalue"),
            stop: this.onStop
          });
          return this;
        };

        _Class.prototype.onStop = function(event, ui) {
          return this.model.set({
            uservalue: ui.value
          });
        };

        _Class.prototype.get_template = function() {
          return $("#agenda_template").html();
        };

        return _Class;

      })(root.ListViewItem)
    };

    AgendaListView.prototype.showMarkersForMember = function(member_model) {
      var agenda, member_agendas, _i, _len, _ref1;
      member_agendas = {};
      _ref1 = member_model.getAgendas();
      for (_i = 0, _len = _ref1.length; _i < _len; _i++) {
        agenda = _ref1[_i];
        member_agendas[agenda.id] = agenda.score;
      }
      return this.collection.each(function(agenda, index) {
        var value;
        value = member_agendas[agenda.id] || 0;
        value = 50 + value / 2;
        return this.$(".slider").eq(index).agendaSlider("setMemberMarker", value);
      });
    };

    return AgendaListView;

  }).call(this, root.ListView);

  root.AppView = (function(_super) {

    __extends(AppView, _super);

    function AppView() {
      this.partyChange = __bind(this.partyChange, this);

      this.initialize = __bind(this.initialize, this);
      return AppView.__super__.constructor.apply(this, arguments);
    }

    AppView.prototype.el = '#app_root';

    AppView.prototype.initialize = function() {
      var _this = this;
      this.candidatesView = new root.CandidatesMainView;
      this.membersView = new root.MembersView;
      this.partyListView = new root.DropdownContainer({
        collection: new root.JSONPCollection(null, {
          model: root.MiscModel,
          url: "http://www.oknesset.org/api/v2/party/",
          localObject: window.mit.party
        })
      });
      this.$(".parties").append(this.partyListView.$el);
      this.partyListView.$el.on('change', this.partyChange);
      this.agendaListView = new root.AgendaListView;
      this.agendaListView.collection.on('change', function() {
        var recalc_timeout;
        console.log("Model changed", arguments);
        if (_this.recalc_timeout) {
          clearTimeout(_this.recalc_timeout);
        }
        return recalc_timeout = setTimeout(function() {
          _this.recalc_timeout = null;
          return _this.calculate();
        }, 100);
      });
      this.$(".agendas").append(this.agendaListView.$el);
      return this.membersView.on('click', function(member) {
        return _this.agendaListView.showMarkersForMember(member);
      });
    };

    AppView.prototype.partyChange = function() {
      console.log("Changed: ", this, arguments);
      return this.membersView.changeParty(this.partyListView.$('option:selected').text());
    };

    AppView.prototype.calculate = function() {
      var weights,
        _this = this;
      weights = {};
      this.agendaListView.collection.each(function(agenda) {
        var uservalue;
        uservalue = agenda.get("uservalue");
        return weights[agenda.get('id')] = uservalue;
      });
      return this.membersView.calculate(weights);
    };

    return AppView;

  })(Backbone.View);

  $(function() {
    root.appView = new root.AppView;
  });

}).call(this);
