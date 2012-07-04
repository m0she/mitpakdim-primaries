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
  root.MemberList = (function() {
    __extends(MemberList, Backbone.Collection);
    function MemberList() {
      MemberList.__super__.constructor.apply(this, arguments);
    }
    MemberList.prototype.model = root.Member;
    MemberList.prototype.url = "http://api.dev.oknesset.org/api/v2/member/?format=jsonp";
    MemberList.prototype.sync = function(method, model, options) {
      options.dataType = "jsonp";
      return Backbone.sync(method, model, options);
    };
    MemberList.prototype.parse = function(response) {
      return response.objects;
    };
    return MemberList;
  })();
  root.MemberView = (function() {
    __extends(MemberView, Backbone.View);
    function MemberView() {
      this.render = __bind(this.render, this);
      MemberView.__super__.constructor.apply(this, arguments);
    }
    MemberView.prototype.template = function() {
      return _.template($("#member_template").html()).apply(null, arguments);
    };
    MemberView.prototype.render = function() {
      console.log("t: ", this.template(this.model.toJSON()), "el:", this.$el);
      this.$el.html(this.template(this.model.toJSON()));
      console.log("z: ", this, "z html", this.$el.html());
      return this;
    };
    return MemberView;
  })();
  root.AppView = (function() {
    __extends(AppView, Backbone.View);
    function AppView() {
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
      return this.memberList.fetch();
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
    return AppView;
  })();
  $(function() {
    root.appView = new root.AppView;
  });
}).call(this);
