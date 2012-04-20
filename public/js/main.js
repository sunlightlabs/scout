$(function() {

  // login link should always point to redirect back
  $("a.login, a.logout").attr("href", $("a.login, a.logout").attr("href") + "?redirect=" + Utils.currentPath());

  $("#search_form input.query").focus(function() {
    $(".initialFilters").show();
  });

  // anything being bound on something that can be pjax'ed 
  // needs to use the #contentWrapper as the parent
  $("#content").on("click", "a[data-pjax]", function() {
    Utils.pjax($(this).attr("href"), $(this).data("pjax"));
    return false;
  });

  $("#content").on("click", "a.untruncate", function() {
    var to_hide = $(this).parent(".truncated");
    var tag = to_hide.data("tag");
    $(".untruncated[data-tag=" + tag + "]").show();
    to_hide.hide();
    return false;
  });

  $("form#search_form").submit(function() {
    var query = $(this).find("input.query").val();
    if (query) query = query.trim();
    if (!query) return;

    // gather what the initial types and filters should be
    var types = NewSearch.subscriptionTypes();
    var options = NewSearch.subscriptionOptions(types);

    var path = "/search/" + types.join(",") + "/" + encodeURIComponent(query);
    var queryString = $.param(options);
    if (queryString)
      path += "?" + queryString;

    window.location = path;
    
    return false;
  });

  $("form#search_form select.subscription_type").change(function() {
    $(".filter.initial").hide();
    $(".filter.initial." + $(this).val()).show();
  });

});

var NewSearch = {
  subscriptionTypes: function() {
    return [$("select.subscription_type").val()];
  },

  // return a hash of subscription-specific filters
  // e.g. {"state_bills": {"state": "DC"}, "regulations": {"agency": "271"}}
  subscriptionOptions: function(types) {
    return {};
  }
};

var Utils = {
    log: function(msg) {
        console.log(msg);
    },

    pjax: function(href, container) {
      if (!container)
        container = "#content";

      $.pjax({
          url: href,
          container: container,
          error: function() {
            Utils.log("Error asking for: " + href);
          }, 
          timeout: 5000
      });
    },

    // returns a path string suitable for redirects back to this location
    currentPath: function() {
      var queryString = window.location.href.replace(window.location.origin + window.location.pathname, "");
      return window.location.pathname + queryString;
    }
};