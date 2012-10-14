(function() {
  var root, _ref;
  var __hasProp = Object.prototype.hasOwnProperty, __extends = function(child, parent) {
    for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; }
    function ctor() { this.constructor = child; }
    ctor.prototype = parent.prototype;
    child.prototype = new ctor;
    child.__super__ = parent.prototype;
    return child;
  }, __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };
  root = (_ref = window.mit) != null ? _ref : window.mit = {};
  root.JSONPSync = function(method, model, options) {
    options.dataType = "jsonp";
    return Backbone.sync(method, model, options);
  };
  root.MiscModel = (function() {
    __extends(MiscModel, Backbone.Model);
    function MiscModel() {
      MiscModel.__super__.constructor.apply(this, arguments);
    }
    return MiscModel;
  })();
  root.Agenda = (function() {
    __extends(Agenda, Backbone.Model);
    function Agenda() {
      Agenda.__super__.constructor.apply(this, arguments);
    }
    Agenda.prototype.defaults = {
      uservalue: 0
    };
    return Agenda;
  })();
  root.Member = (function() {
    var MemberAgenda;
    __extends(Member, Backbone.Model);
    function Member() {
      Member.__super__.constructor.apply(this, arguments);
    }
    Member.prototype.defaults = {
      score: 'N/A'
    };
    MemberAgenda = (function() {
      __extends(MemberAgenda, Backbone.Model);
      function MemberAgenda() {
        MemberAgenda.__super__.constructor.apply(this, arguments);
      }
      MemberAgenda.prototype.urlRoot = "http://api.dev.oknesset.org/api/v2/member-agendas/";
      MemberAgenda.prototype.sync = root.JSONPSync;
      return MemberAgenda;
    })();
    Member.prototype.fetchAgendas = function(force) {
      if (this.agendas_fetching.state() !== "resolved" || force) {
        this.memberAgendas = new MemberAgenda({
          id: this.get('id')
        });
        this.memberAgendas.fetch({
          success: __bind(function() {
            return this.agendas_fetching.resolve();
          }, this),
          error: __bind(function() {
            console.log("Error fetching member agendas", this, arguments);
            return this.agendas_fetching.reject();
          }, this)
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
  })();
  root.LocalVarCollection = (function() {
    __extends(LocalVarCollection, Backbone.Collection);
    function LocalVarCollection() {
      this.sync = __bind(this.sync, this);
      LocalVarCollection.__super__.constructor.apply(this, arguments);
    }
    LocalVarCollection.prototype.initialize = function(models, options) {
      if (options != null ? options.localObject : void 0) {
        console.log("Using local objects for ", this);
        this.localObject = options.localObject;
      }
      if (options != null ? options.url : void 0) {
        return this.url = options.url;
      }
    };
    LocalVarCollection.prototype.sync = function(method, model, options) {
      if (this.localObject === void 0) {
        return this.syncFunc.apply(this, arguments);
      }
      setTimeout(__bind(function() {
        return options.success(this.localObject, null);
      }, this));
    };
    LocalVarCollection.prototype.syncFunc = Backbone.sync;
    LocalVarCollection.prototype.parse = function(response) {
      return response.objects;
    };
    return LocalVarCollection;
  })();
  root.JSONPCollection = (function() {
    __extends(JSONPCollection, root.LocalVarCollection);
    function JSONPCollection() {
      JSONPCollection.__super__.constructor.apply(this, arguments);
    }
    JSONPCollection.prototype.syncFunc = root.JSONPSync;
    return JSONPCollection;
  })();
  root.MemberList = (function() {
    __extends(MemberList, root.JSONPCollection);
    function MemberList() {
      MemberList.__super__.constructor.apply(this, arguments);
    }
    MemberList.prototype.model = root.Member;
    MemberList.prototype.localObject = window.mit.members;
    MemberList.prototype.url = "http://api.dev.oknesset.org/api/v2/member/";
    MemberList.prototype.fetchAgendas = function() {
      var fetches;
      fetches = [];
      this.each(__bind(function(member) {
        return fetches.push(member.fetchAgendas());
      }, this));
      console.log("Waiting for " + fetches.length + " member agendas");
      return this.agendas_fetching = $.when.apply($, fetches).done(__bind(function() {
        return console.log("Got results!", this, arguments);
      }, this)).fail(__bind(function() {
        return console.log("Error getting results!", this, arguments);
      }, this));
    };
    return MemberList;
  })();
  root.TemplateView = (function() {
    __extends(TemplateView, Backbone.View);
    function TemplateView() {
      this.render = __bind(this.render, this);
      TemplateView.__super__.constructor.apply(this, arguments);
    }
    TemplateView.prototype.template = function() {
      return _.template(this.get_template()).apply(null, arguments);
    };
    TemplateView.prototype.render = function() {
      this.$el.html(this.template(this.model.toJSON()));
      return this;
    };
    return TemplateView;
  })();
  root.MemberView = (function() {
    __extends(MemberView, root.TemplateView);
    function MemberView() {
      MemberView.__super__.constructor.apply(this, arguments);
    }
    MemberView.prototype.className = "member_instance";
    MemberView.prototype.get_template = function() {
      return $("#member_template").html();
    };
    return MemberView;
  })();
  root.ListViewItem = (function() {
    __extends(ListViewItem, root.TemplateView);
    function ListViewItem() {
      ListViewItem.__super__.constructor.apply(this, arguments);
    }
    ListViewItem.prototype.tagName = "div";
    ListViewItem.prototype.get_template = function() {
      return "<a href='#'><%= name %></a>";
    };
    return ListViewItem;
  })();
  root.ListView = (function() {
    __extends(ListView, root.TemplateView);
    function ListView() {
      this.initEmptyView = __bind(this.initEmptyView, this);
      this.addAll = __bind(this.addAll, this);
      this.addOne = __bind(this.addOne, this);
      this.initialize = __bind(this.initialize, this);
      ListView.__super__.constructor.apply(this, arguments);
    }
    ListView.prototype.initialize = function() {
      var _base, _base2, _ref2, _ref3;
      root.TemplateView.prototype.initialize.apply(this, arguments);
            if ((_ref2 = (_base = this.options).itemView) != null) {
        _ref2;
      } else {
        _base.itemView = root.ListViewItem;
      };
            if ((_ref3 = (_base2 = this.options).autofetch) != null) {
        _ref3;
      } else {
        _base2.autofetch = true;
      };
      if (this.options.collection) {
        this.options.collection.bind("add", this.addOne);
        this.options.collection.bind("reset", this.addAll);
        if (this.options.autofetch) {
          return this.options.collection.fetch();
        }
      }
    };
    ListView.prototype.addOne = function(modelInstance) {
      var view;
      view = new this.options.itemView({
        model: modelInstance
      });
      modelInstance.view = view;
      return this.$el.append(view.render().$el);
    };
    ListView.prototype.addAll = function() {
      this.initEmptyView();
      return this.options.collection.each(this.addOne);
    };
    ListView.prototype.initEmptyView = function() {
      return this.$el.empty();
    };
    return ListView;
  })();
  root.DropdownItem = (function() {
    __extends(DropdownItem, Backbone.View);
    function DropdownItem() {
      this.render = __bind(this.render, this);
      DropdownItem.__super__.constructor.apply(this, arguments);
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
  })();
  root.DropdownContainer = (function() {
    __extends(DropdownContainer, root.ListView);
    function DropdownContainer() {
      this.initEmptyView = __bind(this.initEmptyView, this);
      DropdownContainer.__super__.constructor.apply(this, arguments);
    }
    DropdownContainer.prototype.tagName = "select";
    DropdownContainer.prototype.options = {
      itemView: root.DropdownItem
    };
    DropdownContainer.prototype.initEmptyView = function() {
      return this.$el.html("<option>-----</option>");
    };
    return DropdownContainer;
  })();
  root.AppView = (function() {
    __extends(AppView, Backbone.View);
    function AppView() {
      this.reevaluateMembers = __bind(this.reevaluateMembers, this);
      this.partyChange = __bind(this.partyChange, this);
      this.initialize = __bind(this.initialize, this);
      AppView.__super__.constructor.apply(this, arguments);
    }
    AppView.prototype.el = '#app_root';
    AppView.prototype.initialize = function() {
      this.memberList = new root.MemberList;
      this.memberList.fetch();
      this.partyListView = new root.DropdownContainer({
        collection: new root.JSONPCollection(null, {
          model: root.MiscModel,
          url: "http://api.dev.oknesset.org/api/v2/party/",
          localObject: window.mit.parties
        })
      });
      this.$(".parties").append(this.partyListView.$el);
      this.partyListView.$el.bind('change', this.partyChange);
      this.agendaListView = new root.ListView({
        collection: new root.JSONPCollection(null, {
          model: root.Agenda,
          localObject: window.mit.agendas,
          url: "http://api.dev.oknesset.org/api/v2/agenda/"
        }),
        itemView: (function() {
          __extends(_Class, root.ListViewItem);
          function _Class() {
            this.onStop = __bind(this.onStop, this);
            _Class.__super__.constructor.apply(this, arguments);
          }
          _Class.prototype.render = function() {
            _Class.__super__.render.call(this);
            this.$('.slider').slider({
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
        })()
      });
      this.agendaListView.collection.on('change', __bind(function() {
        var recalc_timeout;
        console.log("Model changed", arguments);
        if (this.recalc_timeout) {
          clearTimeout(this.recalc_timeout);
        }
        return recalc_timeout = setTimeout(__bind(function() {
          this.recalc_timeout = null;
          return this.calculate();
        }, this), 100);
      }, this));
      this.$(".agendas").append(this.agendaListView.$el);
      return this.agendaListView.$el.bind('change', this.agendaChange);
    };
    AppView.prototype.partyChange = function() {
      console.log("Changed: ", this, arguments);
      this.partyListView.options.selected = this.partyListView.$('option:selected').text();
      this.$('.agendas_container').show();
      return this.reevaluateMembers();
    };
    AppView.prototype.reevaluateMembers = function() {
      this.filteredMemberList = new root.MemberList(this.memberList.filter(__bind(function(object) {
        return object.get('party_name') === this.partyListView.options.selected;
      }, this)), {
        comparator: function(member) {
          return -member.get('score');
        }
      });
      this.filteredMemberList.fetchAgendas();
      this.memberListView = new root.ListView({
        collection: this.filteredMemberList,
        itemView: root.MemberView,
        autofetch: false
      });
      this.$(".members").empty().append(this.memberListView.$el);
      return this.memberListView.options.collection.trigger("reset");
    };
    AppView.prototype.calculate = function() {
      if (!this.filteredMemberList.agendas_fetching) {
        throw "Agenda data not present yet";
      }
      return this.filteredMemberList.agendas_fetching.done(__bind(function() {
        this.calculate_inner();
        return this.filteredMemberList.sort();
      }, this));
    };
    AppView.prototype.calculate_inner = function() {
      var agendasInput;
      console.log("Calculate: ", this, arguments);
      agendasInput = {};
      this.agendaListView.collection.each(__bind(function(agenda) {
        return agendasInput[agenda.get('id')] = agenda.get("uservalue");
      }, this));
      console.log("Agendas input: ", agendasInput);
      return this.memberListView.collection.each(__bind(function(member) {
        console.log("Calcing member: ", member);
        return member.set('score', _.reduce(member.getAgendas(), function(memo, agenda) {
          console.log("Calc step: ", agendasInput[agenda.id], agenda.score);
          return memo += agendasInput[agenda.id] * agenda.score;
        }, 0));
      }, this));
    };
    AppView.prototype.calcOneAsync = function(member, agendasInput) {
      var memberAgendas;
      if (member.get('agendas')) {
        console.log('Already got agendas for ' + member.get('id'));
        calcOne();
        return $.Deferred().resolve();
      }
      memberAgendas = new root.MemberAgenda({
        id: member.get('id')
      });
      return memberAgendas.fetch({
        success: function() {
          member.set('agendas', memberAgendas.get('agendas'));
          return calcOne();
        }
      });
    };
    return AppView;
  })();
  $(function() {
    root.appView = new root.AppView;
  });
}).call(this);
