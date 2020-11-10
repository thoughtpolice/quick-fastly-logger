<div class="title-block" style="text-align: center;" align="center">

# quick-fastly-logger

![Version]
![GPLv3]

[Version]:        https://img.shields.io/badge/release-0.1.0,%20"Developer%20Edition"-red.svg?logo=v
[GPLv3]:          https://img.shields.io/badge/license-GPL3-blueviolet.svg?logo=gnu

<strong>
  <a href="https://github.com/thoughtpolice/quick-fastly-logger">Homepage</a>
  &nbsp;&nbsp;&bull;&nbsp;&nbsp;
  <a href="https://github.com/thoughtpolice/quick-fastly-logger">Documentation</a>
</strong>

---

</div>

Are you writing VCL or Rust? Do **you** need to quickly get some logging
infrastructure set up to use with **[Fastly real-time log
streaming](https://docs.fastly.com/en/guides/log-streaming-syslog)** for
debug/testing purposes? No? Well imagine that you did! Then this might be the
repository for you.

## What?

This repository contains a tool &mdash; packaged as a Linux container image
&mdash; that will listen on port 514 (syslog), parse incoming logs from Fastly,
and spit them back out over a fancy interactive HTTP webpage. This is useful for
debugging Fastly services by using Fastly's [Real-Time Syslog
Streaming](https://docs.fastly.com/en/guides/log-streaming-syslog) feature
(unique amongst the Fastly backends since it opens a persistent TCP connection
to an IP of your choice.)

This means you can easily run this service on a cheap, publicly available VPS
using nothing more than **[Docker](https://docker.com)** (or alternatives such
as **[Podman](https://podman.io)**) and point your Fastly services to it for
debugging needs.

Internally, syslog parsing and log mangling is handled using
**[vector](https://vector.dev)**, while pushing logs into the browser for easy
remote viewing is done using **[ttyd](https://github.com/tsl0922/ttyd)**.

## Why?

Sometimes you just need to log some stuff for debugging in the middle of a
hacking session, and sometimes you just have a really low volume service that
you want to log and don't need to retain storage of. This works just great for
stuff like that.

> **NOTE**: This tool is currently not meant to be used as a production aid, but
> instead as a quick and dirty debugging tool, and is designed as such, so it
> has no TLS or many other features. I may accept changes that make it more
> amenable to production-like use cases, however.

## How?

On any Linux server with a publicly reachable IPv4 address, run the Linux
container `thoughtpolice/quick-fastly-logger` from `hub.docker.com`. Expose port
`514` (syslog) and `7681` (http + websocket) from the container in whatever
manner you wish:

```bash
docker run \
  -p 514:514 \
  -p 80:7681 \
  -d --rm \
  thoughtpolice/quick-fastly-logger:latest
```

> **HEADS UP**: You can use HTTP Basic Authentication for the `ttyd` server if
> you provide the command line argument `-e CREDENTIAL="root:toor"` to the
> `docker run` command, before the name of the container image. This is only
> intended as a simple safeguard, not as a guarantee of integrity or
> authenticity!

Now, visit `http://${IP_ADDRESS}:80` in your browser. You'll see a very fancy
interactive browser-based tty, containing the `stdout` of the `vector` command.
While the page will appear empty and static initially, it is connected to a
websocket that will stream logs into the page as they come into your Fastly
service. But you need to configure that first!

Set up a syslog service according to the **[Fastly Syslog Streaming
Guide](https://docs.fastly.com/en/guides/log-streaming-syslog)**. Some important notes:

- **DO NOT** use TLS. This is currently unsupported (again, quick debugging aid,
  not a production tool!)
- Set the address of the syslog endpoint to the publicly reachable IP address of
  your VPS, on port 514.
- Use the default logging format: `%h %l %u %t "%r" %>s %b`
- You **MUST** select the `Loggly` line format under `Advanced options` (this
  uses **[RFC5424](https://tools.ietf.org/html/rfc5424)** under the hood).

You can then deploy your service with your new logging endpoint.

#### Varnish usage

Out of the box, Varnish will automatically send logs for every request using the
`vcl_log` subroutine, so you don't need to do anything differently. You can also
use `log` directly in your VCL if you wish.

#### Rust (Compute@Edge) usage

You need the `fastly`, `log`, and (surprise) `log-fastly` crates in your
`Cargo.toml`. Then, assuming your logging endpoint is named `vector_logging`,
then setup logging in `main`, and use `warn!()` or `info!()` as you wish:

```rust
#[fastly::main]
fn main(mut req: Request<Body>) -> Result<impl ResponseExt, Error> {
    log_fastly::init_simple("vector_logging", log::LevelFilter::Info);

    let mut pathb = req.uri().path().to_string();
    if pathb.ends_with("/") {
        pathb.push_str("index.html");
    }
    let path = pathb.as_str();

    log::info!("Request for path {}", path); // appears in your browser!
    // ...
}
```

## Who?

&copy; Austin Seipp <<aseipp@fastly.com>> (see `LICENSE.txt`)
