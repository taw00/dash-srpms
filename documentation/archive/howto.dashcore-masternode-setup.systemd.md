# HowTo: Dash Masternode as SystemD Service

_aka I want to run a Dash Masternode like a SysAdmin!_

This edition of these instructions is for those who wish to install and
configure a Dash Masternode running as a traditional `systemd` service.

A Dash Masternode is a server service, therefore it lends itself to the
improved security and robustness that `systemd` offers. I.e., It really is
the "right way" of running your masternode. Another "right way" would be
to run it as a container. But that is beyond the scope of this document.

These instructions are specific to the Red Hat-family of linuxes. As of DASH
Core 0.13, EL7 systems (CentOS/RHEL) are not supportable platforms. This will
undoubtedly change with RHEL8, but until then, please plan to deploy to
Fedora Linux.

**Table of Content**

<!-- TOC START min:2 max:3 link:true update:true -->
- [FIRST: Set up your collateral-bearing wallet](#first-set-up-your-collateral-bearing-wallet)
- [SECOND: Install the operating systems](#second-install-the-operating-systems)
- [[1] Install Dash (and FirewallD)](#1-install-dash-and-firewalld)
- [[2] Configure Dash Server to be a Full Node](#2-configure-dash-server-to-be-a-full-node)
- [[3] Edit `/etc/dashcore/dash.conf` and finish](#3-edit-etcdashcoredashconf-and-finish)
- [[4] Restart the `dashd` systemd service and enable it for restart upon boot](#4-restart-the-dashd-systemd-service-and-enable-it-for-restart-upon-boot)
- [[5] Configure firewall rules](#5-configure-firewall-rules)
- [[6] ON WALLET: Add masternode IP address](#6-on-wallet-add-masternode-ip-address)
- [[7] ON WALLET: Trigger a start of your masternode](#7-on-wallet-trigger-a-start-of-your-masternode)
- [[8] ON MASTERNODE: Monitor masternode enablement status](#8-on-masternode-monitor-masternode-enablement-status)
- [[9] Set up Dash Sentinel](#9-set-up-dash-sentinel)
- [ALL DONE!](#all-done)
- [Email me when `dashd` starts or stops](#email-me-when-dashd-starts-or-stops)
- [Email the admin when the Masternode's status changes from "ENABLED"](#email-the-admin-when-the-masternodes-status-changes-from-enabled)
- [Super fancy crontab settings](#super-fancy-crontab-settings)
- [Improve SSD Write & Delete Performance for Linux Systems by Enabling ATA TRIM](#improve-ssd-write--delete-performance-for-linux-systems-by-enabling-ata-trim)

<!-- TOC END -->



## FIRST: Set up your collateral-bearing wallet

For a general overview of what a masternode is and how it is set up at a high
level, please refer to the overview document found
[here](https://github.com/taw00/dashcore-rpm/blob/master/documentation/README.md).

Before setting up a masternode, you need to acquire 1000 DASH and hold it in a
specially configured wallet. Do that first. You can find instruction for how to
set that up here:
[howto.dashcore-collateral-bearing-wallet-setup.gui.md](https://github.com/taw00/dashcore-rpm/blob/master/documentation/howto.dashcore-collateral-bearing-wallet-setup.gui.md)

Once completed, you may continue.

## SECOND: Install the operating systems

Instruction for setting up, configuring, and securing a Fedora Linux system in preparation for deploying a Dash Masternode can be found here: <https://github.com/taw00/dashcore-rpm/blob/master/documentation/howto.prep-system-for-masternode.md>

Once completed, you may continue.

## [1] Install Dash (and FirewallD)

Because this is a Red Hat -based system, management of installed software is
trivial. This is how easy it is.

***Configure the Dash repositories (you only do this once)***

```bash
sudo rpm --import https://keybase.io/toddwarner/key.asc
sudo dnf install -y https://raw.githubusercontent.com/taw00/dashcore-rpm/master/toddpkgs-dashcore-repo.fedora.rpm
```

***Install Dash server (and FirewallD)***

```
sudo dnf install -y dashcore-server firewalld
```

## [2] Configure Dash Server to be a Full Node

We are configuring this as a `systemd` service. Some of the process has been
done for you. Please note these differences from other instruction you may read
out there.

1. The default data directory will be `/var/lib/dashcore`
2. The default configuration file will be `/etc/dashcore/dash.conf`
3. Both are owned by system user (and group) `dashcore`
4. All elements in 1, 2, and 3 above were installed automatically by the dashcore-server RPM package.

Since the Dash service runs out of `dashcore` user owned directories and
configuration, many of our configuration and ongoing maintenance actions will
be performed by sudo'ing as that user. `dashcore` is a system user, as such that
user can't be logged into and has no home directory. What this means will
become self evident shortly.

A final note, since the default data directory and configuration file locations
are not traditional to the Dash Core upstream codebase, we will often have to
explicitly include them on the commandline when we perform actions.


***Edit `/etc/dashcore/dash.conf`***

In this example, we are going to get the dashcore server running as a node, but
not a masternode yet.

Log in as the normal user, `mnuser` in this example.

With your favorite editor &mdash; some use `nano`, I use `vim` &mdash; open up
`/etc/dashcore/dash.conf` and add the starting template shown below....

```
sudo -u dashcore nano /etc/dashcore/dash.conf
```

Edit that file and save this data in it...
```
# This is a Masternode Server configuration file
# 1 = run as testnet server (fake money), 0 = run as mainnet server (real money)
testnet=0
# Run dashd as a daemon (in the background)
daemon=1
# Listening mode, enabled by default except when 'connect' is being used
listen=1
logtimestamps=1
maxconnections=8

# Remote Procedure Call access configuration...
# server=1 tells Dash-QT and dashd to accept JSON-RPC commands
server=1
# You must set rpcuser and rpcpassword to secure the JSON-RPC api
rpcuser=<make_up_an_alphanumeric_username>
rpcpassword=<make_up_an_alphanumeric_password>
rpcport=9998
# A note about RPC connection control...
# Opening up the RPC port to hosts outside your local trusted network
# is NOT RECOMMENDED, because the rpcpassword is transmitted over the
# network unencrypted -- unless you set up SSL (beyond scope of this doc)
# Fortunately, as a small security measure, by default, only RPC connections
# from localhost are allowed. Specify as many rpcallowip= settings as you
# like to allow connections from other hosts, either as a single IPv4/IPv6
# or with a subnet specification.
rpcallowip=127.0.0.1

#masternode=1
#externalip=<results of "dig +short myip.opendns.com @resolver1.opendns.com">
#masternodeprivkey=<results of "dash-cli masternode genkey" in wallet>
#masternodeblsprivkey=<NEW 0.13 PROCESS THAT WE'LL GET TO SHORTLY>
```

Please take special note of `"testnet=1"` and `"testnet=0"`.

***Change your RPC (remote procedure call username and password)***

Edit `/etc/dashcore/dash.conf` and change...

```
rpcuser=<make_up_an_alphanumeric_username>
rpcpassword=<make_up_an_alphanumeric_password>
```
...to something else (this is an example)...
```
rpcuser=rpc_user_89752q340432
rpcpassword=this_is_a_random_password_984nf983n3o4n349nf9042nnfq3kgsdf898s
```

These are used by your on-system, internal commandline tools for the most part,
so you don't have to memorize them or use them outside of this masternode.

***Start up your Dash full node (it isn't a masternode yet)***

Log in as the normal user, `mnuser` in this example.

```
# You kick off systemd services as root
sudo systemctl start dashd
```

***SSH into two terminals and monitor the situation...***

...watch the logs in one...

```
# ^C out of this tail feed when you are done...
sudo -u dashcore tail -f /var/lib/dashcore/debug.log # if mainnet
#sudo -u dashcore tail -f /var/lib/dashcore/testnet3/debug.log
```

...and watch the blockcount rise (hopefully) in the other...

```
# ^C out of this loop when you are done
watch -n10 sudo -u dashcore dash-cli -conf=/etc/dashcore/dash.conf getblockcount
```

You will know you have sync'ed the entire blockchain when it matches the current block-heigth:

* <https://insight.dashevo.org/insight/> &mdash; for mainnet
* <https://testnet-insight.dashevo.org/insight/> &mdash; for testnet

...or if you are comfortable on the commandline, these are helpful...
```
# "mainnet" block height
curl -o - https://explorer.dash.org/chain/Dash/q/getblockcount
# "testnet" block height
curl -o - https://test.explorer.dash.org/chain/tDash/q/getblockcount
# This command will spit out the block height for this network as your
# masternode sees it (ie, it could be wrong)
sudo -u dashcore dash-cli -conf=/etc/dashcore/dash.conf getchaintips |grep -m1 height | sed 's/[^0-9]*//g'
```


***Once fully sync'ed your configuration as a full node is complete.***


## [3] Edit `/etc/dashcore/dash.conf` and finish

First, write down the value of `dig +short myip.opendns.com @resolver1.opendns.com` that you get at the
commandline of this server. For this example, we are going to use
`93.184.216.34` (yours will be different, of course).

Then take the data you gathered from setting up your wallet in
[howto.dashcore-collateral-bearing-wallet-setup.gui.md](https://github.com/taw00/dashcore-rpm/blob/master/documentation/howto.dashcore-collateral-bearing-wallet-setup.gui.md)
and reconfigured `/etc/dashcore/dash.conf`

```
# Use your favorite editor, in this example, "nano"
sudo -u dashcore nano /etc/dashcore/dash.conf
```

Convert these lines from...
```
#masternode=1
#externalip=<results of "dig +short myip.opendns.com @resolver1.opendns.com">
#masternodeprivkey=<process addressed in separate document>
#masternodeblsprivkey=<new v0.13 process addressed in separate document>
```

...to (and this is example data from the prior wallet exercise)...
```
masternode=1
externalip=93.184.216.34
masternodeprivkey=92yZY5b8bYD5G2Qh1C7Un6Tf3TG3mH4LUZha2rdj3QUDGHNg4W9
#masternodeblsprivkey=<new v0.13 process addressed in separate document>
```

## [4] Restart the `dashd` systemd service and enable it for restart upon boot

```
sudo systemctl restart dashd
# there will be a 30 second+ second pause while systemd allows dashd to shut
# down properly
sudo systemctl enable dashd
```

Now, if you have to reboot your system for whatever reason, the dash service
will restart as well. It is worth remembering that a masternode does not need
to be "restarted" (re-validated really) from a wallet unless it has been
offline for some time (I believe something like 75 minutes -- that quote needs
to be verified).


## [5] Configure firewall rules

You can follow the instruction in
[howto.secure-your-dash-masternode.md](https://github.com/taw00/dashcore-rpm/blob/master/documentation/howto.secure-your-dash-masternode.md),
or just take these steps here. It's recommended that you review that document
though and perhaps implement some of the additional suggestions it may provide.


> _Note: Firewall rules can be a complicated topic. These are bare bones
> git-er-done instructions. You may want to investigate further refinement. It
> will get you started though._


```
# Is firewalld running?
# Turn on and enable firewalld if not already done...
sudo firewall-cmd --state
sudo systemctl start firewalld.service
sudo systemctl enable firewalld.service

# Determine what the default zone is.
# On vultr, for example, the default zone is FedoraServer (it is the assumption
# for this example)
sudo firewall-cmd --get-active-zone

# Whatever that default zone is, that is the starting conditions for your
# configuration. For this example, I am going to demonstrate how to edit my
# default configuration on my Fedora Linux system: FedoraServer. You _could_
# create your own zone definition, but for now, we will be editing the
# configuration that is in place.

# FedoraServer usually starts with ssh, dhcp6-client, and cockpit opened up
# I want to allow SSH and masternode traffic, but I don't want cockpit running
# all the time and by having a static IP, dhcpv6 service is unneccessary.
sudo firewall-cmd --permanent --add-service ssh
sudo firewall-cmd --permanent --add-service dashcore # mainnet
#sudo firewall-cmd --permanent --add-service dashcore-testnet
sudo firewall-cmd --permanent --remove-service dhcpv6-client
sudo firewall-cmd --permanent --remove-service cockpit

# Rate limit incoming ssh and cockpit (if configured on) traffic to 10 per minute
sudo firewall-cmd --permanent --add-rich-rule='rule service name=ssh limit value=10/m accept'
#sudo firewall-cmd --permanent --add-rich-rule='rule service name=cockpit limit value=10/m accept'

# Rate limit incoming dash node/masternode traffic to 100 requests/minute.
sudo firewall-cmd --permanent --add-rich-rule='rule service name=dashcore limit value=100/s accept'
#sudo firewall-cmd --permanent --add-rich-rule='rule service name=dashcore-testnet limit value=100/s accept'

# did it take?
sudo firewall-cmd --reload
sudo firewall-cmd --state
sudo firewall-cmd --list-all
```

_After you `--list-all`, if you see a service you do not wish to be available,
feel free to remove it following the pattern we demonstrated above._


**Some references:**

* FirewallD documentation: <https://fedoraproject.org/wiki/Firewalld>
* Rate limiting as we do above: <https://www.rootusers.com/how-to-use-firewalld-rich-rules-and-zones-for-filtering-and-nat/>
* More on rate limiting: <https://serverfault.com/questions/683671/is-there-a-way-to-rate-limit-connection-attempts-with-firewalld>
* And more: <https://itnotesandscribblings.blogspot.com/2014/08/firewalld-adding-services-and-direct.html>
* Interesting discussion on fighting DOS attacks on http: <https://www.certdepot.net/rhel7-mitigate-http-attacks/>
* Do some web searching for more about firewalld


## [6] ON WALLET: Add masternode IP address

Go back to your wallet (see
[howto.dashcore-collateral-bearing-wallet-setup.gui.md](https://github.com/taw00/dashcore-rpm/blob/master/documentation/howto.dashcore-collateral-bearing-wallet-setup.gui.md))
and edit the `masternode.conf` file referenced there and replace the example IP
address with the IP address of this masternode as found in prior steps above.

Following our examples, that line in the `masternode.conf` file will look
something like this...
```
mn1 93.184.216.34:9999 92yZY5b8bYD5G2Qh1C7Un6Tf3TG3mH4LUZha2rdj3QUDGHNg4W9 b34ad623453453456423454643541325c98d2f8b7a967551f31dd7cefdd67457 1
```

_**Notice that port number. Choose 9999 for mainnet and 19999 for testnet.**_


## [7] ON WALLET: Trigger a start of your masternode

This is it! Flip that bit! This is really a "validation" step that connects
that 1000 DASH collateral to this masternode and says "Okay, full node, you can
now operate on the network as a masternode!"

Go back to your wallet (see
[howto.dashcore-collateral-bearing-wallet-setup.gui.md](https://github.com/taw00/dashcore-rpm/blob/master/documentation/howto.dashcore-collateral-bearing-wallet-setup.gui.md)).

* Navigate the menus: Tools > Debug console
* Enter in that dialogue: `masternode start-alias mn1`<br />
  Alternatively, you can start all masternodes (if you have multiple) with: `masternode start-missing`

Remember `mn1` is our example alias.

Or from the commandline: `dash-cli masternode start-alias mn1`<br />
...optionally: `dash-cli masternode start-missing`

If the command was sent successfully, you should see... "successful" or
something similar. This means the command was sent successfully, not that the
masternode was truly started.

**Recommendation: Once you have issued this command, SHUT DOWN YOUR WALLET.
There is 1000 DASH associated to that wallet. There is no reason to keep it
online for very long. Shut it down.**

## [8] ON MASTERNODE: Monitor masternode enablement status

What you are looking for is ENABLED to be displayed. This can take up to 15
minutes or so. You can really do this from the wallet _or_ the masternode
itself.

From the commandline do this (this is an example; use your masternode's IP
address)...
```
sudo -u dashcore watch -n10 "dash-cli -conf=/etc/dashcore/dash.conf masternode list full | grep 93.184.216.34"
```

While that is going on in one terminal, open up another terminal and...

## [9] Set up Dash Sentinel

There are really two services associated to a masternode, the node itself and a
"sentinel" that performs certain actions and manages expanded processes for the
network. It was already installed when your dashcore-server package was
installed. You just have to turn it on and edit crontab for the `dash` system
user so that it executes every five minutes...

<!-- if you installed from an RPM package, this step goes away
### Turn off testnet/mainnet checking in `sentinel.conf`

Edit the /var/lib/dashcore/sentinel/sentinel.conf file and comment out
`network=testnet` and `network=mainnet` if one of them is set in there. Your
`dash.conf` file properly sets that and the Sentinel default configuration file
may wrongly override your `dash.conf` file. At least it does in the earlier
versions of Sentinel.
-->

***Run it for the first time...***

```
sudo -u dashcore -- bash -c "cd /var/lib/dashcore/sentinel && venv/bin/python bin/sentinel.py"
```

It should create a database and populate it.

Run it again...
```
sudo -u dashcore -- bash -c "cd /var/lib/dashcore/sentinel && venv/bin/python bin/sentinel.py"
```

There should be no output.

> Note, if something seems to be going wrong, set SENTINEL_DEBUG=1 and try to
> make sense of the output
>
> ```
> sudo -u dashcore -- bash -c "cd /var/lib/dashcore/sentinel && SENTINEL_DEBUG=1 venv/bin/python bin/sentinel.py >> /var/log/dashcore/sentinel.log 2>&1"
> less /var/log/dashcore/sentinel.log
> ```

***Edit cron and add a "run it every minute" entry***

On the commandline, edit `crontab` &mdash; notice, that we, like in most
commands, are doing it as the `dashcore` system user...

```
sudo -u dashcore EDITOR="nano" crontab -e
```

...add these lines, save and exit...

```
#SENTINEL_DEBUG=1
* * * * * { cd /var/lib/dashcore/sentinel && venv/bin/python bin/sentinel.py ; } >> /var/log/dashcore/sentinel.log 2>&1
```

&nbsp;

## ALL DONE!

Continue to monitor the enablement status as illustrated in step 8. The status
should start as `PRE_ENABLED`, maybe move to `WATCHDOG_EXPIRED`, but finally is
should settled on `ENABLED`. If your wallet failed to restart it, it will say
something like `NEW_START_REQUIRED`

If all went well, you have a working Dash Masternode! Congratulations. I hope
this was helpful.

Got a dash of feedback? *...har har...* Send it my way <https://keybase.io/toddwarner>    

&nbsp;

&nbsp;

---

# Appendix - Advanced Topics


## Email me when `dashd` starts or stops

SystemD makes it easy for your system to be configured to send you emails if
your masternode is rebooted, or systemd restarts dashd because it crashed, etc.

What takes a bit of doing is setting up your server to send emails in the first
place. That can be a bit tricky, but it is not rocket science. I wrote a whole
separate document on that here:
[Configure "send-only" Email via a 3rd Party SMTP Relay](https://github.com/taw00/howto/blob/master/howto-configure-send-only-email-via-smtp-relay.md)

Once sending email is set up on your server, configuring systemd to send notice
if dashd stops or starts is trivial.

* Edit `/etc/sysconfig/dashd`
* Configure these three settings: `EMAIL_FROM`, `EMAIL_TO`, `MASTERNODE_ALIAS`
  according to how your system is configured (see link above)

You can ultimately test the system by issuing a Masternode restart &mdash
`sudo systemctl restart dashd`. Folks are generally nervous about shutting down their
Masternodes unnecessarily and rightly so, but you will not be positive if your system truly
works without doing so. Just be aware that if you restart services, it may take
those emails a couple minutes to get to you (email is slow).

That's it. Not so hard, right?


## Email the admin when the Masternode's status changes from "ENABLED"

Not written yet. Stay tuned.


## Super fancy crontab settings

Remember to edit with `sudo -u dashcore crontab -e` if dashcore-sentinel is
installed with our RPM packages.

```
# Run Sentinel every minute; All messages are logged.
logfile=/var/log/dashcore/sentinel.log
* * * * * cd /var/lib/dashcore/sentinel && venv/bin/python bin/sentinel.py >> $logfile 2>&1
```

```
# Run Sentinel every minute; dump COPIUS amounts of debug information to logfile
SENTINEL_DEBUG=1
logfile=/var/log/dashcore/sentinel.log
* * * * * cd /var/lib/dashcore/sentinel && venv/bin/python bin/sentinel.py >> $logfile 2>&1
```

```
# Run Sentinel every minute; each run is time stamped in the logs
m0="----Sentinel job started --- pid:"
m1="----Sentinel job completed - pid:" # Not used in this example
t="%b %d %T UTC"
logfile=/var/log/dashcore/sentinel.log
* * * * * { cd /var/lib/dashcore/sentinel && date --utc +"$t $m0 $$" && venv/bin/python bin/sentinel.py ; } >> $logfile 2>&1
```


## Improve SSD Write & Delete Performance for Linux Systems by Enabling ATA TRIM

Because of the way SSDs (Solid State Drives) work, saving new data can impact performance. Namely, data marked as "deleted" have to be completely erased before write. With traditional magnetic drives, data marked for deletion is simply overwritten. Because SSDs have to take this extra step, performance can be impacted and slowly worsens over time.

If, on the other hand, you can alert the operating system that it needs to wipe deleted data in the background, writes (and deletes) can improve in performance.

To learn more, follow this link: <https://github.com/taw00/howto/blob/master/howto-enable-ssd-trim-for-linux.md>
