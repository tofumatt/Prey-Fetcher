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
		
		// If the account switcher is available we'll setup some JS to handle it.
		if ($('#account-controls').length) {
			// Reveal account switcher form
			$('#account-controls-link').click(function(event) {
				$(this).blur();
				$('#account-controls').slideToggle(ANIMATION_SPEED);
				
				event.preventDefault();
			});
			
			// Automatic form submission whenever a radio account
			// switcher is clicked.
			var currentUserAccount = $('#account-switcher input.radio-button:checked').val();
			$('#account-switcher input.radio-button').click(function(event) {
				if ($(this).val() != currentUserAccount) {
					$('#account-switcher').submit();
				}
			});
		}
		
	});
})(jQuery);
