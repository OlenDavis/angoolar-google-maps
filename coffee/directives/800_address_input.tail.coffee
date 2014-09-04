angoolar.addDirective class AddressInput extends angoolar.BaseTemplatedDirective
	$_name: 'AddressInput'

	scope:
		# This expression will be evaluated when a submission is selected with a context with that
		# submission as 'submission' on it. See comment on onSelected in the LookaheadInput
		# directive: If the expression results in a promise, if that promise is resolved, it will empty the
		# input and hide the results. If it is rejected, the results will remain visible with the
		# last selected submission still selected.
		onSelected  : '&'
		query       : "=?#{ @::$_makeName() }"
		allResults  : '=?'
		isFocused   : '=?'
		resultActive: '&'
		placeholder : '@'
		ratioWidth  : '@'
		ratioHeight : '@'
		name        : '@'

	scopeDefaults:
		placeholder: 'Address Search'
		ratioWidth : 16
		ratioHeight: 9

	controller: class AddressInputController extends angoolar.BaseDirectiveController
		$_name: 'AddressInputController'

		$_dependencies: [ '$q', angoolar.GoogleMapsApi ]

		constructor: ->
			super

			@$scope.$watch 'query', @doQuery

			@$scope.$watch 'AddressInputController.$results', ( results ) => @$scope.allResults = results

		doQuery: ( query ) =>
			return @$results = null unless query
			
			@searching = yes
			@$results = @GoogleMapsApi.geocodeAddress( query ).then(
				( @$results ) =>
			).finally => @searching = no

		getMarkerOptions: ( result ) ->
			if result.geometry
				position: result.geometry.location
				title   : result.formatted_address
				visible : yes
			else
				visible: no

		idHack = 0
		getTrackBy: ( result ) ->
			result?.geometry?.location.toString() or ++idHack

		select: ( result ) ->
			address_components = {}
			if result.address_components?
				for address_component in result.address_components
					address_components[ address_component.types[ 0 ] ] =
						long_name : address_component.long_name
						short_name: address_component.short_name

			@$scope.query = result.formatted_address or "#{ result.geometry.location.lat() },#{ result.geometry.location.lng() }"
			@$scope.onSelected
				'result'            : result
				'address_components': address_components
			@$scope.isFocused = no