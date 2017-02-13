#!/usr/bin/env bash

cd -- "/" || exit 1

function __mock_httpd_cleanup () {
	local PORT="${1:-80}"
	local PID

	if [[ -f /var/run/mock-httpd-"${PORT}".pid ]]; then
		PID="$(
			cat /var/run/mock-httpd-${PORT}.pid
		)"

		if [[ -n ${PID} ]]; then
			PID="$(
				ps \
					-o pid= \
					-p ${PID} \
				|| true
			)"
		fi

		if [[ -n ${PID} ]]; then
			{ kill ${PID}; } || true
		fi
	fi
}

function __mock_httpd_usage ()
{
	cat <<-USAGE
	Usage: $(basename ${0}) [OPTIONS]
	       $(basename ${0}) [{-h|--help}]

	Use to mock a web server response. This is not a full server implementation, 
	it responds to all GET requests with the same response.

	Options:
	  -h, --help                 Show this help and exit.
	  --cache-control            Set the Cache-Control response header.
	  -C, --cert=PATH            Path to a SSL/TLS certicate.
	  -c, --content=CONTENT      Set the content for the response body. The 
	                             value must be appropriate for the selected 
	                             content-type. For text/html the content must be
	                             valid HTML to be inserted into the <body>. For 
	                             raw:text/html the value must include the full 
	                             HTML response (including headers).
	  --opts='OPTIONS'           Options for socat; defaults to '-T 1'.
	  -t, --content-type=TYPE    Set the Content-Type for the response. 
	                             Valid content-types: 
	                               - raw:text/html
	                               - raw:text/plain
	                               - text/html (default)
	                               - text/plain 
	  -p, --port=PORT            Set the port to bind to; defaults to 80.
	  -P, --protocol=PROTOCOL    Set the protocol; http (default) or https.
	  -q, --quiet                Suppress all output.
	  -s, --status=STATUS        HTTP status; defaults to '200 OK'.
	USAGE

	exit 1
}

