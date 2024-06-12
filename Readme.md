# unbound Manager/Installer script for ASUS Router running RMerlin firmware.

## Installation (NOTE:Entware is required, so older MIPS based routers may not be supported.)##

Enable SSH on router, then use your preferred SSH Client e.g. Xshell6,MobaXterm, PuTTY etc. 

(TIP: Triple-click the install command below) to copy'n'paste into your router's SSH session:

	mkdir /jffs/addons 2>/dev/null;mkdir /jffs/addons/unbound 2>/dev/null; curl --retry 3 "https://raw.githubusercontent.com/MartineauUK/Unbound-Asuswrt-Merlin/master/unbound_manager.sh" -o "/jffs/addons/unbound/unbound_manager.sh" && chmod 755 "/jffs/addons/unbound/unbound_manager.sh" && /jffs/addons/unbound/unbound_manager.sh


#### To execute the utility, you may then use the _alias_ ####

	unbound_manager

#### NOTE: For a standard screen display 1024x768 (or its modern popular equivalent 1366×768), using Xshell6/MobaXterm, you can dynamically change the font size using the CTRL+Mouse-scroll wheel to have a full-screen recommended unbound_manager window 191x37
#### If using PuTTY I suggest you use PuTTY-url (v0.73) and manually set the unbound_manager window size 191x37 with font 'Terminal 9-point' (unbound_manager can/will display clickable URLs and basic PuTTY won't open the links)

### 28th Feb 2020 Thanks to SNBForums member @juched  for hosting the Ad Block  files on his Github ###
```
+======================================================================+
|  Welcome to the unbound Manager/Installation script (Asuswrt-Merlin) |
|                                                                      |
|                      Version 3.24 by Martineau                       |
|                                                                      |
| Requirements: USB drive with Entware installed                       |
|                                                                      |
|   i = Install unbound DNS Server - Advanced Mode                     |
|       o1. Enable unbound Logging                                     |
|       o2. Integrate with Stubby (Advanced Users)                     |
|       o3. Install Ad and Tracker Blocking                            |
|       o4. Customise CPU/Memory usage                                 |
|       o5. Disable Firefox DNS-over-HTTPS (DoH) (USA users)           |
|       o6. Install Graphical Statistics GUI (Add-ons) TAB             |
|       o7. Integrate with DoT (Advanced Users)                        |
|       o8. Enable DNS Firewall                                        |
|                                                                      |
|   z  = Remove unbound/unbound_manager                                |
|   ?  = About Configuration                                           |
|   3  = Advanced Tools                                                |
|                                                                      |
|     See SNBForums thread https://tinyurl.com/s89z3mm for helpful     |
|         user tips on unbound usage/configuration.                    |
+======================================================================+
1  = Begin unbound Installation Process 		
2  = Remove unbound/unbound_manager		
3  = n/a Start unbound		
4  = n/a Show unbound statistics		
5  = n/a Install Ad and Tracker blocker (Ad Block)		
6  = n/a Install Graphical Statistics GUI Add-on TAB
7  = n/a Enable DNS Firewall [?]


unbound (pid 3113) is running... uptime: 0 Days, 01:14:24 version: 1.11.0 (# Version v1.11 (Date Loaded by unbound_installer Tue Apr 14 17:26:55 DST 2020))


i  = Update unbound Installation ('/opt/var/lib/unbound/')      l  = Show unbound LIVE log entries (lx=Disable Logging)
z  = Remove Existing unbound Installation                       v  = View ('/opt/var/lib/unbound/') unbound Configuration (vx=Edit; vh=View Example Configuration) 
3  = Advanced Tools                                             rl = Reload Configuration (Doesn't halt unbound) e.g. 'rl test1[.conf]' (Recovery use 'rl reset/user')
?  = About Configuration                                        oq = Query unbound Configuration option e.g 'oq verbosity' (ox=Set) e.g. 'ox log-queries yes'

rs = Restart (or Start) unbound                                 s  = Show unbound statistics (s=Summary Totals; sa=All; s+=Enable Extended Stats)

e  = Exit Script

A:Option ==> ?

	Version: v3.24
	Local						md5=6b4a500c071bcbb3f4a6e9596a178d43
	Github						md5=6b4a500c071bcbb3f4a6e9596a178d43
	/jffs/addons/unbound/unbound_manager.md5	md5=6b4a500c071bcbb3f4a6e9596a178d43
```

