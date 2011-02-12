(function($) {
	$().ready(function() {
		var ANIMATION_SPEED = 250;
		
		$('body').addClass('js');
		
		// DMs on the Settings page
		$('#user_enable_dms').click(function(event) {
			$('#dm-priority-container').slideToggle(ANIMATION_SPEED);
		});
		if ($('#user_enable_dms:checked').length == 1)
			$('#dm-priority-container').show();
		
		// Mentions on the Settings page
		$('#user_enable_mentions').click(function(event) {
			$('#mention-priority-container').slideToggle(ANIMATION_SPEED);
		});
		if ($('#user_enable_mentions:checked').length == 1)
			$('#mention-priority-container').show();
		
		// Retweets on the Settings page
		$('#user_disable_retweets').click(function(event) {
			$('#retweet-priority-container').slideToggle(ANIMATION_SPEED);
		});
		if ($('#user_disable_retweets:checked').length == 1)
			$('#retweet-priority-container').show();
		
		// Lists on the Settings page
		$('#user_enable_list').click(function(event) {
			$('#list-container').slideToggle(ANIMATION_SPEED);
		});
		if ($('#user_enable_list:checked').length == 1)
			$('#list-container').show();
		
		// Reveal account switcher form
		$('#account-switcher-link').click(function(event) {
			$(this).blur();
			$('#account-switcher').slideToggle(ANIMATION_SPEED);
			
			event.preventDefault();
		});
		
		// Automatic form submission whenever a radio account
		// switcher is clicked
		$('#account-switcher input.radio-button').click(function(event) {
			$('#account-switcher').submit();
		});
		
	});
})(jQuery);
