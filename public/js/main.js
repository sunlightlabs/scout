$(function() {

  $("form.signup_form").submit(function() {
    var $elem = $(this).find("input.redirect");
    if (!$elem.val())
      $elem.val(window.location.pathname + window.location.hash);
    return true;
  });

});



var Utils = {
    log: function(msg) {
        console.log(msg);
    },

    pjax: function(href, container) {
      if (!container)
        container = "#contentWrapper";

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