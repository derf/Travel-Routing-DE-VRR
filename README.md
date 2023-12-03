# efa - Commandline Public Transit Routing Interface

efa is a commandline client and Perl module for EFA public transit routing
interfaces such as [efa.vrr.de](https://efa.vrr.de). See the
[Travel::Routing::DE::VRR homepage](https://finalrewind.org/projects/Travel-Routing-DE-VRR/)
for details.

## Installation

efa has been packaged as
[libtravel-routing-de-vrr-perl](https://packages.debian.org/search?keywords=libtravel-routing-de-vrr-perl)
for Debian, so you can install it using your package manager of choice on
Debian-based Linux distributions. The package provides the commandline client
as well as the Perl module.

If you are using another distribution or would prefer a more recent version,
you have four installation options:

* `.deb` releases for Debian-based distributions
* Installing the latest release from CPAN
* Installation from source
* Using a Docker image

Except for Docker, **efa** is available in your PATH after installation. You
can run `efa --version` to verify this. Documentation is available via
`man efa`.

### Release Builds for Debian

[lib.finalrewind.org/deb](https://lib.finalrewind.org/deb) provides Debian
packages of all release versions. Note that these are not part of the official
Debian repository and are not covered by its quality assurance process.

To install the latest release, run:

```
wget https://lib.finalrewind.org/deb/libtravel-routing-de-vrr-perl_latest_all.deb
sudo apt install ./libtravel-routing-de-vrr-perl_latest_all.deb
rm libtravel-routing-de-vrr-perl_latest_all.deb
```

Uninstallation works as usual:

```
sudo apt remove libtravel-routing-de-vrr-perl
```

### Installation from CPAN

Travel::Routing::DE::VRR releases are published on the Comprehensive Perl
Archive Network (CPAN) and can be installed using standard Perl module
tools such as cpanminus.

Before proceeding, ensure that you have standard build tools (i.e. make,
pkg-config and a C compiler) installed. You will also need the following
libraries with development headers:

* libssl
* libxml2
* zlib

Now, use a tool of your choice to install the module. Minimum working example:

```
cpanm Travel::Routing::DE::VRR
```

If you run this as root, it will install script and module to `/usr/local` by
default.

### Installation from Source

In this variant, you must ensure availability of dependencies by yourself.
You may use carton or cpanminus with the provided `cpanfile`, Module::Build's
installdeps command, or rely on the Perl modules packaged by your distribution.
On Debian 10+, all dependencies are available from the package repository.

To check whether dependencies are satisfied, run:

```
perl Build.PL
```

If it complains about "... is not installed" or "ERRORS/WARNINGS FOUND IN
PREREQUISITES", it is missing dependencies.

Once all dependencies are satisfied, use Module::Build to build, test and
install the module. Testing is optional -- you may skip the "Build test"
step if you like.

If you downloaded a release tarball, proceed as follows:

```
./Build
./Build test
sudo ./Build install
```

If you are using the Git repository, use the following commands:

```
./Build
./Build manifest
./Build test
sudo ./Build install
```

If you do not have superuser rights or do not want to perform a system-wide
installation, you may leave out `Build install` and use **efa** from the
current working directory.

With carton:

```
carton exec efa --version
```

Otherwise (also works with carton):

```
perl -Ilocal/lib/perl5 -Ilib bin/efa --version
```

### Running efa via Docker

An efa image is available on Docker Hub. It is intended for testing purposes:
due to the latencies involved in spawning a container for each efa invocation,
it is less convenient for day-to-day usage.

Installation:

```
docker pull derfnull/efa:latest
```

Use it by prefixing efa commands with `docker run --rm derfnull/efa:latest`, like so:

```
docker run --rm derfnull/efa:latest --version
```

Documentation is not available in this image. Please refer to the
[online efa manual](https://man.finalrewind.org/1/efa/) instead.
