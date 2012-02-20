$(function() {
  
  $("ul.subscriptions").on("click", "li.keyword button.remove", function() {
    var keyword_id = $(this).data("keyword_id");
    var keyword = $(this).data("keyword");
    
    if (confirm("Remove the saved search \"" + keyword + "\"?")) {
      $.post("/keyword/" + keyword_id, {
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
  
  $("ul.subscriptions").on("click", "li.keyword h2 a", function() {
    var keyword = $(this).data("keyword");
    
    startSearch(keyword);
    
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
    
    startSearch(keyword);
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
          console.log("Subscription deleted: " + subscription_id);

          if (data.deleted_keyword)
            keywordRemoved(keyword, keyword_id);
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
          keyword_id: keyword_id || "",
          subscription_type: subscription_type
        }, 
        function(data) {
          console.log("Subscription created: " + data.subscription_id + ", under keyword " + data.keyword_id);    
          button.data("subscription_id", data.subscription_id);

          if (data.new_keyword) {
            $("ul.subscriptions").prepend(data.pane);
            $("li.keyword#keyword-" + data.keyword_id).addClass("current");
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

    $.get("/search/" + keyword_slug + "/" + subscription_type, {page: next_page}, function(data) {
      page_container.remove();
      container.find("ul.items").append(data.html);
      container.data("current_page", next_page);
    });
  });
  
});

function selectTab(type) {
  if ($("ul.tabs li." + type).size() > 0) {
    $("div.container div.tab").hide();
    $("div.container div.tab." + type).show();
    $("ul.tabs li").removeClass("active");
    $("ul.tabs li." + type).addClass("active");
    window.location.hash = "#" + type;
  }
}

function startSearch(keyword) {
  $.pjax({
    url: "/search/" + encodeURIComponent(keyword),
    container: "#content",
    error: function() {
      showError("Some error while asking for the results template, shouldn't happen.");
    },
    timeout: 3000
  });
}

function searchFor(keyword, subscription_type) {
  var tab = $("ul.tabs li." + subscription_type);
  var container = $("#results div.tab." + subscription_type);

  // reset elements inside tab
  tab.addClass("loading").removeClass("error");
  container.find("div.system_error").hide();
  container.find("ul.items").html("");
  container.find("div.loading_container").show();
  container.find("div.header").hide();

  var keyword_slug = encodeURIComponent(keyword);
  $.get("/search/" + keyword_slug + "/" + subscription_type, function(data) {

    tab.removeClass("loading");
    container.find("div.loading_container").hide();
    container.find("ul.items").html(data.html);

    // error
    if (data.count < 0)  {
      tab.addClass("error");
    } else {
      container.find("div.header").show();
      container.find("div.header span.description").html(data.description);

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

function keywordRemoved(keyword, keyword_id) {
  console.log("Keyword by ID " + keyword_id + " removed.");
  $("#keyword-" + keyword_id).remove();
  delete user_subscriptions[encodeURIComponent(keyword)];
}