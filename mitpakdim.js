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
    return Agenda;
  })();
  root.Member = (function() {
    __extends(Member, Backbone.Model);
    function Member() {
      Member.__super__.constructor.apply(this, arguments);
    }
    return Member;
  })();
  root.MemberAgenda = (function() {
    __extends(MemberAgenda, Backbone.Model);
    function MemberAgenda() {
      MemberAgenda.__super__.constructor.apply(this, arguments);
    }
    MemberAgenda.prototype.urlRoot = "http://api.dev.oknesset.org/api/v2/member-agendas/";
    MemberAgenda.prototype.sync = root.JSONPSync;
    return MemberAgenda;
  })();
  root.JSONCollection = (function() {
    __extends(JSONCollection, Backbone.Collection);
    function JSONCollection() {
      JSONCollection.__super__.constructor.apply(this, arguments);
    }
    JSONCollection.prototype.initialize = function(models, options) {
      if (options != null ? options.url : void 0) {
        return this.url = options.url;
      }
    };
    JSONCollection.prototype.parse = function(response) {
      return response.objects;
    };
    return JSONCollection;
  })();
  root.JSONPCollection = (function() {
    __extends(JSONPCollection, root.JSONCollection);
    function JSONPCollection() {
      JSONPCollection.__super__.constructor.apply(this, arguments);
    }
    JSONPCollection.prototype.sync = root.JSONPSync;
    return JSONPCollection;
  })();
  root.LocalVarCollection = (function() {
    __extends(LocalVarCollection, root.JSONCollection);
    function LocalVarCollection() {
      LocalVarCollection.__super__.constructor.apply(this, arguments);
    }
    LocalVarCollection.prototype.initialize = function(models, options) {
      if (options != null ? options.localObject : void 0) {
        return this.localObject = options.localObject;
      }
    };
    LocalVarCollection.prototype.sync = function(method, model, options) {
      setTimeout(__bind(function() {
        return options.success(this.localObject, null);
      }, this));
    };
    return LocalVarCollection;
  })();
  root.MemberList = (function() {
    __extends(MemberList, root.LocalVarCollection);
    function MemberList() {
      MemberList.__super__.constructor.apply(this, arguments);
    }
    MemberList.prototype.model = root.Member;
    MemberList.prototype.localObject = window.mit.members;
    MemberList.prototype.url = "http://api.dev.oknesset.org/api/v2/member/?format=jsonp";
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
      if ((_ref2 = (_base = this.options).itemView) == null) {
        _base.itemView = root.ListViewItem;
      }
      if ((_ref3 = (_base2 = this.options).autofetch) == null) {
        _base2.autofetch = true;
      }
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
      this.calculate = __bind(this.calculate, this);
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
        collection: new root.LocalVarCollection(null, {
          model: root.MiscModel,
          localObject: window.mit.parties
        })
      });
      this.$(".parties").append(this.partyListView.$el);
      this.partyListView.$el.bind('change', this.partyChange);
      this.agendaListView = new root.ListView({
        collection: new root.LocalVarCollection(null, {
          model: root.MiscModel,
          url: "data/agendas.jsonp",
          localObject: window.mit.agendas
        }),
        itemView: (function() {
          __extends(_Class, root.ListViewItem);
          function _Class() {
            _Class.__super__.constructor.apply(this, arguments);
          }
          _Class.prototype.get_template = function() {
            return $("#agenda_template").html();
          };
          return _Class;
        })()
      });
      this.$(".agendas").append(this.agendaListView.$el);
      this.agendaListView.$el.bind('change', this.agendaChange);
      return this.$("input:button").click(this.calculate);
    };
    AppView.prototype.partyChange = function() {
      console.log("Changed: ", this, arguments);
      this.partyListView.options.selected = this.partyListView.$('option:selected').text();
      this.$('.agendas_container').show();
      return this.reevaluateMembers();
    };
    AppView.prototype.reevaluateMembers = function() {
      this.memberListView = new root.ListView({
        collection: new root.MemberList(this.memberList.filter(__bind(function(object) {
          return object.get('party_name') === this.partyListView.options.selected;
        }, this))),
        itemView: root.MemberView,
        autofetch: false
      });
      this.$(".members").empty().append(this.memberListView.$el);
      return this.memberListView.options.collection.trigger("reset");
    };
    AppView.prototype.calculate = function() {
      var agendasInput, calcs;
      this.$(".members_container").hide();
      console.log("Calculate: ", this, arguments);
      agendasInput = {};
      this.agendaListView.collection.each(__bind(function(agenda) {
        return agendasInput[agenda.get('id')] = agenda.view.$('input:checked').val() || 0;
      }, this));
      console.log("Agendas input: ", agendasInput);
      calcs = [];
      this.memberListView.collection.each(__bind(function(member) {
        return calcs.push(this.calcOneAsync(member, agendasInput));
      }, this));
      console.log("Waiting for " + calcs.length + " member agendas");
      return $.when.apply($, calcs).done(__bind(function() {
        console.log("Got results!", this, arguments);
        return this.$(".members_container").show();
      }, this)).fail(__bind(function() {
        return console.log("Error getting results!", this, arguments);
      }, this));
    };
    AppView.prototype.calcOneAsync = function(member, agendasInput) {
      var calcOne, memberAgendas;
      if (typeof (member.get('score')) === 'number') {
        console.log('Already got score for ' + member.get('id'));
        return $.Deferred().resolve();
      }
      memberAgendas = new root.MemberAgenda({
        id: member.get('id')
      });
      calcOne = function() {
        return member.set('score', _.reduce(memberAgendas.get('agendas'), function(memo, agenda) {
          return memo += agendasInput[agenda.id] * agenda.score;
        }, 0));
      };
      return memberAgendas.fetch({
        success: calcOne
      });
    };
    return AppView;
  })();
  $(function() {
    root.appView = new root.AppView;
  });
}).call(this);
