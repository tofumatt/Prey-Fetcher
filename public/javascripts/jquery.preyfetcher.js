(function($) {
	$().ready(function() {
		var anim_speed = 500;
		
		$('body').addClass('js');
		
		$('#user_enable_dms').click(function(event) {
			$('#dm-priority-container').slideToggle(anim_speed);
		});
		if ($('#user_enable_dms:checked').length == 1)
			$('#dm-priority-container').show();
		
		$('#user_enable_mentions').click(function(event) {
			$('#mention-priority-container').slideToggle(anim_speed);
		});
		if ($('#user_enable_mentions:checked').length == 1)
			$('#mention-priority-container').show();
		
	});
})(jQuery);