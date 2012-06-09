$(function() {

  // login link should always point to redirect back
  $("a.login, a.logout").attr("href", $("a.login, a.logout").attr("href") + "?redirect=" + Utils.currentPath());

  $("#content").on("click", "a.untruncate", function() {
    var to_hide = $(this).parents(".truncated");
    var tag = to_hide.data("tag");
    $(".untruncated[data-tag=" + tag + "]").show();
    to_hide.hide();
    return false;
  });

  $("#content").on("click", 'a[data-pjax]', function() {
    Utils.pjax($(this).attr("href"), $(this).data("pjax"));
    return false;
  });

  $("#search_form .query_type input[type=radio]").change(function() {
    var queryType = $(".query_type input[type=radio]:checked").val();
    $("ul.search_explain").hide();
    $("ul.search_explain." + queryType).show();
    
    var placeholder = {
      simple: "Search for a keyword or phrase...",
      advanced: "Enter search terms..."
    }[queryType];

    $("#search_form input.query").attr("placeholder", placeholder);
  });

  $("form#search_form").submit(function() {
    var query = $(this).find("input.query").val();
    if (query) {
      // no empty string
      query = $.trim(query);

      // also ban plain wildcard searches
      query = query.replace(/^[^\w]*\*[^\w]*$/, '');
    }
    if (!query) return false;

    var queryType = $(".query_type input[type=radio]:checked").val();

    // if we are on the search page itself, this search box integrates with the filters
    if (typeof(goToSearch) != "undefined") {
      // These two values are cached in separate hidden fields, 
      // and not read live from the search box.
      // Editing the search query and switching from simple/advance
      // should only take effect when the user explicitly hits the search button.
      $(".filters input.query").val(query);
      $(".filters input.query_type").val(queryType);
      goToSearch();
    } 

    // we're on the home page, just do a bare search
    else {
      var url = "/search/all/" + encodeURIComponent(query);
      if (queryType == "advanced")
        url += "?query_type=" + queryType;
      window.location = url;
    }

    return false;
  });

});

var Utils = {
    log: function(msg) {
      if (typeof(console) != "undefined")
        console.log(msg);
    },

    pjax: function(href, container) {
      if (!container)
        container = "#center";

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
    currentPath: function(options) {
      var fullDomain = window.location.protocol + "//" + window.location.host;
      var queryString = window.location.href.replace(fullDomain + window.location.pathname, "");
      
      if (options) {
        if (queryString)
          queryString += "&" + $.param(options);
        else
          queryString = "?" + $.param(options);
      }

      return escape(window.location.pathname + queryString);
    }
};