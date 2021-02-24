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




