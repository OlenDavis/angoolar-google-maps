# # GoogleMap
# ## Example Usage (address-input.html)
# 	<div>
# 	
# 		<div
# 			t-lookahead-input  ="result in AddressInputController.$results"
# 			placeholder        ="{{ placeholder }}"
# 			items-changing     ="AddressInputController.searching"
# 			input-value        ="query"
# 			track-by           ="result.geometry.location.toString()"
# 			on-selected        ="AddressInputController.select( result )"
# 			is-focused         ="isFocused"
# 			item-active        ="resultActive({ result: result })"
# 			current-item       ="AddressInputController.$currentResult"
# 			input-class        ="'t-rounded'"
# 			hide-when-selected ="true"
# 			name               ="{{ name }}"
# 			ng-model-options   ="{
# 				updateOn: 'default blur',
# 				debounce: {
# 					default: 500,
# 					blur   : 0
# 				}
# 			}"
# 		>
# 			<div class="less lr-padded">
# 	
# 				<span ng-if="result.formatted_address">
# 					{{ result.formatted_address }}
# 				</span>
# 	
# 				<span
# 					class ="italic light-weight"
# 					ng-if ="! result.formatted_address"
# 				>
# 					No Address ({{ result.geometry.location.lat() }}, {{ result.geometry.location.lng() }})
# 				</span>
# 	
# 			</div>
# 		</div>
# 	
# 		<div
# 			class="shallow-shadow"
# 	
# 			t-fixed-proportion-div
# 			ratio-width  ="{{ ratioWidth }}"
# 			ratio-height ="{{ ratioHeight }}"
# 		>
# 			<div
# 				class        ="absolute tl whole-width whole-height"
# 				center       ="AddressInputController.$currentResult.geometry.location"
# 				t-google-map ="
# 					with marker options AddressInputController.getMarkerOptions( result )
# 					with info window
# 					for result in AddressInputController.$results track by AddressInputController.getTrackBy( result )
# 				"
# 			>
# 				<span ng-click="AddressInputController.select( result )">
# 	
# 					<span ng-if="result.formatted_address">
# 						{{ result.formatted_address }}
# 					</span>
# 	
# 					<span
# 						class ="italic light-weight"
# 						ng-if ="! result.formatted_address"
# 					>
# 						No Address ({{ result.geometry.location.lat() }}, {{ result.geometry.location.lng() }})
# 					</span>
# 	
# 				</span>
# 			</div>
# 		</div>
# 	
# 	</div>