##### New in **v1.20** is the ability to specify which *User Selectable options* are to be installed without having to _manually_ reply to each individual feature prompt

 e.g. Auto install both options 

     o4. Customise CPU/Memory usage (Advanced Users)   
     o5. Disable Firefox DNS-over-HTTPS (DoH) (USA users)  
```
e  = Exit Script

Option ==> i 5 4

<snip>

Customising Unbound configuration Options:
Option Auto Reply 'y'	Customising Unbound Performance/Memory 'proc/sys/net' parameters
	stuning downloaded successfully
Applying Unbound Performance/Memory tweaks using '/jffs/scripts/stuning'
Restarting dnsmasq.....
Done.
 Starting unbound...              done. 
Option Auto Reply 'y'	Installing Firefox DNS-over-HTTPS (DoH) DISABLE/Blocker....
	adblock/firefox_DOH downloaded successfully
Adding Firefox DoH 'include: /opt/var/lib/unbound/adblock/firefox_DOH'

<snip>

Auto install Customisation complete 0 minutes and 48 seconds elapsed - Please wait for up to 10 seconds for status.....


Option ==> ?

	Version=1.24
	Local					md5=f94581fc563a351b6caddc27607b0b3a
	Github					md5=f94581fc563a351b6caddc27607b0b3a
	/jffs/scripts/unbound_manager.md5	md5=f94581fc563a351b6caddc27607b0b3a


	Router Configuration recommended pre-reqs status:

	[✔] Swapfile=262140 kB
	[✖] ***ERROR DNS Filter is OFF!  						see http://10.88.8.1/DNSFilter.asp LAN->DNSFilter Enable DNS-based Filtering
	[✖] ***ERROR WAN: Use local caching DNS server as system resolver=YES  		see http://10.88.8.1/Tools_OtherSettings.asp ->Advanced Tweaks and Hacks
	[✖] ***ERROR Enable local NTP server=NO  					see http://10.88.8.1/Advanced_System_Content.asp ->Basic Config
	[✔] Enable DNS Rebind protection=NO
	[✔] Enable DNSSEC support=NO

	Options (Auto Reply=Y for Options '4 5'):

	[✔] Unbound CPU/Memory Performance tweaks
	[✔] Firefox DNS-over-HTTPS (DoH) DISABLE/Blocker

```
The script will remember the Auto Selected Options (for the *current* session) so you may simply specify the additional Auto install Option feature(s)

 e.g. include additional option

     o3. Ad and Tracker Blocking

```
e  = Exit Script

Option ==> i 3

<snip>

	Options (Auto Reply=Y for Options '3 4 5'):

	[✔] Ad and Tracker Blocking (No. of Adblock domains 63400, - Warning Diversion is also ACTIVE)
	[✔] Unbound CPU/Memory Performance tweaks
	[✔] Firefox DNS-over-HTTPS (DoH) DISABLE/Blocker

```
To Auto reply to **ALL** of the *Selectable User Options*, rather than _manually_ enter the complete list, simply use:

```
e  = Exit Script

Option ==> i all
```

To reinstate **ALL** *Selectable User Option* prompts issue

```
e  = Exit Script

Option ==> i?
```

You can override the default **'Easy mode'** startup i.e switch to **'Advanced mode'** from the command line by using
```
unbound_manager advanced
```
or you can quickly change modes at the option prompt

```
e  = Exit Script

E:Option ==> [ easy | advanced ]
```

# A very succinct description of the implication/use of the option Stubby-Integration #

Courtesty of SNB Forum member @dave14305 [post _1177_](https://www.snbforums.com/threads/unbound-authoritative-recursive-caching-dns-server.58967/page-59#post-549312 "SNB Forums")

Instead of relying on a Google DNS, Cloudflare, Quad9 or NextDNS, Unbound will let you perform the same DNS functions as those public resolvers. Unbound will deal directly with the authoritative name server (i.e. domain owner) instead of relying on a third-party to do that. You cut out that middle-man. If you only want to use Unbound as another forwarder, it's won't really offer much benefit over the built-in dnsmasq.

When Unbound gets a DNS request from a client, it will not use a single upstream server like you may be used to. Say it gets a request to lookup www.snbforums.com. First it will query the root DNS servers to see what server is the owner of the .com top-level domain. Once it knows that server identity, it will query that one to see which DNS nameserver owns snbforums.com within the .com domain. Once it gets that response, it will query the snbforums.com DNS server to get the IP for www within snbforums.com.

It does all that directly between you and those servers, without sharing your DNS query data with a third-party DNS resolver like the ones I mentioned earlier. 
