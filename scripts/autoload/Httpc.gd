class_name Httpc
extends Node

const base_url = "https://obbyrevivalproject.org/back/"

func _parse_headers(headers: Array) -> Dictionary:
	var result = {}
	for header: String in headers:
		var split = header.split(": ", false, 1)
		result.set(split[0], split[1])
	return result
	pass

# 0: success, 1: node error, 2: wrong, 3: server error, 4: server unavailable, 5: no cookie
func login(username: String, password: String) -> Array:
	var auth = GameManager.data.onlineAuth
	var httpNode = HTTPRequest.new()

	var body = {
		"username": username,
		"password": password
	}
	var headers = PackedStringArray([
		"User-Agent: ORPClient",
		"Content-Type: application/json"
	])

	var error = httpNode.request(
		base_url + "accountlogin.php",
		headers,
		HTTPClient.METHOD_POST,
		JSON.stringify(body)
	)

	if error != OK:
		httpNode.queue_free()
		return [1, "HTTP request failed with code %d" % error]

	var response = await httpNode.request_completed
	httpNode.queue_free()

	var result: int = response[0]
	var response_code: int = response[1]
	var response_headers = Array(response[2])

	if response_code == 401:
		return [2, "Incorrect username or password"]
	if response_code == 500:
		return [3, "Server error. Please try again later."]
	if response_code == 503:
		return [4, "Server unavailable. Please try again later."]

	var dict_headers = _parse_headers(response_headers)
	var raw_cookie: String = dict_headers.get("Set-Cookie", dict_headers.get("set-cookie", ""))

	if raw_cookie.is_empty():
		print("Server headers received: ", dict_headers)
		return [5, "Login succeeded but server sent no Set-Cookie header."]

	var set_cookie = raw_cookie.split("; ", false)
	return [0, set_cookie]

# DO NOT INCLUDE .php OR A PREFIX SLASH IN THE PATH
func request(scene, path: String, post: bool = false, body = null) -> Dictionary:
	var auth = GameManager.data.onlineAuth
	var url = base_url + path + ".php"
	var headers = PackedStringArray([
		"User-Agent: ORPClient",
		"Cookie: sesstoken=" + auth,
	])
	var request_body: String = ""

	if not post and body != null:
		var query_string = _format_body_data(body)
		if not query_string.is_empty():
			var delimiter = "&" if "?" in url else "?"
			url += delimiter + query_string

	elif post:
		headers.append("Content-Type: application/json")
		if body != null:
			request_body = JSON.stringify(body)

	var httpNode = HTTPRequest.new()
	scene.add_child(httpNode)
	
	var error = httpNode.request(
		url,
		headers,
		HTTPClient.METHOD_POST if post else HTTPClient.METHOD_GET,
		request_body
	)

	if error != OK:
		httpNode.queue_free()
		return {"success": false, "code": 0, "data": null, "error": "Request initiation failed (Code %d)" % error}

	var response = await httpNode.request_completed
	httpNode.queue_free()

	var result: int = response[0]
	var response_code: int = response[1]
	var response_body: PackedByteArray = response[3]

	if result != HTTPRequest.RESULT_SUCCESS:
		return {"success": false, "code": response_code, "data": null, "error": "Network error standard code: %d" % result}

	# Attempt to parse as JSON first
	var body_text = response_body.get_string_from_utf8()
	var json = JSON.new()
	var parse_err = json.parse(body_text)
	
	var parsed_data = json.data if parse_err == OK else response_body

	return {
		"success": response_code >= 200 and response_code < 300,
		"code": response_code,
		"data": parsed_data,
		"error": ""
	}


## Helper to format Dictionaries, Arrays, or Strings into key=val url-encoded strings safely
func _format_body_data(data) -> String:
	if data is String:
		return data
	elif data is Dictionary:
		var parts: PackedStringArray = []
		for key in data:
			var enc_key = str(key).uri_encode()
			var enc_val = str(data[key]).uri_encode()
			parts.append("%s=%s" % [enc_key, enc_val])
		return "&".join(parts)
	elif data is Array:
		return "&".join(data)
	return ""
