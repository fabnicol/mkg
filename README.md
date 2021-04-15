#### Dependencies

For MKG installation and guidelines, please refer to the **companion Wiki**:   

https://github.com/fabnicol/mkg/wiki

More specifically for dependencies:

https://github.com/fabnicol/mkg/wiki/Frequently-Asked-Questions-(FAQ)#what-dependencies-should-be-installed

Docker images should be not be fetched in the Packages section of this site, but as Releases in the [**mkg_docker_image**](https://github.com/fabnicol/mkg_docker_image/releases) repository.

#### Portability source code

The auxiliary tool `uuid` is an obligatory dependency of MKG.   
On Debian-style platforms, use `sudo apt install uuid`.   
On Gentoo itself as a host, use `emerge -u sys-apps/util-linux`.    
MKG will then make use of `uuidgen` instead of `uuid`.    
For other platforms, the source package of the `uuid` auxiliary tool has been added to enhance
portability.   
Should you need to install it, please perform installation as follows:
   
+ unpack: `tar xzvf libuuid-1.0.3a.tar.gz`   
+ cd libuuid-1.0.3
+ ./configure && make && sudo make install

Finally check that `which uuid` has zero exit code.




