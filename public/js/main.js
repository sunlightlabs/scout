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
    }
};