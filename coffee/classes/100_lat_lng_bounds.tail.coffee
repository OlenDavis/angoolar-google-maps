class angoolar.LatLngBounds
	constructor: ( @sw, @ne ) -> # sw and ne are LatLng instances

	getGoogleVersion: -> new google.maps.LatLngBounds @sw, @ne