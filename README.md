### Dependencies

For MKG installation and guidelines, please refer to the companion Wiki:   

https://github.com/fabnicol/mkg/wiki

More specifically for dependencies:

https://github.com/fabnicol/mkg/wiki/Frequently-Asked-Questions-(FAQ)#what-dependencies-should-be-installed

### Portability source code

The auxiliary tool `uuid` is an obligatory dependency of MKG.   
The source package of the `uuid` auxiliary tool has been added to enhance
portability.   
Should you need to install it, please perform installation as follows:
   
+ unpack: `tar xzvf libuuid-1.0.3a.tar.gz`   
+ cd libuuid-1.0.3
+ ./configure && make && sudo make install

Finally check that `which uuid` has zero exit code.

The ` logtool`  utility is not an MKG dependency but may be used for to monitor builds. Install the package as for libuuid:   

+ unpack: `tar xzvf logtool_1.2.11.tar.gz`   
+ cd logtool-1.2.11
+ ./configure && make && sudo make install



