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
		
		// Lists on the Settings page
		$('#user_enable_list').click(function(event) {
			$('#list-priority-container').slideToggle(ANIMATION_SPEED);
		});
		if ($('#user_enable_list:checked').length == 1)
			$('#list-priority-container').show();
		
	});
})(jQuery);