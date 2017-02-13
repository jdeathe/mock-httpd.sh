# mock-httpd

Minimal mock HTTP/HTTPS server useful for testing; use it to mock a web server response. 

This is not a full server implementation, it responds to all GET requests with the same response.

Requires on GNU Bash, [OpenSSL](https://www.openssl.org/) and [socat](http://www.dest-unreach.org/socat/).

## Installation

```
$ install -m 0755 mock-httpd.sh /usr/local/bin/mock-httpd
```

### Installing dependancies

On RHEL/CentOS with YUM

```
# yum install openssl socat
```

On OSX via [Homebrew](https://brew.sh/)

```
$ brew install openssl socat
```

## Usage

Running without parameters, `-h` or `--help` will return the usage instructions.

```
$ mock-httpd --help
```

## Examples

Listen quietly in the background on port 8080 of localhost and respond with an HTML response containing the body `<p>Hello, world!<p>`.

```
$ sudo bash -c "mock-httpd -q -p 8080 -c '<p>Hello, world\!</p>' & disown"
```

_NOTE:_ To kill the background process the PID can be found from the pid file: `/var/run/mock-httpd-{PORT}.pid`.

Check the running process with `ps`:

```
$ ps -p $(cat /var/run/mock-httpd-8080.pid)
```

Stop the background process with `kill`:

```
$ sudo kill $(cat /var/run/mock-httpd-8080.pid)
```

Listen quietly in the background on port 80 of localhost and respond with a plain text response containing `Hello, world!`.

```
$ sudo bash -c "mock-httpd -q -t text/plain -c 'Hello, world\!' & disown"
```

Listen quietly in the background on port 443 of localhost and respond to HTTPS requests with an HTML response containing the body `<p>Hello, world!<p>`. A self-signed certificate will be generated automatically.

```
$ sudo bash -c "mock-httpd -q -P https -c '<p>Hello, world\!</p>' & disown"
```

On Linux the setsid command can be used to background the process if you are running as a root user.

```
# setsid mock-httpd -q -P https -c "<h1>I\'m HTTPS</h1>"
```
