#                                 MKG Cheatsheet
     
     
| **Running MKG in containers**         |                                              |
|:--------------------------------------|:---------------------------------------------|
| `# mkg dockerize`                     | Running a container for Plasma.              |
|                                       |                                              |
| `$ git checkout gnome`                |                                              |
| `# mkg dockerize gentoo.iso`          | Running a container for Gnome.               |
|                                       |                                              |
| `# docker exec -it ID bash`           | Check job log                                |
| `cont# tail -f nohup.out`             |                                              |
| or:                                   |                                              |
| `grep -E '\[\w{3}\]' /var/log/syslog` | Host log search. Also echoes container logs. |
|                                       | Use `syslog.x` for older logs.               |
|                                       |                                              |
| `# docker cp ID:/mkg/gentoo.iso .`    | Fetch back MKG installer from container.     |
|                                       |                                              |
     
     
| **Running MKG with custom options**         |                                                                              |
|:--------------------------------------------|:-----------------------------------------------------------------------------|
| `# mkg use_mkg_workflow=false [...]`        | Do not use preprocessed live install CD from                                 |
|                                             | Github Actions workflow. You may use:                                        |
|                                             | `ncpus=X,` `bios, cflags, clonezilla_install`                                |
|                                             | `debug_mode, elist, emirrors, kernel_config`                                 |
|                                             | `minimal, minimal_size, ncpus, nonroot_user`                                 |
|                                             | `passwd, processor, rootpasswd, stage3`                                      |
|                                             | `vm_language.`                                                               |
|                                             |                                                                              |
|                                             | Main options:                                                                |
|                                             | `minimal`: just build a minimal desktop.                                     |
|                                             | `cflags=[...,...,...]`: CFLAGS options in list form.                         |
|                                             | `vm_language=..`: set platform language if non US-English (`fr`, `de`, etc.) |
|                                             |                                                                              |
|                                             |                                                                              |
| `# mkg use_clonezilla_workflow=false [...]` | Do not use preprocessed cclonezilla live CD from Github Actions workflow.    |
|                                             | Rebuild this CD again incorporating VirtualBox                               |
|                                             | from current Ubuntu repositories.                                            |
|                                             |                                                                              |
     
     
| **Reusing artifacts previously downloaded** |                                                            |
|:------------------------------------------|:-----------------------------------------------------------|
| `$ mkg custom_clonezilla=file [...]`      | Use this file as CloneZilla live CD.                       |
| `$ mkg download_clonezilla=false [...]`   | Use cached CloneZilla live CD from prior downloads.        |
| `$ mkg download_arch=false [...]`         | Use cached stage3 archive from prior downloads.            |
| `$ mkg download=false [...]`              | Use cached Gentoo minimal install CD from prior downloads. |
|                                           |                                                            |
   
   
| **Input/Output and Backup options**                       |                                                                                                       |
|:----------------------------------------------------------|:------------------------------------------------------------------------------------------------------|
| `$ mkg [...] burn`                                        | Burn Gentoo installer to DVD when processed.                                                          |
| `# mkg [...] hot_install ext_device=sdX`                  | Install Gentoo onto partition **/dev/sdX**.                                                           |
| `# mkg from_device ext_device=sdX \ gentoo.iso`           | Backup partition **/dev/sdX** into a CloneZilla installer **gentoo.iso**                              |
| `# mkg [...] from_iso gentoo.iso burn`                    | Burn **gentoo.iso** to disk.                                                                          |
| `# mkg [...] from_iso gentoo.iso \ ext_device=sdX`        | Create USB stick or any block device installer from **gentoo.iso**                                    |
| `# mkg [...] from_vm vm=... \ gentoo.iso`                 | Create CloneZilla installer image from VM (after VM completed processes and stopped.)                 |
| `# mkg [...] from_vm vm=... \ hot_install ext_device=sdX` | Directly install Gentoo to partition **/dev/sdX** from VM (after VM completed processes and stopped.) |
|                                                           |                                                                                                       |


| **Graphic display and Interaction**            |                                                                                                              |
|:-----------------------------------------------|:-------------------------------------------------------------------------------------------------------------|
| `$ mkg [...] gui=false`                        | Do not display VirtualBox guest in GUI.                                                                      |
| `$ mkg [...] interactive=false`                | Do not interact with user. To be used in scripts and containers, with caution.                               |
| `$ mkg [...] email=...@... \ email_passwd=...` | Send a meesage to email address with given user password upon completion. Not to be used in public networks. |
|                                                |                                                                                                              |