# ## The GoogleMap Directive
angoolar.addDirective class GoogleMap extends angoolar.BaseDirective
	$_name: 'GoogleMap'

	# #### Transclude: true
	# So we're transcluding.
	transclude: yes

	# ### Scope Attributes
	# All these scope attributes are just gravy; not really necessary or integral to the meat and
	# bones of the directive. More could and should be added, or they could all be eliminated for
	# simplicity's sake.
	scope:
		apiKey         : '@'
		options        : "=?"
		# must be an instance of either google.maps.LatLng or angoolar.LatLng
		center         : '=?'
		zoom           : '=?'
		bounds         : '=?'
		# boolean - if true, center will be updated to the browser's current location (if possible)
		currentLocation: '=?'

	# ## The GoogleMap's Controller
	controller: class GoogleMapController extends angoolar.BaseDirectiveController
		$_name: 'GoogleMapController'

		# #### Injected Angular Dependencies
		$_dependencies: [
			'$q'
			'$log'
			'$compile'
			'$parse'
			angoolar.GoogleMapsApi
			angoolar.Geolocation
		]

		# #### Map Default Options
		$defaultOptions:
			center: new angoolar.LatLng 34.0364327, -118.329335 # Los Angeles, CA
			zoom  : 10

		# #### Controller Initialization
		# * First, we wait for the apiKey
		# 	* only the first time (since we can't load the API multiple times)
		constructor: ->
			super

			unwatchApiKey = @$scope.$watch 'apiKey', =>
				# * This will call @mapsReady when the API has been loaded
				@GoogleMapsApi.initialize @mapsReady, @$scope.apiKey
				unwatchApiKey()

				defaultPositionWatch = @Geolocation.watchPosition ( position ) =>
					defaultPositionWatch.$_clearWatch()
					unless @$scope.center
						@$scope.center = new angoolar.LatLng position.coords.latitude, position.coords.longitude

		# * This will be called when the Google Maps API has been loaded, then:
		# 	* setup all the substantive $watch's for the map's scope attributes
		# 		* options - *this is the most important, because when the options is evaluated, then @optionsChanged will be called, and the map itself will be made.*
		# 		* center - this will allow the user of the directive to both find out where the center of the map is, and update the center of the map.
		# 		* zoom - ditto for the zoom of the map
		# 		* bounds - ditto for the bounds of the map
		# 		* currentLocation - this simply indicates whether or not the map's center should be changed to the current location whenever the browser's Geolocation changes (and only when it changes - so the user of the directive can still change the center of the map until the browser's location changes). Note too, that the map will always try to get the current location of the browser once to initialize its center to the user's current location upon loading; and that happens even without currentLocation being truthy.
		mapsReady: =>
			@$scope.$watch 'options',                  @optionsChanged, yes
			@$scope.$watch 'center || options.center', @centerChanged
			@$scope.$watch 'zoom   || options.zoom',   @zoomChanged
			@$scope.$watch 'bounds || options.bounds', @boundsChanged
			@$scope.$watch 'currentLocation',          @currentLocationChanged

			# * *¡Important!* This is where the map is really turned on: where we call *watchGoogleMapsExpression*, and:
			#	* the hash of open info windows is initialized
			#	* the map's click event listener that closes any open info windows is registered
			unwatchMap = @$scope.$watch ( => @map ), =>
				if @map
					unwatchMap()
					@$openInfoWindows = new Array()
					google.maps.event.addListener @map, 'click', @closeInfoWindows
					@watchGoogleMapsExpression()

		# #### Scope Attribute Listeners/Usage
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

		# ## The Meat of the GoogleMap
		# ### The GoogleMap Expression Processing
		# This regex will break down the GoogleMap expression down into all its parts.
		wholeRegex = /^\s*(with\s+marker\s+(?:options\s+([\s\S]+?)\s+)?(?:if\s+([\s\S]+?)\s+)?)?(with\s+info\s+window\s+(?:if\s+([\s\S]+?)\s+)?)?for\s+([\s\S]+?)\s*$/
		wholeErrorMessage = "Google Maps expression expected to be of the form '[with marker [options _marker_options_expression_] [if _marker_condition_expression_]] [with info window [if _info_window_condition_expression_]] for _ng_repeat_expression_' but got: "
		# These two regexes are for processing the ngRepeat expression; the reason we would need
		# this is if the user of the directive decided not to use [with marker...] or [with info
		# window...], which are optional for a reason: in that case, we want to just use the values
		# iterated over by the ngRepeat expression *as* the marker options, and use info windows for
		# each marker.
		ngRepeatRegex = /^\s*([\s\S]+?)\s+in\s+([\s\S]+?)\s*$/
		ngRepeatLhsRegex = /^(?:([\$\w]+)|\(([\$\w]+)\s*,\s*([\$\w]+)\))$/
		ngRepeatErrorMessage = "'_item_' in '_item_ in _collection_' in '_ng_repeat_expression_' in 'marker [options _marker_options_expression_] [if _marker_condition_expression_] [with info window [if _info_window_condition_expression_]] for _ng_repeat_expression_' should be an identifier or '(_key_, _value_)' expression, but got: "

		# marker expression of the form `with marker [options _marker_options_expression_] [if _marker_condition_expression_] [with info window [if _info_window_condition_expression_]] for _ng_repeat_expression_`
		#
		# The following are all examples of valid marker expressions:
		#
		# ex01: `with marker options _marker_options_expression_ if _marker_condition_expression_ with info window if _info_window_condition_expression_ for _ng_repeat_expression_`
		#
		# ex02: `for _ng_repeat_expression_`
		#
		# ex03: `with marker for _ng_repeat_expression_`
		#
		# ex04: `with marker options _marker_options_expression_ for _ng_repeat_expression_`
		#
		# ex05: `with marker options _marker_options_expression_ if _marker_condition_expression_ for _ng_repeat_expression_`
		#
		# ex06: `with marker if _marker_condition_expression_ for _ng_repeat_expression_`
		#
		# ex07: `with marker with info window for _ng_repeat_expression_`
		#
		# ex08: `with marker with info window if _info_window_condition_expression_ for _ng_repeat_expression_`
		#
		# ex09: `with marker options _marker_options_expression_ with info window if _info_window_condition_expression_ for _ng_repeat_expression_`
		#
		# ex10: `with marker options _marker_options_expression_ with info window for _ng_repeat_expression_`
		#
		# ex11: `with marker options _marker_options_expression_ if _marker_condition_expression_ with info window for _ng_repeat_expression_`
		#
		# etc.

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
