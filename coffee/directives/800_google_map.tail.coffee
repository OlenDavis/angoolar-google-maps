angoolar.addDirective class GoogleMap extends angoolar.BaseDirective
	$_name: 'GoogleMap'

	transclude: yes

	scope:
		apiKey         : '@'
		options        : "=?"
		center         : '=?' # must be an instance of either google.maps.LatLng or angoolar.LatLng
		zoom           : '=?'
		bounds         : '=?'
		currentLocation: '=?' # boolean - if true, center will be updated to the browser's current location (if possible)

	controller: class GoogleMapController extends angoolar.BaseDirectiveController
		$_name: 'GoogleMapController'

		$_dependencies: [
			'$q'
			'$log'
			'$compile'
			'$parse'
			angoolar.GoogleMapsApi
			angoolar.Geolocation
		]

		$defaultOptions:
			center: new angoolar.LatLng 34.0364327, -118.329335 # Los Angeles, CA
			zoom  : 10

		constructor: ->
			super

			unwatchApiKey = @$scope.$watch 'apiKey', =>
				@GoogleMapsApi.initialize @mapsReady, @$scope.apiKey
				unwatchApiKey()

				defaultPositionWatch = @Geolocation.watchPosition ( position ) =>
					defaultPositionWatch.$_clearWatch()
					unless @$scope.center
						@$scope.center = new angoolar.LatLng position.coords.latitude, position.coords.longitude

		mapsReady: =>
			@$scope.$watch 'options',                  @optionsChanged, yes
			@$scope.$watch 'center || options.center', @centerChanged
			@$scope.$watch 'zoom   || options.zoom',   @zoomChanged
			@$scope.$watch 'bounds || options.bounds', @boundsChanged
			@$scope.$watch 'currentLocation',          @currentLocationChanged

			unwatchMap = @$scope.$watch ( => @map ), =>
				if @map
					unwatchMap()
					@$openInfoWindows = new Array()
					google.maps.event.addListener @map, 'click', @closeInfoWindows
					@watchGoogleMapsExpression()

		optionsChanged: =>
			unless @map
				@map = new google.maps.Map @$element[ 0 ], angular.extend {}, @$defaultOptions, @$scope.options
			else
				@map.setOptions angular.extend {}, @$defaultOptions, @$scope.options

		centerChanged: ( center ) =>
			if center instanceof google.maps.LatLng or center instanceof angoolar.LatLng
				@map.panTo center

		zoomChanged: ( zoom ) => @map.setZoom zoom if zoom

		boundsChanged: ( bounds ) =>
			if bounds instanceof google.maps.LatLngBounds or bounds instanceof angoolar.LatLngBounds
				@map.panToBounds if bounds instanceof google.maps.LatLngBounds then bounds else bounds.getGoogleVersion()

		currentLocationChanged: =>
			if @$scope.currentLocation
				@$currentPositionWatch = @Geolocation.watchPosition ( position ) =>
					@$scope.center = new angoolar.LatLng position.coords.latitude, position.coords.longitude if @$scope.currentLocation
			else
				@$currentPositionWatch?.$_clearWatch()

		wholeRegex = /^\s*(with\s+marker\s+(?:options\s+([\s\S]+?)\s+)?(?:if\s+([\s\S]+?)\s+)?)?(with\s+info\s+window\s+(?:if\s+([\s\S]+?)\s+)?)?for\s+([\s\S]+?)\s*$/
		wholeErrorMessage = "Google Maps expression expected to be of the form '[with marker [options _marker_options_expression_] [if _marker_condition_expression_]] [with info window [if _info_window_condition_expression_]] for _ng_repeat_expression_' but got: "
		ngRepeatRegex = /^\s*([\s\S]+?)\s+in\s+([\s\S]+?)\s*$/
		ngRepeatLhsRegex = /^(?:([\$\w]+)|\(([\$\w]+)\s*,\s*([\$\w]+)\))$/
		ngRepeatErrorMessage = "'_item_' in '_item_ in _collection_' in '_ng_repeat_expression_' in 'marker [options _marker_options_expression_] [if _marker_condition_expression_] [with info window [if _info_window_condition_expression_]] for _ng_repeat_expression_' should be an identifier or '(_key_, _value_)' expression, but got: "
		watchGoogleMapsExpression: ->
			expression = @$attrs[ GoogleMap::$_makeName() ]
			return unless expression?.length

			matches = expression.match wholeRegex

			unless matches
				return @$log.error wholeErrorMessage + expression

			@withMarker                          = if matches[ 1 ] then yes else no
			@markerOptionsExpression             = matches[    2 ]
			@markerConditionalExpression         = matches[    3 ]
			@withInfoWindow                      = if matches[ 4 ] then yes else no
			@withInfoWindowConditionalExpression = matches[    5 ]
			ngRepeatExpression                   = matches[    6 ]

			unless @markerOptionsExpression
				ngRepeatMatches = ngRepeatExpression.match( ngRepeatRegex )?[ 1 ]?.match ngRepeatLhsRegex
				unless ngRepeatMatches
					return @$log.error ngRepeatErrorMessage + ngRepeatExpression
				@ngRepeatItemGetter = @$parse ngRepeatMatches[ 2 ] or ngRepeatMatches[ 1 ]
			# marker expression of the form "with marker [options _marker_options_expression_] [if _marker_condition_expression_] [with info window [if _info_window_condition_expression_]] for _ng_repeat_expression_"
			# The following are all examples of valid marker expressions:
			# ex01: "with marker options _marker_options_expression_ if _marker_condition_expression_ with info window if _info_window_condition_expression_ for _ng_repeat_expression_"
			# ex02: "for _ng_repeat_expression_"
			# ex03: "with marker for _ng_repeat_expression_"
			# ex04: "with marker options _marker_options_expression_ for _ng_repeat_expression_"
			# ex05: "with marker options _marker_options_expression_ if _marker_condition_expression_ for _ng_repeat_expression_"
			# ex06: "with marker if _marker_condition_expression_ for _ng_repeat_expression_"
			# ex07: "with marker with info window for _ng_repeat_expression_"
			# ex08: "with marker with info window if _info_window_condition_expression_ for _ng_repeat_expression_"
			# ex09: "with marker options _marker_options_expression_ with info window if _info_window_condition_expression_ for _ng_repeat_expression_"
			# ex10: "with marker options _marker_options_expression_ with info window for _ng_repeat_expression_"
			# ex11: "with marker options _marker_options_expression_ if _marker_condition_expression_ with info window for _ng_repeat_expression_"
			# etc.
			
			unless ngRepeatExpression
				return @$log.error wholeErrorMessage + expression

			@$element.append $googleMapsContentsElement = angular.element """
			<div
				style     ='display:none!important'
				ng-repeat =\"#{ ngRepeatExpression }\"
			>
				<div #{ angoolar.camelToDashes GoogleMapContent::$_makeName() }></div>
			</div>
			"""
			@$compile( $googleMapsContentsElement ) googleMapsContentsScope = @$scope.$parent.$new()

			@$scope.$on '$destroy', => googleMapsContentsScope.$destroy()

		closeInfoWindows: =>
			openInfoWindow.close() for openInfoWindow in @$openInfoWindows
			@$openInfoWindows.length = 0

		showInfoWindow: ( infoWindow, marker ) ->
			@closeInfoWindows()
			@$openInfoWindows.push infoWindow
			infoWindow.open @map, marker

