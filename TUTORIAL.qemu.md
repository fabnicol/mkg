Mounting a VDI file with qemu-nbd  
---------------------------------  

`$ sudo modprobe nbd`   
`$ qemu-nbd -c /dev/nbd0 [vdi-file]`   

**Example:**

Connect VDI to loopback device /dev/nbd0:       
   
`$ qemu-nbd -c /dev/nbd0 /home/test/ubuntu.vdi`   
   
You can check the partitions in the image 
using the following command:

`$ sudo fdisk -l /dev/nbd0`    

If you want to mount the first partition 
of the NBD device, use the following command:    
   
`$ sudo mount /dev/nbd0p1 /mnt`   

Finally, unmount /mnt then shutdown nbd services
using the following command:    

`$ sudo qemu-nbd -d /dev/nbd0`  

It is advised to add --read-only before the first 
command if not editing a file, as a security step.   

Converting a VDI file into a partition   
--------------------------------------

Use qemu-img:   

`$ sudo qemu-img convert -m J -p -f vdi [vdi-file] /dev/sdX`      

where J is the number of threads allowed.  
