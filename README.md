# power-led installer
an easy and straightforward way to install ectool, and power-led at the same time.
## what is power-led?

**A script that changes the color of the power button light** on 11th and 12th gen Framework 13 Laptops.

After seeing that it was possible to change the LED color of the power button i thought it would be great to use it as battery indicator, from this i made i tiny 10 lines script that would change it automatically. from that point it escalated into service files and i enjoyed the journey so continued, now i made a setup to automatically deploy it, download ectool, move it and most importantly: **it cleans up after itself**! Hope you like it!

# installation:
## One line command:
This command has been tested on: Ubuntu, Fedora and Arch
```
git clone https://github.com/Player6734/power-led.git /home/$USER/Downloads/power-led_SETUP ; cd /home/$USER/Downloads/power-led_SETUP ; sudo bash ./setup.sh ; cd ; rm -rf /home/$USER/Downloads/power-led_SETUP
```
#### this does the following:

Clone the repository:
```
git clone https://github.com/Player6734/power-led.git /home/$USER/Downloads/power-led_SETUP
```
Enter the direcotry:
```
cd /home/$USER/Downloads/power-led_SETUP
```
Run setup.sh as root:
```
sudo bash ./setup.sh
```
Goes back to user directory:
```
cd
```
Cleans up the repo:
```
rm -rf /home/$USER/Downloads/power-led_SETUP
```

# Issues
- ~~The light hangs on for too long when laptop is shutdown or restarted. (WIP)~~