angoolar.addDirective class GoogleMapContent extends angoolar.BaseDirective
	$_name: 'GoogleMapContent'

	$_requireParents: [ GoogleMap ]

	scope: yes

	controller: class GoogleMapContentController extends angoolar.BaseDirectiveController
		$_name: 'GoogleMapContentController'

		$_link: ->
			super

			@setupMarker()
			@setupInfoWindow()

		setupMarker: ->
			if @GoogleMapController.withMarker
				if @GoogleMapController.markerConditionalExpression
					@unwatchWithMarkerConditionalExpression = @$scope.$watch @GoogleMapController.markerConditionalExpression, ( @withMarker ) ->
						if withMarker
							@attachMarker()
						else
							@detachMarker()
				else
					@withMarker = yes
					@attachMarker()

				@$scope.$on '$destroy', @destroyMarker

		attachMarker: =>
			if @GoogleMapController.markerOptionsExpression
				@unwatchWithMarkerOptionsWatch = @$scope.$watch(
					@GoogleMapController.markerOptionsExpression

					( markerOptions ) =>
						if markerOptions # if the options expression evaluates to a promise, then it will be null till it's resolved
							actualMarkerOptions = angular.extend { position: @GoogleMapController.map.getCenter() }, markerOptions, map: @GoogleMapController.map
							if @marker
								@marker.setOptions actualMarkerOptions
							else
								@marker = new google.maps.Marker actualMarkerOptions

					yes
				)
			else
				@marker = new google.maps.Marker angular.extend { position: @GoogleMapController.map.getCenter() }, @GoogleMapController.ngRepeatItemGetter( @$scope ), map: @GoogleMapController.map

		detachMarker: =>
			@marker?.setMap null

		destroyMarker: =>
			@unwatchWithMarkerConditionalExpression?()
			@unwatchWithMarkerOptionsWatch?()
			@marker?.setMap null
			@marker = null

		setupInfoWindow: ->
			if @GoogleMapController.withInfoWindow
				@infoWindowScope = @$scope.$parent.$new()

				@GoogleMapController.$transclude @infoWindowScope, ( $infoWindowContents ) =>
					@$infoWindowElement = angular.element( '<div></div>' ).append $infoWindowContents
					@attachInfoWindow()

				@$scope.$on '$destroy', @destroyInfoWindow

		attachInfoWindow: =>
			@infoWindow = new google.maps.InfoWindow {
				position: @GoogleMapController.map.getCenter()
				content : @$infoWindowElement[ 0 ]
			}

			if @GoogleMapController.withInfoWindowConditionalExpression
				@unwatchInfoWindowConditionalExpressionWithMarker = @$scope.$watchGroup(
					[
						@GoogleMapController.withInfoWindowConditionalExpression
						( => @withMarker and @marker ) # since the marker's options may be a promise, just because @withMarker is true, doesn't mean the marker can be attached to
					]

					( args ) =>
						[ withInfoWindow, withMarker ] = args

						if withMarker # if with marker, then with info window indicates it's ABLE to be shown by clicking on the marker
							if withInfoWindow
								@attachInfoWindowToMarker()
							else
								@hideInfoWindow()
								@detachInfoWindowFromMarker()
						else # whereas if it's not with marker, then with info window indicates directly that it's shown or closed
							@detachInfoWindowFromMarker()
							if withInfoWindow
								@showInfoWindow()
							else
								@hideInfoWindow()
				)
			else if @GoogleMapController.withMarker
				@unwatchInfoWindowWithMarker = @$scope.$watch ( => @withMarker and @marker ), ( withMarker ) => # since the marker's options may be a promise, just because @withMarker is true, doesn't mean the marker can be attached to
					if withMarker # if with marker, then with info window indicates it's ABLE to be shown by clicking on the marker
						@attachInfoWindowToMarker()
					else
						@hideInfoWindow()
						@detachInfoWindowFromMarker()
			else
				@showInfoWindow()

		attachInfoWindowToMarker: ->
			@infoWindowListener = google.maps.event.addListener @marker, 'click', @showInfoWindow

		detachInfoWindowFromMarker: ->
			google.maps.event.removeListener @infoWindowListener if @infoWindowListener

		showInfoWindow: =>
			@GoogleMapController.showInfoWindow @infoWindow, if @withMarker then @marker else null

		hideInfoWindow: =>
			@infoWindow.close()

		destroyInfoWindow: =>
			@detachInfoWindowFromMarker()
			@unwatchInfoWindowWithMarker?()
			@unwatchInfoWindowConditionalExpressionWithMarker?()
			@infoWindowScope?.$destroy()
			@infoWindowScope = null
