<div align="center">
  <img src="https://res.cloudinary.com/canonical/image/fetch/f_auto,q_auto,fl_sanitize,w_60,h_60/https://dashboard.snapcraft.io/site_media/appmedia/2019/05/multipass.png" width="60" height="60" />
  <img src="https://res.cloudinary.com/canonical/image/fetch/f_auto,q_auto,fl_sanitize,w_60,h_60/https://dashboard.snapcraft.io/site_media/appmedia/2018/11/image-juju-256.svg.png" width="60" height="60" />
</div>

<p align="center">
  <b>Multipass Juju</b>
  <br />
  <i>A simple script to get a Juju dev environment set up.</i>
</p>

---

The idea of this script is to spin up a multipass instance, install Juju, deploy the Dashboard, and expose all required ports.


**Usage**
```
./multipass.sh
Launch a Juju Multipass instance.

Syntax: ./multipass.sh [-h|n|c|d]
options:
-h     Show this help.
-n     Name of the multipass instance. [default: juju]
-c     Juju Channel. [default: latest/beta]
-d     Dev - install and run dotrun
```
