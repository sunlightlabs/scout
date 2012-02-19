$(function() {
  
  $("li.keyword").on("click", "button.remove", function() {
    var keyword_id = $(this).data("keyword_id");
    var keyword = $(this).data("keyword");
    
    if (confirm("Remove the saved search \"" + keyword + "\"?")) {
      $.post("/keyword/" + keyword_id, {
        _method: "delete"
      }, function(data) {
        console.log("Keyword by ID " + keyword_id + " removed.");
        $("#keyword-" + keyword_id).remove();
      })
      .error(function() {
        showError("Error removing saved search.");
      });
    }
    
    return false;
  });
  
  $("li.keyword").on("click", "h2 a", function() {
    var keyword = $(this).data("keyword");
    var keyword_id = $(this).data("keyword_id");
    
    $("input.query").val(keyword);

    // bold the word
    $("li.keyword").removeClass("current");
    $("li.keyword#keyword-" + keyword_id).addClass("current");

    startSearch(keyword, keyword_id);
    
    return false;
  });
  
  $("form#signup_form").submit(function() {
    $(this).find("input.redirect").val(window.location.pathname);
    return true;
  })

  $("form.search").submit(function() {
    var keyword = $("input.query").val();
    if (keyword) keyword = keyword.trim();
    if (!keyword) return;
    
    startSearch(keyword);
    return false;
  });

  $("#content").on("click", "ul.tabs li", function() {
    selectTab($(this).data("type"));
  });

  $("#content").on("click", "section.results div.tab button.refresh", function() {
    searchFor($(this).data("keyword"), null, $(this).data("type"));
  });

  $("#content").on("mouseover", "div.tab button.follow.unfollow", function() {
    $(this).html("Unfollow");
  }).on("mouseout", "button.follow.unfollow", function() {
    $(this).html("Following");
  });

  $("#content").on("click", "div.tab button.follow", function() {
    var subscription_type = $(this).data("type");
    var keyword = $("#keyword_searched").val();
    var keyword_id = $("#keyword_id").val();

    var button = $(this);

    // unfollow the subscription
    if (button.hasClass("unfollow")) {
      var subscription_id = button.data("subscription_id");

      showSave(subscription_type, "follow");
      $.post("/subscription/" + subscription_id, {
          _method: "delete"
        }, 
        function(data) {
          console.log("Subscription deleted: " + subscription_id);

          if (data.deleted_keyword)
            $("#keyword-" + data.keyword_id).remove();
          else {
            $("li.keyword#keyword-" + data.keyword_id).replaceWith(data.pane);
            $("li.keyword#keyword-" + data.keyword_id).addClass("current"); // must re-find to work
          }
          

          button.data("subscription_id", null);
        }
      )
      .error(function() {
        showError("Error deleting subscription.");
        showSave(subscription_type, "follow");
      });

    } else {
      showSave(subscription_type, "unfollow");
      $.post("/subscriptions", {
          keyword: keyword,
          keyword_id: keyword_id,
          subscription_type: subscription_type
        }, 
        function(data) {
          console.log("Subscription created: " + data.subscription_id + ", under keyword " + data.keyword_id);    
          button.data("subscription_id", data.subscription_id);

          if (data.new_keyword) {
            $("ul.subscriptions").prepend(data.pane);
            $("li.keyword#keyword-" + data.keyword_id).addClass("current");
            $("#keyword_id").val(data.keyword_id);
          } else {
            $("li.keyword#keyword-" + data.keyword_id).replaceWith(data.pane);
            $("li.keyword#keyword-" + data.keyword_id).addClass("current") // must re-find to work
          }
        }
      )
      .error(function() {
        showError("Error creating subscription.");
        showSave(subscription_type, "follow");
      });
    }

  });
  
});

function selectTab(type) {
  $("div.container div.tab").hide();
  $("div.container div.tab." + type).show();
  $("ul.tabs li").removeClass("active");
  $("ul.tabs li." + type).addClass("active");
}

function startSearch(keyword, keyword_id) {
  $("#keyword_searched").val(keyword);
  $("#keyword_id").val(keyword_id);

  $.get("/search/" + encodeURIComponent(keyword), function(html) {
    $("#content").html(html);
  }).error(function() {
    showError("Some error while asking for the results template, shouldn't happen.");
  });
}

function searchFor(keyword, keyword_id, subscription_type) {
  var tab = $("ul.tabs li." + subscription_type);
  var container = $("#results div.tab." + subscription_type);

  // reset elements inside tab
  tab.addClass("loading").removeClass("error");
  container.find("div.system_error").hide();
  container.find("div.results_list").html("");
  container.find("div.loading_container").show();
  container.find("div.header").hide();

  // remove any selected keyword
  if (!keyword_id)
    $("li.keyword").removeClass("current");
  
  $.get("/search/" + encodeURIComponent(keyword) + "/" + subscription_type, function(data) {

    tab.removeClass("loading");
    container.find("div.loading_container").hide();
    container.find("div.results_list").html(data.html);

    // error
    if (data.count < 0)  {
      tab.addClass("error");
    } else {
      container.find("div.header").show();
      container.find("div.header span.description").html(data.description);

      var button = $("div.tab." + subscription_type + " button.follow");
      if (keyword_id) {
        var subscriptions = $("li#keyword-" + keyword_id).data("subscriptions");
        if (subscriptions && subscriptions[subscription_type]) {
          button.data("subscription_id", subscriptions[subscription_type]);
          showSave(subscription_type, "unfollow");
        } else {
          button.data("subscription_id", null);
          showSave(subscription_type, "follow");
        }
      } else {
        button.data("subscription_id", null);
        showSave(subscription_type, "follow");
      }

      if (data.count == 0)
        tab.addClass("empty");
      
    }

  }).error(function() {
    tab.removeClass("loading");
    container.find("div.loading_container").hide();
    container.find("div.system_error").show();
  });
}

function showError(msg) {
    console.log(msg);
}

function showSave(subscription_type, status) {
  var button = $("div.tab." + subscription_type + " button.follow");
  
  button.removeClass("unfollow"); 
  
  if (status == "follow") { // default
    button.html("Follow");
  } else if (status == "unfollow") {
    button.addClass("unfollow");
    button.html("Following");
  }
}