function mock_httpd () {
	local ADDRESS_LEFT=""
	local PORT="80"
	local PROTOCOL="http"
	local CACHE_CONTROL="no-cache"
	local CERTIFICATE_PATH=""
	local CONTENT=""
	local CONTENT_TYPE="text/html"
	local SOCAT_OPTIONS="-T 1"
	local STATUS="200 OK"
	local QUIET=false
	local openssl
	local socat

	if command -v openssl &> /dev/null; then
		printf -v \
			openssl \
			-- '%s' \
			"$(
				command -v \
					openssl
			)"
	else
		printf -- "ERROR: %s" \
			"Missing required openssl package." 1>&2
		exit 1
	fi

	if command -v socat &> /dev/null; then
		printf -v \
			socat \
			-- '%s' \
			"$(
				command -v \
					socat
			)"
	else
		printf -- "ERROR: %s" \
			"Missing required socat package." 1>&2
		exit 1
	fi

	if [[ ${#} -eq 0 ]]; then
		__mock_httpd_usage
	fi

	while [[ ${#} -gt 0 ]]; do
		case "${1}" in
			-h|--help)
				__mock_httpd_usage
				break
				;;
			--cache-control=*)
				if [[ -z ${1#*=} ]]; then
					printf -- "ERROR: %s" \
						"Empty option value (${1})" 1>&2
					__mock_httpd_usage
				fi
				CACHE_CONTROL="${1#*=}"
				shift 1
				;;
			-C)
				if [[ -z ${2:-} ]]; then
					printf -- "ERROR: %s" \
						"Empty option value (${1})" 1>&2
					__mock_httpd_usage
				fi
				CERTIFICATE_PATH="${2}"
				shift 2
				;;
			--cert=*)
				if [[ -z ${1#*=} ]]; then
					printf -- "ERROR: %s" \
						"Empty option value (${1})" 1>&2
					__mock_httpd_usage
				fi
				CERTIFICATE_PATH="${1#*=}"
				shift 1
				;;
			--opts=*)
				if [[ -z ${1#*=} ]]; then
					printf -- "ERROR: %s" \
						"Empty option value (${1})" 1>&2
					__mock_httpd_usage
				fi
				SOCAT_OPTIONS="${1#*=}"
				shift 1
				;;
			-t)
				if [[ -z ${2:-} ]]; then
					printf -- "ERROR: %s" \
						"Empty option value (${1})" 1>&2
					__mock_httpd_usage
				fi
				CONTENT_TYPE="${2}"
				shift 2
				;;
			--content-type=*)
				if [[ -z ${1#*=} ]]; then
					printf -- "ERROR: %s" \
						"Empty option value (${1})" 1>&2
					__mock_httpd_usage
				fi
				CONTENT_TYPE="${1#*=}"
				shift 1
				;;
			-c)
				if [[ -z ${2:-} ]]; then
					printf -- "ERROR: %s" \
						"Empty option value (${1})" 1>&2
					__mock_httpd_usage
				fi
				CONTENT="${2}"
				shift 2
				;;
			--content=*)
				if [[ -z ${1#*=} ]]; then
					printf -- "ERROR: %s" \
						"Empty option value (${1})" 1>&2
					__mock_httpd_usage
				fi
				CONTENT="${1#*=}"
				shift 1
				;;
			-p)
				if [[ -z ${2:-} ]]; then
					printf -- "ERROR: %s" \
						"Empty option value (${1})" 1>&2
					__mock_httpd_usage
				fi
				PORT="${2}"
				shift 2
				;;
			--port=*)
				if [[ -z ${1#*=} ]]; then
					printf -- "ERROR: %s" \
						"Empty option value (${1})" 1>&2
					__mock_httpd_usage
				fi
				PORT="${1#*=}"
				shift 1
				;;
			-P)
				if [[ -z ${2:-} ]]; then
					printf -- "ERROR: %s" \
						"Empty option value (${1})" 1>&2
					__mock_httpd_usage
				fi
				PROTOCOL="${2}"
				shift 2
				;;
			--protocol=*)
				if [[ -z ${1#*=} ]]; then
					printf -- "ERROR: %s" \
						"Empty option value (${1})" 1>&2
					__mock_httpd_usage
				fi
				PROTOCOL="${1#*=}"
				shift 1
				;;
			-q|--quiet)
				QUIET=true
				shift 1
				;;
			-s)
				if [[ -z ${2:-} ]]; then
					printf -- "ERROR: %s" \
						"Empty option value (${1})" 1>&2
					__mock_httpd_usage
				fi
				STATUS="${2}"
				shift 2
				;;
			--status=*)
				if [[ -z ${1#*=} ]]; then
					printf -- "ERROR: %s" \
						"Empty option value (${1})" 1>&2
					__mock_httpd_usage
				fi
				STATUS="${1#*=}"
				shift 1
				;;
			*)
				printf -- "ERROR: %s" \
					"Unkown option or option expects a value (${1})" 1>&2
				__mock_httpd_usage
				;;
		esac
	done

	if [[ ${QUIET} == true ]]; then
		exec > /dev/null 2>&1
	else
		exec > /dev/null
	fi

	# Set correct protocol for standard encrypted port.
	if [[ ${PORT} == 443 ]] \
		&& [[ ${PROTOCOL} != https ]]; then
		PROTOCOL=https
	fi

	# Set correct standard encrypted port for encrypted protocol.
	if [[ ${PROTOCOL} == https ]] \
		&& [[ ${PORT} == 80 ]]; then
		PORT=443
	fi

	if [[ ${EUID} -ne 0 ]] \
		&& [[ ${PORT} -lt 1024 ]]; then
		printf -- "ERROR: %s" \
			"For privileged ports, run as root (or sudo)." 1>&2
		exit 1
	fi

	trap "__mock_httpd_cleanup ${PORT}; \
		> /var/run/mock-httpd-${PORT}.pid; \
		exit; \
	" \
		EXIT SIGQUIT SIGINT SIGSTOP SIGTERM ERR

	umask 0

	if [[ ${$} -gt 0 ]]; then
		__mock_httpd_cleanup ${PORT}

		if [[ ${EUID} -ne 0 ]]; then
			sudo bash -c "printf -- \"%s\" \"${$}\" \
				> /var/run/mock-httpd-\"${PORT}\".pid"
		else
			printf -- '%s' "${$}" \
				> /var/run/mock-httpd-"${PORT}".pid
		fi
	fi

	# Escape socat special characters.
	CONTENT="$(
		sed 's~\([,:!]\)~\\\1~g' \
		<<<"${CONTENT:-}"
	)"

	if [[ ${PROTOCOL} == "https" ]]; then
		CERTIFICATE_PATH="${CERTIFICATE_PATH:-/tmp/mock-httpd-${PORT}.crt}"

		if [[ ! -f ${CERTIFICATE_PATH} ]]; then
			${openssl} req \
				-x509 \
				-sha256 \
				-nodes \
				-newkey rsa:2048 \
				-days 365 \
				-subj "/CN=www.localdomain" \
				-keyout "${CERTIFICATE_PATH}" \
				-out "${CERTIFICATE_PATH}" \
			&> /dev/null

			# Generating dhparms is a slow process so, for testing purposes, 
			# use a pre-generated one.
			cat >> "${CERTIFICATE_PATH}" \
				<<-DHPARAMS
			-----BEGIN DH PARAMETERS-----
			MIIBCAKCAQEAz/jfRdBI4yEPhFLXofhppz6agNW4TJBYo1cmY70Fkddhqa/XF1tM
			Vy6cxC4iVqJXvxozeLjpg1co3JGfYelr9OXd1XZxDt4NSsaB5X5AGw7p0cc0MlCG
			4/boaRqVHX3Wz6ts9flHQfu0ooZH7Km82WBnUocLQR6spafbipkFdfE1Cr4WWG6t
			/uabILjK4vfbZtHYOCn0CpK7Z1YM7OFcN94ihojQ/5gtyiPme1HKWB5T7tvdJW2D
			umN+9rcuGIScDgeo7oOvHYYndt39hBLkV9VTBw4hA+JiJKgXjeNAtqM12c9JIFRq
			2HzkAsoX9BZyUe9/XTIKabbppvd9eUNEQwIBAg==
			-----END DH PARAMETERS-----
			DHPARAMS
		fi

		ADDRESS_LEFT="OPENSSL-LISTEN:${PORT},fork,reuseaddr,verify=0,method=TLS1.2,cert=${CERTIFICATE_PATH}"
	else
		ADDRESS_LEFT="TCP4-LISTEN:${PORT},fork,reuseaddr"
	fi

	case "${CONTENT_TYPE}" in
		text/plain)
			if [[ -z ${CONTENT} ]]; then
				CONTENT="Hello\, world\!"
			fi

			exec ${socat} \
				${SOCAT_OPTIONS} \
				${ADDRESS_LEFT} \
				SYSTEM:"printf -- \
					\\\"%s\r\n%s\r\n%s\r\n%s\r\n%s\r\n\r\n%s\\\" \
					\\\"HTTP/1.1 ${STATUS}\\\" \
					\\\"Date\: \$\(date +\\\"%a\, %d %b %Y %H\:%M\:%S %Z\\\"\)\\\" \
					\\\"Cache-Control\: ${CACHE_CONTROL}\\\" \
					\\\"Server\: Mock httpd\\\" \
					\\\"Content-Type\: text/plain; charset=UTF-8\\\" \
					\\\"${CONTENT}\\\"",setsid \
			|| exit 1
			;;
		raw:text/html|raw:text/plain)
			if [[ -z ${CONTENT} ]]; then
				if [[ ${CONTENT_TYPE} == raw:text/plain ]]; then
					CONTENT="$(
						printf -- \
							"%s\r\n%s\r\n%s\r\n%s\r\n%s\r\n\r\n%s" \
							"HTTP/1.1 ${STATUS}" \
							"Date: $(date +"%a, %d %b %Y %H:%M:%S %Z")" \
							"Cache-Control: ${CACHE_CONTROL}" \
							"Server: Mock httpd" \
							"Content-Type: text/plain; charset=UTF-8" \
							"mock-httpd" \
							"Hello, world!"
					)"
				else
					CONTENT="$(
						printf -- \
							"%s\r\n%s\r\n%s\r\n%s\r\n%s\r\n\r\n<!DOCTYPE html>\n<html>\n\t<head>\n\t\t<title>%s</title>\n\t</head>\n\t<body>\n\t\t%s\n\t</body>\n</html>" \
							"HTTP/1.1 ${STATUS}" \
							"Date: $(date +"%a, %d %b %Y %H:%M:%S %Z")" \
							"Cache-Control: ${CACHE_CONTROL}" \
							"Server: Mock httpd" \
							"Content-Type: text/html; charset=UTF-8" \
							"mock-httpd" \
							"<p>Hello, world!</p>"
					)"
				fi

				CONTENT="$(
					sed 's~\([,:!]\)~\\\1~g' \
					<<<"${CONTENT}"
				)"
			fi

			exec ${socat} \
				${SOCAT_OPTIONS} \
				${ADDRESS_LEFT} \
				SYSTEM:"printf -- \\\"${CONTENT}\\\"",setsid \
			|| exit 1
			;;
		text/html|*)
			if [[ -z ${CONTENT} ]]; then
				CONTENT="<p>Hello\, world\!</p>"
			fi

			exec ${socat} \
				${SOCAT_OPTIONS} \
				${ADDRESS_LEFT} \
				SYSTEM:"printf -- \
					\\\"%s\r\n%s\r\n%s\r\n%s\r\n%s\r\n\r\n<\!DOCTYPE html>\n<html>\n\t<head>\n\t\t<title>%s</title>\n\t</head>\n\t<body>\n\t\t%s\n\t</body>\n</html>\\\" \
					\\\"HTTP/1.1 ${STATUS}\\\" \
					\\\"Date\: \$\(date +\\\"%a\, %d %b %Y %H\:%M\:%S %Z\\\"\)\\\" \
					\\\"Cache-Control\: ${CACHE_CONTROL}\\\" \
					\\\"Server\: Mock httpd\\\" \
					\\\"Content-Type\: text/html; charset=UTF-8\\\" \
					\\\"mock-httpd\\\" \
					\\\"${CONTENT}\\\"",setsid \
			|| exit 1
			;;
	esac

	trap - \
		EXIT SIGQUIT SIGINT SIGSTOP SIGTERM ERR

}

mock_httpd "${@}"
