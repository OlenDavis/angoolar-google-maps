angoolar.addFactory class angoolar.GoogleMapsApi extends angoolar.BaseFactory
	$_name: 'GoogleMapsApi'

	$_dependencies: [ '$q' ]

	constructor: ->
		super

		@$geocoderResultsCache  = {} # keys are GeocoderRequest objects stringified, values are the GeocoderResult arrays for each such request

	initialize: ( callback, apiKey, sensor = true ) ->
		if google?.maps?
			@$promise = @$q.when google.maps
		else unless @$promise?
			deferred = @$q.defer()
			@$promise = deferred.promise

			internalCallback = "GoogleMapsApiCallback#{ ( '' + Math.random() ).slice 2 }"
			window[ internalCallback ] = -> deferred.resolve google.maps

			script = document.createElement 'script'
			script.type = 'text/javascript'
			script.src = "https://maps.googleapis.com/maps/api/js?callback=#{ internalCallback }&sensor=#{ sensor }"
			if apiKey
				script.src += "&key=#{ apiKey }"

			$document = angular.element document
			if document.readyState is 'interactive' or document.readyState is 'complete'
				$document.append script
			else
				$document.bind 'ready', -> $document.append script
		
		@$promise.then ( maps ) ->
			callback? maps
			maps

	geocodeAddress        : ( address ) -> @geocode { address: address }
	geocodeAddressToFirst : ( address ) -> @geocode { address: address }, ( results ) -> results[ 0 ]
	geocodeAddressToLatLng: ( address ) -> @geocode { address: address }, ( results ) -> results[ 0 ].geometry.location

	geocode: ( geocoderRequest, extractResult = ( results ) -> results ) -> # returns a promise that resolves to the first/top result (as extracted from it by the extractResult function) or is rejected with the failure status
		@initialize().then =>
			if cachedResults = @$geocoderResultsCache[ JSON.stringify geocoderRequest ]
				return @$q.when extractResult cachedResults

			@$geocoder = @$geocoder or new google.maps.Geocoder()

			deferred = @$q.defer()
			@$geocoder.geocode geocoderRequest, ( results, status ) =>
				if status is google.maps.GeocoderStatus.OK
					@$geocoderResultsCache[ JSON.stringify geocoderRequest ] = results
					deferred.resolve extractResult results
				else
					deferred.reject status

			deferred.promise