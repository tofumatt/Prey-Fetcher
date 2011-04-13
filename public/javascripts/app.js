(function($) {
	$().ready(function() {
		var ANIMATION_SPEED = 250,
		priorities = ['dm', 'favorite', 'mention', 'list', 'retweet'],
		priorityNames = {
			'-3': 'Off',
			'-2': 'Very Low',
			'-1': 'Low',
			'0': 'Normal',
			'1': 'High',
			'2': 'Emergency'
		};
		
		$('body').addClass('js');
		
		for (var i = 0; i < priorities.length; i++) {
			var selectedOption = $('#' + priorities[i] + '_priority option:selected');
			$('<input type="hidden" name="user[' + priorities[i] + '_priority]" id="user_' + priorities[i] + '-slider-value" data-priority="' + priorities[i] + '" />').appendTo('#twitter-options');
			$('#user_' + priorities[i] + '-slider').slider({
				max: 2,
				min: -3,
				step: 1,
				value: $(selectedOption).val(),
				slide: function(event, ui) {
					$('#user_' + $(ui.handle).data('for') + '-slider-value').val(ui.value);
					$(ui.handle).html('<span>' + priorityNames[ui.value] + '</span>');
					
					// Special mention stuff
					if ($(ui.handle).data('for') === 'mention') {
						if (ui.value == -3) {
							$('#mention-restriction').slideUp(ANIMATION_SPEED);
						} else {
							$('#mention-restriction').slideDown(ANIMATION_SPEED);
						}
					}
					
					// Special list stuff
					if ($(ui.handle).data('for') === 'list') {
						if (ui.value == -3) {
							$('#list-selector').slideUp(ANIMATION_SPEED);
						} else {
							$('#list-selector').slideDown(ANIMATION_SPEED);
						}
					}
				}
			}).children('a').data('for', priorities[i]);
			$('#user_' + priorities[i] + '-slider a.ui-slider-handle').html('<span>' + priorityNames[selectedOption.val()] + '</span>');
			
			$('#user_' + priorities[i] + '-slider-value').val($('#user_' + priorities[i] + '-slider').slider('value'));
			
			// Special mention stuff
			if (priorities[i] === 'mention' && selectedOption.val() == -3) {
				$('#mention-restriction').hide();
			}
			
			// Special list stuff
			if (priorities[i] === 'list' && selectedOption.val() == -3) {
				$('#list-selector').hide();
			}
		}
		
		$('.js-hide-parent').click(function(event) {
			$(this).parent().fadeOut(ANIMATION_SPEED);
			
			event.preventDefault();
		});
		
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
		
		// Tabs on the settings page
		if ($('body').hasClass('account')) {
			$('#tabs').tabs({
				select: function(event, ui) {
					if ($(ui.tab).attr('href') === '#account-options') {
						$('#user_submit-container').hide();
					} else {
						$('#user_submit-container').show();
					}
				}
			});
			
			$('#js-refresh_lists').click(function(event) {
				$('#list-form').submit();
			});
			
			$('#js-delete_account').click(function(event) {
				$('#delete-form').submit();
			});
		}
	});
})(jQuery);
