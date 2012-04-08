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

});



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