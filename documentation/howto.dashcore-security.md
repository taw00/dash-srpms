# Configure FirewallD and Fail2Ban on a Dash Core Node

Whenever you expose a server to the wilds of the internet, it becomes vulnerable to attack.

This document will get you started on configuring some basic firewall rules to
help mitigate against some of the more obvious problems, like brute-force DOS
and trimming down the attack surface by only having the minimal ports open.

We'll examine FirewallD and Fails2ban. FirewallD manages communication coming
and going from server. Fails2ban looks for oddities in how folks are attempting
to access and adjusts firewall rules on the fly to squelch misbehavior.

<!-- TOC START min:2 max:4 link:true update:true -->
- [FirewallD](#firewalld)
    - [Install `firewalld`](#install-firewalld)
    - [Mask `iptables`](#mask-iptables)
    - [Configure `firewalld`](#configure-firewalld)
    - [Some references:](#some-references)
- [Fail2Ban](#fail2ban)
    - [Install `fail2ban`...](#install-fail2ban)
    - [Configure `fail2ban`...](#configure-fail2ban)
    - [Enable `fail2ban` and restart...](#enable-fail2ban-and-restart)
    - [Monitor / Analyze](#monitor--analyze)
    - [Reference:](#reference)
- [Done!](#done)

<!-- TOC END -->

## FirewallD

_Note: Firewall rules can be a complicated topic. These are bare bones
git-er-done instructions. You may want to investigate further refinement,
though this will get you well on your way to a better protected system._

#### Install `firewalld`

```
# If Fedora...
sudo dnf install -y firewalld # Probably already installed

# If CentOS7 or RHEL7...
#sudo yum install -y firewalld # Probably already installed

# If Debian or Ubuntu
#sudo apt install -y firewalld
```

#### Mask `iptables`

`iptables` and `firewalld` don't mix. Make sure they don't &mdash; "mask"
`iptables` (assuming it is installed)...

```
sudo systemctl disable iptables.service
sudo systemctl mask iptables.service
```

Note. If you end up ditching `firewalld` and want to go back to `iptables`...

```
sudo systemctl disable firewalld.service
sudo systemctl unmask iptables.service
sudo systemctl mask firewalld.service
```

I leave it as an exercise to the reader as to how to enable and work with
`iptables`.

#### Configure `firewalld`

```
# Is firewalld running? If not, turn it on.
sudo firewall-cmd --state
sudo systemctl start firewalld.service
```

```
# Enable firewalld to start upon boot.
sudo systemctl enable firewalld.service
```

```
# Determine what the default zone is.
sudo firewall-cmd --get-default-zone
sudo firewall-cmd --get-active-zone
```

```
# Take a look at the configuration as it stands now.
sudo firewall-cmd --list-all
```

Whatever that default zone is, that is the starting conditions for your
configuration. For this example, I am going to demonstrate how to edit my
default configuration on my Fedora Linux system: FedoraServer. You _could_
create your own zone definition, but for now, we will be editing the
configuration that is in place.

FedoraServer usually starts with ssh, dhcp6-client, and cockpit opened up by
default.  I want ssh. But dhcpv6 should probably be unneccessary, and cockpit
is something only used intermittently. To be explicit, I am going to add ssh
(though probably already an added service) and removing dhcpv6 and cockpit.

```
# Add and remove base services.
sudo firewall-cmd --permanent --add-service ssh
sudo firewall-cmd --permanent --remove-service dhcpv6-client
#sudo firewall-cmd --permanent --add-service cockpit
sudo firewall-cmd --permanent --remove-service cockpit
```

Of course, Dash services are not enabled by default. If you installed Dash via
our RPM packages (specifically `dashcore-server`), we included the service
definitions for FirewallD. Let's allow that traffic.

```
# Open up the Dash Core Node port (9999 or 19999)
sudo firewall-cmd --permanent --add-service dashcore
#sudo firewall-cmd --permanent --add-service dashcore-testnet

# Optionally open up the RPC port (9998 or 19998) - NOT recommended
#sudo firewall-cmd --permanent --add-service dashcore-rpc
#sudo firewall-cmd --permanent --add-service dashcore-testnet-rpc
```

But if you are running a node that was _not_ installed via our RPM (DNF)
packages, you must be explicit in your port configuration. I.e., you configure
either as done above or with this method.

```
# Open up the Dash Core Node port for nodes not installed via our packaging
sudo firewall-cmd --permanent --add-port=9999/tcp
#sudo firewall-cmd --permanent --add-port=19999/tcp
```

You can see what other services are available with: `firewall-cmd get-services`

You can look through one of the built in service files to determine exactly what
that service is all about: Browse directory `/usr/lib/firewalld/services`

...

Let's rate limit traffic to those ports to reduce abuse. SSH and cockpit, if
those services were added they really need to be rate limited. You would
probably want to rate limit 80 and 443, for example, if this were a webserver
(but using more liberal values). Nodes _probably_ don't need to be rate limited
since they are filtered at the protocol level, but that is something to consider
in the future.


> **Note:** `--add-service`, `--add-rich-rule`, `--add-port` &mdash; all of
> these open up ports to the world (unless explicitely IP limiting). I
> emphasize this point because I don't want people to think that
> `--add-rich-rule` alone will not open up a port. It will.


```
# Rate limit incoming ssh and cockpit traffic to 10 requests per minute
sudo firewall-cmd --permanent --add-rich-rule='rule service name=ssh limit value=10/m accept'
#sudo firewall-cmd --permanent --add-rich-rule='rule service name=cockpit limit value=10/m accept'

# Rate limit incoming dash node (and masternode) traffic to 100 requests per
# minute
sudo firewall-cmd --permanent --add-rich-rule='rule service name=dashcore limit value=100/m accept'
#sudo firewall-cmd --permanent --add-rich-rule='rule service name=dashcore-testnet limit value=100/m accept'
```

We're done with the configuration! That --permanent switch in those commands
saved the changed configuration, but it didn't enable them yet. We need to do a
reload for that to happen.

```
# did it take?
sudo firewall-cmd --reload
sudo firewall-cmd --state
sudo firewall-cmd --list-all
```

_After you `--list-all`, if you see a service you do not wish to be available,
feel free to remove it following the pattern we demonstrated above._


#### Some references:

* FirewallD documentation: <https://fedoraproject.org/wiki/Firewalld>
* Rate limiting as we do above: <https://www.rootusers.com/how-to-use-firewalld-rich-rules-and-zones-for-filtering-and-nat/>
* More on rate limiting: <https://serverfault.com/questions/683671/is-there-a-way-to-rate-limit-connection-attempts-with-firewalld>
* And more: <https://itnotesandscribblings.blogspot.com/2014/08/firewalld-adding-services-and-direct.html>
* Interesting discussion on fighting DOS attacks on http: <https://www.certdepot.net/rhel7-mitigate-http-attacks/>
* Do some web searching for more about firewalld

---

## Fail2Ban

Fail2ban analyzes log files for folks trying to do bad things on your system.
It doesn't have a lot of breadth of functionality, but it can be very
effective, especially against folks poking SSH.

#### Install `fail2ban`...

```
# If Fedora...
sudo dnf install -y fail2ban fail2ban-systemd

# If CentOS7 or RHEL7
#sudo yum install epel-release # if not already installed
#sudo yum install -y fail2ban fail2ban-systemd

# If Debian or Ubuntu
#sudo apt install -y fail2ban
```

If you are not using FirewallD, and instead are using IPTables for your
firewall, uninstall fail2ban-firewalld (for the Red Hat-based systems only).

```
# If Fedora
sudo dnf remove -y fail2ban-firewalld

# If CentOS7 or RHEL7
#sudo yum remove -y fail2ban-firewalld
```

#### Configure `fail2ban`...

Edit `/etc/fail2ban/jail.d/local.conf` _(Optionally `/etc/fail2ban/jail.local`
instead)_

Copy this; paste; then save...

```
[DEFAULT]
# Ban hosts for one hour:
bantime = 3600

# Flip the comments here if you use iptables instead of firewalld
#banaction = iptables-multiport
banaction = firewallcmd-ipset

# Enable logging to the systemd journal
backend = systemd

# Email settings - Optional - Configure this only after send-only email is
# enabled and functional at the system-level.
#destemail = youremail+fail2ban@example.com
#sender = burner_email_address@yahoo.com
#action = %(action_mwl)s


[sshd]
enabled = true
```

For more about setting up "send-only email", read
[this](https://github.com/taw00/howto/blob/master/howto-configure-send-only-email-via-smtp-relay.md).


#### Enable `fail2ban` and restart...

```
sudo systemctl enable fail2ban
sudo systemctl restart fail2ban
```

#### Monitor / Analyze

Watch the IP addresses slowly pile up by occasionally looking in the SSH jail...

```
sudo fail2ban-client status sshd
```

Also watch...

```
sudo journalctl -u fail2ban.service -f
```

...and...

```
sudo tail -F /var/log/fail2ban.log
```

#### Reference:

* <https://fedoraproject.org/wiki/Fail2ban_with_FirewallD>
* <https://en.wikipedia.org/wiki/Fail2ban>
* <http://www.fail2ban.org/>

---

## Done!

Got a dash of feedback? Send it my way: <https://keybase.io/toddwarner>
