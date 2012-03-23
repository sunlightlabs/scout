$(function() {

  $("#user_prefs").submit(function() {
    var values = $.param({_method: "put"}) + "&" + $("form#user_prefs").serialize();
    $.post("/user", values, function(data) {
      $("p.user_results").html("Updated successfully.");
    }).error(function(xhr) {
      console.log(xhr.responseText);
      var data = $.parseJSON(xhr.responseText);
      $("p.user_results").html(data.error);
      showError("Error updating user.");
    });

    return false;
  })
  
  $("ul.subscriptions").on("click", "li.keyword button.remove", function() {
    var keyword_id = $(this).data("keyword_id");
    var keyword = $(this).data("keyword");
    
    if (confirm("Remove the saved search \"" + keyword + "\"?")) {
      $.post("/interest/" + keyword_id, {
        _method: "delete"
      }, function(data) {
        keywordRemoved(keyword, keyword_id);
      })
      .error(function() {
        showError("Error removing saved search.");
      });
    }
    
    return false;
  });
  
  $("ul.subscriptions").on("click", "li.keyword.search h2 a", function() {
    var keyword = $(this).data("keyword");
    
    loadContent("/search/" + encodeURIComponent(keyword));
    
    return false;
  });

  $("ul.subscriptions").on("click", "li.keyword.item h2 a", function() {
    var keyword = $(this).data("keyword");
    var keyword_type = $(this).data("keyword_type");

    loadContent("/" + keyword_type + "/" + keyword);

    return false;
  });  
  
  $("form#signup_form").submit(function() {
    $(this).find("input.redirect").val(window.location.pathname + window.location.hash);
    return true;
  })

  $("form.search").submit(function() {
    var keyword = $("input.query").val();
    if (keyword) keyword = keyword.trim();
    if (!keyword) return;
    
    loadContent("/search/" + encodeURIComponent(keyword));
    
    return false;
  });

  $("#content").on("click", "ul.tabs li", function() {
    selectTab($(this).data("type"));
  });

  $("#content").on("click", "section.results div.tab button.refresh", function() {
    searchFor($(this).data("keyword"), $(this).data("type"));
  });

  $("#content").on("mouseover", "div.tab button.follow.unfollow", function() {
    $(this).html("Unfollow");
  }).on("mouseout", "button.follow.unfollow", function() {
    $(this).html("Following");
  });

  $("#content").on("mouseover", "button.track.untrack", function() {
    $(this).html("Unfollow");
  }).on("mouseout", "button.track.untrack", function() {
    $(this).html("Following");
  });

  $("#content").on("click", "section.show button.track", function() {
    var item_type = $(this).data("item_type");
    var item_id = $(this).data("item_id");
    var button = $(this);

    if (button.hasClass("untrack")) {
      var keyword_id = button.data("keyword_id");
      button.html("Follow").removeClass("untrack");
      $.post("/interest/untrack", {
        _method: "delete",
        interest_id: keyword_id
      }, function(data) {
        showError("Tracking interest deleted: " + keyword_id);
          $("#keyword-" + keyword_id).remove();
          button.data("keyword_id", null);
      }).error(function() {
        showError("Error deleting tracking interest: " + keyword_id);
        button.html("Unfollow").addClass("untrack");
      });
    } else {
      button.html("Unfollow").addClass("untrack");
      $.post("/interest/track", {
          item_id: item_id,
          interest_type: item_type
        }, 
        function(data) {
          showError("Tracking interest created: " + data.interest_id);
          button.data("keyword_id", data.interest_id);
          $("ul.subscriptions").prepend(data.pane);
          $("li.keyword#keyword-" + data.interest_id).addClass("current");
        }
      ).error(function() {
        showError("Error tracking item.");
        button.html("Follow").removeClass("untrack");
      });

    }
  });

  $("#content").on("click", "div.tab button.follow", function() {
    var subscription_type = $(this).data("type");
    var keyword = $(this).data("keyword");
    var keyword_slug = encodeURIComponent(keyword);
    var keyword_id = user_subscriptions[keyword_slug] ? user_subscriptions[keyword_slug].keyword_id : null;
    
    var button = $(this);

    // unfollow the subscription
    if (button.hasClass("unfollow")) {
      var subscription_id = button.data("subscription_id");

      showSave(subscription_type, "follow");
      $.post("/subscription/" + subscription_id, {
          _method: "delete"
        }, 
        function(data) {
          showError("Subscription deleted: " + subscription_id);

          if (data.deleted_interest)
            keywordRemoved(keyword, keyword_id);
          else {
            $("li.keyword#keyword-" + data.interest_id).replaceWith(data.pane);
            $("li.keyword#keyword-" + data.interest_id).addClass("current"); // must re-find to work
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
          interest: keyword,
          interest_id: keyword_id || "",
          subscription_type: subscription_type
        }, 
        function(data) {
          showError("Subscription created: " + data.subscription_id + ", under interest " + data.interest_id);    
          button.data("subscription_id", data.subscription_id);

          if (data.new_interest) {
            $("ul.subscriptions").prepend(data.pane);
            $("li.keyword#keyword-" + data.interest_id).addClass("current");
          } else {
            $("li.keyword#keyword-" + data.interest_id).replaceWith(data.pane);
            $("li.keyword#keyword-" + data.interest_id).addClass("current") // must re-find to work
          }
        }
      )
      .error(function() {
        showError("Error creating subscription.");
        showSave(subscription_type, "follow");
      });
    }

  });

  $("#content").on("click", "ul.items button.page", function() {
    var keyword = $(this).data("keyword");
    var keyword_slug = encodeURIComponent(keyword);
    var subscription_type = $(this).data("type");
    var container = $("#results div.tab." + subscription_type);

    var next_page = container.data("current_page") + 1;

    var page_container = $(this).parent();
    var loader = page_container.find("p");
    $(this).remove();
    loader.show();

    var subscription_data = subscriptionData(subscription_type);
    subscription_data.page = next_page;

    $.get("/items/" + keyword_slug + "/" + subscription_type, subscription_data, function(data) {
      page_container.remove();
      container.find("ul.items").append(data.html);
      container.data("current_page", next_page);
    });
  });

  $("#content").on("click", "ul.items section.more a.landing", function() {
    loadContent($(this).attr("href"));
    return false;
  });
  
});

function loadContent(href) {
  $.pjax({
      url: href,
      container: "#content",
      error: function() {
        showError("Error asking for: " + href);
      },
      timeout: 10000
    });
}

function selectTab(type) {
  if ($("ul.tabs li." + type).size() > 0) {
    $("div.container div.tab").hide();
    $("div.container div.tab." + type).show();
    $("ul.tabs li").removeClass("active");
    $("ul.tabs li." + type).addClass("active");
    window.location.hash = "#" + type;
  }
}

function subscriptionData(subscription_type) {
  var container = $("#results div.tab." + subscription_type);
  var subscription_data = {};
  container.find("div.filter .subscription_data").each(function(i, elem) {
    subscription_data["subscription_data[" + $(elem).prop("name") + "]"] = $(elem).val();
  });
  return subscription_data;
}

function searchFor(keyword, subscription_type) {
  var tab = $("ul.tabs li." + subscription_type);
  var container = $("#results div.tab." + subscription_type);

  // reset elements inside tab
  tab.addClass("loading").removeClass("error");
  container.find("div.system_error").hide();
  container.find("ul.items").html("");
  container.find("div.loading_container").show();
  container.find("div.developer.search").hide();
  container.find("header").hide();
  container.find("div.logged_out").hide();
  container.find("div.filter").hide();

  // assemble hash of any filter options
  var subscription_data = subscriptionData(subscription_type);

  var keyword_slug = encodeURIComponent(keyword);
  $.get("/items/" + keyword_slug + "/" + subscription_type, subscription_data, function(data) {

    tab.removeClass("loading");
    container.find("div.loading_container").hide();
    container.find("ul.items").html(data.html);

    if (data.search_url) {
      container.find("div.developer.json.search").show().find("a").attr("href", data.search_url);
    }

    // error
    if (data.count < 0)  {
      tab.addClass("error");
    } else {
      container.find("header").show();
      container.find("div.logged_out").show();
      container.find("div.filter").show();
      container.find("header span.description").html(data.description);

      var button = $("div.tab." + subscription_type + " button.follow");

      var subscriptions = user_subscriptions[keyword_slug]; // global!
      if (subscriptions && subscriptions.subscriptions[subscription_type]) {
        button.data("subscription_id", subscriptions.subscriptions[subscription_type]);
        showSave(subscription_type, "unfollow");
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

function keywordRemoved(interest, interest_id) {
  showError("Interest by ID " + interest_id + " removed.");
  $("#keyword-" + interest_id).remove();
  delete user_subscriptions[encodeURIComponent(interest)];
}