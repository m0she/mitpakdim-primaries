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
  root.JSONPCollection = (function() {
    __extends(JSONPCollection, Backbone.Collection);
    function JSONPCollection() {
      JSONPCollection.__super__.constructor.apply(this, arguments);
    }
    JSONPCollection.prototype.initialize = function(options) {
      if (options != null ? options.url : void 0) {
        return this.url = options.url;
      }
    };
    JSONPCollection.prototype.sync = function(method, model, options) {
      options.dataType = "jsonp";
      return Backbone.sync(method, model, options);
    };
    JSONPCollection.prototype.parse = function(response) {
      return response.objects;
    };
    return JSONPCollection;
  })();
  root.MemberList = (function() {
    __extends(MemberList, root.JSONPCollection);
    function MemberList() {
      MemberList.__super__.constructor.apply(this, arguments);
    }
    MemberList.prototype.model = root.Member;
    MemberList.prototype.url = "http://api.dev.oknesset.org/api/v2/member/?format=jsonp";
    return MemberList;
  })();
  root.TemplateView = (function() {
    __extends(TemplateView, Backbone.View);
    function TemplateView() {
      this.render = __bind(this.render, this);
      TemplateView.__super__.constructor.apply(this, arguments);
    }
    TemplateView.prototype.className = "member_instance";
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
    MemberView.prototype.template = function() {
      return _.template($("#member_template").html()).apply(null, arguments);
    };
    return MemberView;
  })();
  root.ListView = (function() {
    __extends(ListView, root.TemplateView);
    function ListView() {
      this.addAll = __bind(this.addAll, this);
      this.addOne = __bind(this.addOne, this);
      this.initialize = __bind(this.initialize, this);
      ListView.__super__.constructor.apply(this, arguments);
    }
    ListView.prototype.initialize = function() {
      if (this.options.collection) {
        this.options.collection.bind("add", this.addOne);
        this.options.collection.bind("reset", this.addAll);
        return this.options.collection.fetch();
      }
    };
    ListView.prototype.addOne = function(modelInstance) {
      var view;
      view = new this.options.itemView({
        model: modelInstance
      });
      return this.$el.append(view.render().$el);
    };
    ListView.prototype.addAll = function() {
      return this.options.collection.each(this.addOne);
    };
    return ListView;
  })();
  root.DropdownItem = (function() {
    __extends(DropdownItem, root.TemplateView);
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
      this.initialize = __bind(this.initialize, this);
      DropdownContainer.__super__.constructor.apply(this, arguments);
    }
    DropdownContainer.prototype.tagName = "select";
    DropdownContainer.prototype.initialize = function() {
      this.options.itemView = root.DropdownItem;
      return root.ListView.prototype.initialize.apply(this, arguments);
    };
    return DropdownContainer;
  })();
  root.AppView = (function() {
    __extends(AppView, Backbone.View);
    function AppView() {
      this.partyChange = __bind(this.partyChange, this);
      this.addAll = __bind(this.addAll, this);
      this.addOne = __bind(this.addOne, this);
      this.initialize = __bind(this.initialize, this);
      AppView.__super__.constructor.apply(this, arguments);
    }
    AppView.prototype.el = '#app_root';
    AppView.prototype.initialize = function() {
      this.memberList = new root.MemberList();
      this.memberList.bind("add", this.addOne);
      this.memberList.bind("reset", this.addAll);
      this.memberList.fetch();
      this.partyList = new root.DropdownContainer({
        collection: new root.JSONPCollection({
          model: root.MiscModel,
          url: "http://api.dev.oknesset.org/api/v2/party/?format=jsonp"
        })
      });
      this.$(".parties").append(this.partyList.$el);
      return this.partyList.$el.bind('change', this.partyChange);
    };
    AppView.prototype.addOne = function(member) {
      var view;
      console.log('Adding', member);
      view = new root.MemberView({
        model: member
      });
      return this.$(".members").append(view.render().$el);
    };
    AppView.prototype.addAll = function() {
      return this.memberList.each(this.addOne);
    };
    AppView.prototype.partyChange = function() {
      return console.log("Changed: ", this, arguments);
    };
    return AppView;
  })();
  $(function() {
    root.appView = new root.AppView;
  });
}).call(this);
