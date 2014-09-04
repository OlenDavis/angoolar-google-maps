class angoolar.LatLng extends angoolar.BaseResource
	$_name: 'LatLng'

	constructor: ( @lat, @lng ) ->

	$_fromJson: ( json ) ->
		unless angular.isString json
			throw new Error "LatLng expected its JSON to be a string; instead it was #{ json }."

		[ @lat, @lng ] = json.split ','

		@

	$_toJson: -> "#{ @lat },#{ @lng }"