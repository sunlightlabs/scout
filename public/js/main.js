$(function() {

  $("form.signup_form").submit(function() {
    var $elem = $(this).find("input.redirect");
    if (!$elem.val())
      $elem.val(window.location.pathname + window.location.hash);
    return true;
  });

  // anything being bound on something that can be pjax'ed 
  // needs to use the #contentWrapper as the parent
  $("#content").on("click", "a[data-pjax]", function() {
    Utils.pjax($(this).attr("href"), $(this).data("pjax"));
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

});

var NewSearch = {
  subscriptionTypes: function() {
    return ["federal_bills", "speeches", "state_bills", "regulations"];
  },

  // return a hash of subscription-specific filters
  // e.g. {"state_bills": {"state": "DC"}, "regulations": {"agency": "271"}}
  subscriptionOptions: function(types) {
    return {"state_bills": {"state": "DC"}};
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
    }
};