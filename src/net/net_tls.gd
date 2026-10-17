class_name NetTls
extends RefCounted
## The encryption of the connections between the games and a dedicated
## server (multiplayer, step 5): ENet over DTLS. The server proves nothing
## of who it is (its certificate is its own, made the first time it starts:
## `server_options`, kept in its data folder, FOLDER), but nothing sent can
## be read on the way any more: an account's secret, the chat, the world.
## The games take whatever certificate the server shows
## (`client_options`).

## Where a server keeps its key and certificate (in its data folder).
const FOLDER := "tls"
const KEY_FILE := "server.key"
const CERTIFICATE_FILE := "server.crt"
## The certificate's name, and how long it lasts (years).
const SUBJECT := "CN=Leguitz server,O=Leguitz,C=FR"
const YEARS := 20
const KEY_BITS := 2048


## A server's options: its key and certificate from `data_dir` (made and
## written there the first time; "": made for this run only).
static func server_options(data_dir := "") -> TLSOptions:
	var folder := data_dir.path_join(FOLDER) if data_dir != "" else ""
	var key := CryptoKey.new()
	var certificate := X509Certificate.new()
	if folder != "" and _load(folder, key, certificate):
		return TLSOptions.server(key, certificate)
	var crypto := Crypto.new()
	key = crypto.generate_rsa(KEY_BITS)
	certificate = crypto.generate_self_signed_certificate(key, SUBJECT, _date(0), _date(YEARS))
	if folder != "":
		DirAccess.make_dir_recursive_absolute(folder)
		key.save(folder.path_join(KEY_FILE))
		certificate.save(folder.path_join(CERTIFICATE_FILE))
	return TLSOptions.server(key, certificate)


## A game's options: any certificate is taken (a server's own is never
## signed by anyone the game knows), the connection is encrypted all the
## same.
static func client_options() -> TLSOptions:
	return TLSOptions.client_unsafe()


static func _load(folder: String, key: CryptoKey, certificate: X509Certificate) -> bool:
	var key_path := folder.path_join(KEY_FILE)
	var certificate_path := folder.path_join(CERTIFICATE_FILE)
	if not (FileAccess.file_exists(key_path) and FileAccess.file_exists(certificate_path)):
		return false
	return key.load(key_path) == OK and certificate.load(certificate_path) == OK


## A date `years` from now, as certificates write them (YYYYMMDDhhmmss).
static func _date(years: int) -> String:
	var now := Time.get_datetime_dict_from_system(true)
	return "%04d%02d%02d000000" % [int(now["year"]) + years, now["month"], now["day"]]
